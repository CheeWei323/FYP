import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn =
      GoogleSignIn.instance;

  bool _googleSignInInitialized = false;

  // Current logged-in user.
  User? get currentUser => _auth.currentUser;

  // Listen for login/logout changes.
  Stream<User?> get authStateChanges =>
      _auth.authStateChanges();

  // Register traveller using email and password.
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final UserCredential userCredential =
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Send verification email after registration.
    await userCredential.user?.sendEmailVerification();

    return userCredential;
  }

  // Login using email and password.
  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Let Firebase send its standard password-reset link.
  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  // Send verification email again.
  Future<void> resendVerificationEmail() async {
    final User? user = _auth.currentUser;

    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Refresh current user's information.
  Future<User?> reloadUser() async {
    User? user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    await user.reload();

    return _auth.currentUser;
  }

  // Initialises Google Sign-In when required.
  Future<void> _initializeGoogleSignIn() async {
    if (_googleSignInInitialized) {
      return;
    }

    await _googleSignIn.initialize(
      serverClientId:
      '882145192712-b2gguv4oacptf283eoc0vr0anvd2sccf.apps.googleusercontent.com',
    );

    _googleSignInInitialized = true;
  }

  // Login using Google.
  Future<UserCredential?> signInWithGoogle() async {
    await _initializeGoogleSignIn();

    try {
      final GoogleSignInAccount googleUser =
      await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final OAuthCredential credential =
      GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(
        credential,
      );
    } on GoogleSignInException catch (e) {
      if (e.code ==
          GoogleSignInExceptionCode.canceled) {
        return null;
      }

      rethrow;
    }
  }

  // Logout from Firebase and Google Sign-In.
  Future<void> signOut() async {
    await _auth.signOut();

    try {
      await _initializeGoogleSignIn();
      await _googleSignIn.signOut();
    } catch (_) {
      // Firebase logout has already succeeded.
      // A missing Google session should not block logout.
    }
  }
}
