import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Current logged-in user
  User? get currentUser => _auth.currentUser;

  // Listen for login/logout changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register traveller using email and password
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final UserCredential userCredential =
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Send verification email after registration
    await userCredential.user?.sendEmailVerification();

    return userCredential;
  }

  // Login using email and password
  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Send verification email again
  Future<void> resendVerificationEmail() async {
    final User? user = _auth.currentUser;

    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Refresh current user's information
  Future<User?> reloadUser() async {
    User? user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    await user.reload();

    return _auth.currentUser;
  }

  // Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }
}