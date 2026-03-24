class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String role; // "user" or "merchant"
  final int kycTier;
  final double balance;
  final double offlineLimit;
  final double offlineLimitUsed;
  final double deviceTrustScore;
  final bool isActive;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
    this.kycTier = 1,
    this.balance = 0.0,
    this.offlineLimit = 0.0,
    this.offlineLimitUsed = 0.0,
    this.deviceTrustScore = 0.5,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'],
      role: json['role'] ?? 'user',
      kycTier: json['kyc_tier'] ?? 1,
      balance: (json['balance'] ?? 0).toDouble(),
      offlineLimit: (json['offline_limit'] ?? 0).toDouble(),
      offlineLimitUsed: (json['offline_limit_used'] ?? 0).toDouble(),
      deviceTrustScore: (json['device_trust_score'] ?? 0.5).toDouble(),
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'role': role,
      'kyc_tier': kycTier,
      'balance': balance,
      'offline_limit': offlineLimit,
      'offline_limit_used': offlineLimitUsed,
      'device_trust_score': deviceTrustScore,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isUser => role == 'user';
  bool get isMerchant => role == 'merchant';
  double get offlineLimitRemaining => offlineLimit - offlineLimitUsed;

  AppUser copyWith({
    double? balance,
    double? offlineLimit,
    double? offlineLimitUsed,
  }) {
    return AppUser(
      id: id,
      email: email,
      fullName: fullName,
      phone: phone,
      role: role,
      kycTier: kycTier,
      balance: balance ?? this.balance,
      offlineLimit: offlineLimit ?? this.offlineLimit,
      offlineLimitUsed: offlineLimitUsed ?? this.offlineLimitUsed,
      deviceTrustScore: deviceTrustScore,
      isActive: isActive,
      createdAt: createdAt,
    );
  }
}
