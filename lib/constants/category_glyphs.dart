import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:receipto/constants/category_icons.dart';

/// SVG-based icon system for the redesigned category/subcategory pickers.
///
/// Icon files live in:
///   assets/icons/category/{key}.svg     (11 category icons)
///   assets/icons/subcategory/{key}.svg  (45 subcategory icons)
///
/// The keys below MUST match the SVG file names (e.g. the key `food` loads
/// `assets/icons/category/food.svg`). SVGs should use `currentColor` for their
/// strokes/fills so [CategoryGlyph] can tint them.
class CategoryGlyphs {
  CategoryGlyphs._();

  static const String categoryDir = 'assets/icons/category';
  static const String subcategoryDir = 'assets/icons/subcategory';

  /// The 11 category icons shown in the Add Category picker.
  static const List<String> categoryKeys = [
    'food',
    'transportation',
    'shopping',
    'housing',
    'entertainment',
    'health',
    'utilities',
    'education',
    'social',
    'income',
    'others',
  ];

  /// The 45 subcategory icons shown in the Add Subcategory picker.
  static const List<String> subcategoryKeys = [
    // Food
    'breakfast', 'lunch', 'dinner', 'delivery', 'snacks', 'drinks',
    // Transportation
    'fuel', 'parking', 'maintenance', 'tolls', 'bus', 'train', 'taxi', 'flight',
    // Shopping
    'groceries', 'clothing', 'skincare', 'electronics',
    // Housing
    'rent', 'electricity_bill', 'water_bill', 'home_wifi', 'home_maintenance',
    // Entertainment
    'movies', 'games', 'travel', 'sports', 'subscriptions',
    // Health & Fitness
    'medicine', 'doctor',
    // Utilities/Bills
    'internet', 'top_up',
    // Education
    'courses', 'books', 'stationery', 'tuition_fee', 'printing',
    // Social/Family
    'cash_gifts', 'gatherings',
    // Income
    'pocket_money', 'salary', 'bonus', 'part_time', 'investment_returns',
    'secondhand_sales',
  ];

  /// 20 selectable icon-background colours for a category.
  static const List<Color> palette = [
    Color(0xFFEF4444), // red
    Color(0xFFF97316), // orange
    Color(0xFFF59E0B), // amber
    Color(0xFFFACC15), // yellow
    Color(0xFF84CC16), // lime
    Color(0xFF22C55E), // green
    Color(0xFF10B981), // emerald
    Color(0xFF14B8A6), // teal
    Color(0xFF06B6D4), // cyan
    Color(0xFF0EA5E9), // sky
    Color(0xFF3B82F6), // blue
    Color(0xFF6366F1), // indigo
    Color(0xFF8B5CF6), // violet
    Color(0xFFA855F7), // purple
    Color(0xFFD946EF), // fuchsia
    Color(0xFFEC4899), // pink
    Color(0xFFF43F5E), // rose
    Color(0xFFA16207), // brown
    Color(0xFF64748B), // slate
    Color(0xFF0F172A), // ink
  ];

  static const String placeholderCategory = '$categoryDir/_placeholder.svg';
  static const String placeholderSubcategory =
      '$subcategoryDir/_placeholder.svg';

  static String categoryAsset(String key) => '$categoryDir/$key.svg';
  static String subcategoryAsset(String key) => '$subcategoryDir/$key.svg';

  /// Category SVG path for [key], or the placeholder if it isn't a known key
  /// (e.g. legacy data whose key has no matching SVG). Prevents missing-asset
  /// crashes.
  static String categoryAssetFor(String? key) =>
      (key != null && categoryKeys.contains(key))
          ? categoryAsset(key)
          : placeholderCategory;

  static String subcategoryAssetFor(String? key) =>
      (key != null && subcategoryKeys.contains(key))
          ? subcategoryAsset(key)
          : placeholderSubcategory;

  /// Resolves a category's on-screen icon + colour. [colorValue] wins; when null
  /// (legacy data) it falls back to the old preset colour so nothing looks grey.
  static CategoryVisual categoryVisual({
    String? name,
    String? iconKey,
    int? colorValue,
  }) {
    final color = colorValue != null
        ? Color(colorValue)
        : CategoryIcons.resolve(name ?? '', iconKey).color;
    return CategoryVisual(categoryAssetFor(iconKey), color);
  }
}

/// An SVG asset path paired with the colour it should be shown on.
class CategoryVisual {
  final String assetPath;
  final Color color;
  const CategoryVisual(this.assetPath, this.color);
}

/// Renders an SVG glyph tinted with [color]. Falls back to a neutral glyph while
/// loading. (Used inside [CategoryIconBadge], or standalone.)
class CategoryGlyph extends StatelessWidget {
  final String assetPath;
  final Color color;
  final double size;

  const CategoryGlyph({
    super.key,
    required this.assetPath,
    required this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      placeholderBuilder: (_) =>
          Icon(Icons.circle_outlined, size: size, color: color),
    );
  }
}

/// A rounded square filled with [background], holding a white SVG glyph — the
/// standard way category & subcategory icons are shown across the app.
class CategoryIconBadge extends StatelessWidget {
  final String assetPath;
  final Color background;
  final double size;

  const CategoryIconBadge({
    super.key,
    required this.assetPath,
    required this.background,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: CategoryGlyph(
        assetPath: assetPath,
        color: Colors.white,
        size: size * 0.56,
      ),
    );
  }
}
