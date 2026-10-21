import 'package:flutter_test/flutter_test.dart';
import 'package:basha_lagbe/main.dart';

void main() {
  testWidgets('BashaLagbeApp smoke test and navigation to Post tab', (WidgetTester tester) async {
    await tester.pumpWidget(const BashaLagbeApp());
    await tester.pumpAndSettle();

    // Verify Home tab elements
    expect(find.text('BashaLagbe'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Post'), findsOneWidget);

    // Tap the 'Post' tab on the bottom navigation bar
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    // Verify Post Property Screen is rendered
    expect(find.text('Post a Rental Property'), findsOneWidget);
    expect(find.text('Property Wizard'), findsOneWidget);
    expect(find.text('My Listings'), findsOneWidget);
    expect(find.text('Basic Information'), findsOneWidget);
  });
}
