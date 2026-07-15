import 'package:flutter/material.dart';

/// A selectable icon + colour swatch for a category.
class CategoryIconOption {
  final String key;
  final IconData icon;
  final Color color;

  const CategoryIconOption({
    required this.key,
    required this.icon,
    required this.color,
  });
}

/// Registry of the icon + colour swatches a category can use.
///
/// The first seven presets deliberately mirror the built-in categories
/// (same icon and colour as `AppConstants.categoryIcons` / `categoryColors`),
/// so user-created categories look native alongside them. The rest are generic
/// extras drawn from the same palette family.
class CategoryIcons {
  CategoryIcons._();

  static const List<CategoryIconOption> presets = [
    // ── Mirror the built-in categories ──
    CategoryIconOption(
        key: 'food', icon: Icons.restaurant, color: Color(0xFFFF7043)),
    CategoryIconOption(
        key: 'transport', icon: Icons.directions_car, color: Color(0xFF42A5F5)),
    CategoryIconOption(
        key: 'shopping', icon: Icons.shopping_bag, color: Color(0xFFAB47BC)),
    CategoryIconOption(
        key: 'entertainment', icon: Icons.movie, color: Color(0xFFFFCA28)),
    CategoryIconOption(
        key: 'health', icon: Icons.local_hospital, color: Color(0xFFEF5350)),
    CategoryIconOption(
        key: 'utilities', icon: Icons.bolt, color: Color(0xFF66BB6A)),
    CategoryIconOption(
        key: 'others', icon: Icons.more_horiz, color: Color(0xFF78909C)),

    // ── Generic extras for user-created categories ──
    CategoryIconOption(
        key: 'groceries',
        icon: Icons.local_grocery_store,
        color: Color(0xFF9CCC65)),
    CategoryIconOption(
        key: 'coffee', icon: Icons.local_cafe, color: Color(0xFF8D6E63)),
    CategoryIconOption(key: 'home', icon: Icons.home, color: Color(0xFF42A5F5)),
    CategoryIconOption(
        key: 'education', icon: Icons.school, color: Color(0xFF7E57C2)),
    CategoryIconOption(
        key: 'fitness', icon: Icons.fitness_center, color: Color(0xFF66BB6A)),
    CategoryIconOption(
        key: 'travel', icon: Icons.flight, color: Color(0xFF26C6DA)),
    CategoryIconOption(key: 'pets', icon: Icons.pets, color: Color(0xFFFFA726)),
    CategoryIconOption(
        key: 'gift', icon: Icons.card_giftcard, color: Color(0xFFEC407A)),
    CategoryIconOption(
        key: 'bills', icon: Icons.receipt_long, color: Color(0xFFFF7043)),
    CategoryIconOption(
        key: 'phone', icon: Icons.smartphone, color: Color(0xFF78909C)),
    CategoryIconOption(
        key: 'savings', icon: Icons.savings, color: Color(0xFF4CAF50)),
  ];

  static const CategoryIconOption fallback = CategoryIconOption(
    key: 'others',
    icon: Icons.more_horiz,
    color: Color(0xFF78909C),
  );

  /// Built-in category name → preset key, so existing categories keep the
  /// exact icon they already had before icons became user-selectable.
  static const Map<String, String> _builtInKeys = {
    'Food': 'food',
    'Transport': 'transport',
    'Shopping': 'shopping',
    'Entertainment': 'entertainment',
    'Health': 'health',
    'Utilities': 'utilities',
    'Others': 'others',
  };

  static CategoryIconOption? byKey(String? key) {
    if (key == null) return null;
    for (final p in presets) {
      if (p.key == key) return p;
    }
    return null;
  }

  static String? builtInKeyFor(String categoryName) => _builtInKeys[categoryName];

  /// Resolution order: explicit [iconKey] → built-in match on [name] → fallback.
  static CategoryIconOption resolve(String name, [String? iconKey]) =>
      byKey(iconKey) ?? byKey(_builtInKeys[name]) ?? fallback;
}
