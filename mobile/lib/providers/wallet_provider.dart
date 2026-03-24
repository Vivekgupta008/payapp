import 'package:flutter/material.dart';
import '../models/payment_token.dart';
import '../services/token_service.dart';
import '../services/sync_service.dart';

class WalletProvider extends ChangeNotifier {
  final TokenService _tokenService = TokenService();
  final SyncService _syncService = SyncService();

  List<PaymentToken> _tokens = [];
  double _offlineLimit = 0;
  double _offlineLimitRemaining = 0;
  double _riskScore = 0.5;
  Map<String, dynamic> _riskFactors = {};
  bool _isLoading = false;
  bool _isOnline = true;
  String? _error;

  List<PaymentToken> get tokens => _tokens;
  List<PaymentToken> get activeTokens =>
      _tokens.where((t) => t.isValid).toList();
  double get offlineLimit => _offlineLimit;
  double get offlineLimitRemaining => _offlineLimitRemaining;
  double get riskScore => _riskScore;
  Map<String, dynamic> get riskFactors => _riskFactors;
  bool get isLoading => _isLoading;
  bool get isOnline => _isOnline;
  String? get error => _error;
  double get availableBalance =>
      activeTokens.fold(0.0, (sum, t) => sum + t.amount);

  /// Request new offline tokens from backend
  Future<bool> requestTokens({double? amount}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _tokenService.requestTokens(amount: amount);
      _tokens = result['tokens'] as List<PaymentToken>;
      _offlineLimit = result['offline_limit'] as double;
      _offlineLimitRemaining = result['offline_limit_remaining'] as double;
      _riskScore = result['risk_score'] as double;
      _riskFactors = result['risk_factors'] as Map<String, dynamic>;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Load cached tokens (works offline)
  Future<void> loadCachedTokens() async {
    try {
      _tokens = await _tokenService.getActiveTokens();
      _isOnline = await _syncService.isOnline();
      notifyListeners();
    } catch (e) {
      print('Error loading cached tokens: $e');
    }
  }

  /// Find a suitable token for a payment
  Future<PaymentToken?> findTokenForPayment(double amount) async {
    return await _tokenService.findTokenForAmount(amount);
  }

  /// Mark a token as used after payment
  Future<void> consumeToken(String tokenId) async {
    await _tokenService.consumeToken(tokenId);
    for (final t in _tokens) {
      if (t.tokenId == tokenId) {
        t.isConsumed = true;
      }
    }
    _offlineLimitRemaining = activeTokens.fold(0.0, (s, t) => s + t.amount);
    notifyListeners();
  }

  /// Check connectivity status
  Future<void> checkConnectivity() async {
    _isOnline = await _syncService.isOnline();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
