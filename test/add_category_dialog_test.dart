import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/providers/category_provider.dart';
import 'package:receipto/screens/manage_categories_screen.dart';

/// Regression test for the Add Category dialog rendering nothing but a scrim.
///
/// AlertDialog wraps its content in an IntrinsicWidth, which queries children
/// for intrinsic dimensions. A scrolling viewport (GridView/ListView) throws
/// when asked for those, so the dialog failed to lay out. The icon swatches
/// must therefore stay a non-scrolling layout (Wrap).
void main() {
  testWidgets('Add Category dialog renders its content without throwing',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CategoryProvider(),
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ManageCategoriesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Category'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Category name'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
