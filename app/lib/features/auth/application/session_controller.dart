import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/app_exception.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/data/user_profile.dart';
import '../data/auth_repository.dart';

enum SessionStatus {
  /// Waiting for Firebase to restore a persisted session.
  initializing,
  signedOut,
  needsEmailVerification,
  loadingProfile,
  needsOnboarding,
  ready,

  /// Signed in but the profile could not be loaded (offline, server down).
  profileError,

  /// Server marked the account suspended/deleted.
  restricted,
}

/// Single source of truth for "who is using the app and what can they see".
/// The router redirects purely from [status].
class SessionController extends ChangeNotifier {
  SessionController({
    required AuthRepository auth,
    required ProfileRepository profiles,
  }) : _auth = auth,
       _profiles = profiles {
    _sub = _auth.authStateChanges().listen(_onAuthChanged);
  }

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  StreamSubscription<AuthUser?>? _sub;

  SessionStatus _status = SessionStatus.initializing;
  AuthUser? _user;
  UserProfile? _profile;
  String? _error;
  bool _disposed = false;

  SessionStatus get status => _status;
  AuthUser? get user => _user;
  UserProfile? get profile => _profile;
  String? get error => _error;

  Future<void> _onAuthChanged(AuthUser? user) async {
    final previousUid = _user?.uid;
    _user = user;
    if (user == null) {
      _profile = null;
      _error = null;
      _set(SessionStatus.signedOut);
      return;
    }
    if (user.usesPassword && !user.emailVerified) {
      _set(SessionStatus.needsEmailVerification);
      return;
    }
    // Avoid refetching on benign userChanges() re-emits (token refresh).
    if (previousUid == user.uid && _status == SessionStatus.ready) return;
    await loadProfile();
  }

  Future<void> loadProfile() async {
    _error = null;
    _set(SessionStatus.loadingProfile);
    try {
      final p = await _profiles.fetchMe();
      _profile = p;
      if (p == null || !p.profileCompleted) {
        _set(SessionStatus.needsOnboarding);
      } else if (p.accountStatus == 'suspended' ||
          p.accountStatus == 'deleted') {
        _set(SessionStatus.restricted);
      } else {
        _set(SessionStatus.ready);
      }
    } on AppException catch (e) {
      if (e.code == 'unauthenticated') {
        await signOut();
        return;
      }
      _error = e.message;
      _set(SessionStatus.profileError);
    }
  }

  /// Re-checks email verification after the user taps the link.
  Future<bool> refreshEmailVerification() async {
    final u = await _auth.reload();
    if (u != null && u.emailVerified) {
      _user = u;
      await loadProfile();
      return true;
    }
    return false;
  }

  Future<void> resendVerification() => _auth.sendEmailVerification();

  Future<void> completeOnboarding({
    required String displayName,
    required DateTime dateOfBirth,
    required String city,
    required String bio,
    required List<String> interests,
    required List<String> preferredActivityTypes,
    String? photoUrl,
  }) async {
    _profile = await _profiles.createProfile(
      displayName: displayName,
      dateOfBirth: dateOfBirth,
      city: city,
      bio: bio,
      interests: interests,
      preferredActivityTypes: preferredActivityTypes,
      photoUrl: photoUrl,
    );
    _set(SessionStatus.ready);
  }

  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? city,
    List<String>? interests,
    List<String>? preferredActivityTypes,
    String? photoUrl,
  }) async {
    _profile = await _profiles.updateProfile(
      displayName: displayName,
      bio: bio,
      city: city,
      interests: interests,
      preferredActivityTypes: preferredActivityTypes,
      photoUrl: photoUrl,
    );
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Deletes server-side data (the backend also removes the Auth user), then
  /// clears the local session.
  Future<void> deleteAccount() async {
    await _profiles.deleteAccountData();
    await _auth.signOut();
  }

  void _set(SessionStatus s) {
    if (_disposed) return;
    _status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
