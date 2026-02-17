/// AuthProvider – manages authentication state via ChangeNotifier.
///
/// Wraps [auth_service] functions and exposes reactive state for the UI.
library;

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart' as auth;
import '../services/firestore_service.dart' as db;

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _loading = true;
  StreamSubscription<User?>? _sub;

  AuthProvider() {
    _sub = auth.authStateChanges.listen((user) {
      _user = user;
      _loading = false;
      if (user != null) {
        db.ensureUserDoc();
      }
      notifyListeners();
    });
  }

  // ── Getters ────────────────────────────────────────────────────────────
  User? get user => _user;
  bool get isLoading => _loading;
  bool get isSignedIn => _user != null;
  bool get isAnonymous => _user?.isAnonymous ?? true;
  String get displayName => auth.displayName;
  String? get photoUrl => auth.photoUrl;
  String? get email => auth.email;
  String? get uid => _user?.uid;
  bool get isEmailVerified => auth.isEmailVerified;
  String? get phoneNumber => auth.phoneNumber;
  List<String> get linkedProviders => auth.linkedProviders;
  bool get hasPasswordProvider => auth.hasPasswordProvider;
  bool get hasGoogleProvider => auth.hasGoogleProvider;
  bool get hasPhoneProvider => auth.hasPhoneProvider;

  // ── Anonymous ──────────────────────────────────────────────────────────
  Future<void> signInAnonymously() async {
    _loading = true;
    notifyListeners();
    await auth.signInAnonymously();
  }

  // ── Google ─────────────────────────────────────────────────────────────
  Future<bool> signInWithGoogle() async {
    _loading = true;
    notifyListeners();
    final user = await auth.signInWithGoogle();
    return user != null;
  }

  // ── Email / Password ──────────────────────────────────────────────────
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _loading = true;
    notifyListeners();
    final err = await auth.signUpWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );
    _loading = false;
    notifyListeners();
    return err;
  }

  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _loading = true;
    notifyListeners();
    final err = await auth.signInWithEmail(email: email, password: password);
    _loading = false;
    notifyListeners();
    return err;
  }

  // ── Email Verification ────────────────────────────────────────────────
  Future<String?> sendEmailVerification() async {
    return auth.sendEmailVerification();
  }

  Future<bool> reloadAndCheckVerified() async {
    final verified = await auth.reloadAndCheckVerified();
    notifyListeners();
    return verified;
  }

  // ── Password Reset ────────────────────────────────────────────────────
  Future<String?> sendPasswordReset(String email) async {
    return auth.sendPasswordReset(email);
  }

  // ── Email Change ──────────────────────────────────────────────────────
  Future<String?> updateEmail(String newEmail) async {
    final err = await auth.updateEmail(newEmail);
    if (err == null) notifyListeners();
    return err;
  }

  // ── Password Change ───────────────────────────────────────────────────
  Future<String?> updatePassword(String newPassword) async {
    return auth.updatePassword(newPassword);
  }

  // ── Re-authenticate ───────────────────────────────────────────────────
  Future<String?> reauthenticateWithPassword(String password) async {
    return auth.reauthenticateWithPassword(password);
  }

  // ── Phone / SMS ───────────────────────────────────────────────────────
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(User user) onAutoVerified,
    required void Function(String error) onError,
  }) async {
    return auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onAutoVerified: (user) {
        notifyListeners();
        onAutoVerified(user);
      },
      onError: onError,
    );
  }

  Future<String?> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final err = await auth.confirmSmsCode(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    if (err == null) notifyListeners();
    return err;
  }

  Future<String?> unlinkPhone() async {
    final err = await auth.unlinkPhone();
    if (err == null) notifyListeners();
    return err;
  }

  // ── Display Name ──────────────────────────────────────────────────────
  Future<String?> updateDisplayName(String name) async {
    final err = await auth.updateDisplayName(name);
    if (err == null) notifyListeners();
    return err;
  }

  // ── Sign Out ──────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await auth.signOut();
  }

  // ── Delete Account ────────────────────────────────────────────────────
  Future<String?> deleteAccount() async {
    return auth.deleteAccount();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
