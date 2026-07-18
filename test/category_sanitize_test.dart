import 'package:flutter_test/flutter_test.dart';
import 'package:receipto/models/category_model.dart';
import 'package:receipto/providers/category_provider.dart';

/// Verifies the data-layer self-heal that fixes the recurring icon corruption:
/// built-in categories whose stored iconKey drifted are forced back to their
/// canonical value, duplicate rows are dropped, and "Others" is guaranteed.
void main() {
  test('heals a built-in whose iconKey was overwritten (Food -> shopping)', () {
    final corrupted = [
      const CategoryModel(name: 'Food', iconKey: 'shopping'), // corrupted
      const CategoryModel(name: 'Transport', iconKey: 'transport'),
      const CategoryModel(name: 'Others', iconKey: 'others'),
    ];

    final (cleaned, changed) = CategoryProvider.sanitize(corrupted);

    expect(changed, isTrue);
    expect(cleaned.firstWhere((c) => c.name == 'Food').iconKey, 'food');
    expect(
        cleaned.firstWhere((c) => c.name == 'Transport').iconKey, 'transport');
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
    expect(CategoryProvider.isBuiltIn('Health'), isTrue);
    expect(CategoryProvider.isBuiltIn('Coffee'), isFalse);
  });
}
