import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? auth})
    : _auth = auth ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _auth;
  Future<void>? _googleInit;

  AuthUser? _map(fb.User? u) => u == null
      ? null
      : AuthUser(
          uid: u.uid,
          email: u.email,
          emailVerified: u.emailVerified,
          displayName: u.displayName,
          photoUrl: u.photoURL,
          usesPassword: u.providerData.any((p) => p.providerId == 'password'),
        );

  @override
  Stream<AuthUser?> authStateChanges() => _auth.userChanges().map(_map);

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(friendlyAuthMessage(e.code), code: e.code);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthFailure('Sign-in was cancelled.', code: 'cancelled');
      }
      throw const AuthFailure(
        'Google sign-in didn\'t work. Please try again or use email.',
        code: 'google-failed',
      );
    }
  }

  @override
  Future<void> signInWithGoogle() => _guard(() async {
    if (kIsWeb) {
      await _auth.signInWithPopup(fb.GoogleAuthProvider());
      return;
    }
    _googleInit ??= GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleServerClientId.isEmpty
          ? null
          : AppConfig.googleServerClientId,
    );
    await _googleInit;
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthFailure('Google sign-in didn\'t return a token.');
    }
    await _auth.signInWithCredential(
      fb.GoogleAuthProvider.credential(idToken: idToken),
    );
  });

  @override
  Future<void> signInWithEmail(String email, String password) => _guard(
    () => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<void> registerWithEmail(String email, String password) =>
      _guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await cred.user?.sendEmailVerification();
      });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> sendEmailVerification() =>
      _guard(() async => _auth.currentUser?.sendEmailVerification());

  @override
  Future<AuthUser?> reload() => _guard(() async {
    await _auth.currentUser?.reload();
    await _auth.currentUser?.getIdToken(true); // refresh email_verified claim
    return _map(_auth.currentUser);
  });

  @override
  Future<String?> idToken({bool forceRefresh = false}) async {
    try {
      return await _auth.currentUser?.getIdToken(forceRefresh);
    } on fb.FirebaseAuthException {
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        /* not signed in with Google */
      }
    }
    await _auth.signOut();
  }

  @override
  Future<void> deleteAccount({String? password}) => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (password != null && user.email != null) {
      await user.reauthenticateWithCredential(
        fb.EmailAuthProvider.credential(email: user.email!, password: password),
      );
    }
    await user.delete();
  });
}

/// Maps Firebase Auth error codes to messages a non-technical user can act on.
String friendlyAuthMessage(String code) {
  switch (code) {
    case 'invalid-email':
      return 'That email address doesn\'t look right.';
    case 'user-disabled':
      return 'This account has been disabled. Contact support if you think this is a mistake.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return 'Email or password is incorrect.';
    case 'email-already-in-use':
      return 'An account with this email already exists. Try signing in instead.';
    case 'weak-password':
      return 'Please choose a stronger password (at least 8 characters).';
    case 'account-exists-with-different-credential':
      return 'This email is already registered with a different sign-in method. Sign in with that method first.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a few minutes and try again.';
    case 'network-request-failed':
      return 'No internet connection. Check your network and try again.';
    case 'requires-recent-login':
      return 'For your security, please sign in again before doing this.';
    case 'popup-closed-by-user':
    case 'cancelled-popup-request':
      return 'Sign-in was cancelled.';
    case 'operation-not-allowed':
      return 'This sign-in method isn\'t enabled yet.';
    default:
      return 'Something went wrong. Please try again.';
  }
}
