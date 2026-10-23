import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:basha_lagbe/main.dart';
import 'package:basha_lagbe/property_details_screen.dart';
import 'package:basha_lagbe/post_property_screen.dart';
import 'package:basha_lagbe/profile_screen.dart';
import 'package:basha_lagbe/services/cloudinary_service.dart';

/// Centralized Cloud Firestore Service for BashaLagbe.
///
/// Provides a safe foundation for interacting with Cloud Firestore,
/// including environment availability checks, custom instance injection
/// for tests, collection path constants, and error message translation.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  static final FirestoreService instance = FirestoreService();
  final FirebaseFirestore? _customFirestore;

  // Collection name constants
  static const String usersCollection = 'users';
  static const String propertiesCollection = 'properties';
  static const String rentalRequestsCollection = 'rental_requests';
  static const String contactInfoSubcollection = 'contact_info';
  static const String defaultContactDocId = 'details';

  /// Returns true if Firebase has been initialized in this runtime environment.
  bool get isFirebaseAvailable {
    if (_customFirestore != null) return true;
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Returns the active [FirebaseFirestore] instance.
  ///
  /// Throws a [FirebaseException] with code `app-not-initialized` if Firebase
  /// is not initialized in the current environment.
  FirebaseFirestore get firestore {
    if (_customFirestore != null) return _customFirestore;
    if (!isFirebaseAvailable) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'app-not-initialized',
        message: 'Firebase has not been initialized. Please check your setup.',
      );
    }
    return FirebaseFirestore.instance;
  }

  // ---------------------------------------------------------------------------
  // Favourites Synchronization (Stage 2)
  // ---------------------------------------------------------------------------

  /// Real-time stream of the current authenticated user's favourite property IDs.
  ///
  /// Returns an empty stream if Firebase is not initialized or if [userId] is empty.
  Stream<Set<String>> streamFavourites(String userId) {
    final cleanUid = userId.trim();
    if (!isFirebaseAvailable || cleanUid.isEmpty) {
      return const Stream.empty();
    }
    try {
      return firestore
          .collection(usersCollection)
          .doc(cleanUid)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists) return <String>{};
        final data = snapshot.data();
        if (data == null || !data.containsKey('favouritePropertyIds')) {
          return <String>{};
        }
        final rawList = data['favouritePropertyIds'];
        if (rawList is List) {
          return rawList.whereType<String>().toSet();
        }
        return <String>{};
      });
    } catch (e) {
      debugPrint('FirestoreService.streamFavourites error: $e');
      return const Stream.empty();
    }
  }

  /// Fetches the user's favourite property IDs once from Firestore.
  Future<Set<String>> getFavourites(String userId) async {
    final cleanUid = userId.trim();
    if (!isFirebaseAvailable || cleanUid.isEmpty) {
      return <String>{};
    }
    try {
      final doc = await firestore.collection(usersCollection).doc(cleanUid).get();
      if (!doc.exists) return <String>{};
      final data = doc.data();
      if (data == null || !data.containsKey('favouritePropertyIds')) {
        return <String>{};
      }
      final rawList = data['favouritePropertyIds'];
      if (rawList is List) {
        return rawList.whereType<String>().toSet();
      }
      return <String>{};
    } catch (e) {
      debugPrint('FirestoreService.getFavourites error: $e');
      return <String>{};
    }
  }

  /// Adds a property ID to the user's favourites in Firestore.
  ///
  /// Uses [FieldValue.arrayUnion] to atomically prevent duplicates.
  Future<void> addFavourite(String userId, String propertyId) async {
    final cleanUid = userId.trim();
    final cleanPropId = propertyId.trim();
    if (!isFirebaseAvailable || cleanUid.isEmpty || cleanPropId.isEmpty) {
      return;
    }
    await firestore.collection(usersCollection).doc(cleanUid).set({
      'favouritePropertyIds': FieldValue.arrayUnion([cleanPropId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Removes a property ID from the user's favourites in Firestore.
  ///
  /// Uses [FieldValue.arrayRemove] to atomically remove the item.
  Future<void> removeFavourite(String userId, String propertyId) async {
    final cleanUid = userId.trim();
    final cleanPropId = propertyId.trim();
    if (!isFirebaseAvailable || cleanUid.isEmpty || cleanPropId.isEmpty) {
      return;
    }
    await firestore.collection(usersCollection).doc(cleanUid).set({
      'favouritePropertyIds': FieldValue.arrayRemove([cleanPropId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // Property Listings (Stage 3)
  // ---------------------------------------------------------------------------

  /// Generates a new unique property ID using Firestore's auto-ID generator.
  String generatePropertyId() {
    return firestore.collection(propertiesCollection).doc().id;
  }

  /// Creates a new property document in the [propertiesCollection].
  ///
  /// Always sets `ownerId` to the authenticated user's UID and `status` to 'pending'.
  /// Landlord email is intentionally omitted from the public property document to protect privacy;
  /// contact details are stored in the protected [contactInfoSubcollection] subcollection.
  Future<String> createProperty({
    required String ownerId,
    String? ownerEmail,
    required Map<String, dynamic> data,
    String? propertyId,
  }) async {
    final cleanUid = ownerId.trim();
    if (!isFirebaseAvailable || cleanUid.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'Must be authenticated to submit a property listing.',
      );
    }

    final docRef = (propertyId != null && propertyId.trim().isNotEmpty)
        ? firestore.collection(propertiesCollection).doc(propertyId.trim())
        : firestore.collection(propertiesCollection).doc();
    final Map<String, dynamic> docData = Map<String, dynamic>.from(data);

    // Enforce security & auditing invariants
    docData['ownerId'] = cleanUid;
    // Omit ownerEmail to protect landlord privacy on public property listings
    docData['status'] = 'pending';
    docData['moderationNote'] = null;
    docData['createdAt'] = FieldValue.serverTimestamp();
    docData['updatedAt'] = FieldValue.serverTimestamp();

    await docRef.set(docData);
    return docRef.id;
  }

  /// Real-time stream of all approved listings for public browsing.
  ///
  /// Explicitly queries where `status == 'approved'`.
  Stream<List<Property>> streamApprovedProperties() {
    if (!isFirebaseAvailable) {
      return const Stream.empty();
    }
    try {
      return firestore
          .collection(propertiesCollection)
          .where('status', isEqualTo: 'approved')
          .snapshots()
          .map((snapshot) {
        final list = <Property>[];
        for (final doc in snapshot.docs) {
          try {
            final property = propertyFromFirestore(doc.id, doc.data());
            list.add(property);
          } catch (e) {
            debugPrint('Failed to parse property doc ${doc.id}: $e');
          }
        }
        return list;
      });
    } catch (e) {
      debugPrint('FirestoreService.streamApprovedProperties error: $e');
      return const Stream.empty();
    }
  }

  /// Real-time stream of the current authenticated user's listings.
  ///
  /// Explicitly queries where `ownerId == userId`.
  Stream<List<SubmittedListing>> streamUserListings(String userId) {
    final cleanUid = userId.trim();
    if (!isFirebaseAvailable || cleanUid.isEmpty) {
      return const Stream.empty();
    }
    try {
      return firestore
          .collection(propertiesCollection)
          .where('ownerId', isEqualTo: cleanUid)
          .snapshots()
          .map((snapshot) {
        final list = <SubmittedListing>[];
        for (final doc in snapshot.docs) {
          try {
            final listing = submittedListingFromFirestore(doc.id, doc.data());
            list.add(listing);
          } catch (e) {
            debugPrint('Failed to parse user listing doc ${doc.id}: $e');
          }
        }
        // Sort descending by submittedAt in memory
        list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
        return list;
      });
    } catch (e) {
      debugPrint('FirestoreService.streamUserListings error: $e');
      return const Stream.empty();
    }
  }

  /// Updates permitted user-editable fields of a property listing owned by the user.
  ///
  /// Enforces re-moderation: any content edit automatically reverts status to 'pending'
  /// and resets moderationNote to null for re-review.
  Future<void> updateProperty({
    required String propertyId,
    required String ownerId,
    required Map<String, dynamic> updates,
  }) async {
    final cleanUid = ownerId.trim();
    final cleanPropId = propertyId.trim();
    if (!isFirebaseAvailable || cleanUid.isEmpty || cleanPropId.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Invalid property or user ID for update.',
      );
    }

    // Sanitize updates to permitted user-editable fields
    const permittedKeys = {
      'title',
      'description',
      'propertyType',
      'division',
      'area',
      'fullAddress',
      'landmark',
      'rentPerMonth',
      'depositAmount',
      'sizeSqFt',
      'floorLevel',
      'bedrooms',
      'bathrooms',
      'balconies',
      'facilities',
      'availability',
      'availableNow',
      'preferredTenant',
      'utilityNotice',
      'nearbyHighlights',
      'photos',
    };

    final sanitized = <String, dynamic>{};
    for (final entry in updates.entries) {
      if (permittedKeys.contains(entry.key)) {
        sanitized[entry.key] = entry.value;
      }
    }

    // Security invariant: any owner content edit resets status to 'pending'
    // and clears moderationNote for moderation re-review before going live.
    sanitized['status'] = 'pending';
    sanitized['moderationNote'] = null;
    sanitized['updatedAt'] = FieldValue.serverTimestamp();

    await firestore.collection(propertiesCollection).doc(cleanPropId).update(sanitized);
  }

  /// Deletes a property listing from Firestore.
  Future<void> deleteProperty({
    required String propertyId,
    required String ownerId,
  }) async {
    final cleanUid = ownerId.trim();
    final cleanPropId = propertyId.trim();
    if (!isFirebaseAvailable || cleanUid.isEmpty || cleanPropId.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Invalid property or user ID for deletion.',
      );
    }

    try {
      await firestore
          .collection(propertiesCollection)
          .doc(cleanPropId)
          .collection(contactInfoSubcollection)
          .doc(defaultContactDocId)
          .delete();
    } catch (_) {}

    await firestore.collection(propertiesCollection).doc(cleanPropId).delete();
  }

  // ---------------------------------------------------------------------------
  // Photo Uploads (Cloudinary Integration)
  // ---------------------------------------------------------------------------

  /// Uploads new in-memory photos to Cloudinary using an unsigned upload preset
  /// and returns the serialized photo list for Firestore along with temporary delete tokens.
  ///
  /// - Enforces 5 MB max and JPG/PNG/WebP format before upload.
  /// - Collects delete tokens (if returned by preset) for rollback on failure.
  /// - Preserves existing photos during edit.
  Future<CloudinaryPhotosUploadResult> uploadPropertyPhotos({
    required String ownerId,
    required String propertyId,
    required List<WizardPhotoItem> photos,
  }) async {
    return CloudinaryService.instance.uploadPropertyPhotos(
      ownerId: ownerId,
      propertyId: propertyId,
      photos: photos,
    );
  }

  /// Safely attempts to delete multiple uploaded images using their [deleteTokens].
  Future<void> deletePhotosByTokens(Iterable<String> deleteTokens) async {
    await CloudinaryService.instance.deletePhotosByTokens(deleteTokens);
  }

  /// Safely attempts to delete an uploaded image using [deleteToken] if available.
  Future<void> deleteStorageFile(String storagePath, {String? deleteToken}) async {
    if (deleteToken != null && deleteToken.isNotEmpty) {
      await CloudinaryService.instance.deleteByToken(deleteToken);
    }
  }

  // ---------------------------------------------------------------------------
  // Rental Requests (Phase 1)
  // ---------------------------------------------------------------------------

  /// Creates a new rental request document in [rentalRequestsCollection].
  ///
  /// Enforces:
  /// - User must be authenticated with non-empty [tenantId].
  /// - [propertyId] and [ownerId] must be non-empty.
  /// - Cannot request own property ([tenantId] != [ownerId]).
  /// - Duplicate active request check: prevents multiple active requests
  ///   ('pending' or 'accepted') by the same tenant for the same property.
  Future<String> createRentalRequest({
    required String propertyId,
    required String ownerId,
    required String tenantId,
    required String tenantEmail,
    required String tenantName,
    required String tenantPhone,
    required String preferredMoveIn,
    String message = '',
    required String propertyTitle,
    required String propertyArea,
    required int rentPerMonth,
    String? propertyPhotoUrl,
  }) async {
    final cleanPropId = propertyId.trim();
    final cleanOwnerId = ownerId.trim();
    final cleanTenantId = tenantId.trim();

    if (cleanTenantId.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'Must be authenticated to submit a rental request.',
      );
    }

    if (cleanPropId.isEmpty || cleanOwnerId.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Missing property or landlord identification.',
      );
    }

    if (cleanTenantId == cleanOwnerId) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'You cannot submit a rental request for your own property.',
      );
    }

    // Defensive check: document ID parts must not contain path delimiters
    if (cleanPropId.contains('/') || cleanTenantId.contains('/')) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Invalid property or tenant identification format.',
      );
    }

    if (!isFirebaseAvailable) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'Must be authenticated to submit a rental request.',
      );
    }

    // Deterministic document ID to prevent simultaneous duplicate active requests atomically
    final docId = '${cleanPropId}_$cleanTenantId';
    final docRef = firestore.collection(rentalRequestsCollection).doc(docId);

    return await firestore.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(docRef);

      dynamic existingCreatedAt;
      if (snapshot.exists) {
        final data = snapshot.data();
        final currentStatus = (data?['status'] as String? ?? '').toLowerCase();

        // Permits reapplication only when the previous status is 'cancelled' or 'rejected'
        if (currentStatus != 'cancelled' && currentStatus != 'rejected') {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'already-exists',
            message: 'You already have an active rental request for this property.',
          );
        }

        // Reapplication is allowed after previous request was cancelled or rejected
        existingCreatedAt = data?['createdAt'];
      }

      final docData = <String, dynamic>{
        'propertyId': cleanPropId,
        'ownerId': cleanOwnerId,
        'tenantId': cleanTenantId,
        'tenantEmail': tenantEmail.trim(),
        'tenantName': tenantName.trim(),
        'tenantPhone': tenantPhone.trim(),
        'preferredMoveIn': preferredMoveIn.trim(),
        'message': message.trim(),
        'propertyTitle': propertyTitle.trim(),
        'propertyArea': propertyArea.trim(),
        'rentPerMonth': rentPerMonth,
        'propertyPhotoUrl': propertyPhotoUrl,
        'status': 'pending',
        'landlordNote': null,
        'createdAt': existingCreatedAt ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      transaction.set(docRef, docData);
      return docId;
    });
  }

  /// Checks whether an active request ('pending' or 'accepted') exists for [tenantId] and [propertyId].
  Future<bool> hasActiveRentalRequest({
    required String propertyId,
    required String tenantId,
  }) async {
    final cleanPropId = propertyId.trim();
    final cleanTenantId = tenantId.trim();
    if (!isFirebaseAvailable ||
        cleanPropId.isEmpty ||
        cleanTenantId.isEmpty ||
        cleanPropId.contains('/') ||
        cleanTenantId.contains('/')) {
      return false;
    }
    try {
      final docId = '${cleanPropId}_$cleanTenantId';
      final doc = await firestore.collection(rentalRequestsCollection).doc(docId).get();
      if (!doc.exists) return false;
      final status = (doc.data()?['status'] as String? ?? '').toLowerCase();
      return status == 'pending' || status == 'accepted';
    } catch (e) {
      debugPrint('FirestoreService.hasActiveRentalRequest error: $e');
      return false;
    }
  }

  /// Real-time stream of rental requests submitted by the authenticated tenant.
  Stream<List<RentalRequest>> streamTenantRequests(String tenantId) {
    final cleanUid = tenantId.trim();
    if (!isFirebaseAvailable || cleanUid.isEmpty) {
      return const Stream.empty();
    }
    try {
      return firestore
          .collection(rentalRequestsCollection)
          .where('tenantId', isEqualTo: cleanUid)
          .snapshots()
          .map((snapshot) {
        final list = <RentalRequest>[];
        for (final doc in snapshot.docs) {
          try {
            list.add(rentalRequestFromFirestore(doc.id, doc.data()));
          } catch (e) {
            debugPrint('Failed to parse rental request doc ${doc.id}: $e');
          }
        }
        list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
        return list;
      });
    } catch (e) {
      debugPrint('FirestoreService.streamTenantRequests error: $e');
      return const Stream.empty();
    }
  }

  /// Real-time stream of incoming rental requests for a specific property (for landlords).
  ///
  /// Constrained by [ownerId] to ensure compliance with Firestore Security Rules.
  Stream<List<RentalRequest>> streamPropertyRequests({
    required String propertyId,
    required String ownerId,
  }) {
    final cleanPropId = propertyId.trim();
    final cleanOwnerId = ownerId.trim();
    if (!isFirebaseAvailable || cleanPropId.isEmpty || cleanOwnerId.isEmpty) {
      return const Stream.empty();
    }
    try {
      return firestore
          .collection(rentalRequestsCollection)
          .where('ownerId', isEqualTo: cleanOwnerId)
          .where('propertyId', isEqualTo: cleanPropId)
          .snapshots()
          .map((snapshot) {
        final list = <RentalRequest>[];
        for (final doc in snapshot.docs) {
          try {
            list.add(rentalRequestFromFirestore(doc.id, doc.data()));
          } catch (e) {
            debugPrint('Failed to parse property request doc ${doc.id}: $e');
          }
        }
        list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
        return list;
      });
    } catch (e) {
      debugPrint('FirestoreService.streamPropertyRequests error: $e');
      return const Stream.empty();
    }
  }

  /// Real-time stream of all incoming rental requests across all properties owned by [ownerId].
  Stream<List<RentalRequest>> streamLandlordRequests(String ownerId) {
    final cleanUid = ownerId.trim();
    if (!isFirebaseAvailable || cleanUid.isEmpty) {
      return const Stream.empty();
    }
    try {
      return firestore
          .collection(rentalRequestsCollection)
          .where('ownerId', isEqualTo: cleanUid)
          .snapshots()
          .map((snapshot) {
        final list = <RentalRequest>[];
        for (final doc in snapshot.docs) {
          try {
            list.add(rentalRequestFromFirestore(doc.id, doc.data()));
          } catch (e) {
            debugPrint('Failed to parse landlord request doc ${doc.id}: $e');
          }
        }
        list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
        return list;
      });
    } catch (e) {
      debugPrint('FirestoreService.streamLandlordRequests error: $e');
      return const Stream.empty();
    }
  }

  /// Landlord accepts or rejects a rental request, with an optional response note.
  Future<void> respondToRentalRequest({
    required String requestId,
    required String ownerId,
    required String status,
    String? landlordNote,
  }) async {
    final cleanReqId = requestId.trim();
    final cleanOwnerId = ownerId.trim();
    final cleanStatus = status.trim().toLowerCase();

    if (cleanOwnerId.isEmpty || cleanReqId.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'Must be authenticated to respond to a rental request.',
      );
    }

    if (cleanStatus != 'accepted' && cleanStatus != 'rejected') {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Invalid status. Landlord response must be accepted or rejected.',
      );
    }

    if (!isFirebaseAvailable) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'Must be authenticated to respond to a rental request.',
      );
    }

    final updates = <String, dynamic>{
      'status': cleanStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (landlordNote != null && landlordNote.trim().isNotEmpty) {
      updates['landlordNote'] = landlordNote.trim();
    }

    await firestore.collection(rentalRequestsCollection).doc(cleanReqId).update(updates);
  }

  /// Tenant withdraws / cancels their own pending rental request.
  Future<void> cancelRentalRequest({
    required String requestId,
    required String tenantId,
  }) async {
    final cleanReqId = requestId.trim();
    final cleanTenantId = tenantId.trim();

    if (cleanTenantId.isEmpty || cleanReqId.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'Must be authenticated to cancel a rental request.',
      );
    }

    if (!isFirebaseAvailable) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'Must be authenticated to cancel a rental request.',
      );
    }

    await firestore.collection(rentalRequestsCollection).doc(cleanReqId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // Landlord Contact Details (Strict Subcollection Isolation)
  // ---------------------------------------------------------------------------

  /// Sets or updates the landlord contact information for [propertyId].
  ///
  /// Strictly stored in subcollection `/properties/{propertyId}/contact_info/details`
  /// to protect privacy in accordance with Firestore Security Rules.
  Future<void> setPropertyContactInfo({
    required String propertyId,
    required String ownerId,
    required LandlordContactInfo contactInfo,
  }) async {
    final cleanPropId = propertyId.trim();
    final cleanOwnerId = ownerId.trim();

    if (cleanOwnerId.isEmpty || cleanPropId.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'Must be authenticated to update property contact details.',
      );
    }

    if (!isFirebaseAvailable) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'app-not-initialized',
        message: 'Firebase is not initialized in this environment.',
      );
    }

    final docRef = firestore
        .collection(propertiesCollection)
        .doc(cleanPropId)
        .collection(contactInfoSubcollection)
        .doc(defaultContactDocId);

    final existing = await docRef.get();
    if (existing.exists) {
      final updates = <String, dynamic>{
        'phone': (contactInfo.phone != null && contactInfo.phone!.trim().isNotEmpty)
            ? contactInfo.phone!.trim()
            : null,
        'whatsapp': (contactInfo.whatsapp != null && contactInfo.whatsapp!.trim().isNotEmpty)
            ? contactInfo.whatsapp!.trim()
            : null,
        'email': (contactInfo.email != null && contactInfo.email!.trim().isNotEmpty)
            ? contactInfo.email!.trim()
            : null,
        'otherTitle': (contactInfo.otherTitle != null && contactInfo.otherTitle!.trim().isNotEmpty)
            ? contactInfo.otherTitle!.trim()
            : null,
        'otherLink': (contactInfo.otherLink != null && contactInfo.otherLink!.trim().isNotEmpty)
            ? contactInfo.otherLink!.trim()
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await docRef.update(updates);
    } else {
      if (contactInfo.isEmpty) return;
      final data = <String, dynamic>{
        'ownerId': cleanOwnerId,
        'propertyId': cleanPropId,
        'phone': (contactInfo.phone != null && contactInfo.phone!.trim().isNotEmpty)
            ? contactInfo.phone!.trim()
            : null,
        'whatsapp': (contactInfo.whatsapp != null && contactInfo.whatsapp!.trim().isNotEmpty)
            ? contactInfo.whatsapp!.trim()
            : null,
        'email': (contactInfo.email != null && contactInfo.email!.trim().isNotEmpty)
            ? contactInfo.email!.trim()
            : null,
        'otherTitle': (contactInfo.otherTitle != null && contactInfo.otherTitle!.trim().isNotEmpty)
            ? contactInfo.otherTitle!.trim()
            : null,
        'otherLink': (contactInfo.otherLink != null && contactInfo.otherLink!.trim().isNotEmpty)
            ? contactInfo.otherLink!.trim()
            : null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await docRef.set(data);
    }
  }

  /// Fetches landlord contact information for [propertyId] once.
  ///
  /// Accessible only by the owner or an authenticated tenant whose rental request is 'accepted'.
  Future<LandlordContactInfo?> getPropertyContactInfo(String propertyId) async {
    final cleanPropId = propertyId.trim();
    if (!isFirebaseAvailable || cleanPropId.isEmpty) return null;
    try {
      final doc = await firestore
          .collection(propertiesCollection)
          .doc(cleanPropId)
          .collection(contactInfoSubcollection)
          .doc(defaultContactDocId)
          .get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return LandlordContactInfo.fromMap(data);
    } catch (e) {
      debugPrint('FirestoreService.getPropertyContactInfo error: $e');
      return null;
    }
  }

  /// Real-time stream of landlord contact info for [propertyId].
  ///
  /// Emits the contact info, or null if the document does not exist.
  /// If an error occurs (such as permission-denied), the error is emitted to the stream.
  Stream<LandlordContactInfo?> streamPropertyContactInfo(String propertyId) {
    final cleanPropId = propertyId.trim();
    if (!isFirebaseAvailable || cleanPropId.isEmpty) {
      return Stream.value(null);
    }
    try {
      return firestore
          .collection(propertiesCollection)
          .doc(cleanPropId)
          .collection(contactInfoSubcollection)
          .doc(defaultContactDocId)
          .snapshots()
          .map((doc) {
            if (!doc.exists) return null;
            final data = doc.data();
            if (data == null) return null;
            return LandlordContactInfo.fromMap(data);
          });
    } catch (e) {
      debugPrint('FirestoreService.streamPropertyContactInfo catch: $e');
      return Stream.error(e);
    }
  }

  /// Fetches the rental request submitted by [tenantId] for [propertyId], if any.
  Future<RentalRequest?> getTenantRentalRequest({
    required String propertyId,
    required String tenantId,
  }) async {
    final cleanPropId = propertyId.trim();
    final cleanTenantId = tenantId.trim();
    if (!isFirebaseAvailable || cleanPropId.isEmpty || cleanTenantId.isEmpty) {
      return null;
    }
    try {
      final docId = '${cleanPropId}_$cleanTenantId';
      final doc = await firestore.collection(rentalRequestsCollection).doc(docId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return rentalRequestFromFirestore(doc.id, data);
    } catch (e) {
      debugPrint('FirestoreService.getTenantRentalRequest error: $e');
      return null;
    }
  }

  /// Real-time stream of the rental request submitted by [tenantId] for [propertyId].
  Stream<RentalRequest?> streamTenantRentalRequest({
    required String propertyId,
    required String tenantId,
  }) {
    final cleanPropId = propertyId.trim();
    final cleanTenantId = tenantId.trim();
    if (!isFirebaseAvailable || cleanPropId.isEmpty || cleanTenantId.isEmpty) {
      return Stream.value(null);
    }
    try {
      final docId = '${cleanPropId}_$cleanTenantId';
      return firestore
          .collection(rentalRequestsCollection)
          .doc(docId)
          .snapshots()
          .map((doc) {
            if (!doc.exists) return null;
            final data = doc.data();
            if (data == null) return null;
            return rentalRequestFromFirestore(doc.id, data);
          });
    } catch (e) {
      debugPrint('FirestoreService.streamTenantRentalRequest catch: $e');
      return Stream.error(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Converters
  // ---------------------------------------------------------------------------

  /// Converts a Firestore document map into a [Property] instance.
  static Property propertyFromFirestore(String id, Map<String, dynamic> data) {
    final typeStr = data['propertyType'] as String? ?? 'family';
    final propType = PropertyType.fromString(typeStr);

    final rawPhotos = data['photos'] as List? ?? [];
    final photos = <PropertyPhoto>[];
    for (var i = 0; i < rawPhotos.length; i++) {
      final p = rawPhotos[i];
      if (p is Map) {
        photos.add(
          PropertyPhoto(
            label: p['label'] as String? ?? 'Property Photo',
            imageUrl: p['imageUrl'] as String?,
            storagePath: p['storagePath'] as String?,
            isCover: p['isCover'] as bool? ?? (i == 0),
            order: (p['order'] as num?)?.toInt() ?? i,
            assetPath: p['assetPath'] as String?,
          ),
        );
      }
    }

    final rawFacilities = data['facilities'] as List? ?? [];
    final facilities = rawFacilities.whereType<String>().toList();

    final rawHighlights = data['nearbyHighlights'] as List? ?? [];
    final highlights = rawHighlights.whereType<String>().toList();

    return Property(
      id: id,
      title: data['title'] as String? ?? 'Rental Property',
      area: data['area'] as String? ?? 'Dhaka, Bangladesh',
      landmark: data['landmark'] as String? ?? '',
      fullAddress: data['fullAddress'] as String?,
      rentPerMonth: (data['rentPerMonth'] as num?)?.toInt() ?? 0,
      depositAmount: (data['depositAmount'] as num?)?.toInt(),
      sizeSqFt: (data['sizeSqFt'] as num?)?.toInt(),
      floorLevel: data['floorLevel'] as String? ?? 'Not specified',
      balconies: (data['balconies'] as num?)?.toInt() ?? 0,
      type: propType,
      bedrooms: (data['bedrooms'] as num?)?.toInt() ?? 0,
      bathrooms: (data['bathrooms'] as num?)?.toInt() ?? 0,
      availability: data['availability'] as String? ?? 'Available now',
      availableNow: data['availableNow'] as bool? ?? true,
      icon: propType == PropertyType.family
          ? Icons.apartment
          : propType == PropertyType.bachelor
              ? Icons.home_work
              : Icons.groups,
      gradientStart: const Color(0xFF2E9E6B),
      gradientEnd: const Color(0xFF0E5E3B),
      description: data['description'] as String? ?? '',
      facilities: facilities,
      nearbyHighlights: highlights,
      photos: photos,
      utilityNotice: data['utilityNotice'] as String? ?? 'Electricity & utility bills as per usage/sub-meter',
      isDemo: false,
      ownerId: data['ownerId'] as String?,
    );
  }

  /// Converts a Firestore document map into a [SubmittedListing] instance.
  static SubmittedListing submittedListingFromFirestore(String id, Map<String, dynamic> data) {
    final property = propertyFromFirestore(id, data);
    final statusStr = data['status'] as String? ?? 'pending';
    final status = ListingStatus.fromString(statusStr);

    DateTime submittedAt = DateTime.now();
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) {
      submittedAt = createdAt.toDate();
    }

    final rawPhotos = data['photos'] as List? ?? [];
    final photos = <WizardPhotoItem>[];
    for (var i = 0; i < rawPhotos.length; i++) {
      final p = rawPhotos[i];
      if (p is Map) {
        photos.add(
          WizardPhotoItem(
            id: 'photo-$i',
            label: p['label'] as String? ?? 'Photo ${i + 1}',
            networkUrl: p['imageUrl'] as String?,
            storagePath: p['storagePath'] as String?,
            isCover: p['isCover'] as bool? ?? (i == 0),
          ),
        );
      }
    }

    return SubmittedListing(
      id: id,
      property: property,
      status: status,
      submittedAt: submittedAt,
      photos: photos,
      moderationNote: data['moderationNote'] as String?,
      ownerId: data['ownerId'] as String?,
      isDemo: false,
    );
  }

  /// Converts a Firestore document map into a [RentalRequest] instance.
  static RentalRequest rentalRequestFromFirestore(String id, Map<String, dynamic> data) {
    DateTime requestedAt = DateTime.now();
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) {
      requestedAt = createdAt.toDate();
    }

    DateTime? updatedAt;
    final updatedTimestamp = data['updatedAt'];
    if (updatedTimestamp is Timestamp) {
      updatedAt = updatedTimestamp.toDate();
    }

    final propTitle = data['propertyTitle'] as String? ?? 'Rental Property';
    final propArea = data['propertyArea'] as String? ?? 'Dhaka';
    final rent = (data['rentPerMonth'] as num?)?.toInt() ?? 0;
    final propPhotoUrl = data['propertyPhotoUrl'] as String?;
    final propId = data['propertyId'] as String? ?? '';
    final ownerId = data['ownerId'] as String?;

    final property = Property(
      id: propId,
      title: propTitle,
      area: propArea,
      landmark: '',
      rentPerMonth: rent,
      type: PropertyType.family,
      bedrooms: 1,
      bathrooms: 1,
      availability: 'Available',
      availableNow: true,
      icon: Icons.apartment,
      gradientStart: const Color(0xFF2E9E6B),
      gradientEnd: const Color(0xFF0E5E3B),
      photos: propPhotoUrl != null && propPhotoUrl.isNotEmpty
          ? [PropertyPhoto(label: propTitle, imageUrl: propPhotoUrl)]
          : const [],
      ownerId: ownerId,
    );

    return RentalRequest(
      id: id,
      property: property,
      renterName: data['tenantName'] as String? ?? 'Applicant',
      renterPhone: data['tenantPhone'] as String? ?? '',
      preferredMoveIn: data['preferredMoveIn'] as String? ?? 'Immediate',
      message: data['message'] as String? ?? '',
      requestedAt: requestedAt,
      status: data['status'] as String? ?? 'pending',
      ownerId: ownerId,
      tenantId: data['tenantId'] as String?,
      tenantEmail: data['tenantEmail'] as String?,
      landlordNote: data['landlordNote'] as String?,
      updatedAt: updatedAt,
      isDemo: false,
    );
  }

  /// Translates [FirebaseException] and network/timeout exceptions into user-friendly messages.
  static String getFriendlyErrorMessage(Object error) {
    if (error is TimeoutException) {
      return error.message ?? 'Network request timed out. Please check your internet connection.';
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Access denied. You do not have permission to access or modify this data.';
        case 'unavailable':
          return 'The database service is temporarily unavailable. Please check your internet connection.';
        case 'not-found':
          return 'The requested document or listing was not found.';
        case 'already-exists':
          return 'You already have an active rental request for this property.';
        case 'resource-exhausted':
          return 'Quota exceeded. Please try again later.';
        case 'cancelled':
          return 'The database operation was cancelled.';
        case 'unauthenticated':
          return 'You must be signed in to access this feature.';
        case 'deadline-exceeded':
          return 'The connection timed out. Please check your network and try again.';
        case 'app-not-initialized':
          return 'Firebase is not initialized in this environment.';
        default:
          return error.message ?? 'A database error occurred (${error.code}).';
      }
    }
    final str = error.toString();
    if (str.contains('timed out') || str.contains('TimeoutException')) {
      return 'Network request timed out. Please check your internet connection.';
    }
    if (str.contains('permission-denied') ||
        str.contains('Missing or insufficient permissions')) {
      return 'Access denied. You do not have permission to access or modify this data.';
    }
    return str;
  }
}

/// Landlord direct contact details revealed only to tenants with an accepted rental request.
class LandlordContactInfo {
  const LandlordContactInfo({
    this.phone,
    this.whatsapp,
    this.email,
    this.otherTitle,
    this.otherLink,
  });

  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? otherTitle;
  final String? otherLink;

  /// Returns true if all contact fields are null or empty.
  bool get isEmpty =>
      (phone == null || phone!.trim().isEmpty) &&
      (whatsapp == null || whatsapp!.trim().isEmpty) &&
      (email == null || email!.trim().isEmpty) &&
      (otherLink == null || otherLink!.trim().isEmpty);

  bool get isNotEmpty => !isEmpty;

  Map<String, dynamic> toMap() {
    return {
      'phone': (phone != null && phone!.trim().isNotEmpty) ? phone!.trim() : null,
      'whatsapp': (whatsapp != null && whatsapp!.trim().isNotEmpty) ? whatsapp!.trim() : null,
      'email': (email != null && email!.trim().isNotEmpty) ? email!.trim() : null,
      'otherTitle': (otherTitle != null && otherTitle!.trim().isNotEmpty) ? otherTitle!.trim() : null,
      'otherLink': (otherLink != null && otherLink!.trim().isNotEmpty) ? otherLink!.trim() : null,
    };
  }

  factory LandlordContactInfo.fromMap(Map<String, dynamic> map) {
    return LandlordContactInfo(
      phone: map['phone'] as String?,
      whatsapp: map['whatsapp'] as String?,
      email: map['email'] as String?,
      otherTitle: map['otherTitle'] as String?,
      otherLink: map['otherLink'] as String?,
    );
  }

  LandlordContactInfo copyWith({
    String? phone,
    String? whatsapp,
    String? email,
    String? otherTitle,
    String? otherLink,
  }) {
    return LandlordContactInfo(
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      otherTitle: otherTitle ?? this.otherTitle,
      otherLink: otherLink ?? this.otherLink,
    );
  }

  /// Validates phone number format if provided. Returns null if valid or empty, or an error message.
  static String? validateOptionalPhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = value.trim();
    final phoneRegex = RegExp(r'^\+?[0-9\s\-()]{7,25}$');
    if (!phoneRegex.hasMatch(cleaned)) {
      return 'Please enter a valid phone number (digits, optional +, min 7 digits).';
    }
    return null;
  }

  /// Validates email format if provided. Returns null if valid or empty, or an error message.
  static String? validateOptionalEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = value.trim();
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(cleaned) || cleaned.length > 100) {
      return 'Please enter a valid email address (max 100 characters).';
    }
    return null;
  }

  /// Validates optional other link. Returns null if valid or empty, or an error message.
  static String? validateOptionalLink(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = value.trim();
    if (cleaned.contains(' ') || cleaned.length > 300) {
      return 'Please enter a valid URL/link without spaces (max 300 characters).';
    }
    return null;
  }
}
