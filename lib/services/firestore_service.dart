import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
