import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:receipto/services/database_helper.dart';

/// Manages the list of payment methods available when adding transactions.
///
/// The list is persisted as a JSON array of strings in the SQLite settings
/// table under [_settingsKey]. "Cash" and "Others" are protected and can
/// never be deleted.
class PaymentMethodProvider extends ChangeNotifier {
  static const String _settingsKey = 'payment_methods';

  static const List<String> _defaults = [
    'Cash',
    'CIMB',
    'GX Bank',
    'Touch n Go',
    'ShopeePay',
    'Grab Pay',
    'Others',
  ];

  List<String> _methods = List.from(_defaults);

  List<String> get methods => List.unmodifiable(_methods);

  /// Loads payment methods from the SQLite settings table.
  /// Falls back to [_defaults] if nothing is stored yet.
  Future<void> loadMethods() async {
    final raw = await DatabaseHelper.instance.getSetting(_settingsKey);
    if (raw == null) {
      _methods = List.from(_defaults);
    } else {
      final list = jsonDecode(raw) as List<dynamic>;
      _methods = list.cast<String>();

      // Always guarantee the two protected fallbacks exist.
      if (!_methods.contains('Cash')) { _methods.insert(0, 'Cash'); }
      if (!_methods.contains('Others')) { _methods.add('Others'); }
    }
    notifyListeners();
  }

  /// Adds [method] to the list. Silently ignores duplicates (case-insensitive)
  /// and empty strings.
  Future<void> addMethod(String method) async {
    final trimmed = method.trim();
    if (trimmed.isEmpty) { return; }
    if (_methods.any((m) => m.toLowerCase() == trimmed.toLowerCase())) {
      return;
    }
    _methods.add(trimmed);
    await _persist();
    notifyListeners();
  }

  /// Deletes [method]. "Cash" and "Others" are protected and ignored.
  Future<void> deleteMethod(String method) async {
    if (method == 'Cash' || method == 'Others') { return; }
    _methods.remove(method);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await DatabaseHelper.instance.setSetting(
      _settingsKey,
      jsonEncode(_methods),
    );
  }
}
