import 'dart:convert';
import '../models/payment_token.dart';
import '../models/transaction.dart';

class QrTransferService {
  /// Generate QR code data for a payment
  /// This encodes the signed token + payment amount into a JSON string
  static String generatePaymentQR({
    required PaymentToken token,
    required double paymentAmount,
    required String senderName,
  }) {
    final payload = {
      'type': 'offline_payment',
      'version': 1,
      'token_id': token.tokenId,
      'user_id': token.userId,
      'amount': paymentAmount,
      'token_amount': token.amount,
      'issued_at': token.issuedAt,
      'expires_at': token.expiresAt,
      'nonce': token.nonce,
      'signature': token.signature,
      'sender_name': senderName,
      'timestamp': DateTime.now().toIso8601String(),
    };

    return jsonEncode(payload);
  }

  /// Parse a scanned QR code and extract payment data
  static Map<String, dynamic>? parsePaymentQR(String qrData) {
    try {
      final data = jsonDecode(qrData);

      // Validate it's an offline payment QR
      if (data['type'] != 'offline_payment') return null;

      // Required fields check
      final requiredFields = [
        'token_id', 'user_id', 'amount', 'nonce', 'signature',
      ];
      for (final field in requiredFields) {
        if (data[field] == null) return null;
      }

      return data;
    } catch (_) {
      return null;
    }
  }

  /// Validate payment data locally (no network needed)
  static PaymentValidation validatePayment(Map<String, dynamic> paymentData) {
    // Check expiry
    final expiresAt = paymentData['expires_at'];
    if (expiresAt != null) {
      try {
        final expiry = DateTime.parse(expiresAt);
        if (DateTime.now().isAfter(expiry)) {
          return PaymentValidation(
            isValid: false,
            error: 'Payment token has expired',
          );
        }
      } catch (_) {
        return PaymentValidation(
          isValid: false,
          error: 'Invalid expiry date',
        );
      }
    }

    // Check amount
    final amount = (paymentData['amount'] as num?)?.toDouble() ?? 0;
    final tokenAmount = (paymentData['token_amount'] as num?)?.toDouble() ?? 0;
    if (amount <= 0) {
      return PaymentValidation(
        isValid: false,
        error: 'Invalid payment amount',
      );
    }
    if (amount > tokenAmount) {
      return PaymentValidation(
        isValid: false,
        error: 'Payment amount exceeds token limit',
      );
    }

    // Check signature exists
    if (paymentData['signature'] == null ||
        paymentData['signature'].toString().isEmpty) {
      return PaymentValidation(
        isValid: false,
        error: 'Missing payment signature',
      );
    }

    return PaymentValidation(
      isValid: true,
      amount: amount,
      senderName: paymentData['sender_name'] ?? 'Unknown',
      senderId: paymentData['user_id'] ?? '',
      tokenId: paymentData['token_id'] ?? '',
      nonce: paymentData['nonce'] ?? '',
      signature: paymentData['signature'] ?? '',
    );
  }

  /// Create a transaction record from validated payment data
  static OfflineTransaction createTransactionFromPayment(
    Map<String, dynamic> paymentData, {
    required String merchantId,
    required String merchantName,
  }) {
    return OfflineTransaction(
      tokenId: paymentData['token_id'],
      senderId: paymentData['user_id'],
      receiverId: merchantId,
      receiverName: merchantName,
      amount: (paymentData['amount'] as num).toDouble(),
      nonce: paymentData['nonce'],
      signature: paymentData['signature'],
      status: 'pending_offline',
      createdAt: DateTime.now().toIso8601String(),
    );
  }
}

class PaymentValidation {
  final bool isValid;
  final String? error;
  final double? amount;
  final String? senderName;
  final String? senderId;
  final String? tokenId;
  final String? nonce;
  final String? signature;

  PaymentValidation({
    required this.isValid,
    this.error,
    this.amount,
    this.senderName,
    this.senderId,
    this.tokenId,
    this.nonce,
    this.signature,
  });
}
