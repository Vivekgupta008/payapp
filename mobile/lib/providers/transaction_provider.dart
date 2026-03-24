import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/offline_storage.dart';
import '../services/sync_service.dart';
import '../services/api_service.dart';

class TransactionProvider extends ChangeNotifier {
  final OfflineStorage _storage = OfflineStorage();
  final SyncService _syncService = SyncService();
  final ApiService _api = ApiService();

  List<OfflineTransaction> _transactions = [];
  List<OfflineTransaction> _serverTransactions = [];
  int _pendingCount = 0;
  double _pendingAmount = 0;
  bool _isSyncing = false;
  String? _lastSyncError;

  List<OfflineTransaction> get transactions => _transactions;
  List<OfflineTransaction> get serverTransactions => _serverTransactions;
  List<OfflineTransaction> get allTransactions {
    // Merge local and server transactions, dedup by nonce
    final seen = <String>{};
    final merged = <OfflineTransaction>[];
    for (final tx in _transactions) {
      if (seen.add(tx.nonce)) merged.add(tx);
    }
    for (final tx in _serverTransactions) {
      if (seen.add(tx.nonce)) merged.add(tx);
    }
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  int get pendingCount => _pendingCount;
  double get pendingAmount => _pendingAmount;
  bool get isSyncing => _isSyncing;
  String? get lastSyncError => _lastSyncError;

  /// Load transactions from local storage
  Future<void> loadLocalTransactions({String? userId}) async {
    if (userId != null) {
      _transactions = await _storage.getTransactionsForUser(userId);
    } else {
      _transactions = await _storage.getAllTransactions();
    }
    _pendingCount = await _storage.getPendingCount();
    _pendingAmount = await _storage.getTotalPending();
    notifyListeners();
  }

  /// Store a new offline transaction
  Future<void> addTransaction(OfflineTransaction tx) async {
    await _storage.insertTransaction(tx);
    _transactions.insert(0, tx);
    _pendingCount++;
    _pendingAmount += tx.amount;
    notifyListeners();
  }

  /// Sync pending transactions with backend
  Future<Map<String, int>> syncTransactions() async {
    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    try {
      final result = await _syncService.syncPendingTransactions();
      // Reload local transactions to get updated statuses
      _transactions = await _storage.getAllTransactions();
      _pendingCount = await _storage.getPendingCount();
      _pendingAmount = await _storage.getTotalPending();
      _isSyncing = false;
      notifyListeners();
      return result;
    } catch (e) {
      _lastSyncError = e.toString();
      _isSyncing = false;
      notifyListeners();
      return {'settled': 0, 'failed': 0};
    }
  }

  /// Fetch transaction history from server
  Future<void> fetchServerTransactions({bool isUser = true}) async {
    try {
      final endpoint = isUser ? '/api/dashboard/user' : '/api/dashboard/merchant';
      final response = await _api.get(endpoint);
      final txList = response['recent_transactions'] as List? ?? [];
      _serverTransactions = txList.map((t) {
        return OfflineTransaction(
          id: t['id'],
          tokenId: t['token_id'] ?? '',
          senderId: '',
          receiverName: t['counterparty_name'],
          amount: (t['amount'] ?? 0).toDouble(),
          nonce: t['token_id'] ?? '',
          signature: '',
          status: t['status'] ?? 'settled',
          createdAt: t['created_at'] ?? DateTime.now().toIso8601String(),
          settledAt: t['settled_at'],
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      print('Error fetching server transactions: $e');
    }
  }

  /// Start background sync monitoring
  void startSync() {
    _syncService.onSyncCompleted = (settled, failed) {
      loadLocalTransactions();
    };
    _syncService.startMonitoring();
  }

  /// Stop background sync
  void stopSync() {
    _syncService.stopMonitoring();
  }
}
