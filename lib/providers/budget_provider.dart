import 'dart:convert';

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
      _computeSpent(),
    ]);
    _limits = results[0];
    _spent = results[1];
    _isLoading = false;
    notifyListeners();
  }

  /// Refreshes only the current-month spending figures (e.g. after a new
  /// transaction is added). Limits are left untouched.
  Future<void> refreshSpending() async {
    _spent = await _computeSpent();
    notifyListeners();
  }

  /// Current-month spending rolled up so a budget on a parent category (e.g.
  /// "Food") includes spending tagged with its subcategories (Dining, Coffee…).
  /// Raw spending is keyed by the stored category, which is usually a
  /// subcategory, so a plain parent lookup would otherwise read zero.
  Future<Map<String, double>> _computeSpent() async {
    final db = DatabaseHelper.instance;
    final raw = await db.getCategorySpendingForMonth(DateTime.now());
    final categoriesJson = await db.getSetting('categories');
    return _rollUpToParents(raw, categoriesJson);
  }

  /// Adds each category's subcategory spending into the parent's total. Keeps
  /// the original per-subcategory entries too (so a budget set directly on a
  /// subcategory still resolves).
  static Map<String, double> _rollUpToParents(
    Map<String, double> raw,
    String? categoriesJson,
  ) {
    if (categoriesJson == null) return raw;
    final out = Map<String, double>.from(raw);
    final list = jsonDecode(categoriesJson) as List<dynamic>;
    for (final c in list) {
      final map = c as Map<String, dynamic>;
      final name = map['name'] as String;
      // Subcategories are objects {name, iconKey}, but legacy backups stored
      // them as bare name strings — handle both.
      final subs = (map['subcategories'] as List<dynamic>?) ?? const [];
      var total = raw[name] ?? 0;
      for (final s in subs) {
        final subName = s is String ? s : (s as Map<String, dynamic>)['name'];
        total += raw[subName] ?? 0;
      }
      out[name] = total;
    }
    return out;
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
