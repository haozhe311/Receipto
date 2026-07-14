import 'package:flutter/foundation.dart';
import 'package:receipto/models/recurring_transaction.dart';
import 'package:receipto/models/transaction.dart' as model;
import 'package:receipto/services/database_helper.dart';

/// Manages recurring transaction templates and materialises due ones into
/// real transactions. Also surfaces the subset flagged as subscriptions.
class RecurringProvider extends ChangeNotifier {
  List<RecurringTransaction> _items = [];
  bool _isLoading = false;

  List<RecurringTransaction> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;

  /// Recurring templates flagged as subscriptions.
  List<RecurringTransaction> get subscriptions =>
      _items.where((r) => r.isSubscription).toList();

  /// Combined monthly cost of all active subscriptions (weekly normalised).
  double get monthlySubscriptionCost => _items
      .where((r) => r.isSubscription && r.active && r.isIncome == false)
      .fold(0.0, (sum, r) => sum + r.monthlyEquivalent);

  Future<void> loadRecurring() async {
    _isLoading = true;
    notifyListeners();
    final rows = await DatabaseHelper.instance.getRecurring();
    _items = rows.map(RecurringTransaction.fromMap).toList();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addRecurring(RecurringTransaction r) async {
    await DatabaseHelper.instance.insertRecurring(r.toMap());
    await loadRecurring();
  }

  Future<void> updateRecurring(RecurringTransaction r) async {
    if (r.id == null) return;
    await DatabaseHelper.instance.updateRecurring(r.id!, r.toMap());
    await loadRecurring();
  }

  Future<void> deleteRecurring(int id) async {
    await DatabaseHelper.instance.deleteRecurring(id);
    _items.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  Future<void> toggleActive(RecurringTransaction r) async {
    await updateRecurring(r.copyWith(active: !r.active));
  }

  /// Materialises every active recurring template whose [nextDate] is on or
  /// before today into a real transaction, advancing the schedule (handles
  /// several missed periods). Returns the number of transactions created.
  Future<int> processDue() async {
    final db = DatabaseHelper.instance;
    final rows = await db.getRecurring();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    int created = 0;

    for (final row in rows) {
      var r = RecurringTransaction.fromMap(row);
      if (!r.active || r.id == null) continue;

      var next = r.nextDate;
      var changed = false;
      // Guard against runaway loops from bad data.
      var safety = 0;
      while (!next.isAfter(todayDate) && safety < 240) {
        await db.insertTransaction(
          model.Transaction(
            date: next,
            merchant: r.merchant,
            amount: r.amount,
            category: r.category,
            paymentMethod: r.paymentMethod,
            type: r.type,
            note: r.note,
          ),
        );
        created++;
        next = r.advance(next);
        changed = true;
        safety++;
      }

      if (changed) {
        await db.updateRecurring(r.id!, r.copyWith(nextDate: next).toMap());
      }
    }

    if (created > 0) await loadRecurring();
    return created;
  }
}
