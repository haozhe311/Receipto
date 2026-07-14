import 'package:flutter/foundation.dart';
import 'package:receipto/services/database_helper.dart';

/// Manages per-category monthly budgets and tracks spending against them
/// for the current calendar month.
class BudgetProvider extends ChangeNotifier {
  Map<String, double> _limits = {};
  Map<String, double> _spent = {};
  bool _isLoading = false;

  /// {category: monthlyLimit} for categories that have a budget set.
  Map<String, double> get limits => Map.unmodifiable(_limits);

  /// {category: amountSpentThisMonth} for the current month (expense only).
  Map<String, double> get spent => Map.unmodifiable(_spent);

  bool get isLoading => _isLoading;

  /// Categories whose current-month spending exceeds their budget.
  List<String> get overBudgetCategories {
    final out = <String>[];
    _limits.forEach((category, limit) {
      if ((_spent[category] ?? 0) > limit) out.add(category);
    });
    return out;
  }

  /// True if any category is currently over budget.
  bool get hasOverBudget => overBudgetCategories.isNotEmpty;

  /// Spent amount for a category this month (0 if none).
  double spentFor(String category) => _spent[category] ?? 0;

  /// Budget limit for a category, or null if not set.
  double? limitFor(String category) => _limits[category];

  /// Loads budgets and current-month spending from the database.
  Future<void> loadBudgets() async {
    _isLoading = true;
    notifyListeners();
    final db = DatabaseHelper.instance;
    final results = await Future.wait([
      db.getBudgets(),
      db.getCategorySpendingForMonth(DateTime.now()),
    ]);
    _limits = results[0];
    _spent = results[1];
    _isLoading = false;
    notifyListeners();
  }

  /// Refreshes only the current-month spending figures (e.g. after a new
  /// transaction is added). Limits are left untouched.
  Future<void> refreshSpending() async {
    _spent = await DatabaseHelper.instance
        .getCategorySpendingForMonth(DateTime.now());
    notifyListeners();
  }

  Future<void> setBudget(String category, double monthlyLimit) async {
    await DatabaseHelper.instance.setBudget(category, monthlyLimit);
    _limits = {..._limits, category: monthlyLimit};
    notifyListeners();
  }

  Future<void> deleteBudget(String category) async {
    await DatabaseHelper.instance.deleteBudget(category);
    _limits = {..._limits}..remove(category);
    notifyListeners();
  }
}
