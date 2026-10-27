import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Centralized Firebase Authentication Service for BashaLagbe.
///
/// Encapsulates user registration, sign-in, password reset, sign-out,
/// and auth-state stream listeners with friendly error message translation.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _customAuth = auth;

  static final AuthService instance = AuthService();
  final FirebaseAuth? _customAuth;

  /// Returns true if Firebase has been initialized in this runtime environment.
  bool get isFirebaseAvailable {
    if (_customAuth != null) return true;
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Returns the active [FirebaseAuth] instance.
  FirebaseAuth get auth {
    if (_customAuth != null) return _customAuth;
    if (!isFirebaseAvailable) {
      throw FirebaseAuthException(
        code: 'app-not-initialized',
        message: 'Firebase has not been initialized. Please verify your platform setup.',
      );
    }
    return FirebaseAuth.instance;
  }

  /// Real-time stream of the current authenticated [User].
  Stream<User?> get authStateChanges {
    if (!isFirebaseAvailable) {
      return const Stream.empty();
    }
    try {
      return auth.authStateChanges();
    } catch (e) {
      debugPrint('AuthService.authStateChanges error: $e');
      return const Stream.empty();
    }
  }

  /// Synchronously returns the currently signed-in [User], or `null` if unauthenticated.
  User? get currentUser {
    if (!isFirebaseAvailable) return null;
    try {
      return auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Registers a new user with email, password, and an optional display name.
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final trimmedEmail = email.trim();
    final credential = await auth.createUserWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );

    if (credential.user != null && displayName != null && displayName.trim().isNotEmpty) {
      try {
        await credential.user!.updateDisplayName(displayName.trim());
        await credential.user!.reload();
      } catch (e) {
        debugPrint('Failed to set initial displayName: $e');
      }
    }

    return credential;
  }

  /// Signs in an existing user with email and password.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sends a password reset email to the given address.
  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    await auth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  /// Signs out the currently authenticated user.
  Future<void> signOut() async {
    if (isFirebaseAvailable) {
      await auth.signOut();
    }
  }

  /// Updates the current user's display name.
  Future<void> updateDisplayName(String displayName) async {
    final user = currentUser;
    if (user != null) {
      await user.updateDisplayName(displayName.trim());
      await user.reload();
    }
  }

  /// Sends an email verification link to the current user.
  Future<void> sendEmailVerification() async {
    final user = currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Permanently deletes the currently authenticated user account.
  ///
  /// Throws a [FirebaseAuthException] with code `requires-recent-login` if the
  /// user has not re-authenticated recently.
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user != null) {
      await user.delete();
    }
  }

  /// Translates [FirebaseAuthException] codes into user-friendly messages.
  static String getFriendlyErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'requires-recent-login':
          return 'For security, please log out and log back in before deleting your account.';
        case 'user-not-found':
          return 'No account found with this email address. Please register first.';
        case 'wrong-password':
          return 'Incorrect password. Please try again or reset your password.';
        case 'invalid-credential':
          return 'Invalid email or password. Please verify your credentials.';
        case 'email-already-in-use':
          return 'An account already exists with this email address. Please log in.';
        case 'invalid-email':
          return 'The email address is not formatted correctly.';
        case 'weak-password':
          return 'Password is too weak. Please use at least 6 characters.';
        case 'user-disabled':
          return 'This account has been disabled. Please contact BashaLagbe support.';
        case 'operation-not-allowed':
          return 'Email/password sign-in is not enabled in Firebase Console. Please enable it in Firebase Console under Authentication > Sign-in method.';
        case 'too-many-requests':
          return 'Too many failed attempts. Temporary block activated. Please wait a moment and try again.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection and try again.';
        case 'app-not-initialized':
          return 'Firebase is not initialized in this environment.';
        default:
          return error.message ?? 'An unexpected authentication error occurred (${error.code}).';
      }
    }
    return error.toString();
  }
}
