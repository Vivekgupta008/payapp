class OfflineTransaction {
  final String? id;
  final String tokenId;
  final String senderId;
  final String? receiverId;
  final String? receiverName;
  final double amount;
  final String nonce;
  final String signature;
  String status; // pending_offline, synced, settled, failed, fraud_flagged
  final String createdAt;
  String? syncedAt;
  String? settledAt;

  OfflineTransaction({
    this.id,
    required this.tokenId,
    required this.senderId,
    this.receiverId,
    this.receiverName,
    required this.amount,
    required this.nonce,
    required this.signature,
    this.status = 'pending_offline',
    String? createdAt,
    this.syncedAt,
    this.settledAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  factory OfflineTransaction.fromJson(Map<String, dynamic> json) {
    return OfflineTransaction(
      id: json['id'],
      tokenId: json['token_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      receiverId: json['receiver_id'],
      receiverName: json['receiver_name'] ?? json['counterparty_name'],
      amount: (json['amount'] ?? 0).toDouble(),
      nonce: json['nonce'] ?? '',
      signature: json['signature'] ?? '',
      status: json['status'] ?? 'pending_offline',
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
      syncedAt: json['synced_at'],
      settledAt: json['settled_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token_id': tokenId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'receiver_name': receiverName,
      'amount': amount,
      'nonce': nonce,
      'signature': signature,
      'device_timestamp': createdAt,
    };
  }

  // For SQLite storage
  Map<String, dynamic> toDbMap() {
    return {
      'token_id': tokenId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'receiver_name': receiverName,
      'amount': amount,
      'nonce': nonce,
      'signature': signature,
      'status': status,
      'created_at': createdAt,
      'synced_at': syncedAt,
      'settled_at': settledAt,
    };
  }

  factory OfflineTransaction.fromDbMap(Map<String, dynamic> map) {
    return OfflineTransaction(
      id: map['id']?.toString(),
      tokenId: map['token_id'] ?? '',
      senderId: map['sender_id'] ?? '',
      receiverId: map['receiver_id'],
      receiverName: map['receiver_name'],
      amount: (map['amount'] ?? 0).toDouble(),
      nonce: map['nonce'] ?? '',
      signature: map['signature'] ?? '',
      status: map['status'] ?? 'pending_offline',
      createdAt: map['created_at'] ?? DateTime.now().toIso8601String(),
      syncedAt: map['synced_at'],
      settledAt: map['settled_at'],
    );
  }

  bool get isPending => status == 'pending_offline';
  bool get isSettled => status == 'settled';
  bool get isFlagged => status == 'fraud_flagged';
  bool get isFailed => status == 'failed';

  String get statusDisplay {
    switch (status) {
      case 'pending_offline':
        return 'Completed (Offline)';
      case 'synced':
        return 'Synced';
      case 'settled':
        return 'Settled';
      case 'failed':
        return 'Failed';
      case 'fraud_flagged':
        return 'Under Review';
      default:
        return status;
    }
  }
}
