import 'package:uuid/uuid.dart';

/// Status values for a PaymentBlob
class BlobStatus {
  static const String pendingSync = 'pending_sync';
  static const String synced = 'synced';
  static const String rejected = 'rejected';
}

/// A PaymentBlob represents a single offline payment capture.
/// It is decoupled from settlement — the blob is stored locally and
/// submitted to the backend when connectivity is restored.
///
/// This lives alongside the existing token-based OfflineTransaction.
/// Tokens gate how much can be spent offline; blobs record what was spent.
class PaymentBlob {
  final String id;
  final String senderId;
  final String receiverId;
  final double amount;
  final DateTime timestamp;
  final String nonce;
  final String deviceSignature; // placeholder — filled with dummy value for now
  String status; // BlobStatus constants
  final bool isOffline;
  final double offlineLimitAtTime; // limit cached in SharedPrefs at payment time

  PaymentBlob({
    String? id,
    required this.senderId,
    required this.receiverId,
    required this.amount,
    DateTime? timestamp,
    String? nonce,
    String deviceSignature = 'DEVICE_SIG_PLACEHOLDER',
    this.status = BlobStatus.pendingSync,
    required this.isOffline,
    required this.offlineLimitAtTime,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now(),
        nonce = nonce ?? const Uuid().v4(),
        deviceSignature = deviceSignature;

  // ── Serialization ────────────────────────────────────────────

  factory PaymentBlob.fromJson(Map<String, dynamic> json) {
    return PaymentBlob(
      id: json['id'] ?? const Uuid().v4(),
      senderId: json['sender_id'] ?? '',
      receiverId: json['receiver_id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      nonce: json['nonce'] ?? const Uuid().v4(),
      deviceSignature: json['device_signature'] ?? 'DEVICE_SIG_PLACEHOLDER',
      status: json['status'] ?? BlobStatus.pendingSync,
      isOffline: json['is_offline'] ?? true,
      offlineLimitAtTime: (json['offline_limit_at_time'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'nonce': nonce,
      'device_signature': deviceSignature,
      'status': status,
      'is_offline': isOffline,
      'offline_limit_at_time': offlineLimitAtTime,
    };
  }

  // ── SQLite helpers ───────────────────────────────────────────

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'nonce': nonce,
      'device_signature': deviceSignature,
      'status': status,
      'is_offline': isOffline ? 1 : 0,
      'offline_limit_at_time': offlineLimitAtTime,
    };
  }

  factory PaymentBlob.fromDbMap(Map<String, dynamic> map) {
    return PaymentBlob(
      id: map['id'] ?? const Uuid().v4(),
      senderId: map['sender_id'] ?? '',
      receiverId: map['receiver_id'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      nonce: map['nonce'] ?? const Uuid().v4(),
      deviceSignature: map['device_signature'] ?? 'DEVICE_SIG_PLACEHOLDER',
      status: map['status'] ?? BlobStatus.pendingSync,
      isOffline: (map['is_offline'] ?? 1) == 1,
      offlineLimitAtTime: (map['offline_limit_at_time'] ?? 0).toDouble(),
    );
  }

  // ── Convenience getters ──────────────────────────────────────

  bool get isPendingSync => status == BlobStatus.pendingSync;
  bool get isSynced => status == BlobStatus.synced;
  bool get isRejected => status == BlobStatus.rejected;

  String get statusDisplay {
    switch (status) {
      case BlobStatus.pendingSync:
        return 'Pending Sync';
      case BlobStatus.synced:
        return 'Synced';
      case BlobStatus.rejected:
        return 'Rejected';
      default:
        return status;
    }
  }
}
