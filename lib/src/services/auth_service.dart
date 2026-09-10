import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService({required this.firebaseReady});

  final bool firebaseReady;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: const ['email']);

  User? get currentUser => firebaseReady ? _auth.currentUser : null;

  Stream<User?> get authStateChanges {
    if (!firebaseReady) return Stream<User?>.value(null);
    return _auth.authStateChanges();
  }

  bool signedInWithGoogle(User user) {
    return user.providerData.any((provider) => provider.providerId == 'google.com');
  }

  bool signedInWithPassword(User user) {
    return user.providerData.any((provider) => provider.providerId == 'password');
  }

  Future<UserCredential> signInWithEmail(String email, String password) {
    _requireFirebase();
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> createWithEmail(String email, String password) async {
    _requireFirebase();
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await result.user?.sendEmailVerification();
    return result;
  }

  Future<void> sendPasswordReset(String email) {
    _requireFirebase();
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<UserCredential?> signInWithGoogle() async {
    _requireFirebase();
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    final authentication = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: authentication.accessToken,
      idToken: authentication.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<User?> reloadCurrentUser() async {
    _requireFirebase();
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.reload();
    return _auth.currentUser;
  }

  Future<User?> updateDisplayName(String displayName) async {
    _requireFirebase();
    final user = _auth.currentUser;
    if (user == null) return null;
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return user;
    await user.updateDisplayName(trimmed);
    await user.reload();
    return _auth.currentUser;
  }

  Future<void> sendCurrentUserVerification() async {
    _requireFirebase();
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return;
    await user.sendEmailVerification();
  }

  /// Firebase requires a recent authentication before destructive account
  /// operations. Google accounts re-use the provider picker; password accounts
  /// require the user's current password and never store it.
  Future<void> reauthenticateCurrentUser({String? password}) async {
    _requireFirebase();
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in before deleting your account.');

    if (signedInWithGoogle(user)) {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw StateError('Google confirmation was cancelled.');
      }
      final authentication = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: authentication.accessToken,
        idToken: authentication.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      return;
    }

    if (signedInWithPassword(user)) {
      final email = user.email;
      final currentPassword = password ?? '';
      if (email == null || email.isEmpty) {
        throw StateError('This account does not have an email address.');
      }
      if (currentPassword.isEmpty) {
        throw StateError('Enter your current password to continue.');
      }
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      return;
    }

    throw StateError(
      'Homi cannot confirm this sign-in method yet. Contact support before deleting the account.',
    );
  }

  Future<void> deleteReauthenticatedCurrentUser() async {
    _requireFirebase();
    final user = _auth.currentUser;
    if (user == null) return;
    await user.delete();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Firebase identity deletion already succeeded; a provider sign-out
      // failure must not recreate or block the deleted account.
    }
  }

  Future<void> signOut() async {
    if (!firebaseReady) return;
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  void _requireFirebase() {
    if (!firebaseReady) {
      throw StateError('Homi cloud services are unavailable on this device.');
    }
  }
}
