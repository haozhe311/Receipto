/// A template that automatically generates a real [Transaction] on a schedule.
///
/// When [isSubscription] is true it also appears in the Subscriptions view.
class RecurringTransaction {
  final int? id;
  final String merchant;
  final double amount;
  final String category;
  final String paymentMethod;
  final String type; // 'expense' | 'income'
  final String frequency; // 'weekly' | 'monthly'
  final DateTime nextDate;
  final bool isSubscription;
  final String? note;
  final bool active;
  final DateTime createdAt;

  RecurringTransaction({
    this.id,
    required this.merchant,
    required this.amount,
    required this.category,
    this.paymentMethod = 'Cash',
    this.type = 'expense',
    this.frequency = 'monthly',
    required this.nextDate,
    this.isSubscription = false,
    this.note,
    this.active = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isIncome => type == 'income';

  /// Advances a date by one period of this recurrence's frequency.
  DateTime advance(DateTime from) {
    if (frequency == 'weekly') {
      return from.add(const Duration(days: 7));
    }
    // monthly — keep the same day-of-month where possible.
    return DateTime(from.year, from.month + 1, from.day);
  }

  /// Estimated cost normalised to a monthly figure (weekly × 52 ÷ 12).
  double get monthlyEquivalent =>
      frequency == 'weekly' ? amount * 52 / 12 : amount;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'merchant': merchant,
      'amount': amount,
      'category': category,
      'payment_method': paymentMethod,
      'type': type,
      'frequency': frequency,
      'next_date': nextDate.toIso8601String().split('T').first,
      'is_subscription': isSubscription ? 1 : 0,
      'note': note,
      'active': active ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'] as int?,
      merchant: map['merchant'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      paymentMethod: (map['payment_method'] as String?) ?? 'Cash',
      type: (map['type'] as String?) ?? 'expense',
      frequency: (map['frequency'] as String?) ?? 'monthly',
      nextDate: DateTime.parse(map['next_date'] as String),
      isSubscription: (map['is_subscription'] as int? ?? 0) == 1,
      note: map['note'] as String?,
      active: (map['active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  RecurringTransaction copyWith({
    int? id,
    String? merchant,
    double? amount,
    String? category,
    String? paymentMethod,
    String? type,
    String? frequency,
    DateTime? nextDate,
    bool? isSubscription,
    String? note,
    bool? active,
    DateTime? createdAt,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      type: type ?? this.type,
      frequency: frequency ?? this.frequency,
      nextDate: nextDate ?? this.nextDate,
      isSubscription: isSubscription ?? this.isSubscription,
      note: note ?? this.note,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
