/// Firebase Authentication service.
///
/// Supports:
///   - Anonymous auth (auto)
///   - Google Sign-In (popup on web)
///   - Email/password sign-up & sign-in
///   - Email verification
///   - Password reset
///   - Email address change
///   - Phone / SMS verification (MFA-ready)
///
/// Anonymous users can upgrade to email or Google without losing data.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

final _auth = FirebaseAuth.instance;

// ---------------------------------------------------------------------------
// Getters
// ---------------------------------------------------------------------------

User? get currentUser => _auth.currentUser;
Stream<User?> get authStateChanges => _auth.authStateChanges();
bool get isSignedIn => _auth.currentUser != null;
bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

String get displayName {
  final user = _auth.currentUser;
  if (user == null || user.isAnonymous) return 'Guest';
  return user.displayName ?? user.email ?? 'User';
}

String? get photoUrl => _auth.currentUser?.photoURL;
String? get email => _auth.currentUser?.email;
bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;
String? get phoneNumber => _auth.currentUser?.phoneNumber;

/// List of linked provider IDs (e.g. 'password', 'google.com', 'phone').
List<String> get linkedProviders =>
    _auth.currentUser?.providerData.map((p) => p.providerId).toList() ?? [];

bool get hasPasswordProvider => linkedProviders.contains('password');
bool get hasGoogleProvider => linkedProviders.contains('google.com');
bool get hasPhoneProvider => linkedProviders.contains('phone');

// ---------------------------------------------------------------------------
// Anonymous
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Google Sign-In
// ---------------------------------------------------------------------------

