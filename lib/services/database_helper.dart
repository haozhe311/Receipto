import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:receipto/models/transaction.dart' as model;

/// Singleton helper for managing the local SQLite database.
///
/// Handles schema creation, CRUD operations for transactions,
/// key-value settings storage, and JSON export/import for backup.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _dbName = 'receipto.db';
  static const int _dbVersion = 1;

  // Table and column names
  static const String tableTransactions = 'transactions';
  static const String tableSettings = 'settings';

  Database? _database;

  /// Returns the database instance, creating it on first access.
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  /// Creates the database tables on first launch.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableTransactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        merchant TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        is_ocr INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSettings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ---------------------------------------------------------------------------
  // Transaction CRUD
  // ---------------------------------------------------------------------------

  /// Inserts a new transaction and returns the auto-generated row ID.
  Future<int> insertTransaction(model.Transaction transaction) async {
    final db = await database;
    return await db.insert(tableTransactions, transaction.toMap());
  }

  /// Retrieves transactions with optional category and date range filters.
  /// Results are ordered by date descending (most recent first).
  Future<List<model.Transaction>> getTransactions({
    String? category,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;

    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (category != null) {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }
    if (from != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(from.toIso8601String().split('T').first);
    }
    if (to != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(to.toIso8601String().split('T').first);
    }

    final result = await db.query(
      tableTransactions,
      where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date DESC, created_at DESC',
    );

    return result.map((map) => model.Transaction.fromMap(map)).toList();
  }

  /// Retrieves the most recent [limit] transactions for AI chatbot context.
  Future<List<model.Transaction>> getRecentTransactions(int limit) async {
    final db = await database;
    final result = await db.query(
      tableTransactions,
      orderBy: 'date DESC, created_at DESC',
      limit: limit,
    );
    return result.map((map) => model.Transaction.fromMap(map)).toList();
  }

  /// Updates an existing transaction. Returns the number of rows affected.
  Future<int> updateTransaction(model.Transaction transaction) async {
    final db = await database;
    return await db.update(
      tableTransactions,
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  /// Deletes a transaction by ID. Returns the number of rows deleted.
  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      tableTransactions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Returns the total spending for a given month (defaults to current month).
  Future<double> getMonthlyTotal({DateTime? month}) async {
    final db = await database;
    final now = month ?? DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM $tableTransactions '
      'WHERE date >= ? AND date <= ?',
      [
        firstDay.toIso8601String().split('T').first,
        lastDay.toIso8601String().split('T').first,
      ],
    );
    return (result.first['total'] as num).toDouble();
  }

  // ---------------------------------------------------------------------------
  // Settings key-value store
  // ---------------------------------------------------------------------------

  /// Reads a setting value by key. Returns null if the key doesn't exist.
  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query(
      tableSettings,
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) return null;
    return result.first['value'] as String;
  }

  /// Writes a setting value. Creates or replaces the existing entry.
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      tableSettings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------------------------------------------------------------------------
  // Backup: JSON export / import
  // ---------------------------------------------------------------------------

  /// Exports all transactions as a JSON-encoded string for backup.
  Future<String> getAllTransactionsAsJson() async {
    final db = await database;
    final result = await db.query(tableTransactions, orderBy: 'id ASC');
    return jsonEncode(result);
  }

  /// Imports transactions from a JSON string, replacing all existing data.
  ///
  /// Runs inside a database transaction for atomicity — if any insert fails,
  /// the entire operation is rolled back and existing data is preserved.
  Future<void> importTransactionsFromJson(String jsonString) async {
    final List<dynamic> rows = jsonDecode(jsonString) as List<dynamic>;
    final db = await database;

    await db.transaction((txn) async {
      // Clear existing transactions
      await txn.delete(tableTransactions);

      // Insert all imported rows
      for (final row in rows) {
        final map = Map<String, dynamic>.from(row as Map);
        // Remove the id so SQLite auto-generates new ones
        map.remove('id');
        await txn.insert(tableTransactions, map);
      }
    });
  }
}
