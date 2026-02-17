/// Firebase Authentication service.
///
/// Supports Google Sign-In (via Firebase popup on web) and anonymous auth.
/// Anonymous users can upgrade to Google without losing data.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

final _auth = FirebaseAuth.instance;

/// Current Firebase user (null if not signed in).
User? get currentUser => _auth.currentUser;

/// Stream of auth state changes.
Stream<User?> get authStateChanges => _auth.authStateChanges();

/// Whether the user is signed in (anonymous or Google).
bool get isSignedIn => _auth.currentUser != null;

/// Whether the current user is anonymous.
bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

/// Sign in anonymously.  Returns the user.
Future<User?> signInAnonymously() async {
  try {
    final result = await _auth.signInAnonymously();
    debugPrint('Auth: signed in anonymously as ${result.user?.uid}');
    return result.user;
  } catch (e) {
    debugPrint('Auth: anonymous sign-in failed: $e');
    return null;
  }
}

/// Sign in with Google using Firebase Auth popup (works on web).
///
/// If the user is currently anonymous, links the Google credential
/// to preserve their Firestore data (searches, favorites).
Future<User?> signInWithGoogle() async {
  try {
    final googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');

    // If currently anonymous, link the credential to keep data.
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        final result = await current.linkWithPopup(googleProvider);
        debugPrint('Auth: linked Google to anonymous user ${result.user?.uid}');
        return result.user;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          debugPrint('Auth: credential already in use, signing in directly');
          final result = await _auth.signInWithPopup(googleProvider);
          return result.user;
        }
        rethrow;
      }
    }

    final result = await _auth.signInWithPopup(googleProvider);
    debugPrint('Auth: signed in with Google as ${result.user?.uid}');
    return result.user;
  } catch (e) {
    debugPrint('Auth: Google sign-in failed: $e');
    return null;
  }
}

/// Sign out.
Future<void> signOut() async {
  try {
    await _auth.signOut();
    debugPrint('Auth: signed out');
  } catch (e) {
    debugPrint('Auth: sign-out failed: $e');
  }
}

/// Display name (Google name or "Guest").
String get displayName {
  final user = _auth.currentUser;
  if (user == null || user.isAnonymous) return 'Guest';
  return user.displayName ?? user.email ?? 'User';
}

/// Profile photo URL (null for anonymous).
String? get photoUrl => _auth.currentUser?.photoURL;

/// Email (null for anonymous).
String? get email => _auth.currentUser?.email;
