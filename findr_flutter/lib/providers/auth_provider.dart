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

  User? get user => _user;
  bool get isLoading => _loading;
  bool get isSignedIn => _user != null;
  bool get isAnonymous => _user?.isAnonymous ?? true;
  String get displayName => auth.displayName;
  String? get photoUrl => auth.photoUrl;
  String? get email => auth.email;
  String? get uid => _user?.uid;

  Future<void> signInAnonymously() async {
    _loading = true;
    notifyListeners();
    await auth.signInAnonymously();
    // authStateChanges listener handles the rest.
  }

  Future<bool> signInWithGoogle() async {
    _loading = true;
    notifyListeners();
    final user = await auth.signInWithGoogle();
    return user != null;
  }

  Future<void> signOut() async {
    await auth.signOut();
    // authStateChanges listener handles the rest.
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