Future<User?> signInWithGoogle() async {
  try {
    final googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');

    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        final result = await current.linkWithPopup(googleProvider);
        debugPrint('Auth: linked Google to anonymous ${result.user?.uid}');
        return result.user;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
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

// ---------------------------------------------------------------------------
// Email / Password – Sign Up
// ---------------------------------------------------------------------------

/// Create a new account with email & password.
/// If the user is anonymous, links the email credential to keep data.
/// Returns a user-facing error message or null on success.
Future<String?> signUpWithEmail({
  required String email,
  required String password,
  String? displayName,
}) async {
  try {
    final current = _auth.currentUser;

    UserCredential result;
    if (current != null && current.isAnonymous) {
      // Link to keep anonymous data.
      final credential =
          EmailAuthProvider.credential(email: email, password: password);
      try {
        result = await current.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          return 'An account already exists with that email.';
        }
        return _friendlyError(e);
      }
    } else {
      result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    }

    // Set display name if provided.
    if (displayName != null && displayName.isNotEmpty) {
      await result.user?.updateDisplayName(displayName);
    }

    // Send verification email.
    if (result.user != null && !result.user!.emailVerified) {
      await result.user!.sendEmailVerification();
      debugPrint('Auth: verification email sent to $email');
    }

    debugPrint('Auth: signed up with email as ${result.user?.uid}');
    return null; // success
  } on FirebaseAuthException catch (e) {
    return _friendlyError(e);
  } catch (e) {
    debugPrint('Auth: email sign-up failed: $e');
    return 'Something went wrong. Please try again.';
  }
}

// ---------------------------------------------------------------------------
// Email / Password – Sign In
// ---------------------------------------------------------------------------

/// Sign in with email & password.
/// Returns a user-facing error message or null on success.
Future<String?> signInWithEmail({
  required String email,
  required String password,
}) async {
  try {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    debugPrint('Auth: signed in with email as ${result.user?.uid}');
    return null;
  } on FirebaseAuthException catch (e) {
    return _friendlyError(e);
  } catch (e) {
    debugPrint('Auth: email sign-in failed: $e');
    return 'Something went wrong. Please try again.';
  }
}

// ---------------------------------------------------------------------------
// Email Verification
// ---------------------------------------------------------------------------

/// Re-send the email verification link.
Future<String?> sendEmailVerification() async {
  try {
    final user = _auth.currentUser;
    if (user == null) return 'Not signed in.';
    if (user.emailVerified) return 'Email is already verified.';
    await user.sendEmailVerification();
    debugPrint('Auth: verification email sent');
    return null;
  } on FirebaseAuthException catch (e) {
    return _friendlyError(e);
  } catch (e) {
    return 'Could not send verification email.';
  }
}

/// Reload the user to check if email has been verified.
Future<bool> reloadAndCheckVerified() async {
  try {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  } catch (_) {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Password Reset
// ---------------------------------------------------------------------------

/// Send a password reset email.
/// Returns a user-facing error message or null on success.
Future<String?> sendPasswordReset(String email) async {
  try {
    await _auth.sendPasswordResetEmail(email: email);
    debugPrint('Auth: password reset email sent to $email');
    return null;
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found') {
      return 'No account found with that email.';
    }
    return _friendlyError(e);
  } catch (e) {
    return 'Could not send reset email.';
  }
}

// ---------------------------------------------------------------------------
// Email Address Change
// ---------------------------------------------------------------------------

/// Update the user's email address (requires recent sign-in).
/// A verification email is sent to the new address.
/// Returns error message or null on success.
Future<String?> updateEmail(String newEmail) async {
  try {
    final user = _auth.currentUser;
    if (user == null) return 'Not signed in.';
    await user.verifyBeforeUpdateEmail(newEmail);
    debugPrint('Auth: verification sent to new email $newEmail');
    return null;
  } on FirebaseAuthException catch (e) {
    if (e.code == 'requires-recent-login') {
      return 'Please sign in again before changing your email.';
    }
    return _friendlyError(e);
  } catch (e) {
    return 'Could not update email.';
  }
}

// ---------------------------------------------------------------------------
// Password Change
// ---------------------------------------------------------------------------

/// Update the user's password (requires recent sign-in).
Future<String?> updatePassword(String newPassword) async {
  try {
    final user = _auth.currentUser;
    if (user == null) return 'Not signed in.';
    await user.updatePassword(newPassword);
    debugPrint('Auth: password updated');
    return null;
  } on FirebaseAuthException catch (e) {
    if (e.code == 'requires-recent-login') {
      return 'Please sign in again before changing your password.';
    }
    if (e.code == 'weak-password') {
      return 'Password is too weak. Use at least 6 characters.';
    }
    return _friendlyError(e);
  } catch (e) {
    return 'Could not update password.';
  }
}

// ---------------------------------------------------------------------------
// Re-authenticate (needed before sensitive operations)
// ---------------------------------------------------------------------------

/// Re-authenticate with email/password (for email change, password change, etc.).
Future<String?> reauthenticateWithPassword(String password) async {
  try {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return 'Not signed in with email.';
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
    return null;
  } on FirebaseAuthException catch (e) {
    if (e.code == 'wrong-password') return 'Incorrect password.';
    return _friendlyError(e);
  } catch (e) {
    return 'Re-authentication failed.';
  }
}

// ---------------------------------------------------------------------------
// Phone / SMS Verification
// ---------------------------------------------------------------------------

/// Start phone number verification (sends SMS code).
///
/// [onCodeSent] is called with the verificationId when the code is sent.
/// [onAutoVerified] is called if auto-verification succeeds (Android only).
/// [onError] is called with a user-facing error message.
Future<void> verifyPhoneNumber({
  required String phoneNumber,
  required void Function(String verificationId) onCodeSent,
  required void Function(User user) onAutoVerified,
  required void Function(String error) onError,
  Duration timeout = const Duration(seconds: 60),
}) async {
  try {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: timeout,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verification (Android auto-retrieval).
        try {
          final user = _auth.currentUser;
          if (user != null && !user.isAnonymous) {
            await user.linkWithCredential(credential);
          } else {
            await _auth.signInWithCredential(credential);
          }
          onAutoVerified(_auth.currentUser!);
        } catch (e) {
          onError('Auto-verification failed: $e');
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(_friendlyError(e));
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        debugPrint('Auth: SMS auto-retrieval timeout');
      },
    );
  } catch (e) {
    onError('Could not send verification code.');
  }
}

/// Confirm the SMS code and link phone number to the current user.
/// Returns error message or null on success.
Future<String?> confirmSmsCode({
  required String verificationId,
  required String smsCode,
}) async {
  try {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final user = _auth.currentUser;
    if (user != null && !user.isAnonymous) {
      // Link phone to existing account.
      await user.linkWithCredential(credential);
      debugPrint('Auth: phone linked to user ${user.uid}');
    } else {
      await _auth.signInWithCredential(credential);
      debugPrint('Auth: signed in with phone');
    }
    return null;
  } on FirebaseAuthException catch (e) {
    if (e.code == 'invalid-verification-code') {
      return 'Invalid code. Please try again.';
    }
    if (e.code == 'credential-already-in-use') {
      return 'This phone number is already linked to another account.';
    }
    return _friendlyError(e);
  } catch (e) {
    return 'Verification failed.';
  }
}

/// Unlink phone number from the current user.
Future<String?> unlinkPhone() async {
  try {
    await _auth.currentUser?.unlink('phone');
    debugPrint('Auth: phone unlinked');
    return null;
  } catch (e) {
    return 'Could not unlink phone number.';
  }
}

// ---------------------------------------------------------------------------
// Update Display Name
// ---------------------------------------------------------------------------

Future<String?> updateDisplayName(String name) async {
  try {
    await _auth.currentUser?.updateDisplayName(name);
    await _auth.currentUser?.reload();
    return null;
  } catch (e) {
    return 'Could not update name.';
  }
}

// ---------------------------------------------------------------------------
// Sign Out
// ---------------------------------------------------------------------------

Future<void> signOut() async {
  try {
    await _auth.signOut();
    debugPrint('Auth: signed out');
  } catch (e) {
    debugPrint('Auth: sign-out failed: $e');
  }
}

// ---------------------------------------------------------------------------
// Delete Account
// ---------------------------------------------------------------------------

/// Permanently delete the user account (requires recent sign-in).
Future<String?> deleteAccount() async {
  try {
    await _auth.currentUser?.delete();
    debugPrint('Auth: account deleted');
    return null;
  } on FirebaseAuthException catch (e) {
    if (e.code == 'requires-recent-login') {
      return 'Please sign in again before deleting your account.';
    }
    return _friendlyError(e);
  } catch (e) {
    return 'Could not delete account.';
  }
}

// ---------------------------------------------------------------------------
// Error helpers
// ---------------------------------------------------------------------------

String _friendlyError(FirebaseAuthException e) {
  switch (e.code) {
    case 'email-already-in-use':
      return 'An account already exists with that email.';
    case 'invalid-email':
      return 'Invalid email address.';
    case 'weak-password':
      return 'Password is too weak. Use at least 6 characters.';
    case 'user-not-found':
      return 'No account found with that email.';
    case 'wrong-password':
      return 'Incorrect password.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'operation-not-allowed':
      return 'This sign-in method is not enabled.';
    case 'requires-recent-login':
      return 'Please sign in again to complete this action.';
    case 'invalid-verification-code':
      return 'Invalid verification code.';
    case 'invalid-phone-number':
      return 'Invalid phone number format.';
    case 'credential-already-in-use':
      return 'This credential is already linked to another account.';
    case 'network-request-failed':
      return 'Network error. Check your connection.';
    default:
      debugPrint('Auth error [${e.code}]: ${e.message}');
      return e.message ?? 'Authentication error. Please try again.';
  }
}
