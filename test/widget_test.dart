import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:basha_lagbe/main.dart';
import 'package:basha_lagbe/post_property_screen.dart';
import 'package:basha_lagbe/profile_screen.dart';
import 'package:basha_lagbe/services/auth_service.dart';
import 'package:basha_lagbe/services/firestore_service.dart';
import 'package:basha_lagbe/property_details_screen.dart';
import 'package:basha_lagbe/services/cloudinary_service.dart';

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

  test('FirestoreService favourite methods handle uninitialized/empty inputs safely', () async {
    final service = FirestoreService.instance;

    // Stream with empty UID should return empty stream
    final streamEmpty = service.streamFavourites('');
    expect(await streamEmpty.isEmpty, isTrue);

    // Get favourites with empty UID should return empty set
    final setEmpty = await service.getFavourites('');
    expect(setEmpty, isEmpty);

    // Add and remove favourite with empty inputs should complete without throwing
    await expectLater(service.addFavourite('', ''), completes);
    await expectLater(service.removeFavourite('', ''), completes);
  });

  testWidgets('Guest favourites toggle and synchronization across Home and Saved tabs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const testProp = Property(
      id: 'approved-prop-1',
      title: 'Green Nest Family Flat',
      area: 'Mirpur 10, Dhaka',
      landmark: 'Near Mirpur 10 Metro Rail Station',
      fullAddress: 'Road 4, Block C, Section 10, Mirpur, Dhaka',
      rentPerMonth: 18000,
      depositAmount: 36000,
      sizeSqFt: 1250,
      floorLevel: '4th Floor (Lift-3)',
      balconies: 2,
      type: PropertyType.family,
      bedrooms: 3,
      bathrooms: 2,
      availability: 'Available now',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Color(0xFF2E9E6B),
      gradientEnd: Color(0xFF0E5E3B),
      description: 'Spacious family flat.',
      facilities: ['Lift (Elevator)'],
      nearbyHighlights: ['Metro Station'],
      photos: [],
      utilityNotice: 'Water & Gas included in rent.',
      isDemo: false,
    );

    await tester.pumpWidget(const BashaLagbeApp(initialApprovedProperties: [testProp]));
    await tester.pumpAndSettle();

    // In Home screen, initially no properties are saved
    // Verify first property card favorite icon exists
    final saveButton = find.byTooltip('Save this home').first;
    expect(saveButton, findsOneWidget);

    // Tap to save the first property
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Now it should show tooltip 'Remove from saved'
    expect(find.byTooltip('Remove from saved'), findsOneWidget);

    // Navigate to Saved tab
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();

    // Verify Saved tab shows 1 saved home
    expect(find.text('Saved Homes'), findsOneWidget);
    expect(find.text('1 homes saved'), findsOneWidget);

    // Tap remove from saved on the Saved tab
    final removeButton = find.byTooltip('Remove from saved');
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    // Verify empty state is displayed
    expect(find.text('0 homes saved'), findsOneWidget);
    expect(find.text('No saved homes yet'), findsOneWidget);
  });

  test('FirestoreService property converters handle empty/partial data cleanly', () {
    final emptyData = <String, dynamic>{};
    final prop = FirestoreService.propertyFromFirestore('test-123', emptyData);
    expect(prop.id, 'test-123');
    expect(prop.title, 'Rental Property');
    expect(prop.rentPerMonth, 0);
    expect(prop.type, PropertyType.family);
    expect(prop.isDemo, isFalse);

    final listing = FirestoreService.submittedListingFromFirestore('sub-456', {
      'title': 'Test Flat',
      'rentPerMonth': 20000,
      'status': 'pending',
      'ownerId': 'user-1',
    });
    expect(listing.id, 'sub-456');
    expect(listing.property.title, 'Test Flat');
    expect(listing.property.rentPerMonth, 20000);
    expect(listing.status, ListingStatus.pendingReview);
    expect(listing.ownerId, 'user-1');
  });

  test('FirestoreService property methods handle uninitialized/empty inputs safely', () async {
    final service = FirestoreService.instance;

    // Streams should return empty without throwing
    expect(await service.streamApprovedProperties().isEmpty, isTrue);
    expect(await service.streamUserListings('').isEmpty, isTrue);

    // Empty user ID calls should throw unauthenticated/invalid-argument FirebaseException
    await expectLater(
      () => service.createProperty(ownerId: '', ownerEmail: '', data: {}),
      throwsA(isA<FirebaseException>()),
    );
    await expectLater(
      () => service.updateProperty(propertyId: '', ownerId: '', updates: {}),
      throwsA(isA<FirebaseException>()),
    );
    await expectLater(
      () => service.deleteProperty(propertyId: '', ownerId: ''),
      throwsA(isA<FirebaseException>()),
    );
  });

  testWidgets('Post Property screen shows landlord sign-in banner and opens auth modal', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const BashaLagbeApp());
    await tester.pumpAndSettle();

    // Navigate to Post tab
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    // Verify Landlord Sign-In Required banner is shown
    expect(find.text('Landlord Sign-In Required'), findsOneWidget);
    expect(find.text('Browsing as guest. Sign in to submit and persist your property to Cloud Firestore.'), findsOneWidget);

    // Tap Sign In button on the banner
    final signInBtn = find.widgetWithText(FilledButton, 'Sign In').first;
    await tester.tap(signInBtn);
    await tester.pumpAndSettle();

    // Verify AuthSheet dialog appears
    expect(find.text('Sign in to BashaLagbe'), findsOneWidget);
  });

  testWidgets('Home displays friendly empty state when no approved properties exist and PropertyCard handles badges correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const BashaLagbeApp());
    await tester.pumpAndSettle();

    // Home screen contains no hardcoded demo properties and shows friendly empty state
    expect(find.text('No approved properties yet'), findsOneWidget);
    expect(find.text('Post a Property'), findsOneWidget);
    expect(find.text('Demo Preview'), findsNothing);
    expect(find.textContaining('Demo listings: all homes shown here are fictional'), findsNothing);

    // Verify PropertyCard badge logic for verified cloud vs demo preview
    const cloudProp = Property(
      id: 'cloud-1',
      title: 'Cloud Verified Apartment',
      area: 'Banani',
      landmark: '',
      rentPerMonth: 35000,
      type: PropertyType.family,
      bedrooms: 3,
      bathrooms: 3,
      availability: 'Available now',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Color(0xFF2E9E6B),
      gradientEnd: Color(0xFF0E5E3B),
      isDemo: false,
    );
    const demoProp = Property(
      id: 'demo-1',
      title: 'Demo Apartment',
      area: 'Mirpur',
      landmark: '',
      rentPerMonth: 20000,
      type: PropertyType.family,
      bedrooms: 2,
      bathrooms: 2,
      availability: 'Available now',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Color(0xFF2E9E6B),
      gradientEnd: Color(0xFF0E5E3B),
      isDemo: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                PropertyCard(
                  property: cloudProp,
                  isFavourite: false,
                  onFavouriteTap: () {},
                  onTap: () {},
                ),
                PropertyCard(
                  property: demoProp,
                  isFavourite: false,
                  onFavouriteTap: () {},
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verified Cloud'), findsOneWidget);
    expect(find.text('Demo Preview'), findsOneWidget);
  });

  testWidgets('Verify Firebase UID is not displayed on Post and Profile screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const BashaLagbeApp());
    await tester.pumpAndSettle();

    // Check Home
    expect(find.textContaining('Firebase UID'), findsNothing);

    // Check Post
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Firebase UID'), findsNothing);

    // Check Profile
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Firebase UID'), findsNothing);
  });

  test('Phase 1: Property model ownerId field works properly', () {
    const propDefault = Property(
      id: 'prop-1',
      title: 'Flat 1',
      area: 'Dhanmondi',
      landmark: 'Lake',
      rentPerMonth: 25000,
      type: PropertyType.family,
      bedrooms: 3,
      bathrooms: 2,
      availability: 'Immediate',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.green,
      gradientEnd: Colors.teal,
    );
    expect(propDefault.ownerId, isNull);

    const propWithOwner = Property(
      id: 'prop-2',
      title: 'Flat 2',
      area: 'Gulshan',
      landmark: 'Park',
      rentPerMonth: 50000,
      type: PropertyType.family,
      bedrooms: 3,
      bathrooms: 3,
      availability: 'Next Month',
      availableNow: false,
      icon: Icons.apartment,
      gradientStart: Colors.green,
      gradientEnd: Colors.teal,
      ownerId: 'landlord_uid_123',
    );
    expect(propWithOwner.ownerId, 'landlord_uid_123');
  });

  test('Phase 1: RentalRequest model and status helpers work properly', () {
    final now = DateTime(2026, 10, 22, 10, 0);
    final req = RentalRequest(
      id: 'req_123',
      property: const Property(
        id: 'prop_1',
        title: 'Title',
        area: 'Area',
        landmark: '',
        rentPerMonth: 20000,
        type: PropertyType.family,
        bedrooms: 2,
        bathrooms: 1,
        availability: 'Available',
        availableNow: true,
        icon: Icons.apartment,
        gradientStart: Colors.green,
        gradientEnd: Colors.teal,
      ),
      renterName: 'Karim',
      renterPhone: '01711111111',
      preferredMoveIn: 'Immediate',
      message: 'Can I visit tomorrow?',
      requestedAt: now,
      status: 'pending',
      ownerId: 'landlord_1',
      tenantId: 'tenant_1',
      tenantEmail: 'karim@test.com',
    );

    expect(req.isPending, isTrue);
    expect(req.isAccepted, isFalse);
    expect(req.isRejected, isFalse);
    expect(req.isCancelled, isFalse);

    final accepted = req.copyWith(status: 'accepted', landlordNote: 'Visit at 3 PM');
    expect(accepted.isAccepted, isTrue);
    expect(accepted.isPending, isFalse);
    expect(accepted.landlordNote, 'Visit at 3 PM');

    final rejected = req.copyWith(status: 'rejected');
    expect(rejected.isRejected, isTrue);

    final cancelled = req.copyWith(status: 'cancelled');
    expect(cancelled.isCancelled, isTrue);
  });

  test('Phase 1: FirestoreService converts rental request maps properly', () {
    final data = {
      'propertyId': 'p_456',
      'ownerId': 'owner_abc',
      'tenantId': 'tenant_xyz',
      'tenantEmail': 'tenant@test.com',
      'tenantName': 'Rahim',
      'tenantPhone': '01822222222',
      'preferredMoveIn': '1st of next month',
      'message': 'Family of 3',
      'propertyTitle': 'Sunny Apartment',
      'propertyArea': 'Uttara',
      'rentPerMonth': 30000,
      'propertyPhotoUrl': 'https://example.com/photo.jpg',
      'status': 'pending',
      'landlordNote': null,
    };

    final request = FirestoreService.rentalRequestFromFirestore('doc_req_789', data);
    expect(request.id, 'doc_req_789');
    expect(request.ownerId, 'owner_abc');
    expect(request.tenantId, 'tenant_xyz');
    expect(request.tenantEmail, 'tenant@test.com');
    expect(request.renterName, 'Rahim');
    expect(request.renterPhone, '01822222222');
    expect(request.preferredMoveIn, '1st of next month');
    expect(request.message, 'Family of 3');
    expect(request.property.title, 'Sunny Apartment');
    expect(request.property.area, 'Uttara');
    expect(request.property.rentPerMonth, 30000);
    expect(request.status, 'pending');
    expect(request.isPending, isTrue);
    expect(request.landlordNote, isNull);
  });

  test('Phase 1: FirestoreService validates rental request arguments and guards safely', () async {
    final service = FirestoreService.instance;

    // 1. Unauthenticated / empty tenant
    expect(
      () => service.createRentalRequest(
        propertyId: 'p1',
        ownerId: 'owner1',
        tenantId: '',
        tenantEmail: 't@test.com',
        tenantName: 'Name',
        tenantPhone: '017',
        preferredMoveIn: 'Immediate',
        propertyTitle: 'Title',
        propertyArea: 'Area',
        rentPerMonth: 20000,
      ),
      throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unauthenticated')),
    );

    // 2. Empty property or owner ID
    expect(
      () => service.createRentalRequest(
        propertyId: '',
        ownerId: 'owner1',
        tenantId: 'tenant1',
        tenantEmail: 't@test.com',
        tenantName: 'Name',
        tenantPhone: '017',
        preferredMoveIn: 'Immediate',
        propertyTitle: 'Title',
        propertyArea: 'Area',
        rentPerMonth: 20000,
      ),
      throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'invalid-argument')),
    );

    // 3. Self-rental request (tenantId == ownerId)
    expect(
      () => service.createRentalRequest(
        propertyId: 'p1',
        ownerId: 'user_same',
        tenantId: 'user_same',
        tenantEmail: 'user@test.com',
        tenantName: 'Name',
        tenantPhone: '017',
        preferredMoveIn: 'Immediate',
        propertyTitle: 'Title',
        propertyArea: 'Area',
        rentPerMonth: 20000,
      ),
      throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
    );

    // 4. Invalid document ID characters (slash)
    expect(
      () => service.createRentalRequest(
        propertyId: 'p/1',
        ownerId: 'owner1',
        tenantId: 'tenant1',
        tenantEmail: 't@test.com',
        tenantName: 'Name',
        tenantPhone: '017',
        preferredMoveIn: 'Immediate',
        propertyTitle: 'Title',
        propertyArea: 'Area',
        rentPerMonth: 20000,
      ),
      throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'invalid-argument')),
    );

    // 5. Respond to request validation (invalid status)
    expect(
      () => service.respondToRentalRequest(
        requestId: 'req_1',
        ownerId: 'owner_1',
        status: 'invalid_status',
      ),
      throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'invalid-argument')),
    );

    // 6. Streams and hasActiveRentalRequest handle empty inputs gracefully
    expect(await service.hasActiveRentalRequest(propertyId: '', tenantId: ''), isFalse);
    expect(await service.hasActiveRentalRequest(propertyId: 'p/1', tenantId: 't1'), isFalse);
    expect(await service.streamTenantRequests('').isEmpty, isTrue);
    expect(await service.streamPropertyRequests(propertyId: '', ownerId: '').isEmpty, isTrue);
    expect(await service.streamLandlordRequests('').isEmpty, isTrue);

    // 7. Friendly error message handles 'already-exists'
    final friendlyMsg = FirestoreService.getFriendlyErrorMessage(
      FirebaseException(plugin: 'cloud_firestore', code: 'already-exists'),
    );
    expect(friendlyMsg, contains('already have an active rental request'));
  });

  test('Phase 1: Deterministic document ID and reapplication state logic', () {
    const propId = 'prop_abc';
    const tenantId = 'tenant_xyz';
    final deterministicDocId = '${propId}_$tenantId';
    expect(deterministicDocId, 'prop_abc_tenant_xyz');

    // Simulate an existing request in 'rejected' status
    final rejectedReq = RentalRequest(
      id: deterministicDocId,
      property: const Property(
        id: propId,
        title: 'Title',
        area: 'Area',
        landmark: '',
        rentPerMonth: 20000,
        type: PropertyType.family,
        bedrooms: 2,
        bathrooms: 1,
        availability: 'Available',
        availableNow: true,
        icon: Icons.apartment,
        gradientStart: Colors.green,
        gradientEnd: Colors.teal,
      ),
      renterName: 'Renter',
      renterPhone: '017',
      preferredMoveIn: 'Immediate',
      requestedAt: DateTime.now(),
      status: 'rejected',
      ownerId: 'owner_1',
      tenantId: tenantId,
    );
    expect(rejectedReq.isRejected, isTrue);
    expect(rejectedReq.isPending, isFalse);

    // Simulate re-application (status transitions back to pending)
    final reappliedReq = rejectedReq.copyWith(
      status: 'pending',
      preferredMoveIn: '1st of next month',
      message: 'Updated move in date',
      landlordNote: null,
      updatedAt: DateTime.now(),
    );
    expect(reappliedReq.isPending, isTrue);
    expect(reappliedReq.isRejected, isFalse);
    expect(reappliedReq.landlordNote, isNull);
    expect(reappliedReq.id, deterministicDocId);
  });

  // ---------------------------------------------------------------------------
  // Phase 2: Tenant Submission Flow Tests
  // ---------------------------------------------------------------------------

  testWidgets('Phase 2: Guest tapping Request to Rent on cloud property prompts Sign In', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const cloudProp = Property(
      id: 'cloud_prop_101',
      title: 'Modern 3BHK Flat',
      area: 'Banani',
      landmark: 'Road 11',
      rentPerMonth: 45000,
      type: PropertyType.family,
      bedrooms: 3,
      bathrooms: 3,
      availability: 'Immediate',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.teal,
      gradientEnd: Colors.blue,
      ownerId: 'landlord_uid_999',
      isDemo: false,
    );

    bool signInTriggered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PropertyDetailsScreen(
          property: cloudProp,
          favouriteIds: const {},
          onToggleFavourite: (_) {},
          onRequireSignIn: () {
            signInTriggered = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial button text
    expect(find.text('Request to Rent'), findsOneWidget);

    // Tap Request to Rent as guest
    await tester.tap(find.text('Request to Rent'));
    await tester.pumpAndSettle();

    // Verify Sign In Required dialog appears
    expect(find.text('Sign In Required'), findsOneWidget);
    expect(
      find.text('You need to sign in to send a rental request to the landlord and track its status.'),
      findsOneWidget,
    );

    // Tap Sign In button in dialog
    final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
    expect(signInBtn, findsOneWidget);
    await tester.tap(signInBtn);
    await tester.pumpAndSettle();

    expect(signInTriggered, isTrue);
  });

  testWidgets('Phase 2: Owner viewing own property sees Your Property (Owner) button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const ownedProp = Property(
      id: 'owned_prop_102',
      title: 'Owner Luxury Apartment',
      area: 'Gulshan 2',
      landmark: 'Near Park',
      rentPerMonth: 75000,
      type: PropertyType.family,
      bedrooms: 4,
      bathrooms: 4,
      availability: 'Immediate',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.purple,
      gradientEnd: Colors.indigo,
      ownerId: 'owner_user_777',
      isDemo: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PropertyDetailsScreen(
          property: ownedProp,
          favouriteIds: const {},
          onToggleFavourite: (_) {},
          firebaseUser: _TestFakeUser(
            uid: 'owner_user_777',
            email: 'owner@bashalagbe.com',
            displayName: 'Property Owner',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify owner button text
    expect(find.text('Your Property (Owner)'), findsOneWidget);

    // Tap button: verify friendly message
    await tester.tap(find.text('Your Property (Owner)'));
    await tester.pump();
    expect(find.textContaining('You are the owner of this property'), findsOneWidget);
  });

  testWidgets('Phase 2: RequestToRentSheet validates required name and phone fields', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const testProp = Property(
      id: 'cloud_prop_103',
      title: 'Cozy Studio',
      area: 'Mirpur DOHS',
      landmark: '',
      rentPerMonth: 18000,
      type: PropertyType.bachelor,
      bedrooms: 1,
      bathrooms: 1,
      availability: 'Immediate',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.teal,
      gradientEnd: Colors.green,
      ownerId: 'landlord_123',
      isDemo: false,
    );

    bool submitted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RequestToRentSheet(
            property: testProp,
            currentUser: _TestFakeUser(uid: 'tenant_abc', email: 'tenant@test.com'),
            onSubmitted: (_) {
              submitted = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Clear name and phone text fields
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), ''); // Name
    await tester.enterText(textFields.at(1), ''); // Phone
    await tester.pumpAndSettle();

    // Tap Send Rental Request
    final submitBtn = find.widgetWithText(FilledButton, 'Send Rental Request');
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Verify validation errors appear and submission did not happen
    expect(find.text('Please enter your full name.'), findsOneWidget);
    expect(find.text('Please enter a contact phone number.'), findsOneWidget);
    expect(submitted, isFalse);

    // Provide short phone number
    await tester.enterText(textFields.at(0), 'Karim');
    await tester.enterText(textFields.at(1), '017'); // Less than 6 chars
    await tester.pumpAndSettle();

    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid phone number (at least 6 digits).'), findsOneWidget);
    expect(submitted, isFalse);
  });

  testWidgets('Phase 2: Demo property preserves local demo request submission', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const demoProp = Property(
      id: 'prop-demo-1',
      title: 'Demo City View Flat',
      area: 'Dhanmondi',
      landmark: '',
      rentPerMonth: 28000,
      type: PropertyType.family,
      bedrooms: 3,
      bathrooms: 2,
      availability: 'Immediate',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.green,
      gradientEnd: Colors.teal,
      isDemo: true,
    );

    RentalRequest? recordedRequest;

    await tester.pumpWidget(
      MaterialApp(
        home: PropertyDetailsScreen(
          property: demoProp,
          favouriteIds: const {},
          onToggleFavourite: (_) {},
          onRentalRequestSubmitted: (req) {
            recordedRequest = req;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Request to Rent
    await tester.tap(find.text('Request to Rent'));
    await tester.pumpAndSettle();

    // Verify Demo Notice is visible
    expect(find.textContaining('Local Demo Notice: This request is stored locally'), findsOneWidget);
    expect(find.text('Submit Demo Rental Request'), findsOneWidget);

    // Tap Submit Demo Rental Request
    await tester.tap(find.text('Submit Demo Rental Request'));
    await tester.pumpAndSettle();

    // Verify submission recorded and marked as demo
    expect(recordedRequest, isNotNull);
    expect(recordedRequest!.isDemo, isTrue);

    // Verify button updated to Request Sent (Demo)
    expect(find.text('Request Sent (Demo)'), findsOneWidget);
  });

  testWidgets('Phase 2: Cloud request submission error handling does not falsely show success', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const cloudProp = Property(
      id: 'cloud_prop_err_1',
      title: 'Lakefront Penthouse',
      area: 'Gulshan 1',
      landmark: '',
      rentPerMonth: 90000,
      type: PropertyType.family,
      bedrooms: 4,
      bathrooms: 4,
      availability: 'Immediate',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.indigo,
      gradientEnd: Colors.blue,
      ownerId: 'landlord_err_test',
      isDemo: false,
    );

    bool submitted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RequestToRentSheet(
            property: cloudProp,
            currentUser: _TestFakeUser(
              uid: 'tenant_err_uid',
              email: 'tenant@test.com',
              displayName: 'Tanzim',
              phoneNumber: '01812345678',
            ),
            onSubmitted: (_) {
              submitted = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Send Rental Request
    final submitBtn = find.widgetWithText(FilledButton, 'Send Rental Request');
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // In uninitialized test environment, FirestoreService throws an exception which is caught
    // Verify that the sheet surfaces the friendly error and does NOT claim success
    expect(submitted, isFalse);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('You must be signed in to access this feature.'), findsOneWidget);
    expect(find.byType(RequestToRentSheet), findsOneWidget);
  });

  testWidgets('Phase 3: Tenant tracking displays requests with proper status badges, formatted dates, and no raw UIDs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const prop1 = Property(
      id: 'prop_p3_1',
      title: 'Green View Apartment',
      area: 'Dhanmondi 27',
      landmark: 'Near Rapa Plaza',
      rentPerMonth: 28000,
      type: PropertyType.family,
      bedrooms: 3,
      bathrooms: 2,
      availability: 'Available now',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.green,
      gradientEnd: Colors.teal,
      ownerId: 'owner_uid_999',
    );

    const prop2 = Property(
      id: 'prop_p3_2',
      title: 'Blue Sky Studio',
      area: 'Dhanmondi 27',
      landmark: 'Near Rapa Plaza',
      rentPerMonth: 28000,
      type: PropertyType.family,
      bedrooms: 3,
      bathrooms: 2,
      availability: 'Available now',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.green,
      gradientEnd: Colors.teal,
      ownerId: 'owner_uid_999',
    );

    const prop3 = Property(
      id: 'prop_p3_3',
      title: 'Cosy Room Mess',
      area: 'Dhanmondi 27',
      landmark: 'Near Rapa Plaza',
      rentPerMonth: 28000,
      type: PropertyType.family,
      bedrooms: 3,
      bathrooms: 2,
      availability: 'Available now',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.green,
      gradientEnd: Colors.teal,
      ownerId: 'owner_uid_999',
    );

    const prop4 = Property(
      id: 'prop_p3_4',
      title: 'Lake Breeze Flat',
      area: 'Dhanmondi 27',
      landmark: 'Near Rapa Plaza',
      rentPerMonth: 28000,
      type: PropertyType.family,
      bedrooms: 3,
      bathrooms: 2,
      availability: 'Available now',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.green,
      gradientEnd: Colors.teal,
      ownerId: 'owner_uid_999',
    );

    final reqs = [
      RentalRequest(
        id: 'prop_p3_1_tenant_uid_111',
        property: prop1,
        renterName: 'Sadia Rahman',
        renterPhone: '01700000001',
        preferredMoveIn: '1st of next month',
        message: 'Looking for long-term stay',
        requestedAt: DateTime(2026, 10, 22),
        status: 'pending',
        ownerId: 'owner_uid_999',
        tenantId: 'tenant_uid_111',
      ),
      RentalRequest(
        id: 'prop_p3_2_tenant_uid_111',
        property: prop2,
        renterName: 'Sadia Rahman',
        renterPhone: '01700000001',
        preferredMoveIn: 'Immediate',
        requestedAt: DateTime(2026, 10, 20),
        status: 'accepted',
        ownerId: 'owner_uid_999',
        tenantId: 'tenant_uid_111',
        landlordNote: 'Call me after 6 PM',
      ),
      RentalRequest(
        id: 'prop_p3_3_tenant_uid_111',
        property: prop3,
        renterName: 'Sadia Rahman',
        renterPhone: '01700000001',
        preferredMoveIn: 'Next week',
        requestedAt: DateTime(2026, 10, 18),
        status: 'rejected',
        ownerId: 'owner_uid_999',
        tenantId: 'tenant_uid_111',
      ),
      RentalRequest(
        id: 'prop_p3_4_tenant_uid_111',
        property: prop4,
        renterName: 'Sadia Rahman',
        renterPhone: '01700000001',
        preferredMoveIn: 'Immediate',
        requestedAt: DateTime(2026, 10, 15),
        status: 'cancelled',
        ownerId: 'owner_uid_999',
        tenantId: 'tenant_uid_111',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RentalRequestsSheet(
            rentalRequests: reqs,
            onCancelRequest: (_) {},
            onExploreHomes: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Titles and Rent
    expect(find.text('Green View Apartment'), findsOneWidget);
    expect(find.text('Blue Sky Studio'), findsOneWidget);
    expect(find.text('Cosy Room Mess'), findsOneWidget);
    expect(find.text('Lake Breeze Flat'), findsOneWidget);

    // Verify Status badges
    expect(find.text('Pending Review'), findsOneWidget);
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Declined'), findsOneWidget);
    expect(find.text('Withdrawn'), findsOneWidget);

    // Verify landlord note
    expect(find.textContaining('Landlord Note: "Call me after 6 PM"'), findsOneWidget);

    // Verify submission date
    expect(find.text('Submitted 22 Oct 2026'), findsOneWidget);

    // Verify raw internal IDs and UIDs are NEVER exposed in the UI
    expect(find.textContaining('prop_p3_1_tenant_uid_111'), findsNothing);
    expect(find.textContaining('owner_uid_999'), findsNothing);
    expect(find.textContaining('tenant_uid_111'), findsNothing);
  });

  testWidgets('Phase 3: Tenant can only withdraw Pending requests', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const prop = Property(
      id: 'prop_p3_withdraw',
      title: 'Green View Apartment',
      area: 'Dhanmondi',
      landmark: '',
      rentPerMonth: 25000,
      type: PropertyType.family,
      bedrooms: 2,
      bathrooms: 2,
      availability: 'Available now',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.green,
      gradientEnd: Colors.teal,
    );

    const prop2 = Property(
      id: 'prop_p3_accepted',
      title: 'Accepted Flat',
      area: 'Dhanmondi',
      landmark: '',
      rentPerMonth: 25000,
      type: PropertyType.family,
      bedrooms: 2,
      bathrooms: 2,
      availability: 'Available now',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.green,
      gradientEnd: Colors.teal,
    );

    final reqs = [
      RentalRequest(
        id: 'req_pending_1',
        property: prop,
        renterName: 'Sadia',
        renterPhone: '01700000001',
        preferredMoveIn: 'Immediate',
        requestedAt: DateTime(2026, 10, 22),
        status: 'pending',
      ),
      RentalRequest(
        id: 'req_accepted_2',
        property: prop2,
        renterName: 'Sadia',
        renterPhone: '01700000001',
        preferredMoveIn: 'Immediate',
        requestedAt: DateTime(2026, 10, 20),
        status: 'accepted',
      ),
    ];

    String? cancelledId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RentalRequestsSheet(
            rentalRequests: reqs,
            onCancelRequest: (id) {
              cancelledId = id;
            },
            onExploreHomes: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Withdraw Request button exists only once (for pending request)
    final withdrawBtn = find.widgetWithText(TextButton, 'Withdraw Request');
    expect(withdrawBtn, findsOneWidget);

    // Tap Withdraw Request
    await tester.tap(withdrawBtn);
    await tester.pumpAndSettle();

    expect(cancelledId, 'req_pending_1');
  });

  testWidgets('Phase 3: Landlord request management displays incoming requests and tenant details without raw IDs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const prop = Property(
      id: 'prop_landlord_test',
      title: 'Gulshan Garden House',
      area: 'Gulshan 2',
      landmark: 'Near Embassy',
      rentPerMonth: 65000,
      type: PropertyType.family,
      bedrooms: 3,
      bathrooms: 3,
      availability: 'Available now',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.green,
      gradientEnd: Colors.teal,
      ownerId: 'landlord_uid_100',
    );

    final req = RentalRequest(
      id: 'prop_landlord_test_tenant_uid_200',
      property: prop,
      renterName: 'Fahim Ahmed',
      renterPhone: '01819999999',
      preferredMoveIn: '1st of next month',
      message: 'Small family with one child',
      requestedAt: DateTime(2026, 10, 22),
      status: 'pending',
      ownerId: 'landlord_uid_100',
      tenantId: 'tenant_uid_200',
      tenantEmail: 'fahim@example.com',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LandlordRequestsSheet(
            currentUserId: 'landlord_uid_100',
            initialRequests: [req],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Check header and property title
    expect(find.text('Incoming Rental Requests'), findsOneWidget);
    expect(find.text('Gulshan Garden House'), findsOneWidget);

    // Check tenant details
    expect(find.text('Fahim Ahmed'), findsOneWidget);
    expect(find.text('01819999999'), findsOneWidget);
    expect(find.text('fahim@example.com'), findsOneWidget);
    expect(find.text('Preferred Move-in: 1st of next month'), findsOneWidget);
    expect(find.text('"Small family with one child"'), findsOneWidget);
    expect(find.text('Submitted 22 Oct 2026'), findsOneWidget);

    // Check Accept and Decline buttons are present for pending request
    expect(find.widgetWithText(FilledButton, 'Accept'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Decline'), findsOneWidget);

    // Verify no raw UIDs or internal document IDs are visible
    expect(find.textContaining('prop_landlord_test_tenant_uid_200'), findsNothing);
    expect(find.textContaining('landlord_uid_100'), findsNothing);
    expect(find.textContaining('tenant_uid_200'), findsNothing);
  });

  testWidgets('Phase 3: Landlord Accept/Decline opens dialog with optional note', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const prop = Property(
      id: 'prop_landlord_guard',
      title: 'Banani Studio Apartment',
      area: 'Banani',
      landmark: '',
      rentPerMonth: 35000,
      type: PropertyType.bachelor,
      bedrooms: 1,
      bathrooms: 1,
      availability: 'Available now',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.green,
      gradientEnd: Colors.teal,
      ownerId: 'my_landlord_uid',
    );

    final ownedReq = RentalRequest(
      id: 'req_owned_1',
      property: prop,
      renterName: 'Rina Begum',
      renterPhone: '01912345678',
      preferredMoveIn: 'Immediate',
      requestedAt: DateTime(2026, 10, 22),
      status: 'pending',
      ownerId: 'my_landlord_uid',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LandlordRequestsSheet(
            currentUserId: 'my_landlord_uid',
            initialRequests: [ownedReq],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Accept
    await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
    await tester.pumpAndSettle();

    // Verify dialog opened with optional note field
    expect(find.text('Accept Rental Request'), findsOneWidget);
    expect(find.textContaining('Accept rental request from Rina Begum'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Accept Rental Request'), findsNothing);
  });

  testWidgets('Phase 3: Landlord cannot respond to requests for properties they do not own (ownership guard)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const prop = Property(
      id: 'prop_landlord_guard_2',
      title: 'Banani Studio Apartment',
      area: 'Banani',
      landmark: '',
      rentPerMonth: 35000,
      type: PropertyType.bachelor,
      bedrooms: 1,
      bathrooms: 1,
      availability: 'Available now',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.green,
      gradientEnd: Colors.teal,
      ownerId: 'different_owner_uid',
    );

    final unownedReq = RentalRequest(
      id: 'req_unowned_2',
      property: prop,
      renterName: 'Another Tenant',
      renterPhone: '01512345678',
      preferredMoveIn: 'Immediate',
      requestedAt: DateTime(2026, 10, 22),
      status: 'pending',
      ownerId: 'different_owner_uid', // different owner
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LandlordRequestsSheet(
            currentUserId: 'my_landlord_uid',
            initialRequests: [unownedReq],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Accept on unowned request
    await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
    await tester.pumpAndSettle();

    // Confirm dialog did NOT open, friendly ownership warning surfaced
    expect(find.text('Accept Rental Request'), findsNothing);
    expect(find.text('You cannot respond to requests for properties you do not own.'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Landlord Contact Details & Reveal Feature Tests
  // ---------------------------------------------------------------------------

  group('LandlordContactInfo model and validation tests', () {
    test('serialization toMap and fromMap works accurately', () {
      const contact = LandlordContactInfo(
        phone: '01711223344',
        whatsapp: '+8801711223344',
        email: 'landlord@example.com',
        otherTitle: 'Messenger',
        otherLink: 'https://m.me/landlord',
      );

      expect(contact.isEmpty, isFalse);
      expect(contact.isNotEmpty, isTrue);

      final map = contact.toMap();
      expect(map['phone'], '01711223344');
      expect(map['whatsapp'], '+8801711223344');
      expect(map['email'], 'landlord@example.com');
      expect(map['otherTitle'], 'Messenger');
      expect(map['otherLink'], 'https://m.me/landlord');

      final fromMap = LandlordContactInfo.fromMap(map);
      expect(fromMap.phone, contact.phone);
      expect(fromMap.whatsapp, contact.whatsapp);
      expect(fromMap.email, contact.email);
      expect(fromMap.otherTitle, contact.otherTitle);
      expect(fromMap.otherLink, contact.otherLink);
    });

    test('isEmpty is true when all fields are null or whitespace', () {
      const empty1 = LandlordContactInfo();
      expect(empty1.isEmpty, isTrue);
      expect(empty1.isNotEmpty, isFalse);

      const empty2 = LandlordContactInfo(
        phone: '   ',
        whatsapp: '',
        email: '  ',
        otherTitle: '   ',
        otherLink: '',
      );
      expect(empty2.isEmpty, isTrue);
      expect(empty2.isNotEmpty, isFalse);
    });

    test('validateOptionalPhone validates digits and optional plus correctly', () {
      // Valid inputs
      expect(LandlordContactInfo.validateOptionalPhone(null), isNull);
      expect(LandlordContactInfo.validateOptionalPhone(''), isNull);
      expect(LandlordContactInfo.validateOptionalPhone('   '), isNull);
      expect(LandlordContactInfo.validateOptionalPhone('01711223344'), isNull);
      expect(LandlordContactInfo.validateOptionalPhone('+8801711223344'), isNull);
      expect(LandlordContactInfo.validateOptionalPhone('0181-234-5678'), isNull);

      // Invalid inputs
      expect(LandlordContactInfo.validateOptionalPhone('123'), isNotNull);
      expect(LandlordContactInfo.validateOptionalPhone('abc01711223344'), isNotNull);
      expect(LandlordContactInfo.validateOptionalPhone('invalid-phone!'), isNotNull);
    });

    test('validateOptionalEmail validates standard email structures', () {
      // Valid inputs
      expect(LandlordContactInfo.validateOptionalEmail(null), isNull);
      expect(LandlordContactInfo.validateOptionalEmail(''), isNull);
      expect(LandlordContactInfo.validateOptionalEmail('   '), isNull);
      expect(LandlordContactInfo.validateOptionalEmail('owner@basha.com'), isNull);
      expect(LandlordContactInfo.validateOptionalEmail('my.name+tag@example.org'), isNull);

      // Invalid inputs
      expect(LandlordContactInfo.validateOptionalEmail('plainaddress'), isNotNull);
      expect(LandlordContactInfo.validateOptionalEmail('@missingusername.com'), isNotNull);
      expect(LandlordContactInfo.validateOptionalEmail('user@.com'), isNotNull);
    });

    test('validateOptionalLink rejects spaces and excessively long URLs', () {
      // Valid inputs
      expect(LandlordContactInfo.validateOptionalLink(null), isNull);
      expect(LandlordContactInfo.validateOptionalLink(''), isNull);
      expect(LandlordContactInfo.validateOptionalLink('   '), isNull);
      expect(LandlordContactInfo.validateOptionalLink('https://m.me/owner'), isNull);
      expect(LandlordContactInfo.validateOptionalLink('https://wa.me/8801711223344'), isNull);

      // Invalid inputs
      expect(LandlordContactInfo.validateOptionalLink('https://m.me/owner with space'), isNotNull);
      expect(LandlordContactInfo.validateOptionalLink('a' * 301), isNotNull);
    });
  });

  testWidgets('RentalRequestsSheet reveals LandlordContactCard when status is accepted', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const prop = Property(
      id: 'prop_accepted_1',
      title: 'Gulshan Modern Penthouse',
      area: 'Gulshan-2',
      landmark: '',
      rentPerMonth: 65000,
      type: PropertyType.family,
      bedrooms: 3,
      bathrooms: 3,
      availability: 'Available now',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.green,
      gradientEnd: Colors.teal,
      ownerId: 'owner_123',
    );

    final acceptedReq = RentalRequest(
      id: 'req_accepted_1',
      property: prop,
      renterName: 'Renter Tenant',
      renterPhone: '01700000000',
      preferredMoveIn: 'Immediate',
      requestedAt: DateTime(2026, 10, 22),
      status: 'accepted',
      landlordNote: 'Call me anytime tomorrow after 10 AM.',
      ownerId: 'owner_123',
      tenantId: 'tenant_123',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RentalRequestsSheet(
            rentalRequests: [acceptedReq],
            onCancelRequest: (_) {},
            onExploreHomes: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify accepted badge and landlord note are present
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Accepted by Landlord'), findsOneWidget);
    expect(find.text('Landlord Note: "Call me anytime tomorrow after 10 AM."'), findsOneWidget);

    // Verify LandlordContactCard is rendered
    expect(find.byType(LandlordContactCard), findsOneWidget);
  });

  testWidgets('RentalRequestsSheet hides contact info when status is pending, rejected, or cancelled', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const prop = Property(
      id: 'prop_test_2',
      title: 'Dhanmondi Lake View Flat',
      area: 'Dhanmondi',
      landmark: '',
      rentPerMonth: 28000,
      type: PropertyType.family,
      bedrooms: 2,
      bathrooms: 2,
      availability: 'Available now',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.green,
      gradientEnd: Colors.teal,
      ownerId: 'owner_456',
    );

    final pendingReq = RentalRequest(
      id: 'req_pending_1',
      property: prop,
      renterName: 'Renter Tenant',
      renterPhone: '01700000000',
      preferredMoveIn: 'Immediate',
      requestedAt: DateTime(2026, 10, 22),
      status: 'pending',
      ownerId: 'owner_456',
      tenantId: 'tenant_123',
    );

    final rejectedReq = RentalRequest(
      id: 'req_rejected_1',
      property: prop,
      renterName: 'Renter Tenant',
      renterPhone: '01700000000',
      preferredMoveIn: 'Immediate',
      requestedAt: DateTime(2026, 10, 21),
      status: 'rejected',
      ownerId: 'owner_456',
      tenantId: 'tenant_123',
    );

    final cancelledReq = RentalRequest(
      id: 'req_cancelled_1',
      property: prop,
      renterName: 'Renter Tenant',
      renterPhone: '01700000000',
      preferredMoveIn: 'Immediate',
      requestedAt: DateTime(2026, 10, 20),
      status: 'cancelled',
      ownerId: 'owner_456',
      tenantId: 'tenant_123',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RentalRequestsSheet(
            rentalRequests: [pendingReq, rejectedReq, cancelledReq],
            onCancelRequest: (_) {},
            onExploreHomes: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify LandlordContactCard is NOT rendered for pending, rejected, or cancelled
    expect(find.byType(LandlordContactCard), findsNothing);

    // Verify clear status guidance messages are shown
    expect(
      find.text('Landlord contact details will be revealed here once accepted.'),
      findsOneWidget,
    );
    expect(
      find.text('Request declined. Landlord contact details remain private.'),
      findsOneWidget,
    );
    expect(
      find.text('Request withdrawn. Contact details are unavailable.'),
      findsOneWidget,
    );
  });

  testWidgets('LandlordContactCard handles uninitialized/empty streams without infinite loading', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LandlordContactCard(
            propertyId: 'prop_empty_contact',
            landlordNote: 'Call after 5pm',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // In unit test environment, streamPropertyContactInfo emits null
    // It must NOT spin indefinitely; it must cleanly render the accepted note state
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Rental Request Accepted!'), findsOneWidget);
    expect(find.textContaining('Call after 5pm'), findsOneWidget);
  });

  test('Cloudinary: photo model and serialization preserve publicId (storagePath), isCover, and order', () {
    const photo = PropertyPhoto(
      label: 'Master Bedroom',
      imageUrl: 'https://res.cloudinary.com/sgbsxxtm/image/upload/v1729720000/properties/owner_1/prop_1/photo_1.jpg',
      storagePath: 'properties/owner_1/prop_1/photo_1',
      isCover: true,
      order: 0,
    );
    expect(photo.label, 'Master Bedroom');
    expect(photo.imageUrl, contains('photo_1.jpg'));
    expect(photo.storagePath, 'properties/owner_1/prop_1/photo_1');
    expect(photo.isCover, isTrue);
    expect(photo.order, 0);
    expect(photo.isNetworkPhoto, isTrue);
    expect(photo.isAssetPhoto, isFalse);

    // Serialization in propertyFromFirestore
    final rawData = {
      'title': 'Mirpur 10 Apartment',
      'propertyType': 'family',
      'photos': [
        {
          'label': 'Master Bedroom',
          'imageUrl': 'https://res.cloudinary.com/sgbsxxtm/image/upload/v1729720000/properties/owner_1/prop_1/photo_1.jpg',
          'storagePath': 'properties/owner_1/prop_1/photo_1',
          'isCover': true,
          'order': 0,
        },
        {
          'label': 'Dining Area',
          'imageUrl': 'https://res.cloudinary.com/sgbsxxtm/image/upload/v1729720000/properties/owner_1/prop_1/photo_2.jpg',
          'storagePath': 'properties/owner_1/prop_1/photo_2',
          'isCover': false,
          'order': 1,
        },
      ],
    };

    final property = FirestoreService.propertyFromFirestore('prop_1', rawData);
    expect(property.photos.length, 2);
    expect(property.photos[0].label, 'Master Bedroom');
    expect(property.photos[0].storagePath, 'properties/owner_1/prop_1/photo_1');
    expect(property.photos[0].isCover, isTrue);
    expect(property.photos[0].order, 0);
    expect(property.photos[1].label, 'Dining Area');
    expect(property.photos[1].storagePath, 'properties/owner_1/prop_1/photo_2');
    expect(property.photos[1].isCover, isFalse);
    expect(property.photos[1].order, 1);

    // Serialization in submittedListingFromFirestore
    final listing = FirestoreService.submittedListingFromFirestore('prop_1', rawData);
    expect(listing.photos.length, 2);
    expect(listing.photos[0].label, 'Master Bedroom');
    expect(listing.photos[0].networkUrl, contains('photo_1.jpg'));
    expect(listing.photos[0].storagePath, 'properties/owner_1/prop_1/photo_1');
    expect(listing.photos[0].isCover, isTrue);
    expect(listing.photos[1].label, 'Dining Area');
    expect(listing.photos[1].storagePath, 'properties/owner_1/prop_1/photo_2');
    expect(listing.photos[1].isCover, isFalse);
  });

  test('Cloudinary: client-side image validation enforces 5 MB limit and JPG/PNG/WebP format', () {
    // 1. Empty bytes
    expect(CloudinaryService.validateImageBytes(Uint8List(0)), contains('empty'));

    // 2. > 5 MB
    final oversized = Uint8List(5 * 1024 * 1024 + 1);
    expect(CloudinaryService.validateImageBytes(oversized), contains('too large'));

    // 3. Unsupported magic bytes
    final textBytes = Uint8List.fromList('hello world fake image'.codeUnits);
    expect(CloudinaryService.validateImageBytes(textBytes), contains('Unsupported image format'));

    // 4. Valid JPG magic bytes
    final jpgBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
    expect(CloudinaryService.validateImageBytes(jpgBytes), isNull);

    // 5. Valid PNG magic bytes
    final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    expect(CloudinaryService.validateImageBytes(pngBytes), isNull);

    // 6. Valid WebP magic bytes (RIFF....WEBP)
    final webpBytes = Uint8List.fromList([
      0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50,
    ]);
    expect(CloudinaryService.validateImageBytes(webpBytes), isNull);

    // 7. Strictly reject unsupported magic bytes even if filename has an allowed extension
    final fallbackBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    expect(CloudinaryService.validateImageBytes(fallbackBytes, fileName: 'bedroom.jpg'), contains('Unsupported image format'));
    expect(CloudinaryService.validateImageBytes(fallbackBytes, fileName: 'bedroom.png'), contains('Unsupported image format'));
    expect(CloudinaryService.validateImageBytes(fallbackBytes, fileName: 'bedroom.webp'), contains('Unsupported image format'));
    expect(CloudinaryService.validateImageBytes(fallbackBytes, fileName: 'document.pdf'), contains('Unsupported image format'));
  });

  test('Cloudinary: upload failure rollback safely cleans up newly uploaded files via delete tokens', () async {
    final service = _TestMockCloudinaryService();
    final photo1 = WizardPhotoItem(
      id: 'p1',
      label: 'Photo 1',
      bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF]),
    );
    final photo2 = WizardPhotoItem(
      id: 'p2',
      label: 'Photo 2',
      bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF]),
    );

    bool didThrow = false;
    try {
      await service.uploadPropertyPhotos(
        ownerId: 'owner_123',
        propertyId: 'prop_abc',
        photos: [photo1, photo2],
      );
    } catch (_) {
      didThrow = true;
    }
    expect(didThrow, isTrue);

    // Verify that photo 1 (which returned del_token_1 before photo 2 failed) was rolled back via its delete token
    expect(service.deletedTokens.length, 1);
    expect(service.deletedTokens.first, 'del_token_1');
  });

  test('Cloudinary: deleteByToken handles null and empty tokens safely without crashing', () async {
    final service = CloudinaryService.instance;
    expect(await service.deleteByToken(null), isFalse);
    expect(await service.deleteByToken(''), isFalse);
    expect(await service.deleteByToken('   '), isFalse);
  });

  test('Cloudinary: uploadPropertyPhotos preserves delete tokens for rollback and excludes existing photos from rollback tokens', () async {
    final service = _TestMockCloudinaryService();
    final newPhoto = WizardPhotoItem(
      id: 'p_new',
      label: 'New Room',
      bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF]),
    );
    final existingPhoto = WizardPhotoItem(
      id: 'p_exist',
      label: 'Existing Room',
      networkUrl: 'https://res.cloudinary.com/sgbsxxtm/image/upload/v1/properties/existing.jpg',
      storagePath: 'properties/existing',
      isCover: true,
    );

    final result = await service.uploadPropertyPhotos(
      ownerId: 'owner_123',
      propertyId: 'prop_abc',
      photos: [existingPhoto, newPhoto],
    );

    expect(result.photos.length, 2);
    // Only the new photo has a delete token
    expect(result.deleteTokens.length, 1);
    expect(result.deleteTokens.first, 'del_token_1');

    // Simulate Firestore create failure rollback
    await service.deletePhotosByTokens(result.deleteTokens);
    expect(service.deletedTokens, contains('del_token_1'));
    // Ensure existing photo was not touched
    expect(service.deletedTokens.length, 1);
  });

  test('Cloudinary & Network: timeout error is converted to user-friendly message', () {
    final timeoutError = TimeoutException('Cloudinary upload timed out after 30 seconds. Please check your internet connection.');
    final message = FirestoreService.getFriendlyErrorMessage(timeoutError);
    expect(message, contains('timed out'));
    expect(message, contains('internet connection'));
  });

  testWidgets('Storage: PropertyDetailsScreen gracefully falls back to stock gallery for legacy listings with null URLs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const legacyProp = Property(
      id: 'legacy_prop_1',
      title: 'Legacy Dhanmondi Flat',
      area: 'Dhanmondi 27',
      landmark: 'Near Rapa Plaza',
      rentPerMonth: 28000,
      type: PropertyType.family,
      bedrooms: 2,
      bathrooms: 2,
      availability: 'Available now',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.green,
      gradientEnd: Colors.teal,
      photos: [
        PropertyPhoto(label: 'Room 1', imageUrl: null, storagePath: null),
        PropertyPhoto(label: 'Room 2', imageUrl: null, storagePath: null),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PropertyDetailsScreen(
          property: legacyProp,
          favouriteIds: const {},
          onToggleFavourite: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify the gallery fell back to the stock apartment photos instead of failing
    expect(find.text('Main Living Space'), findsOneWidget);
    expect(find.text('Legacy Dhanmondi Flat'), findsWidgets);
  });

  testWidgets('Storage: PropertyImagePlaceholder renders network cover image and falls back to gradient when absent', (WidgetTester tester) async {
    const propWithCover = Property(
      id: 'prop_cover',
      title: 'Cover Home',
      area: 'Gulshan',
      landmark: '',
      rentPerMonth: 50000,
      type: PropertyType.family,
      bedrooms: 3,
      bathrooms: 3,
      availability: 'Available now',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.blue,
      gradientEnd: Colors.indigo,
      photos: [
        PropertyPhoto(
          label: 'Cover Photo',
          imageUrl: 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688',
          isCover: true,
        ),
      ],
    );

    const propNoCover = Property(
      id: 'prop_no_cover',
      title: 'Gradient Home',
      area: 'Banani',
      landmark: '',
      rentPerMonth: 40000,
      type: PropertyType.family,
      bedrooms: 2,
      bathrooms: 2,
      availability: 'Available now',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: Colors.green,
      gradientEnd: Colors.teal,
      photos: [],
    );

    // Pump widget with cover photo
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PropertyImagePlaceholder(property: propWithCover),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);

    // Pump widget without cover photo
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PropertyImagePlaceholder(property: propNoCover),
        ),
      ),
    );
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.apartment), findsOneWidget);
  });
}

class _TestMockCloudinaryService extends CloudinaryService {
  final List<String> deletedTokens = [];
  int uploadCount = 0;

  @override
  Future<CloudinaryUploadResult> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String? folder,
  }) async {
    uploadCount++;
    if (uploadCount == 2) {
      throw Exception('Network disconnected during Cloudinary upload');
    }
    return CloudinaryUploadResult(
      secureUrl: 'https://res.cloudinary.com/sgbsxxtm/image/upload/v1/properties/$fileName',
      publicId: 'properties/$fileName',
      deleteToken: 'del_token_$uploadCount',
    );
  }

  @override
  Future<bool> deleteByToken(String? deleteToken) async {
    if (deleteToken != null) {
      deletedTokens.add(deleteToken);
      return true;
    }
    return false;
  }
}

// -----------------------------------------------------------------------------
// Test Fake User Helper
// -----------------------------------------------------------------------------

class _TestFakeUser extends Fake implements User {
  _TestFakeUser({
    required this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
  });

  @override
  final String uid;

  @override
  final String? email;

  @override
  final String? displayName;

  @override
  final String? phoneNumber;
}
