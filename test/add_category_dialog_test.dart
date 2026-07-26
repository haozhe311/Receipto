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
/// when asked for those. The dialog side-steps this by giving its content a
/// fixed-width SizedBox, so IntrinsicWidth resolves without recursing into the
/// icon/colour grids.
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

    // With the full preset list, the button sits below the fold — scroll to it.
    final addButton = find.text('Add Category');
    await tester.scrollUntilVisible(addButton, 300);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Icon'), findsWidgets);
    expect(find.text('Colour'), findsWidgets);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
