/// A money account / wallet (cash, bank, e-wallet). The current balance is
/// computed from the opening balance plus all transactions and transfers that
/// reference this account's [name] as their payment method.
class Account {
  final int? id;
  final String name;
  final String type; // 'cash' | 'bank' | 'ewallet' | 'other'
  final double openingBalance;
  final DateTime createdAt;

  Account({
    this.id,
    required this.name,
    this.type = 'cash',
    this.openingBalance = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type,
      'opening_balance': openingBalance,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: (map['type'] as String?) ?? 'cash',
      openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Account copyWith({
    int? id,
    String? name,
    String? type,
    double? openingBalance,
    DateTime? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      openingBalance: openingBalance ?? this.openingBalance,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// A movement of money from one account to another.
class Transfer {
  final int? id;
  final String fromAccount;
  final String toAccount;
  final double amount;
  final DateTime date;
  final String? note;
  final DateTime createdAt;

  Transfer({
    this.id,
    required this.fromAccount,
    required this.toAccount,
    required this.amount,
    required this.date,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'from_account': fromAccount,
      'to_account': toAccount,
      'amount': amount,
      'date': date.toIso8601String().split('T').first,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Transfer.fromMap(Map<String, dynamic> map) {
    return Transfer(
      id: map['id'] as int?,
      fromAccount: map['from_account'] as String,
      toAccount: map['to_account'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
