import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction.dart';
import '../../services/qr_transfer.dart';
import '../../config/theme.dart';

class PayScreen extends StatefulWidget {
  const PayScreen({super.key});

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  final _amountCtrl = TextEditingController();
  String? _qrData;
  bool _isProcessing = false;
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _generatePayment() async {
    setState(() {
      _error = null;
      _successMessage = null;
      _qrData = null;
    });

    final amountStr = _amountCtrl.text.trim();
    if (amountStr.isEmpty) {
      setState(() => _error = 'Please enter an amount');
      return;
    }

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }

    if (amount > 5000) {
      setState(() => _error = 'Maximum offline payment is ₹5,000');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final wallet = context.read<WalletProvider>();
      final auth = context.read<AuthProvider>();

      // Find a suitable token
      final token = await wallet.findTokenForPayment(amount);
      if (token == null) {
        setState(() {
          _error = 'No available tokens for this amount. '
              'Available balance: ₹${wallet.availableBalance.toStringAsFixed(2)}';
          _isProcessing = false;
        });
        return;
      }

      // Generate QR code
      final qrPayload = QrTransferService.generatePaymentQR(
        token: token,
        paymentAmount: amount,
        senderName: auth.user?.fullName ?? 'User',
      );

      setState(() {
        _qrData = qrPayload;
        _isProcessing = false;
        _successMessage = 'Show this QR to the merchant';
      });
    } catch (e) {
      setState(() {
        _error = 'Error generating payment: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _confirmPayment() async {
    if (_qrData == null) return;

    final wallet = context.read<WalletProvider>();
    final txProvider = context.read<TransactionProvider>();
    final auth = context.read<AuthProvider>();

    // Parse the QR data to extract token info
    final paymentData = QrTransferService.parsePaymentQR(_qrData!);
    if (paymentData == null) return;

    // Mark token as consumed
    await wallet.consumeToken(paymentData['token_id']);

    // Record transaction locally
    final tx = OfflineTransaction(
      tokenId: paymentData['token_id'],
      senderId: auth.user?.id ?? '',
      receiverName: 'Merchant',
      amount: (paymentData['amount'] as num).toDouble(),
      nonce: paymentData['nonce'],
      signature: paymentData['signature'],
      status: 'pending_offline',
    );
    await txProvider.addTransaction(tx);

    setState(() {
      _qrData = null;
      _successMessage = 'Payment of ₹${paymentData['amount']} confirmed!';
      _amountCtrl.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Payment recorded (offline)'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Make Payment'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Available balance
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.secondaryColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet,
                      color: AppTheme.secondaryColor),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available for Offline Payment',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        formatter.format(wallet.availableBalance),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${wallet.activeTokens.length} tokens',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Amount Input
            const Text(
              'Enter Amount',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold),
                hintText: '0.00',
                hintStyle: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade300,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            // Quick amounts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [50, 100, 200, 500].map((amount) {
                return ActionChip(
                  label: Text('₹$amount'),
                  onPressed: () {
                    _amountCtrl.text = amount.toString();
                  },
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.05),
                  side: BorderSide(
                      color: AppTheme.primaryColor.withOpacity(0.2)),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Error
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.errorColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: AppTheme.errorColor, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Generate QR button
            if (_qrData == null)
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _generatePayment,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.qr_code),
                  label: Text(
                    _isProcessing ? 'Processing...' : 'Generate Payment QR',
                  ),
                ),
              ),

            // QR Code display
            if (_qrData != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Show this QR to Merchant',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Merchant will scan to accept payment',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: QrImageView(
                        data: _qrData!,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.circle,
                          color: AppTheme.primaryColor,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.circle,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _qrData = null;
                              _successMessage = null;
                            });
                          },
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _confirmPayment,
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Confirm Paid'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Success message
            if (_successMessage != null && _qrData == null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.successColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppTheme.successColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
