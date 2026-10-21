import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:basha_lagbe/main.dart';

void main() {
  testWidgets('BashaLagbeApp smoke test and navigation across tabs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const BashaLagbeApp());
    await tester.pumpAndSettle();

    // Verify Home tab elements
    expect(find.text('BashaLagbe'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Post'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // 1. Navigate to Post tab
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    expect(find.text('Post a Rental Property'), findsOneWidget);
    expect(find.text('Property Wizard'), findsOneWidget);
    expect(find.text('My Listings'), findsOneWidget);

    // 2. Navigate to Profile tab
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    // Verify Profile header and user details
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Tanvir Ahmed'), findsOneWidget);
    expect(find.text('tanvir.basha@gmail.com'), findsOneWidget);
    expect(find.text('+880 1712-345678'), findsOneWidget);
    expect(find.text('Edit Profile Details'), findsOneWidget);

    // Verify My Activity section
    expect(find.text('My Activity'), findsOneWidget);
    expect(find.text('My Listings'), findsOneWidget);
    expect(find.text('Saved Properties'), findsOneWidget);
    expect(find.text('My Rental Requests'), findsOneWidget);

    // Verify Support & Settings section
    expect(find.text('Settings & Preferences'), findsOneWidget);
    expect(find.text('Rental Notifications'), findsOneWidget);
    expect(find.text('Help & FAQs'), findsOneWidget);
    expect(find.text('About BashaLagbe'), findsOneWidget);
    expect(find.text('Privacy Policy & Terms'), findsOneWidget);

    // 3. Test tapping Saved Properties in Activity navigates to Saved tab
    await tester.tap(find.text('Saved Properties'));
    await tester.pumpAndSettle();
    expect(find.text('Saved Homes'), findsOneWidget);

    // 4. Return to Profile tab
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('My Profile'), findsOneWidget);

    // 5. Test opening Edit Profile modal
    await tester.tap(find.text('Edit Profile Details'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Demo Profile'), findsOneWidget);
    expect(find.text('Save Edits'), findsOneWidget);

    // Cancel edit modal
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Demo Profile'), findsNothing);
  });
}
