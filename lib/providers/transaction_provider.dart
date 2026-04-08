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

  // Selected month for the home screen navigator (always the 1st of the month).
  DateTime _selectedMonth = _firstOfMonth(DateTime.now());

  List<model.Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get selectedCategory => _selectedCategory;
  double get monthlyTotal => _monthlyTotal;
  int get transactionCount => _transactions.length;

  /// The month currently displayed on the home screen.
  DateTime get selectedMonth => _selectedMonth;

  /// True when the displayed month is the current calendar month.
  bool get isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

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

  /// Moves the selected month by [delta] months (+1 = forward, -1 = backward),
  /// clamped so the user cannot navigate beyond the current month.
  void navigateMonth(int delta) {
    final candidate = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + delta,
    );
    final now = _firstOfMonth(DateTime.now());
    if (candidate.isAfter(now)) return; // never go into the future
    _selectedMonth = candidate;
    // Reset category filter when changing months for a clean view.
    _selectedCategory = null;
    loadTransactions();
  }

  /// Loads transactions from the database for the selected month
  /// with the current category filter applied.
  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    final firstDay = _selectedMonth;
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    _transactions = await DatabaseHelper.instance.getTransactions(
      category: _selectedCategory,
      from: firstDay,
      to: lastDay,
    );
    _monthlyTotal = await DatabaseHelper.instance.getMonthlyTotal(
      month: _selectedMonth,
    );

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

  /// Sets the category filter within the current month and reloads.
  /// Pass null to show all categories.
  void filterByCategory(String? category) {
    _selectedCategory = category;
    loadTransactions();
  }

  static DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month);
}
