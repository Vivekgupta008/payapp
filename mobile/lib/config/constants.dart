import 'package:flutter/foundation.dart';

class AppConstants {
  // Backend API URL - change this to your server address
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String publicKeyKey = 'server_public_key';
  static const String offlineTokensKey = 'offline_tokens';

  // Database
  static const String dbName = 'offline_pay.db';
  static const int dbVersion = 1;

  // Token settings
  static const int maxOfflineTokens = 10;
  static const Duration tokenCheckInterval = Duration(minutes: 5);

  // Sync settings
  static const Duration syncInterval = Duration(seconds: 30);
  static const int maxSyncRetries = 3;
}
