import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/payment_token.dart';
import '../models/transaction.dart';
import '../config/constants.dart';

class OfflineStorage {
  static final OfflineStorage _instance = OfflineStorage._internal();
  factory OfflineStorage() => _instance;
  OfflineStorage._internal();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await openDatabase(
        AppConstants.dbName,
        version: AppConstants.dbVersion,
        onCreate: _createTables,
      );
    }
    
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux)) {
       sqfliteFfiInit();
       databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Offline tokens table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_tokens (
        token_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        amount REAL NOT NULL,
        issued_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        nonce TEXT NOT NULL UNIQUE,
        signature TEXT NOT NULL,
        is_consumed INTEGER DEFAULT 0
      )
    ''');

    // Offline transactions table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        token_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        receiver_id TEXT,
        receiver_name TEXT,
        amount REAL NOT NULL,
        nonce TEXT NOT NULL UNIQUE,
        signature TEXT NOT NULL,
        status TEXT DEFAULT 'pending_offline',
        created_at TEXT NOT NULL,
        synced_at TEXT,
        settled_at TEXT
      )
    ''');
  }

  // ─── Token Operations ──────────────────────────────────────

  Future<void> insertToken(PaymentToken token) async {
    final db = await database;
    await db.insert(
      'offline_tokens',
      token.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PaymentToken>> getActiveTokens() async {
    final db = await database;
    final results = await db.query(
      'offline_tokens',
      where: 'is_consumed = ?',
      whereArgs: [0],
    );
    return results
        .map((r) => PaymentToken.fromDbMap(r))
        .where((t) => !t.isExpired)
        .toList();
  }

  Future<void> markTokenConsumed(String tokenId) async {
    final db = await database;
    await db.update(
      'offline_tokens',
      {'is_consumed': 1},
      where: 'token_id = ?',
      whereArgs: [tokenId],
    );
  }

  Future<void> clearAllTokens() async {
    final db = await database;
    await db.delete('offline_tokens');
  }

  // ─── Transaction Operations ────────────────────────────────

  Future<int> insertTransaction(OfflineTransaction tx) async {
    final db = await database;
    return await db.insert(
      'offline_transactions',
      tx.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<OfflineTransaction>> getPendingTransactions() async {
    final db = await database;
    final results = await db.query(
      'offline_transactions',
      where: 'status = ?',
      whereArgs: ['pending_offline'],
      orderBy: 'created_at ASC',
    );
    return results.map((r) => OfflineTransaction.fromDbMap(r)).toList();
  }

  Future<List<OfflineTransaction>> getAllTransactions() async {
    final db = await database;
    final results = await db.query(
      'offline_transactions',
      orderBy: 'created_at DESC',
    );
    return results.map((r) => OfflineTransaction.fromDbMap(r)).toList();
  }

  Future<List<OfflineTransaction>> getTransactionsForUser(String userId) async {
    final db = await database;
    final results = await db.query(
      'offline_transactions',
      where: 'sender_id = ? OR receiver_id = ?',
      whereArgs: [userId, userId],
      orderBy: 'created_at DESC',
    );
    return results.map((r) => OfflineTransaction.fromDbMap(r)).toList();
  }

  Future<void> updateTransactionStatus(
    String nonce,
    String status, {
    String? syncedAt,
    String? settledAt,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{'status': status};
    if (syncedAt != null) updates['synced_at'] = syncedAt;
    if (settledAt != null) updates['settled_at'] = settledAt;

    await db.update(
      'offline_transactions',
      updates,
      where: 'nonce = ?',
      whereArgs: [nonce],
    );
  }

  Future<int> getPendingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM offline_transactions WHERE status = 'pending_offline'",
    );
    return result.first['cnt'] as int? ?? 0;
  }

  Future<double> getTotalPending() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM offline_transactions WHERE status = 'pending_offline'",
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
