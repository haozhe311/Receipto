import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:receipto/constants/category_glyphs.dart';
import 'package:receipto/constants/category_icons.dart';
import 'package:receipto/models/category_model.dart';
import 'package:receipto/services/database_helper.dart';

/// Manages the dynamic list of transaction categories and their subcategories.
///
/// Categories are persisted as a JSON string in the SQLite settings table
/// under the key [_settingsKey]. On first launch (no stored value) the
/// provider falls back to [_defaults]. "Others" is always kept as a
/// fallback and cannot be renamed or deleted.
class CategoryProvider extends ChangeNotifier {
  static const String _settingsKey = 'categories';

  /// The category that is always present and protected from edits/deletion.
  static const String protectedName = 'Others';

  /// Preset categories: SVG icon + background colour + iconned subcategories.
  static const List<CategoryModel> _defaults = [
    CategoryModel(name: 'Food', iconKey: 'food', colorValue: 0xFFF97316,
        subcategories: [
          SubcategoryModel(name: 'Breakfast', iconKey: 'breakfast'),
          SubcategoryModel(name: 'Lunch', iconKey: 'lunch'),
          SubcategoryModel(name: 'Dinner', iconKey: 'dinner'),
          SubcategoryModel(name: 'Delivery', iconKey: 'delivery'),
          SubcategoryModel(name: 'Snacks', iconKey: 'snacks'),
          SubcategoryModel(name: 'Drinks', iconKey: 'drinks'),
        ]),
    CategoryModel(name: 'Transportation', iconKey: 'transportation',
        colorValue: 0xFF3B82F6, subcategories: [
          SubcategoryModel(name: 'Fuel', iconKey: 'fuel'),
          SubcategoryModel(name: 'Parking', iconKey: 'parking'),
          SubcategoryModel(name: 'Maintenance', iconKey: 'maintenance'),
          SubcategoryModel(name: 'Tolls', iconKey: 'tolls'),
          SubcategoryModel(name: 'Bus', iconKey: 'bus'),
          SubcategoryModel(name: 'Train', iconKey: 'train'),
          SubcategoryModel(name: 'Taxi', iconKey: 'taxi'),
          SubcategoryModel(name: 'Flight', iconKey: 'flight'),
        ]),
    CategoryModel(name: 'Shopping', iconKey: 'shopping',
        colorValue: 0xFFA855F7, subcategories: [
          SubcategoryModel(name: 'Groceries', iconKey: 'groceries'),
          SubcategoryModel(name: 'Clothing', iconKey: 'clothing'),
          SubcategoryModel(name: 'Skincare', iconKey: 'skincare'),
          SubcategoryModel(name: 'Electronics', iconKey: 'electronics'),
        ]),
    CategoryModel(name: 'Housing', iconKey: 'housing', colorValue: 0xFF14B8A6,
        subcategories: [
          SubcategoryModel(name: 'Rent', iconKey: 'rent'),
          SubcategoryModel(name: 'Electricity Bill', iconKey: 'electricity_bill'),
          SubcategoryModel(name: 'Water Bill', iconKey: 'water_bill'),
          SubcategoryModel(name: 'Home Wi-Fi', iconKey: 'home_wifi'),
          SubcategoryModel(name: 'Maintenance', iconKey: 'home_maintenance'),
        ]),
    CategoryModel(name: 'Entertainment', iconKey: 'entertainment',
        colorValue: 0xFFEC4899, subcategories: [
          SubcategoryModel(name: 'Movies', iconKey: 'movies'),
          SubcategoryModel(name: 'Games', iconKey: 'games'),
          SubcategoryModel(name: 'Travel', iconKey: 'travel'),
          SubcategoryModel(name: 'Sports', iconKey: 'sports'),
          SubcategoryModel(name: 'Subscriptions', iconKey: 'subscriptions'),
        ]),
    CategoryModel(name: 'Health & Fitness', iconKey: 'health',
        colorValue: 0xFFEF4444, subcategories: [
          SubcategoryModel(name: 'Medicine', iconKey: 'medicine'),
          SubcategoryModel(name: 'Doctor', iconKey: 'doctor'),
        ]),
    CategoryModel(name: 'Utilities/Bills', iconKey: 'utilities',
        colorValue: 0xFFF59E0B, subcategories: [
          SubcategoryModel(name: 'Internet', iconKey: 'internet'),
          SubcategoryModel(name: 'Top-Up', iconKey: 'top_up'),
        ]),
    CategoryModel(name: 'Education', iconKey: 'education',
        colorValue: 0xFF6366F1, subcategories: [
          SubcategoryModel(name: 'Courses', iconKey: 'courses'),
          SubcategoryModel(name: 'Books', iconKey: 'books'),
          SubcategoryModel(name: 'Stationery', iconKey: 'stationery'),
          SubcategoryModel(name: 'Tuition Fee', iconKey: 'tuition_fee'),
          SubcategoryModel(name: 'Printing', iconKey: 'printing'),
        ]),
    CategoryModel(name: 'Social/Family', iconKey: 'social',
        colorValue: 0xFFF43F5E, subcategories: [
          SubcategoryModel(name: 'Cash Gifts', iconKey: 'cash_gifts'),
          SubcategoryModel(name: 'Gatherings', iconKey: 'gatherings'),
        ]),
    CategoryModel(name: 'Income', iconKey: 'income', colorValue: 0xFF22C55E,
        subcategories: [
          SubcategoryModel(name: 'Pocket Money', iconKey: 'pocket_money'),
          SubcategoryModel(name: 'Salary', iconKey: 'salary'),
          SubcategoryModel(name: 'Bonus', iconKey: 'bonus'),
          SubcategoryModel(name: 'Part-time', iconKey: 'part_time'),
          SubcategoryModel(
              name: 'Investment Returns', iconKey: 'investment_returns'),
          SubcategoryModel(
              name: 'Second-hand Sales', iconKey: 'secondhand_sales'),
        ]),
    CategoryModel(name: 'Others', iconKey: 'others', colorValue: 0xFF64748B),
  ];

