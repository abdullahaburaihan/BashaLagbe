import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:basha_lagbe/main.dart';
import 'package:basha_lagbe/services/auth_service.dart';
import 'package:basha_lagbe/services/firestore_service.dart';

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

    // Verify Profile header and signed-out card
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Welcome to BashaLagbe'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(
      find.text('Currently browsing as guest. Saved homes and search work locally.'),
      findsOneWidget,
    );

    // Verify that the old demo profile (Tanvir Ahmed) is NOT shown when signed out
    expect(find.text('Tanvir Ahmed'), findsNothing);
    expect(find.text('tanvir.basha@gmail.com'), findsNothing);
    expect(find.text('Edit Demo Profile'), findsNothing);

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
    expect(find.text('Welcome to BashaLagbe'), findsOneWidget);
  });

  testWidgets('Firebase Auth dialog and form validation test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const BashaLagbeApp());
    await tester.pumpAndSettle();

    // Go to Profile tab
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    // Tap "Sign In" button in signed-out card
    final signInButton = find.widgetWithText(FilledButton, 'Sign In');
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    // Verify AuthSheet is displayed in Sign In mode
    expect(find.text('Sign in to BashaLagbe'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);

    // Trigger validation on empty submission
    // Find the submit button with text 'Sign In' inside the dialog/sheet
    final submitButton = find.widgetWithText(FilledButton, 'Sign In').last;
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email.'), findsOneWidget);
    expect(find.text('Please enter a password.'), findsOneWidget);

    // Test Forgot Password Dialog
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.text('Send Link'), findsOneWidget);

    // Close Forgot Password dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Reset Password'), findsNothing);

    // Switch to Register tab
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    expect(find.text('Create Your Account'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);

    // Close Auth dialog/sheet
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();
    expect(find.text('Create Your Account'), findsNothing);
  });

  test('AuthService error translation unit tests', () {
    expect(
      AuthService.getFriendlyErrorMessage(FirebaseAuthException(code: 'user-not-found')),
      contains('No account found with this email'),
    );
    expect(
      AuthService.getFriendlyErrorMessage(FirebaseAuthException(code: 'wrong-password')),
      contains('Incorrect password'),
    );
    expect(
      AuthService.getFriendlyErrorMessage(FirebaseAuthException(code: 'invalid-credential')),
      contains('Invalid email or password'),
    );
    expect(
      AuthService.getFriendlyErrorMessage(FirebaseAuthException(code: 'email-already-in-use')),
      contains('already exists'),
    );
    expect(
      AuthService.getFriendlyErrorMessage(FirebaseAuthException(code: 'weak-password')),
      contains('at least 6 characters'),
    );
    expect(
      AuthService.getFriendlyErrorMessage(FirebaseAuthException(code: 'operation-not-allowed')),
      contains('Email/password sign-in is not enabled in Firebase Console'),
    );
    expect(
      AuthService.getFriendlyErrorMessage(FirebaseAuthException(code: 'too-many-requests')),
      contains('Too many failed attempts'),
    );
    expect(
      AuthService.getFriendlyErrorMessage(FirebaseAuthException(code: 'network-request-failed')),
      contains('Network error'),
    );
  });

  test('FirestoreService initialization and error translation tests', () {
    // 1. Verify collection constants
    expect(FirestoreService.usersCollection, 'users');
    expect(FirestoreService.propertiesCollection, 'properties');
    expect(FirestoreService.rentalRequestsCollection, 'rental_requests');

    // 2. In uninitialized headless test environment, accessing firestore throws a clear exception
    final service = FirestoreService.instance;
    if (!service.isFirebaseAvailable) {
      expect(
        () => service.firestore,
        throwsA(isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'app-not-initialized',
        )),
      );
    }

    // 3. Verify error message translation
    expect(
      FirestoreService.getFriendlyErrorMessage(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
      contains('permission'),
    );
    expect(
      FirestoreService.getFriendlyErrorMessage(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ),
      contains('unavailable'),
    );
    expect(
      FirestoreService.getFriendlyErrorMessage(
        FirebaseException(plugin: 'cloud_firestore', code: 'unauthenticated'),
      ),
      contains('signed in'),
    );
    expect(
      FirestoreService.getFriendlyErrorMessage(
        FirebaseException(plugin: 'cloud_firestore', code: 'not-found'),
      ),
      contains('not found'),
    );
  });
}
