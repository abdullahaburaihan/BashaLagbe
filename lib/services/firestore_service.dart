import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:basha_lagbe/main.dart';
import 'package:basha_lagbe/property_details_screen.dart';
import 'package:basha_lagbe/post_property_screen.dart';

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

  /// Creates a new property document in the [propertiesCollection].
  ///
  /// Always sets `ownerId` to the authenticated user's UID and `status` to 'pending'.
  Future<String> createProperty({
    required String ownerId,
    required String ownerEmail,
    required Map<String, dynamic> data,
  }) async {
    final cleanUid = ownerId.trim();
    if (!isFirebaseAvailable || cleanUid.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'Must be authenticated to submit a property listing.',
      );
    }

    final docRef = firestore.collection(propertiesCollection).doc();
    final Map<String, dynamic> docData = Map<String, dynamic>.from(data);

    // Enforce security & auditing invariants
    docData['ownerId'] = cleanUid;
    docData['ownerEmail'] = ownerEmail.trim();
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
  /// Prevents modifying `ownerId`, `status`, `moderationNote`, or `createdAt`.
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

    await firestore.collection(propertiesCollection).doc(cleanPropId).delete();
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
    for (final p in rawPhotos) {
      if (p is Map) {
        photos.add(
          PropertyPhoto(
            label: p['label'] as String? ?? 'Property Photo',
            imageUrl: p['imageUrl'] as String?,
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

  /// Translates [FirebaseException] codes into user-friendly messages.
  static String getFriendlyErrorMessage(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Access denied. You do not have permission to access or modify this data.';
        case 'unavailable':
          return 'The database service is temporarily unavailable. Please check your internet connection.';
        case 'not-found':
          return 'The requested document or listing was not found.';
        case 'already-exists':
          return 'This record already exists in the database.';
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
    return error.toString();
  }
}
