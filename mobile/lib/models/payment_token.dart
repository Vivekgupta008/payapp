class PaymentToken {
  final String tokenId;
  final String userId;
  final double amount;
  final String issuedAt;
  final String expiresAt;
  final String nonce;
  final String signature;
  bool isConsumed;

  PaymentToken({
    required this.tokenId,
    required this.userId,
    required this.amount,
    required this.issuedAt,
    required this.expiresAt,
    required this.nonce,
    required this.signature,
    this.isConsumed = false,
  });

  factory PaymentToken.fromJson(Map<String, dynamic> json) {
    return PaymentToken(
      tokenId: json['token_id'] ?? '',
      userId: json['user_id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      issuedAt: json['issued_at'] ?? '',
      expiresAt: json['expires_at'] ?? '',
      nonce: json['nonce'] ?? '',
      signature: json['signature'] ?? '',
      isConsumed: json['is_consumed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token_id': tokenId,
      'user_id': userId,
      'amount': amount,
      'issued_at': issuedAt,
      'expires_at': expiresAt,
      'nonce': nonce,
      'signature': signature,
      'is_consumed': isConsumed,
    };
  }

  /// Create the payment payload for QR code
  Map<String, dynamic> toPaymentPayload(double paymentAmount) {
    return {
      'token_id': tokenId,
      'user_id': userId,
      'amount': paymentAmount,
      'token_amount': amount,
      'issued_at': issuedAt,
      'expires_at': expiresAt,
      'nonce': nonce,
      'signature': signature,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  bool get isExpired {
    try {
      final expiry = DateTime.parse(expiresAt);
      return DateTime.now().isAfter(expiry);
    } catch (_) {
      return true;
    }
  }

  bool get isValid => !isConsumed && !isExpired;

  // For SQLite storage
  Map<String, dynamic> toDbMap() {
    return {
      'token_id': tokenId,
      'user_id': userId,
      'amount': amount,
      'issued_at': issuedAt,
      'expires_at': expiresAt,
      'nonce': nonce,
      'signature': signature,
      'is_consumed': isConsumed ? 1 : 0,
    };
  }

  factory PaymentToken.fromDbMap(Map<String, dynamic> map) {
    return PaymentToken(
      tokenId: map['token_id'] ?? '',
      userId: map['user_id'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      issuedAt: map['issued_at'] ?? '',
      expiresAt: map['expires_at'] ?? '',
      nonce: map['nonce'] ?? '',
      signature: map['signature'] ?? '',
      isConsumed: (map['is_consumed'] ?? 0) == 1,
    );
  }
}
