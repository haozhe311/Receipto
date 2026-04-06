import 'package:flutter/foundation.dart';
import 'package:receipto/models/transaction.dart' as model;
import 'package:receipto/services/database_helper.dart';

/// Manages the transaction list state and exposes CRUD operations.
///
/// Screens use [context.watch<TransactionProvider>()] to reactively rebuild
/// when data changes, and [context.read<TransactionProvider>()] for one-off
/// method calls like add/update/delete.
class TransactionProvider extends ChangeNotifier {
  List<model.Transaction> _transactions = [];
  bool _isLoading = false;
  String? _selectedCategory;
  double _monthlyTotal = 0;

  List<model.Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get selectedCategory => _selectedCategory;
  double get monthlyTotal => _monthlyTotal;
  int get transactionCount => _transactions.length;

  /// Total spending across all loaded transactions.
  double get totalSpending =>
      _transactions.fold(0, (sum, t) => sum + t.amount);

  /// Spending grouped by category from the loaded transactions.
  Map<String, double> get spendingByCategory {
    final map = <String, double>{};
    for (final t in _transactions) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  /// Loads transactions from the database with the current filter applied.
  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    _transactions = await DatabaseHelper.instance.getTransactions(
      category: _selectedCategory,
    );
    _monthlyTotal = await DatabaseHelper.instance.getMonthlyTotal();

    _isLoading = false;
    notifyListeners();
  }

  /// Inserts a new transaction and refreshes the list.
  Future<void> addTransaction(model.Transaction transaction) async {
    await DatabaseHelper.instance.insertTransaction(transaction);
    await loadTransactions();
  }

  /// Updates an existing transaction and refreshes the list.
  Future<void> updateTransaction(model.Transaction transaction) async {
    await DatabaseHelper.instance.updateTransaction(transaction);
    await loadTransactions();
  }

  /// Deletes a transaction by ID and refreshes the list.
  Future<void> deleteTransaction(int id) async {
    await DatabaseHelper.instance.deleteTransaction(id);
    await loadTransactions();
  }

  /// Sets the category filter and reloads. Pass null to show all.
  void filterByCategory(String? category) {
    _selectedCategory = category;
    loadTransactions();
  }
}
