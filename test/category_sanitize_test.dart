import 'package:flutter_test/flutter_test.dart';
import 'package:receipto/models/category_model.dart';
import 'package:receipto/providers/category_provider.dart';

/// Verifies the data-layer normalisation: built-in category icons are now
/// user-customisable and preserved (only the protected "Others" stays pinned),
/// duplicate rows are dropped, and "Others" is guaranteed present.
void main() {
  test('preserves a built-in category\'s customised icon', () {
    final custom = [
      const CategoryModel(name: 'Food', iconKey: 'coffee'), // user's choice
      const CategoryModel(name: 'Transport', iconKey: 'travel'),
      const CategoryModel(name: 'Others', iconKey: 'others'),
    ];

    final (cleaned, changed) = CategoryProvider.sanitize(custom);

    expect(changed, isFalse);
    expect(cleaned.firstWhere((c) => c.name == 'Food').iconKey, 'coffee');
    expect(cleaned.firstWhere((c) => c.name == 'Transport').iconKey, 'travel');
  });

  test('pins the protected "Others" icon back if it drifted', () {
    final drifted = [
      const CategoryModel(name: 'Food', iconKey: 'food'),
      const CategoryModel(name: 'Others', iconKey: 'shopping'), // drifted
    ];

    final (cleaned, changed) = CategoryProvider.sanitize(drifted);

    expect(changed, isTrue);
    expect(cleaned.firstWhere((c) => c.name == 'Others').iconKey, 'others');
    expect(cleaned.firstWhere((c) => c.name == 'Food').iconKey, 'food');
  });

  test('drops duplicate category rows, keeping the first', () {
    final withDupes = [
      const CategoryModel(name: 'Food', iconKey: 'food'),
      const CategoryModel(name: 'Food', iconKey: 'shopping'), // orphaned dupe
      const CategoryModel(name: 'Others', iconKey: 'others'),
    ];

    final (cleaned, changed) = CategoryProvider.sanitize(withDupes);

    expect(changed, isTrue);
    expect(cleaned.where((c) => c.name == 'Food').length, 1);
    expect(cleaned.firstWhere((c) => c.name == 'Food').iconKey, 'food');
  });

  test('does not touch a custom category\'s icon', () {
    final list = [
      const CategoryModel(name: 'Coffee', iconKey: 'coffee'),
      const CategoryModel(name: 'Others', iconKey: 'others'),
    ];

    final (cleaned, changed) = CategoryProvider.sanitize(list);

    expect(changed, isFalse);
    expect(cleaned.firstWhere((c) => c.name == 'Coffee').iconKey, 'coffee');
  });

  test('guarantees Others when missing', () {
    final (cleaned, changed) = CategoryProvider.sanitize(
      [const CategoryModel(name: 'Food', iconKey: 'food')],
    );
    expect(changed, isTrue);
    expect(cleaned.any((c) => c.name == 'Others'), isTrue);
  });

  test('a clean list is reported unchanged and untouched', () {
    final list = [
      const CategoryModel(name: 'Food', iconKey: 'food'),
      const CategoryModel(name: 'Transport', iconKey: 'transport'),
      const CategoryModel(name: 'Others', iconKey: 'others'),
    ];
    final (cleaned, changed) = CategoryProvider.sanitize(list);
    expect(changed, isFalse);
    expect(cleaned.length, list.length);
  });

  test('built-ins cannot be identified as custom', () {
    expect(CategoryProvider.isBuiltIn('Food'), isTrue);
    expect(CategoryProvider.isBuiltIn('Health & Fitness'), isTrue);
    expect(CategoryProvider.isBuiltIn('Coffee'), isFalse);
  });
}
