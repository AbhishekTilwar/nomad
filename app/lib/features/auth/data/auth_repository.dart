/// Minimal view of the signed-in identity, decoupled from firebase_auth so
/// state logic can be unit-tested with a fake repository.
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.emailVerified,
    this.displayName,
    this.photoUrl,
    this.usesPassword = false,
  });

  final String uid;
  final String? email;
  final bool emailVerified;
  final String? displayName;
  final String? photoUrl;
  final bool usesPassword;
}

class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

abstract class AuthRepository {
  /// Emits the current user (or null) and every change, including token expiry
  /// sign-outs.
  Stream<AuthUser?> authStateChanges();
  AuthUser? get currentUser;

  Future<void> signInWithGoogle();
  Future<void> signInWithEmail(String email, String password);
  Future<void> registerWithEmail(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> sendEmailVerification();

  /// Reloads the user and returns the fresh state (to pick up verification).
  Future<AuthUser?> reload();
  Future<String?> idToken({bool forceRefresh = false});
  Future<void> signOut();

  /// Deletes the Auth account. May throw [AuthFailure] with code
  /// `requires-recent-login`.
  Future<void> deleteAccount({String? password});
}
