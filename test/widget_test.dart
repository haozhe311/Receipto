import 'package:flutter_test/flutter_test.dart';
import 'package:receipto/main.dart';

void main() {
  testWidgets('App launches with Receipto title', (WidgetTester tester) async {
    await tester.pumpWidget(const ReceiptoApp());
    expect(find.text('Receipto'), findsOneWidget);
  });
}
