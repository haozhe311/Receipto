import 'package:flutter/foundation.dart';
import 'package:receipto/models/account.dart';
import 'package:receipto/services/database_helper.dart';

/// Manages money accounts / wallets and transfers between them, computing a
/// live balance per account and overall net worth.
///
/// An account's balance is derived from its opening balance plus every
/// transaction whose payment method matches the account name, plus transfers
/// in, minus transfers out.
class AccountProvider extends ChangeNotifier {
  List<Account> _accounts = [];
  List<Transfer> _transfers = [];
  Map<String, Map<String, double>> _flow = {};
  bool _isLoading = false;

  List<Account> get accounts => List.unmodifiable(_accounts);
  List<Transfer> get transfers => List.unmodifiable(_transfers);
  bool get isLoading => _isLoading;

  List<String> get accountNames => _accounts.map((a) => a.name).toList();

  /// Sum of all account balances.
  double get netWorth =>
      _accounts.fold(0.0, (sum, a) => sum + balanceOf(a));

  /// Computes the current balance for an account.
  double balanceOf(Account account) {
    final flow = _flow[account.name];
    final income = flow?['income'] ?? 0;
    final expense = flow?['expense'] ?? 0;

    double transfersIn = 0;
    double transfersOut = 0;
    for (final t in _transfers) {
      if (t.toAccount == account.name) transfersIn += t.amount;
      if (t.fromAccount == account.name) transfersOut += t.amount;
    }

    return account.openingBalance +
        income -
        expense +
        transfersIn -
        transfersOut;
  }

  Future<void> loadAccounts() async {
    _isLoading = true;
    notifyListeners();
    final db = DatabaseHelper.instance;
    await _seedIfNeeded(db);
    final results = await Future.wait([
      db.getAccounts(),
      db.getTransfers(),
      db.getPaymentFlow(),
    ]);
    _accounts = (results[0] as List<Map<String, dynamic>>)
        .map(Account.fromMap)
        .toList();
    _transfers = (results[1] as List<Map<String, dynamic>>)
        .map(Transfer.fromMap)
        .toList();
    _flow = results[2] as Map<String, Map<String, double>>;
    _isLoading = false;
    notifyListeners();
  }

  /// Seeds accounts exactly once — on first ever load, creates an account for
  /// each payment method already used by transactions (so history maps), plus
  /// a guaranteed "Cash". A settings flag prevents re-seeding after the user
  /// deletes accounts.
  Future<void> _seedIfNeeded(DatabaseHelper db) async {
    if (await db.getSetting('accounts_seeded') == 'true') return;
    final existing = await db.getAccounts();
    if (existing.isEmpty) {
      final names = <String>{'Cash', ...await db.getDistinctPaymentMethods()};
      for (final name in names) {
        await db.insertAccount(
          Account(name: name, type: guessType(name)).toMap(),
        );
      }
    }
    await db.setSetting('accounts_seeded', 'true');
  }

  /// Best-effort account type from a name, for a sensible default icon.
  static String guessType(String name) {
    final n = name.toLowerCase();
    if (n.contains('cash')) return 'cash';
    if (n.contains('bank') ||
        n.contains('cimb') ||
        n.contains('maybank') ||
        n.contains('rhb') ||
        n.contains('public') ||
        n.contains('hong leong') ||
        n.contains('gx')) {
      return 'bank';
    }
    if (n.contains('pay') ||
        n.contains('tng') ||
        n.contains('touch') ||
        n.contains('wallet') ||
        n.contains('grab') ||
        n.contains('boost') ||
        n.contains('shopee')) {
      return 'ewallet';
    }
    return 'other';
  }

  Future<void> addAccount({
    required String name,
    required String type,
    required double openingBalance,
  }) async {
    final account = Account(
      name: name,
      type: type,
      openingBalance: openingBalance,
    );
    await DatabaseHelper.instance.insertAccount(account.toMap());
    await loadAccounts();
  }

  Future<void> updateAccount(Account account) async {
    if (account.id == null) return;
    await DatabaseHelper.instance.updateAccount(account.id!, account.toMap());
    await loadAccounts();
  }

  Future<void> deleteAccount(int id) async {
    await DatabaseHelper.instance.deleteAccount(id);
    await loadAccounts();
  }

  Future<void> addTransfer({
    required String fromAccount,
    required String toAccount,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    final transfer = Transfer(
      fromAccount: fromAccount,
      toAccount: toAccount,
      amount: amount,
      date: date,
      note: note,
    );
    await DatabaseHelper.instance.insertTransfer(transfer.toMap());
    await loadAccounts();
  }

  Future<void> deleteTransfer(int id) async {
    await DatabaseHelper.instance.deleteTransfer(id);
    await loadAccounts();
  }
}
