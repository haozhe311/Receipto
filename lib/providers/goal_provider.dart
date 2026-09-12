import 'package:flutter/foundation.dart';
import 'package:receipto/models/goal.dart';
import 'package:receipto/services/database_helper.dart';

/// The amount and direction a goal-linked transaction ended up reflecting on
/// its goal, returned by [GoalProvider.syncTransactionEdit] so the caller can
/// write it back onto the transaction being saved.
class GoalSyncResult {
  final double amount;
  final bool wasIncome;

  const GoalSyncResult({required this.amount, required this.wasIncome});
}

/// A goal-linked transaction's effect on its goal's saved amount: a
/// contribution (expense) adds to it, a withdrawal (income) subtracts.
double _goalEffectOf(double amount, bool wasIncome) =>
    wasIncome ? -amount : amount;

/// Manages the user's savings goals and their contributions.
class GoalProvider extends ChangeNotifier {
  List<Goal> _goals = [];
  bool _isLoading = false;

  List<Goal> get goals => List.unmodifiable(_goals);
  bool get isLoading => _isLoading;

  /// Total amount saved across all goals.
  double get totalSaved => _goals.fold(0, (sum, g) => sum + g.savedAmount);

  /// Total target across all goals.
  double get totalTarget => _goals.fold(0, (sum, g) => sum + g.targetAmount);

  Future<void> loadGoals() async {
    _isLoading = true;
    notifyListeners();
    final rows = await DatabaseHelper.instance.getGoals();
    _goals = rows.map(Goal.fromMap).toList();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addGoal({
    required String name,
    required double targetAmount,
    DateTime? targetDate,
  }) async {
    final goal = Goal(
      name: name,
      targetAmount: targetAmount,
      targetDate: targetDate,
    );
    await DatabaseHelper.instance.insertGoal(goal.toMap());
    await loadGoals();
  }

  Future<void> deleteGoal(int id) async {
    await DatabaseHelper.instance.deleteGoal(id);
    _goals.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  /// Adds [delta] to a goal's saved amount (can be negative). The result is
  /// clamped to the range [0, targetAmount] so contributions never overshoot
  /// or go negative. Returns the actual delta applied after clamping, so
  /// callers can move exactly that amount on or off a real account.
  Future<double> contribute(Goal goal, double delta) async {
    if (goal.id == null) return 0;
    final newSaved =
        (goal.savedAmount + delta).clamp(0.0, goal.targetAmount);
    final actualDelta = newSaved - goal.savedAmount;
    if (actualDelta == 0) return 0;
    final updated = goal.copyWith(savedAmount: newSaved);
    await DatabaseHelper.instance.updateGoal(goal.id!, updated.toMap());
    final idx = _goals.indexWhere((g) => g.id == goal.id);
    if (idx != -1) {
      _goals[idx] = updated;
      notifyListeners();
    }
    return actualDelta;
  }

  /// Reverts the effect of a goal-linked transaction that is being deleted.
  /// [wasIncome] is the deleted transaction's type ('income' means it was a
  /// withdrawal, so that [amount] is added back to the goal; otherwise it was
  /// a contribution, so [amount] is subtracted). Loads the goal straight from
  /// the database rather than relying on [goals] being populated, since the
  /// screen deleting the transaction may never have visited the Goals screen.
  /// A no-op if the goal no longer exists.
  Future<void> reverseTransaction({
    required int goalId,
    required double amount,
    required bool wasIncome,
  }) async {
    final row = await DatabaseHelper.instance.getGoal(goalId);
    if (row == null) return;
    await contribute(Goal.fromMap(row), -_goalEffectOf(amount, wasIncome));
    // Keep the in-memory list in sync if some other screen has it loaded.
    if (_goals.isNotEmpty) await loadGoals();
  }

  /// Re-syncs a goal when one of its linked transactions is edited rather
  /// than deleted: removes the old amount/direction's effect and applies the
  /// new one, in a single clamped step so a boundary clamp can't discard part
  /// of the edit. Loads the goal straight from the database, same as
  /// [reverseTransaction].
  ///
  /// Returns the amount/direction that actually ended up reflected on the
  /// goal, which can differ from [newAmount]/[newWasIncome] if applying the
  /// edit in full would have overshot the target or gone below zero — the
  /// caller should write this back onto the transaction being saved so the
  /// two stay consistent. Returns the requested new values unchanged if the
  /// goal no longer exists.
  Future<GoalSyncResult> syncTransactionEdit({
    required int goalId,
    required double oldAmount,
    required bool oldWasIncome,
    required double newAmount,
    required bool newWasIncome,
  }) async {
    final row = await DatabaseHelper.instance.getGoal(goalId);
    if (row == null) {
      return GoalSyncResult(amount: newAmount, wasIncome: newWasIncome);
    }
    final goal = Goal.fromMap(row);

    final oldEffect = _goalEffectOf(oldAmount, oldWasIncome);
    final desiredEffect = _goalEffectOf(newAmount, newWasIncome);
    final netDelta = desiredEffect - oldEffect;
    if (netDelta == 0) {
      return GoalSyncResult(amount: oldAmount, wasIncome: oldWasIncome);
    }

    final actualNetDelta = await contribute(goal, netDelta);
    final actualEffect = oldEffect + actualNetDelta;

    return actualEffect >= 0
        ? GoalSyncResult(amount: actualEffect, wasIncome: false)
        : GoalSyncResult(amount: -actualEffect, wasIncome: true);
  }
}
