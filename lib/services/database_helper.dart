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
  static const int _dbVersion = 6;

  // Table and column names
  static const String tableTransactions = 'transactions';
  static const String tableSettings = 'settings';
  static const String tableBudgets = 'budgets';
  static const String tableGoals = 'goals';
  static const String tableRecurring = 'recurring';
  static const String tableSplits = 'splits';
  static const String tableAccounts = 'accounts';
  static const String tableTransfers = 'transfers';

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
      onUpgrade: _onUpgrade,
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
        payment_method TEXT NOT NULL DEFAULT 'Cash',
        type TEXT NOT NULL DEFAULT 'expense',
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

    await _createBudgetsTable(db);
    await _createGoalsTable(db);
    await _createRecurringTable(db);
    await _createSplitsTable(db);
    await _createAccountsTable(db);
    await _createTransfersTable(db);

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_date ON $tableTransactions(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_category ON $tableTransactions(category)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_type ON $tableTransactions(type)',
    );
  }

  Future<void> _createBudgetsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableBudgets (
        category TEXT PRIMARY KEY,
        monthly_limit REAL NOT NULL
      )
    ''');
  }

  Future<void> _createGoalsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableGoals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        saved_amount REAL NOT NULL DEFAULT 0,
        target_date TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createRecurringTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableRecurring (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'Cash',
        type TEXT NOT NULL DEFAULT 'expense',
        frequency TEXT NOT NULL DEFAULT 'monthly',
        next_date TEXT NOT NULL,
        is_subscription INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createSplitsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableSplits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT NOT NULL,
        total_amount REAL NOT NULL,
        date TEXT NOT NULL,
        participants TEXT NOT NULL,
        paid_by_me INTEGER NOT NULL DEFAULT 1,
        payer_name TEXT,
        your_share REAL NOT NULL DEFAULT 0,
        your_share_settled INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createAccountsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableAccounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'cash',
        opening_balance REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createTransfersTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableTransfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_account TEXT NOT NULL,
        to_account TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Migrates the database schema between versions.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 → v2: add payment_method column (existing rows default to 'Cash')
      await db.execute(
        "ALTER TABLE $tableTransactions ADD COLUMN payment_method TEXT NOT NULL DEFAULT 'Cash'",
      );
    }
    if (oldVersion < 3) {
      // v2 → v3: add indexes for date and category to speed up month queries
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_date ON $tableTransactions(date)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_category ON $tableTransactions(category)',
      );
    }
    if (oldVersion < 4) {
      // v3 → v4: income/expense type, plus budgets and goals tables.
      await db.execute(
        "ALTER TABLE $tableTransactions ADD COLUMN type TEXT NOT NULL DEFAULT 'expense'",
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_type ON $tableTransactions(type)',
      );
      await _createBudgetsTable(db);
      await _createGoalsTable(db);
    }
    if (oldVersion < 5) {
      // v4 → v5: recurring, splits, accounts, and transfers.
      await _createRecurringTable(db);
      await _createSplitsTable(db);
      await _createAccountsTable(db);
      await _createTransfersTable(db);
    }
    if (oldVersion < 6) {
      // v5 → v6: split expenses gain a direction (who paid) so the app can
      // track money you owe as well as money owed to you.
      await db.execute(
        'ALTER TABLE $tableSplits ADD COLUMN paid_by_me INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE $tableSplits ADD COLUMN payer_name TEXT',
      );
      await db.execute(
        'ALTER TABLE $tableSplits ADD COLUMN your_share REAL NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE $tableSplits ADD COLUMN your_share_settled INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Transaction CRUD
  // ---------------------------------------------------------------------------

  /// Inserts a new transaction and returns the auto-generated row ID.
  Future<int> insertTransaction(model.Transaction transaction) async {
    final db = await database;
    return await db.insert(tableTransactions, transaction.toMap());
  }

  /// Retrieves transactions with optional category, date range, and pagination.
  /// Results are ordered by date descending (most recent first).
  Future<List<model.Transaction>> getTransactions({
    String? category,
    DateTime? from,
    DateTime? to,
    int? limit,
    int? offset,
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
      limit: limit,
      offset: offset,
    );

    return result.map((map) => model.Transaction.fromMap(map)).toList();
  }

  /// Returns the total number of transactions matching the given filters.
  /// Used by the provider to show an accurate count even with pagination.
  Future<int> getTransactionCount({
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

    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $tableTransactions'
      '${whereClauses.isNotEmpty ? ' WHERE ${whereClauses.join(' AND ')}' : ''}',
      whereArgs.isNotEmpty ? whereArgs : null,
    );
    return (result.first['cnt'] as int);
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

  /// Returns the total EXPENSE spending for a given month (defaults to current).
  /// Optionally filtered to a single [category]. Income is excluded.
  Future<double> getMonthlyTotal({DateTime? month, String? category}) async {
    final db = await database;
    final now = month ?? DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    final whereParts = ["type = 'expense'", 'date >= ?', 'date <= ?'];
    final args = <dynamic>[
      firstDay.toIso8601String().split('T').first,
      lastDay.toIso8601String().split('T').first,
    ];

    if (category != null) {
      whereParts.add('category = ?');
      args.add(category);
    }

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM $tableTransactions '
      'WHERE ${whereParts.join(' AND ')}',
      args,
    );
    return (result.first['total'] as num).toDouble();
  }

  /// Returns the total INCOME for a given month (defaults to current month).
  Future<double> getMonthlyIncome({DateTime? month}) async {
    final db = await database;
    final now = month ?? DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM $tableTransactions "
      "WHERE type = 'income' AND date >= ? AND date <= ?",
      [
        firstDay.toIso8601String().split('T').first,
        lastDay.toIso8601String().split('T').first,
      ],
    );
    return (result.first['total'] as num).toDouble();
  }

  /// Returns expense spending grouped by category for a single month.
  /// Map is {category: total}, only categories with spending are included.
  Future<Map<String, double>> getCategorySpendingForMonth(
    DateTime month,
  ) async {
    final db = await database;
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final rows = await db.rawQuery(
      "SELECT category, COALESCE(SUM(amount), 0) as total "
      "FROM $tableTransactions "
      "WHERE type = 'expense' AND date >= ? AND date <= ? "
      "GROUP BY category ORDER BY total DESC",
      [
        firstDay.toIso8601String().split('T').first,
        lastDay.toIso8601String().split('T').first,
      ],
    );

    return {
      for (final r in rows)
        r['category'] as String: (r['total'] as num).toDouble(),
    };
  }

  /// Returns expense and income totals per month for the last [months] months
  /// (including the current month), oldest first. Missing months are filled 0.
  Future<List<Map<String, dynamic>>> getMonthlyTrend(int months) async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - (months - 1), 1);

    final rows = await db.rawQuery(
      "SELECT strftime('%Y-%m', date) AS month, type, "
      "COALESCE(SUM(amount), 0) AS total "
      "FROM $tableTransactions WHERE date >= ? "
      "GROUP BY month, type",
      [start.toIso8601String().split('T').first],
    );

    // Index results by "YYYY-MM" → {expense, income}.
    final byMonth = <String, Map<String, double>>{};
    for (final r in rows) {
      final m = r['month'] as String;
      final t = r['type'] as String;
      final total = (r['total'] as num).toDouble();
      byMonth.putIfAbsent(m, () => {'expense': 0, 'income': 0});
      byMonth[m]![t] = total;
    }

    // Build a continuous list of months so gaps render as zero bars.
    final out = <Map<String, dynamic>>[];
    for (int i = 0; i < months; i++) {
      final d = DateTime(now.year, now.month - (months - 1) + i, 1);
      final key =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
      out.add({
        'month': key,
        'date': d,
        'expense': byMonth[key]?['expense'] ?? 0.0,
        'income': byMonth[key]?['income'] ?? 0.0,
      });
    }
    return out;
  }

  /// Renames a category everywhere it is referenced by name, so renaming from
  /// Manage Categories never orphans existing records.
  Future<void> renameCategoryEverywhere(String oldName, String newName) async {
    if (oldName == newName) return;
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(tableTransactions, {'category': newName},
          where: 'category = ?', whereArgs: [oldName]);
      await txn.update(tableRecurring, {'category': newName},
          where: 'category = ?', whereArgs: [oldName]);
      // budgets keys on category — drop any row already using the new name
      // so the update can't violate the primary key.
      await txn
          .delete(tableBudgets, where: 'category = ?', whereArgs: [newName]);
      await txn.update(tableBudgets, {'category': newName},
          where: 'category = ?', whereArgs: [oldName]);
    });
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
  // AI context queries
  // ---------------------------------------------------------------------------

  /// Returns per-category EXPENSE spending grouped by year, newest year first.
  Future<List<Map<String, dynamic>>> getYearlySummary() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        strftime('%Y', date) AS year,
        category,
        SUM(amount) AS total,
        COUNT(*) AS count
      FROM $tableTransactions
      WHERE type = 'expense'
      GROUP BY year, category
      ORDER BY year DESC, total DESC
    ''');
  }

  /// Returns per-category EXPENSE spending grouped by month (YYYY-MM), newest first.
  Future<List<Map<String, dynamic>>> getMonthlySummary() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        strftime('%Y-%m', date) AS month,
        category,
        SUM(amount) AS total,
        COUNT(*) AS count
      FROM $tableTransactions
      WHERE type = 'expense'
      GROUP BY month, category
      ORDER BY month DESC, total DESC
    ''');
  }

  /// Returns a single-row overview of all transaction data.
  /// all_time_total is expenses only; income is reported separately.
  Future<Map<String, dynamic>> getDataOverview() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS total_transactions,
        MIN(date) AS earliest_date,
        MAX(date) AS latest_date,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS all_time_total,
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS all_time_income
      FROM $tableTransactions
    ''');
    return rows.first;
  }

  // ---------------------------------------------------------------------------
  // Budgets
  // ---------------------------------------------------------------------------

  /// Returns all category budgets as a {category: monthlyLimit} map.
  Future<Map<String, double>> getBudgets() async {
    final db = await database;
    final rows = await db.query(tableBudgets);
    return {
      for (final r in rows)
        r['category'] as String: (r['monthly_limit'] as num).toDouble(),
    };
  }

  /// Creates or updates the monthly limit for a category.
  Future<void> setBudget(String category, double monthlyLimit) async {
    final db = await database;
    await db.insert(
      tableBudgets,
      {'category': category, 'monthly_limit': monthlyLimit},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Removes the budget for a category.
  Future<void> deleteBudget(String category) async {
    final db = await database;
    await db.delete(tableBudgets, where: 'category = ?', whereArgs: [category]);
  }

  // ---------------------------------------------------------------------------
  // Goals
  // ---------------------------------------------------------------------------

  /// Returns all savings goals, newest first.
  Future<List<Map<String, dynamic>>> getGoals() async {
    final db = await database;
    return await db.query(tableGoals, orderBy: 'created_at DESC');
  }

  /// Inserts a new goal and returns its row ID.
  Future<int> insertGoal(Map<String, dynamic> goal) async {
    final db = await database;
    return await db.insert(tableGoals, goal);
  }

  /// Updates an existing goal by ID.
  Future<int> updateGoal(int id, Map<String, dynamic> goal) async {
    final db = await database;
    return await db.update(
      tableGoals,
      goal,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes a goal by ID.
  Future<int> deleteGoal(int id) async {
    final db = await database;
    return await db.delete(tableGoals, where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Recurring transactions (also powers subscriptions)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getRecurring() async {
    final db = await database;
    return await db.query(tableRecurring, orderBy: 'next_date ASC');
  }

  Future<int> insertRecurring(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(tableRecurring, row);
  }

  Future<int> updateRecurring(int id, Map<String, dynamic> row) async {
    final db = await database;
    return await db.update(
      tableRecurring,
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteRecurring(int id) async {
    final db = await database;
    return await db.delete(tableRecurring, where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Split expenses
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getSplits() async {
    final db = await database;
    return await db.query(tableSplits, orderBy: 'date DESC, id DESC');
  }

  Future<int> insertSplit(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(tableSplits, row);
  }

  Future<int> updateSplit(int id, Map<String, dynamic> row) async {
    final db = await database;
    return await db.update(tableSplits, row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteSplit(int id) async {
    final db = await database;
    return await db.delete(tableSplits, where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Accounts / wallets and transfers
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final db = await database;
    return await db.query(tableAccounts, orderBy: 'created_at ASC');
  }

  /// Distinct payment-method names already used by transactions. Used once to
  /// seed accounts so historical transactions map to an account.
  Future<List<String>> getDistinctPaymentMethods() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT payment_method FROM $tableTransactions '
      'WHERE payment_method IS NOT NULL',
    );
    return rows
        .map((r) => (r['payment_method'] as String?) ?? '')
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  Future<int> insertAccount(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(tableAccounts, row);
  }

  Future<int> updateAccount(int id, Map<String, dynamic> row) async {
    final db = await database;
    return await db.update(tableAccounts, row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAccount(int id) async {
    final db = await database;
    return await db.delete(tableAccounts, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getTransfers() async {
    final db = await database;
    return await db.query(tableTransfers, orderBy: 'date DESC, id DESC');
  }

  Future<int> insertTransfer(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(tableTransfers, row);
  }

  Future<int> deleteTransfer(int id) async {
    final db = await database;
    return await db.delete(tableTransfers, where: 'id = ?', whereArgs: [id]);
  }

  /// Returns income and expense totals grouped by payment method, used to
  /// compute per-account balances. Shape: {paymentMethod: {income, expense}}.
  Future<Map<String, Map<String, double>>> getPaymentFlow() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT payment_method, type, COALESCE(SUM(amount), 0) AS total '
      'FROM $tableTransactions GROUP BY payment_method, type',
    );
    final out = <String, Map<String, double>>{};
    for (final r in rows) {
      final pm = r['payment_method'] as String;
      final type = r['type'] as String;
      final total = (r['total'] as num).toDouble();
      out.putIfAbsent(pm, () => {'income': 0, 'expense': 0});
      out[pm]![type] = total;
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Backup: JSON export / import
  // ---------------------------------------------------------------------------

  /// Backup schema version written into every new backup file.
  static const int backupSchemaVersion = 2;

  /// Exports the full app dataset as a JSON object string for backup.
  ///
  /// Covers transactions, categories, budgets, goals, recurring templates,
  /// accounts, and account transfers. Categories live in the settings table
  /// as a JSON string, so they are inlined here as a list.
  Future<String> getAllDataAsJson() async {
    final db = await database;
    final categoriesRaw = await getSetting('categories');

    return jsonEncode({
      'schema_version': backupSchemaVersion,
      'transactions': await db.query(tableTransactions, orderBy: 'id ASC'),
      'categories':
          categoriesRaw != null ? jsonDecode(categoriesRaw) : <dynamic>[],
      'budgets': await db.query(tableBudgets),
      'goals': await db.query(tableGoals, orderBy: 'id ASC'),
      'recurring': await db.query(tableRecurring, orderBy: 'id ASC'),
      'accounts': await db.query(tableAccounts, orderBy: 'id ASC'),
      'transfers': await db.query(tableTransfers, orderBy: 'id ASC'),
    });
  }

  /// Imports a backup, replacing existing data. Handles both the current
  /// object schema and the legacy v1 format (a bare array of transactions).
  ///
  /// Any section absent from the backup is left untouched; present sections
  /// replace their table. Runs in a single transaction for atomicity.
  Future<void> importAllDataFromJson(String jsonString) async {
    final decoded = jsonDecode(jsonString);
    final db = await database;

    await db.transaction((txn) async {
      // Legacy v1: a bare JSON array of transaction rows.
      if (decoded is List) {
        await _replaceRows(txn, tableTransactions, decoded, stripId: true);
        return;
      }

      final map = decoded as Map<String, dynamic>;

      if (map['transactions'] is List) {
        await _replaceRows(
            txn, tableTransactions, map['transactions'] as List, stripId: true);
      }
      if (map['budgets'] is List) {
        await _replaceRows(
            txn, tableBudgets, map['budgets'] as List, stripId: false);
      }
      if (map['goals'] is List) {
        await _replaceRows(txn, tableGoals, map['goals'] as List, stripId: true);
      }
      if (map['recurring'] is List) {
        await _replaceRows(
            txn, tableRecurring, map['recurring'] as List, stripId: true);
      }
      if (map['accounts'] is List) {
        await _replaceRows(
            txn, tableAccounts, map['accounts'] as List, stripId: true);
        // Don't let one-time account seeding re-run over restored accounts.
        await txn.insert(
          tableSettings,
          {'key': 'accounts_seeded', 'value': 'true'},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (map['transfers'] is List) {
        await _replaceRows(
            txn, tableTransfers, map['transfers'] as List, stripId: true);
      }
      if (map['categories'] is List) {
        await txn.insert(
          tableSettings,
          {'key': 'categories', 'value': jsonEncode(map['categories'])},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Clears [table] then inserts [rows]. When [stripId] is true the primary-key
  /// `id` is dropped so SQLite regenerates it (tables with AUTOINCREMENT ids).
  Future<void> _replaceRows(
    Transaction txn,
    String table,
    List<dynamic> rows, {
    required bool stripId,
  }) async {
    await txn.delete(table);
    for (final row in rows) {
      final map = Map<String, dynamic>.from(row as Map);
      if (stripId) map.remove('id');
      await txn.insert(table, map);
    }
  }
}
