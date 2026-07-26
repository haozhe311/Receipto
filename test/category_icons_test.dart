import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipto/constants/category_icons.dart';
import 'package:receipto/models/category_model.dart';

/// Guards the category icon mapping. Transport/Health once rendered Shopping's
/// icon because their persisted iconKey had been overwritten; these tests pin
/// the resolution rules so a regression in the mapping is caught here.
void main() {
  test('built-in categories resolve to their canonical icon and colour', () {
    const expected = {
      'Food': (Icons.restaurant, 0xFFFF7043),
      'Transportation': (Icons.directions_car, 0xFF42A5F5),
      'Shopping': (Icons.shopping_bag, 0xFFAB47BC),
      'Entertainment': (Icons.movie, 0xFFFFCA28),
      'Health & Fitness': (Icons.local_hospital, 0xFFEF5350),
      'Utilities/Bills': (Icons.bolt, 0xFF66BB6A),
      'Others': (Icons.more_horiz, 0xFF78909C),
    };

    for (final entry in expected.entries) {
      final resolved = CategoryIcons.resolve(entry.key, null);
      expect(resolved.icon, entry.value.$1, reason: entry.key);
      expect(resolved.color.toARGB32(), entry.value.$2, reason: entry.key);
    }
  });

  test('every built-in name maps to a preset that actually exists', () {
    for (final name in const [
      'Food',
      'Transportation',
      'Shopping',
      'Entertainment',
      'Health & Fitness',
      'Utilities/Bills',
      'Others',
    ]) {
      final key = CategoryIcons.builtInKeyFor(name);
      expect(key, isNotNull, reason: name);
      expect(CategoryIcons.byKey(key), isNotNull, reason: name);
    }
  });

  test('preset keys are unique', () {
    final keys = CategoryIcons.presets.map((p) => p.key).toList();
    expect(keys.toSet().length, keys.length);
  });

  test('an explicit iconKey wins, and does not leak across categories', () {
    expect(
        CategoryIcons.resolve('Transportation', 'shopping').icon, Icons.shopping_bag);
    expect(CategoryIcons.resolve('Transportation', null).icon, Icons.directions_car);
    expect(CategoryIcons.resolve('Health & Fitness', null).icon, Icons.local_hospital);
  });

  test('CategoryModel JSON round-trip preserves iconKey and subcategories', () {
    const original = CategoryModel(
      name: 'Transportation',
      iconKey: 'transport',
      subcategories: [
        SubcategoryModel(name: 'Bus', iconKey: 'bus'),
        SubcategoryModel(name: 'Grab'),
      ],
    );
    final restored = CategoryModel.fromJson(original.toJson());
    expect(restored.iconKey, 'transport');
    expect(restored.subcategories.map((s) => s.name), ['Bus', 'Grab']);
    expect(restored.subcategories.first.iconKey, 'bus');
  });

  test('legacy subcategories as bare strings still parse', () {
    final restored = CategoryModel.fromJson({
      'name': 'Food',
      'subcategories': ['Lunch', 'Dinner'],
    });
    expect(restored.subcategories.map((s) => s.name), ['Lunch', 'Dinner']);
    expect(restored.subcategories.first.iconKey, isNull);
  });

  test('legacy JSON without iconKey still resolves by name', () {
    final restored = CategoryModel.fromJson({'name': 'Health & Fitness', 'emoji': '🏥'});
    expect(restored.iconKey, isNull);
    expect(
      CategoryIcons.resolve(restored.name, restored.iconKey).icon,
      Icons.local_hospital,
    );
  });
}
