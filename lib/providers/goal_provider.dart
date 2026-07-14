import 'package:flutter/foundation.dart';
import 'package:receipto/models/goal.dart';
import 'package:receipto/services/database_helper.dart';

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
  /// or go negative.
  Future<void> contribute(Goal goal, double delta) async {
    if (goal.id == null) return;
    final newSaved =
        (goal.savedAmount + delta).clamp(0.0, goal.targetAmount);
    final updated = goal.copyWith(savedAmount: newSaved);
    await DatabaseHelper.instance.updateGoal(goal.id!, updated.toMap());
    final idx = _goals.indexWhere((g) => g.id == goal.id);
    if (idx != -1) {
      _goals[idx] = updated;
      notifyListeners();
    }
  }
}
