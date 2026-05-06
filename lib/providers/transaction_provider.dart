import 'package:flutter/foundation.dart';
import 'package:receipto/models/transaction.dart' as model;
import 'package:receipto/services/database_helper.dart';

/// Manages the transaction list state and exposes CRUD operations.
///
/// Screens use [context.watch<TransactionProvider>()] to reactively rebuild
/// when data changes, and [context.read<TransactionProvider>()] for one-off
/// method calls like add/update/delete.
class TransactionProvider extends ChangeNotifier {
  static const int _pageSize = 30;

  List<model.Transaction> _transactions = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _loadedPages = 0;
  String? _selectedCategory;
  double _monthlyTotal = 0;
  double? _filteredTotal;
  int _monthlyCount = 0;

  // Selected month for the home screen navigator (always the 1st of the month).
  DateTime _selectedMonth = _firstOfMonth(DateTime.now());

  List<model.Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get selectedCategory => _selectedCategory;
  double get monthlyTotal => _monthlyTotal;
  /// Total for the active category filter, or the full month total when no filter.
  double get displayTotal => _selectedCategory != null ? (_filteredTotal ?? 0) : _monthlyTotal;
  int get transactionCount => _monthlyCount;

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

  /// Loads the first page of transactions for the selected month
  /// with the current category filter applied.
  Future<void> loadTransactions() async {
    // Cancel any in-flight loadMore so its result doesn't overwrite ours.
    _isLoadingMore = false;
    _hasMore = false;
    _isLoading = true;
    notifyListeners();

    final firstDay = _selectedMonth;
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final db = DatabaseHelper.instance;

    try {
      final futures = <Future>[
        db.getTransactions(
          category: _selectedCategory,
          from: firstDay,
          to: lastDay,
          limit: _pageSize,
          offset: 0,
        ),
        db.getMonthlyTotal(month: _selectedMonth),
        db.getTransactionCount(
          category: _selectedCategory,
          from: firstDay,
          to: lastDay,
        ),
        if (_selectedCategory != null)
          db.getMonthlyTotal(month: _selectedMonth, category: _selectedCategory),
      ];
      final results = await Future.wait(futures);

      _transactions = results[0] as List<model.Transaction>;
      _monthlyTotal = results[1] as double;
      _monthlyCount = (results[2] as num).toInt();
      _filteredTotal = _selectedCategory != null ? results[3] as double : null;
      _loadedPages = 1;
      _hasMore = _transactions.length < _monthlyCount;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads the next page of transactions and appends to the existing list.
  Future<void> loadMoreTransactions() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    _isLoadingMore = true;
    notifyListeners();

    final firstDay = _selectedMonth;
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    try {
      final next = await DatabaseHelper.instance.getTransactions(
        category: _selectedCategory,
        from: firstDay,
        to: lastDay,
        limit: _pageSize,
        offset: _loadedPages * _pageSize,
      );

      _transactions = [..._transactions, ...next];
      _loadedPages++;
      _hasMore = _transactions.length < _monthlyCount;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
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
