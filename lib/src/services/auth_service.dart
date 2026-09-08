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

  Future<UserCredential> signInWithEmail(String email, String password) {
    _requireFirebase();
    return _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
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

  Future<void> signOut() async {
    if (!firebaseReady) return;
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  void _requireFirebase() {
    if (!firebaseReady) {
      throw StateError('Firebase is not configured on this Android build yet.');
    }
  }
}
