/// A savings goal the user is working towards (e.g. "Emergency Fund").
class Goal {
  final int? id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime? targetDate;
  final DateTime createdAt;

  Goal({
    this.id,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0,
    this.targetDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Progress from 0.0 to 1.0 (clamped).
  double get progress {
    if (targetAmount <= 0) return 0;
    return (savedAmount / targetAmount).clamp(0.0, 1.0);
  }

  /// Amount still needed to reach the target (never negative).
  double get remaining => (targetAmount - savedAmount).clamp(0, double.infinity);

  /// True once the saved amount has reached or passed the target.
  bool get isComplete => savedAmount >= targetAmount;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'target_amount': targetAmount,
      'saved_amount': savedAmount,
      'target_date': targetDate?.toIso8601String().split('T').first,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'] as int?,
      name: map['name'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      savedAmount: (map['saved_amount'] as num?)?.toDouble() ?? 0,
      targetDate: (map['target_date'] as String?) != null
          ? DateTime.tryParse(map['target_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Goal copyWith({
    int? id,
    String? name,
    double? targetAmount,
    double? savedAmount,
    DateTime? targetDate,
    DateTime? createdAt,
  }) {
    return Goal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