  List<CategoryModel> _categories = List.from(_defaults);

  List<CategoryModel> get categories => List.unmodifiable(_categories);

  /// Ordered list of category name strings (for backward-compat consumers).
  List<String> get categoryNames => _categories.map((c) => c.name).toList();

  /// Looks up a category by name, or null when it no longer exists.
  CategoryModel? byName(String name) {
    for (final c in _categories) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// If [value] is a subcategory, returns the name of its parent category;
  /// otherwise null. Used so a transaction tagged with a subcategory can still
  /// resolve the parent's icon and be recognised as a valid selection.
  String? parentOf(String value) {
    for (final c in _categories) {
      if (c.subcategories.any((s) => s.name == value)) return c.name;
    }
    return null;
  }

  /// Looks up a subcategory (by its value) and its parent, or null.
  SubcategoryModel? subcategoryOf(String value) {
    for (final c in _categories) {
      for (final s in c.subcategories) {
        if (s.name == value) return s;
      }
    }
    return null;
  }

  /// Resolves the SVG glyph + background colour for a stored transaction
  /// [value], which may be a top-level category or a subcategory name. A
  /// subcategory shows its own glyph tinted with the parent's colour.
  CategoryVisual visualForValue(String value) {
    final cat = byName(value);
    if (cat != null) {
      return CategoryGlyphs.categoryVisual(
        name: cat.name,
        iconKey: cat.iconKey,
        colorValue: cat.colorValue,
      );
    }
    final parentName = parentOf(value);
    if (parentName != null) {
      final parent = byName(parentName);
      final sub = subcategoryOf(value);
      final color = CategoryGlyphs.categoryVisual(
        name: parentName,
        iconKey: parent?.iconKey,
        colorValue: parent?.colorValue,
      ).color;
      return CategoryVisual(
        CategoryGlyphs.subcategoryAssetFor(sub?.iconKey),
        color,
      );
    }
    // Unknown value (e.g. a deleted category still on old transactions).
    return CategoryVisual(
      CategoryGlyphs.placeholderSubcategory,
      const Color(0xFF64748B),
    );
  }

  /// True if [value] is a valid transaction category — either a top-level
  /// category or a subcategory of one.
  bool isSelectable(String value) =>
      byName(value) != null || parentOf(value) != null;

  /// Loads categories from the SQLite settings table.
  /// Falls back to [_defaults] if nothing is stored yet.
  Future<void> loadCategories() async {
    final raw = await DatabaseHelper.instance.getSetting(_settingsKey);
    if (raw == null) {
      _categories = List.from(_defaults);
    } else {
      final list = jsonDecode(raw) as List<dynamic>;
      _categories = list
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Clean the loaded data every launch: heal built-in icons, drop duplicate
    // rows, and guarantee "Others" exists. If anything was off, write the
    // corrected data straight back so storage self-heals.
    final (cleaned, changed) = sanitize(_categories);
    _categories = cleaned;
    if (changed) await _persist();

    notifyListeners();
  }

  /// Normalises a category list:
  ///  - drops duplicate names (case-insensitive, keeping the first),
  ///  - pins ONLY the protected "Others" category to its canonical icon (every
  ///    other category — including the built-ins — keeps whatever icon the user
  ///    has chosen, so built-in icons are user-customisable),
  ///  - guarantees the protected "Others" category is present.
  ///
  /// Returns the cleaned list and whether anything actually changed. Pure and
  /// side-effect free so it can be unit-tested without a database.
  @visibleForTesting
  static (List<CategoryModel>, bool) sanitize(List<CategoryModel> input) {
    var changed = false;
    final seen = <String>{};
    final out = <CategoryModel>[];

    for (final c in input) {
      if (!seen.add(c.name.toLowerCase())) {
        changed = true; // duplicate row dropped
        continue;
      }
      // "Others" stays cosmetically fixed; keep every other icon as chosen.
      if (c.name == protectedName && c.iconKey != 'others') {
        out.add(c.copyWith(iconKey: 'others'));
        changed = true;
      } else {
        out.add(c);
      }
    }

    if (!out.any((c) => c.name == protectedName)) {
      out.add(const CategoryModel(name: protectedName, iconKey: 'others'));
      changed = true;
    }
    return (out, changed);
  }

  /// True for the built-in categories (matched by their default name).
  static bool isBuiltIn(String name) =>
      CategoryIcons.builtInKeyFor(name) != null;

  /// Adds a new category with an icon + background colour. Does nothing if a
  /// category with the same name (case-insensitive) already exists.
  Future<void> addCategory(
    String name,
    String iconKey, {
    int? colorValue,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_categories.any(
      (c) => c.name.toLowerCase() == trimmed.toLowerCase(),
    )) {
      return;
    }

    _categories.add(
      CategoryModel(name: trimmed, iconKey: iconKey, colorValue: colorValue),
    );
    await _persist();
    notifyListeners();
  }

  /// Deletes a category by name. "Others" is protected and ignored.
  Future<void> deleteCategory(String name) async {
    if (name == protectedName) return;
    _categories.removeWhere((c) => c.name == name);
    await _persist();
    notifyListeners();
  }

  /// Changes a category's icon swatch and persists it — reflected everywhere
  /// the icon is resolved via [CategoryIcons.resolve]. Works for built-in and
  /// user-created categories alike; only the protected "Others" is locked.
  Future<void> setIcon(String name, String iconKey) async {
    if (name == protectedName) return;
    final idx = _categories.indexWhere((c) => c.name == name);
    if (idx == -1) return;
    _categories[idx] = _categories[idx].copyWith(iconKey: iconKey);
    await _persist();
    notifyListeners();
  }

  /// Changes a category's background colour. "Others" is locked.
  Future<void> setColor(String name, int colorValue) async {
    if (name == protectedName) return;
    final idx = _categories.indexWhere((c) => c.name == name);
    if (idx == -1) return;
    _categories[idx] = _categories[idx].copyWith(colorValue: colorValue);
    await _persist();
    notifyListeners();
  }

  /// Renames a category and cascades the rename to every record that
  /// references it by name (transactions, budgets, recurring templates).
  ///
  /// Returns false when the new name is empty, unchanged, clashes with an
  /// existing category, or the category is protected.
  Future<bool> renameCategory(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || oldName == protectedName) return false;
    if (trimmed == oldName) return true;
    if (_categories.any((c) => c.name.toLowerCase() == trimmed.toLowerCase())) {
      return false;
    }
    final idx = _categories.indexWhere((c) => c.name == oldName);
    if (idx == -1) return false;

    _categories[idx] = _categories[idx].copyWith(name: trimmed);
    await _persist();
    await DatabaseHelper.instance.renameCategoryEverywhere(oldName, trimmed);
    notifyListeners();
    return true;
  }

  /// Adds a subcategory with an optional icon. Ignores blanks and
  /// case-insensitive duplicates.
  Future<void> addSubcategory(
    String categoryName,
    String subcategory, {
    String? iconKey,
  }) async {
    final trimmed = subcategory.trim();
    if (trimmed.isEmpty) return;
    final idx = _categories.indexWhere((c) => c.name == categoryName);
    if (idx == -1) return;

    final existing = _categories[idx].subcategories;
    if (existing.any((s) => s.name.toLowerCase() == trimmed.toLowerCase())) {
      return;
    }

    _categories[idx] = _categories[idx].copyWith(
      subcategories: [
        ...existing,
        SubcategoryModel(name: trimmed, iconKey: iconKey),
      ],
    );
    await _persist();
    notifyListeners();
  }

  /// Changes an existing subcategory's icon.
  Future<void> setSubcategoryIcon(
    String categoryName,
    String subcategory,
    String iconKey,
  ) async {
    final idx = _categories.indexWhere((c) => c.name == categoryName);
    if (idx == -1) return;
    final subs = [
      for (final s in _categories[idx].subcategories)
        s.name == subcategory ? s.copyWith(iconKey: iconKey) : s,
    ];
    _categories[idx] = _categories[idx].copyWith(subcategories: subs);
    await _persist();
    notifyListeners();
  }

  Future<void> deleteSubcategory(
    String categoryName,
    String subcategory,
  ) async {
    final idx = _categories.indexWhere((c) => c.name == categoryName);
    if (idx == -1) return;
    final updated = [..._categories[idx].subcategories]
      ..removeWhere((s) => s.name == subcategory);
    _categories[idx] = _categories[idx].copyWith(subcategories: updated);
    await _persist();
    notifyListeners();
  }

  /// Resolves the icon swatch for a category name (used by display surfaces
  /// that only know the name, e.g. transaction rows).
  CategoryIconOption iconFor(String name) =>
      CategoryIcons.resolve(name, byName(name)?.iconKey);

  Future<void> _persist() async {
    final json = jsonEncode(_categories.map((c) => c.toJson()).toList());
    await DatabaseHelper.instance.setSetting(_settingsKey, json);
  }
}
