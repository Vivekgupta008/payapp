import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Manages the user's AI/ML-assigned offline credit limit.
///
/// The limit is fetched from the backend when online and cached in
/// SharedPreferences. It expires after 24 hours — if expired and the
/// device is offline, the available limit becomes ₹0.
///
/// After each offline payment the remaining limit is decremented locally.
/// When the user syncs, the backend recalculates and pushes a new limit.
class OfflineLimitService {
  static final OfflineLimitService _instance = OfflineLimitService._internal();
  factory OfflineLimitService() => _instance;
  OfflineLimitService._internal();

  // SharedPreferences keys
  static const String _keyLimit = 'offline_limit';
  static const String _keyRemaining = 'offline_limit_remaining';
  static const String _keyExpiry = 'offline_limit_expiry';

  static const Duration _limitTtl = Duration(hours: 24);

  final ApiService _api = ApiService();

  // ── Public API ────────────────────────────────────────────────

  /// Returns the currently available offline limit.
  /// Returns ₹0 if the cached limit has expired or was never fetched.
  Future<double> getAvailableLimit() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isExpired(prefs)) return 0.0;
    return prefs.getDouble(_keyRemaining) ?? 0.0;
  }

  /// Returns the total limit (not decremented by usage).
  /// Returns ₹0 if expired.
  Future<double> getTotalLimit() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isExpired(prefs)) return 0.0;
    return prefs.getDouble(_keyLimit) ?? 0.0;
  }

  /// Whether the cached limit is still valid (not expired).
  Future<bool> isLimitValid() async {
    final prefs = await SharedPreferences.getInstance();
    return !_isExpired(prefs);
  }

  /// Deducts [amount] from the locally cached remaining limit.
  /// Called immediately after each offline payment, before sync.
  Future<void> deductFromLimit(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getDouble(_keyRemaining) ?? 0.0;
    final updated = (current - amount).clamp(0.0, double.infinity);
    await prefs.setDouble(_keyRemaining, updated);
  }

  /// Fetches the limit from the backend and caches it locally.
  /// Should be called whenever the device comes online.
  /// Returns the new limit, or null on failure.
  Future<double?> fetchAndCacheLimit() async {
    try {
      final response = await _api.get('/api/user/offline-limit');
      final limit = (response['limit'] ?? 0).toDouble();
      final expiryStr = response['expiry'] as String?;

      final expiry = expiryStr != null
          ? DateTime.parse(expiryStr)
          : DateTime.now().add(_limitTtl);

      await _saveLimit(limit, expiry);
      return limit;
    } catch (_) {
      return null;
    }
  }

  /// Saves a new limit (called after a successful sync when the backend
  /// pushes a recalculated limit).
  Future<void> updateLimitFromSync(double newLimit) async {
    final expiry = DateTime.now().add(_limitTtl);
    await _saveLimit(newLimit, expiry);
  }

  /// Resets remaining limit back to total (e.g. after all blobs are settled).
  Future<void> resetRemainingToTotal() async {
    final prefs = await SharedPreferences.getInstance();
    final total = prefs.getDouble(_keyLimit) ?? 0.0;
    await prefs.setDouble(_keyRemaining, total);
  }

  // ── Private helpers ───────────────────────────────────────────

  bool _isExpired(SharedPreferences prefs) {
    final expiryStr = prefs.getString(_keyExpiry);
    if (expiryStr == null) return true;
    try {
      final expiry = DateTime.parse(expiryStr);
      return DateTime.now().isAfter(expiry);
    } catch (_) {
      return true;
    }
  }

  Future<void> _saveLimit(double limit, DateTime expiry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLimit, limit);
    await prefs.setDouble(_keyRemaining, limit);
    await prefs.setString(_keyExpiry, expiry.toIso8601String());
  }
}
