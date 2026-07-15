import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  /// Built-in categories, each pinned to the icon swatch it has always used.
  static const List<CategoryModel> _defaults = [
    CategoryModel(name: 'Food', iconKey: 'food', emoji: '🍽️'),
    CategoryModel(name: 'Transport', iconKey: 'transport', emoji: '🚗'),
    CategoryModel(name: 'Shopping', iconKey: 'shopping', emoji: '🛍️'),
    CategoryModel(name: 'Entertainment', iconKey: 'entertainment', emoji: '🎬'),
    CategoryModel(name: 'Health', iconKey: 'health', emoji: '🏥'),
    CategoryModel(name: 'Utilities', iconKey: 'utilities', emoji: '⚡'),
    CategoryModel(name: 'Others', iconKey: 'others', emoji: '📦'),
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

      // Always guarantee "Others" as the last-resort fallback.
      if (!_categories.any((c) => c.name == protectedName)) {
        _categories.add(
          const CategoryModel(name: protectedName, iconKey: 'others'),
        );
      }
    }
    notifyListeners();
  }

  /// Adds a new category with an icon swatch. Does nothing if a category with
  /// the same name (case-insensitive) already exists.
  Future<void> addCategory(String name, String iconKey) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_categories.any(
      (c) => c.name.toLowerCase() == trimmed.toLowerCase(),
    )) {
      return;
    }

    _categories.add(CategoryModel(name: trimmed, iconKey: iconKey));
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

  /// Changes a category's icon swatch.
  Future<void> setIcon(String name, String iconKey) async {
    final idx = _categories.indexWhere((c) => c.name == name);
    if (idx == -1) return;
    _categories[idx] = _categories[idx].copyWith(iconKey: iconKey);
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

  /// Adds a subcategory. Ignores blanks and case-insensitive duplicates.
  Future<void> addSubcategory(String categoryName, String subcategory) async {
    final trimmed = subcategory.trim();
    if (trimmed.isEmpty) return;
    final idx = _categories.indexWhere((c) => c.name == categoryName);
    if (idx == -1) return;

    final existing = _categories[idx].subcategories;
    if (existing.any((s) => s.toLowerCase() == trimmed.toLowerCase())) return;

    _categories[idx] =
        _categories[idx].copyWith(subcategories: [...existing, trimmed]);
    await _persist();
    notifyListeners();
  }

  Future<void> deleteSubcategory(
    String categoryName,
    String subcategory,
  ) async {
    final idx = _categories.indexWhere((c) => c.name == categoryName);
    if (idx == -1) return;
    final updated = [..._categories[idx].subcategories]..remove(subcategory);
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
