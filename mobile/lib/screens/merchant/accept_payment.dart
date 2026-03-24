import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/qr_transfer.dart';
import '../../config/theme.dart';

class AcceptPaymentScreen extends StatefulWidget {
  const AcceptPaymentScreen({super.key});

  @override
  State<AcceptPaymentScreen> createState() => _AcceptPaymentScreenState();
}

class _AcceptPaymentScreenState extends State<AcceptPaymentScreen> {
  MobileScannerController? _scannerCtrl;
  bool _isScanning = false;
  PaymentValidation? _validation;
  Map<String, dynamic>? _paymentData;
  bool _paymentAccepted = false;

  void _startScanning() {
    _scannerCtrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    setState(() {
      _isScanning = true;
      _validation = null;
      _paymentData = null;
      _paymentAccepted = false;
    });
  }

  void _stopScanning() {
    _scannerCtrl?.dispose();
    _scannerCtrl = null;
    setState(() => _isScanning = false);
  }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final qrData = barcode!.rawValue!;
    _stopScanning();

    // Parse and validate the QR data
    final data = QrTransferService.parsePaymentQR(qrData);
    if (data == null) {
      setState(() {
        _validation = PaymentValidation(
          isValid: false,
          error: 'Invalid QR code - not an OfflinePay payment',
        );
      });
      return;
    }

    final validation = QrTransferService.validatePayment(data);
    setState(() {
      _validation = validation;
      _paymentData = data;
    });
  }

  Future<void> _acceptPayment() async {
    if (_paymentData == null || _validation == null || !_validation!.isValid) {
      return;
    }

    final auth = context.read<AuthProvider>();
    final txProvider = context.read<TransactionProvider>();

    // Create transaction record
    final tx = QrTransferService.createTransactionFromPayment(
      _paymentData!,
      merchantId: auth.user?.id ?? '',
      merchantName: auth.user?.fullName ?? 'Merchant',
    );

    // Store locally
    await txProvider.addTransaction(tx);

    setState(() => _paymentAccepted = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment of ₹${_validation!.amount?.toStringAsFixed(2)} accepted!',
          ),
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
  void dispose() {
    _scannerCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Accept Payment'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            if (!_isScanning && _validation == null) ...[
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner,
                    size: 64,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Scan Customer QR Code',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ask the customer to show their payment QR code.\n'
                'No internet needed to accept payments!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _startScanning,
                  icon: const Icon(Icons.qr_code_scanner, size: 24),
                  label: const Text(
                    'Start Scanning',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],

            // Scanner
            if (_isScanning) ...[
              const Text(
                'Point camera at customer\'s QR code',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 350,
                  child: _scannerCtrl != null
                      ? MobileScanner(
                          controller: _scannerCtrl!,
                          onDetect: _onDetect,
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _stopScanning,
                child: const Text('Cancel Scan'),
              ),
            ],

            // Validation result
            if (_validation != null && !_paymentAccepted) ...[
              const SizedBox(height: 16),
              if (_validation!.isValid) ...[
                // Valid payment
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.successColor.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.successColor.withOpacity(0.1),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.verified,
                        color: AppTheme.successColor,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Payment Verified',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _DetailRow(
                              label: 'Amount',
                              value: formatter.format(_validation!.amount),
                              bold: true,
                            ),
                            _DetailRow(
                              label: 'From',
                              value: _validation!.senderName ?? 'Unknown',
                            ),
                            _DetailRow(
                              label: 'Token ID',
                              value: _validation!.tokenId?.substring(0, 8) ?? '',
                              mono: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _validation = null;
                                  _paymentData = null;
                                });
                              },
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _acceptPayment,
                              icon: const Icon(Icons.check),
                              label: const Text('Accept Payment'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.successColor,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Invalid payment
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.errorColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.errorColor,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Invalid Payment',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.errorColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _validation!.error ?? 'Unknown error',
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _startScanning,
                        child: const Text('Scan Again'),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            // Payment accepted
            if (_paymentAccepted) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.successColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(36),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 48,
                        color: AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Payment Accepted! ✅',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatter.format(_validation?.amount ?? 0),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stored offline. Will settle when connected.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _validation = null;
                            _paymentData = null;
                            _paymentAccepted = false;
                          });
                          _startScanning();
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Accept Another Payment'),
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool mono;

  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: bold ? 18 : 14,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}
