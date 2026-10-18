import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Converts raw Firebase / network exceptions into short, user-friendly strings.
class AppErrorHandler {
  AppErrorHandler._();

  static String handle(Object error) {
    debugPrint('[AppErrorHandler] $error');

    if (error is FirebaseAuthException) {
      return _firebaseAuthMessage(error);
    }

    if (error is FirebaseException) {
      return _firestoreMessage(error);
    }

    final msg = error.toString();

    // Catch connectivity patterns
    if (msg.contains('SocketException') ||
        msg.contains('network') ||
        msg.contains('NetworkException') ||
        msg.contains('Failed host lookup')) {
      return 'No internet connection. Please try again.';
    }

    // Strip noisy prefixes from Exception()
    final cleaned =
        msg.replaceFirst('Exception: ', '').replaceFirst('Error: ', '');
    return cleaned.isNotEmpty ? cleaned : 'An unexpected error occurred.';
  }

  // ── Firebase Auth ──────────────────────────────────────────────────────────

  static String _firebaseAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 8 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  // ── Firestore ──────────────────────────────────────────────────────────────

  static String _firestoreMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Firestore denied this save. Please check your account access and try again.';
      case 'not-found':
        return 'The requested data was not found.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again later.';
      case 'deadline-exceeded':
        return 'The request timed out. Check your connection.';
      case 'already-exists':
        return 'This record already exists.';
      default:
        return e.message ?? 'A database error occurred.';
    }
  }
}
