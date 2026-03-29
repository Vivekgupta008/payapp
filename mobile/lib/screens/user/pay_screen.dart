import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction.dart';
import '../../models/payment_blob.dart';
import '../../services/qr_transfer.dart';
import '../../services/offline_limit_service.dart';
import '../../services/offline_queue_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/api_service.dart';
import '../../services/ble_service.dart';
import '../../config/theme.dart';

class PayScreen extends StatefulWidget {
  const PayScreen({super.key});

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  final _amountCtrl = TextEditingController();
  final _scanAmountCtrl = TextEditingController();

  // Token-based payment state (existing online flow)
  String? _qrData;
  bool _isProcessing = false;
  String? _error;
  String? _successMessage;

  // Scan-to-pay state (Case 1/2/3 — blob flow)
  MobileScannerController? _scannerCtrl;
  bool _isScanning = false;
  bool _isBLETransferring = false;
  ReceiverQRData? _scannedReceiver;

  final _limitService = OfflineLimitService();
  final _queueService = OfflineQueueService();
  final _connectivityService = ConnectivityService();
  final _bleService = BLEService();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _scanAmountCtrl.dispose();
    _scannerCtrl?.dispose();
    super.dispose();
  }

  // ── Scan-to-pay helpers ──────────────────────────────────────

  void _startScan() {
    _scannerCtrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    setState(() {
      _isScanning = true;
      _scannedReceiver = null;
      _error = null;
    });
  }

  void _stopScan() {
    _scannerCtrl?.dispose();
    _scannerCtrl = null;
    setState(() => _isScanning = false);
  }

  void _onQRDetected(BarcodeCapture capture) {
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    _stopScan();

    final receiver = QrTransferService.parseReceiveQR(raw);
    if (receiver == null) {
      setState(() => _error = 'Not a valid receive QR code. Ask the merchant for their QR.');
      return;
    }
    setState(() => _scannedReceiver = receiver);
    _showAmountDialog(receiver);
  }

  Future<void> _showAmountDialog(ReceiverQRData receiver) async {
    _scanAmountCtrl.clear();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pay ${receiver.receiverName}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _scanAmountCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                prefixStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                hintText: '0.00',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _processOfflinePayment(receiver);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Confirm Payment', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _processOfflinePayment(ReceiverQRData receiver) async {
    final amountStr = _scanAmountCtrl.text.trim();
    final amount = double.tryParse(amountStr);

    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }

    setState(() { _isProcessing = true; _error = null; _successMessage = null; });

    final auth = context.read<AuthProvider>();
    final senderId = auth.user?.id ?? '';

    // Check connectivity — route to online or offline path
    final isOnline = await _connectivityService.checkNow();

    if (isOnline) {
      // Case 2: sender online → normal API payment (backend handles offline receiver)
      await _processOnlinePayment(senderId, receiver, amount);
      return;
    }

    // Case 1: sender offline → PaymentBlob path
    final availableLimit = await _limitService.getAvailableLimit();
    if (amount > availableLimit) {
      setState(() {
        _error = 'Offline limit insufficient.\n'
            'Available: ₹${availableLimit.toStringAsFixed(2)}  |  '
            'Requested: ₹${amount.toStringAsFixed(2)}';
        _isProcessing = false;
      });
      return;
    }

    final blob = PaymentBlob(
      senderId: senderId,
      receiverId: receiver.receiverId,
      amount: amount,
      isOffline: true,
      offlineLimitAtTime: availableLimit,
    );

    await _queueService.enqueue(blob);
    await _limitService.deductFromLimit(amount);

    // Case 3: if receiver embedded a BLE UUID in their QR, attempt BLE transfer.
    // The blob is already in the sender's queue regardless of BLE outcome,
    // so it will be submitted to the backend when the sender comes online.
    bool? bleSuccess;
    if (receiver.bleUuid != null) {
      setState(() { _isProcessing = true; _isBLETransferring = true; });
      bleSuccess = await _bleService.sendBlobViaBLE(blob, receiver.bleUuid!);
      setState(() { _isBLETransferring = false; });
    }

    String successMsg;
    if (bleSuccess == true) {
      successMsg = 'Payment of ₹${amount.toStringAsFixed(2)} to '
          '${receiver.receiverName} sent via Bluetooth.';
    } else if (bleSuccess == false) {
      successMsg = 'Payment of ₹${amount.toStringAsFixed(2)} queued. '
          'Bluetooth transfer failed — will sync when online.';
    } else {
      successMsg = 'Payment of ₹${amount.toStringAsFixed(2)} to '
          '${receiver.receiverName} sent offline. Will sync when you reconnect.';
    }

    setState(() {
      _isProcessing = false;
      _scannedReceiver = null;
      _successMessage = successMsg;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('₹${amount.toStringAsFixed(2)} sent offline ✓'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _processOnlinePayment(
    String senderId,
    ReceiverQRData receiver,
    double amount,
  ) async {
    // Case 2: POST to /api/payments/online
    // Backend debits sender immediately; if receiver is offline, it holds
    // the credit — receiver claims it on next sync.
    try {
      final blob = PaymentBlob(
        senderId: senderId,
        receiverId: receiver.receiverId,
        amount: amount,
        isOffline: false,
        offlineLimitAtTime: 0,
        status: BlobStatus.synced,
      );

      await Future.wait([
        _queueService.enqueue(blob),
        _callOnlinePaymentApi(
          receiverId: receiver.receiverId,
          receiverName: receiver.receiverName,
          amount: amount,
          nonce: blob.nonce,
        ),
      ]);

      // Refresh wallet balance
      if (mounted) {
        await context.read<AuthProvider>().refreshUser();
      }

      setState(() {
        _isProcessing = false;
        _successMessage =
            'Payment of ₹${amount.toStringAsFixed(2)} to ${receiver.receiverName} sent!';
      });
    } catch (e) {
      setState(() {
        _error = 'Payment failed: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _callOnlinePaymentApi({
    required String receiverId,
    required String receiverName,
    required double amount,
    required String nonce,
  }) async {
    await _ApiHelper.postOnlinePayment(
      receiverId: receiverId,
      receiverName: receiverName,
      amount: amount,
      nonce: nonce,
    );
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
        actions: [
          // Offline limit badge in app bar
          FutureBuilder<double>(
            future: _limitService.getAvailableLimit(),
            builder: (ctx, snap) {
              final limit = snap.data ?? 0.0;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: wallet.isOnline
                          ? AppTheme.successColor.withOpacity(0.12)
                          : AppTheme.offlineColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      wallet.isOnline
                          ? 'Online'
                          : 'Offline limit: ₹${limit.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: wallet.isOnline
                            ? AppTheme.successColor
                            : AppTheme.offlineColor,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
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

            // ── Scan & Pay (Case 1: offline, Case 2: online) ──────
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Scan Merchant QR to Pay',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            if (_isScanning) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 280,
                  child: _scannerCtrl != null
                      ? MobileScanner(
                          controller: _scannerCtrl!,
                          onDetect: _onQRDetected,
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _stopScan,
                child: const Text('Cancel'),
              ),
            ] else ...[
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _startScan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan & Pay'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryColor),
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],

            if (_scannedReceiver != null && !_isScanning) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: AppTheme.primaryColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Paying: ${_scannedReceiver!.receiverName}',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_isBLETransferring) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Connecting via Bluetooth to send payment...',
                        style: TextStyle(fontSize: 13, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_isProcessing) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Generate Offline Token QR',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

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

/// Thin wrapper so pay_screen can call ApiService without importing Provider.
class _ApiHelper {
  static final _api = ApiService();

  static Future<void> postOnlinePayment({
    required String receiverId,
    required String receiverName,
    required double amount,
    required String nonce,
  }) async {
    await _api.post('/api/payments/online', {
      'receiver_id': receiverId,
      'receiver_name': receiverName,
      'amount': amount,
      'nonce': nonce,
    });
  }
}
