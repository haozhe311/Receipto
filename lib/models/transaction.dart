/// Represents a single financial transaction stored in the local SQLite database.
class Transaction {
  final int? id;
  final DateTime date;
  final String merchant;
  final double amount;
  final String category;
  final String paymentMethod;
  final bool isOcr;
  final String? note;
  final DateTime createdAt;

  Transaction({
    this.id,
    required this.date,
    required this.merchant,
    required this.amount,
    required this.category,
    this.paymentMethod = 'Cash',
    this.isOcr = false,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Converts this Transaction to a Map for SQLite insertion.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date.toIso8601String().split('T').first, // YYYY-MM-DD
      'merchant': merchant,
      'amount': amount,
      'category': category,
      'payment_method': paymentMethod,
      'is_ocr': isOcr ? 1 : 0,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Creates a Transaction from a SQLite row map.
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      merchant: map['merchant'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      paymentMethod: (map['payment_method'] as String?) ?? 'Cash',
      isOcr: (map['is_ocr'] as int) == 1,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Creates a copy of this Transaction with the given fields replaced.
  Transaction copyWith({
    int? id,
    DateTime? date,
    String? merchant,
    double? amount,
    String? category,
    String? paymentMethod,
    bool? isOcr,
    String? note,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      date: date ?? this.date,
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isOcr: isOcr ?? this.isOcr,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Converts to a compact map for AI chatbot context (excludes internal fields).
  Map<String, dynamic> toCompactMap() {
    return {
      'date': date.toIso8601String().split('T').first,
      'merchant': merchant,
      'amount': amount,
      'category': category,
      'payment_method': paymentMethod,
    };
  }
}
