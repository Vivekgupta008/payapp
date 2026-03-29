import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// A standalone stream-based connectivity service.
///
/// All UI widgets and offline-payment logic subscribe to [statusStream]
/// so the entire app reacts live when the device goes online/offline.
/// SyncService and other services delegate to this instead of creating
/// their own Connectivity instances.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  // Broadcast so multiple listeners (UI + SyncService + BLE logic) can subscribe
  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  StreamSubscription<ConnectivityResult>? _sub;
  bool _isOnline = true;

  /// Live stream of online/offline state. `true` = online.
  Stream<bool> get statusStream => _controller.stream;

  /// Last known connectivity state (synchronous read).
  bool get isOnline => _isOnline;

  /// Start listening to platform connectivity events.
  /// Safe to call multiple times — re-entrant.
  void startListening() {
    if (_sub != null) return;
    _sub = _connectivity.onConnectivityChanged.listen(_onResult);
  }

  /// Stop listening (call in dispose / app background).
  void stopListening() {
    _sub?.cancel();
    _sub = null;
  }

  /// One-shot async check — refreshes [isOnline] and emits to stream.
  Future<bool> checkNow() async {
    final result = await _connectivity.checkConnectivity();
    _onResult(result);
    return _isOnline;
  }

  void _onResult(ConnectivityResult result) {
    final online = result != ConnectivityResult.none;
    if (online != _isOnline) {
      _isOnline = online;
      _controller.add(_isOnline);
    }
  }
}
