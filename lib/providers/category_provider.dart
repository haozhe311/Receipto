import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:receipto/models/category_model.dart';
import 'package:receipto/services/database_helper.dart';

/// Manages the dynamic list of transaction categories.
///
/// Categories are persisted as a JSON string in the SQLite settings table
/// under the key [_settingsKey]. On first launch (no stored value) the
/// provider falls back to [_defaults]. "Others" is always kept as a
/// fallback and cannot be deleted.
class CategoryProvider extends ChangeNotifier {
  static const String _settingsKey = 'categories';

  /// Built-in categories with default emojis.
  /// The emoji is displayed in the Manage Categories list and (for custom
  /// categories only) in the category chip widget.
  static const List<CategoryModel> _defaults = [
    CategoryModel(name: 'Food',          emoji: '🍽️'),
    CategoryModel(name: 'Transport',     emoji: '🚗'),
    CategoryModel(name: 'Shopping',      emoji: '🛍️'),
    CategoryModel(name: 'Entertainment', emoji: '🎬'),
    CategoryModel(name: 'Health',        emoji: '🏥'),
    CategoryModel(name: 'Utilities',     emoji: '⚡'),
    CategoryModel(name: 'Others',        emoji: '📦'),
  ];

  List<CategoryModel> _categories = List.from(_defaults);

  List<CategoryModel> get categories => List.unmodifiable(_categories);

  /// Ordered list of category name strings (for backward-compat consumers).
  List<String> get categoryNames =>
      _categories.map((c) => c.name).toList();

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
      if (!_categories.any((c) => c.name == 'Others')) {
        _categories.add(const CategoryModel(name: 'Others', emoji: '📦'));
    }
    }
    notifyListeners();
  }

  /// Adds a new category. Does nothing if a category with the same name
  /// (case-insensitive) already exists.
  Future<void> addCategory(String name, String emoji) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) { return; }
    if (_categories.any(
      (c) => c.name.toLowerCase() == trimmed.toLowerCase(),
    )) { return; }

    _categories.add(CategoryModel(name: trimmed, emoji: emoji.trim()));
    await _persist();
    notifyListeners();
  }

  /// Deletes a category by name. "Others" is protected and ignored.
  Future<void> deleteCategory(String name) async {
    if (name == 'Others') return;
    _categories.removeWhere((c) => c.name == name);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final json = jsonEncode(_categories.map((c) => c.toJson()).toList());
    await DatabaseHelper.instance.setSetting(_settingsKey, json);
  }
}
