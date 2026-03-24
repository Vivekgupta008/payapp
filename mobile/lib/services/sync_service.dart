import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/transaction.dart';
import 'api_service.dart';
import 'offline_storage.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final ApiService _api = ApiService();
  final OfflineStorage _storage = OfflineStorage();
  final Connectivity _connectivity = Connectivity();

  StreamSubscription? _connectivitySub;
  Timer? _syncTimer;
  bool _isSyncing = false;

  // Callbacks for UI updates
  Function()? onSyncStarted;
  Function(int settled, int failed)? onSyncCompleted;
  Function(String error)? onSyncError;

  /// Start monitoring connectivity and sync when online
  void startMonitoring() {
    _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      (result) {
  final hasConnection = result != ConnectivityResult.none;
        if (hasConnection) {
          syncPendingTransactions();
        }
      },
    );

    // Also set up periodic sync
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => syncPendingTransactions(),
    );
  }

  /// Stop monitoring
  void stopMonitoring() {
    _connectivitySub?.cancel();
    _syncTimer?.cancel();
    _connectivitySub = null;
    _syncTimer = null;
  }

  /// Check if device is currently online
  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Sync all pending offline transactions to the backend
  Future<Map<String, int>> syncPendingTransactions() async {
    if (_isSyncing) return {'settled': 0, 'failed': 0};

    _isSyncing = true;
    onSyncStarted?.call();

    try {
      // Check connectivity
      final online = await isOnline();
      if (!online) {
        _isSyncing = false;
        return {'settled': 0, 'failed': 0};
      }

      // Get pending transactions
      final pending = await _storage.getPendingTransactions();
      if (pending.isEmpty) {
        _isSyncing = false;
        return {'settled': 0, 'failed': 0};
      }

      // Submit batch to backend
      final response = await _api.post('/api/sync/transactions', {
        'transactions': pending.map((tx) => tx.toJson()).toList(),
      });

      int settled = 0;
      int failed = 0;

      // Process results
      final results = response['results'] as List? ?? [];
      for (final result in results) {
        final nonce = result['nonce'];
        final status = result['status'];

        String newStatus;
        switch (status) {
          case 'settled':
            newStatus = 'settled';
            settled++;
            break;
          case 'duplicate':
            newStatus = 'settled'; // Already processed
            settled++;
            break;
          case 'fraud_flagged':
            newStatus = 'fraud_flagged';
            failed++;
            break;
          default:
            newStatus = 'failed';
            failed++;
        }

        await _storage.updateTransactionStatus(
          nonce,
          newStatus,
          syncedAt: DateTime.now().toIso8601String(),
          settledAt: newStatus == 'settled'
              ? DateTime.now().toIso8601String()
              : null,
        );
      }

      onSyncCompleted?.call(settled, failed);
      _isSyncing = false;
      return {'settled': settled, 'failed': failed};
    } catch (e) {
      print('Sync error: $e');
      onSyncError?.call(e.toString());
      _isSyncing = false;
      return {'settled': 0, 'failed': 0};
    }
  }

  /// Get sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    final pendingCount = await _storage.getPendingCount();
    final pendingAmount = await _storage.getTotalPending();
    final online = await isOnline();

    return {
      'pending_count': pendingCount,
      'pending_amount': pendingAmount,
      'is_online': online,
      'is_syncing': _isSyncing,
    };
  }
}
