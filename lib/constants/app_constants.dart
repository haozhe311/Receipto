import 'package:flutter/material.dart';

/// App-wide constants for Receipto.
class AppConstants {
  AppConstants._();

  static const String appName = 'Receipto';
  static const String currencySymbol = 'RM';
  static const String currencyLocale = 'en_MY';

  /// Available transaction categories.
  static const List<String> categories = [
    'Food',
    'Transport',
    'Shopping',
    'Entertainment',
    'Health',
    'Utilities',
    'Others',
  ];

  /// Maps each category to a Material icon.
  static const Map<String, IconData> categoryIcons = {
    'Food': Icons.restaurant,
    'Transport': Icons.directions_car,
    'Shopping': Icons.shopping_bag,
    'Entertainment': Icons.movie,
    'Health': Icons.local_hospital,
    'Utilities': Icons.bolt,
    'Others': Icons.more_horiz,
  };

  /// Maps each category to a color for visual distinction.
  static const Map<String, Color> categoryColors = {
    'Food': Color(0xFFFF7043),
    'Transport': Color(0xFF42A5F5),
    'Shopping': Color(0xFFAB47BC),
    'Entertainment': Color(0xFFFFCA28),
    'Health': Color(0xFFEF5350),
    'Utilities': Color(0xFF66BB6A),
    'Others': Color(0xFF78909C),
  };

  /// Dark-tinted icon container backgrounds for each category (dark theme).
  static const Map<String, Color> categoryDarkTints = {
    'Food': Color(0xFF1E2E1E),
    'Transport': Color(0xFF1E1E2E),
    'Shopping': Color(0xFF2E1E2E),
    'Entertainment': Color(0xFF2E2E1E),
    'Health': Color(0xFF2E1E1E),
    'Utilities': Color(0xFF1E2A2E),
    'Others': Color(0xFF252540),
  };
}
