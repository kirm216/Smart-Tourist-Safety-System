import 'package:firebase_auth/firebase_auth.dart';

import 'auth_error_messages.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Unable to identify the newly created user.');
      }

      await user.updateDisplayName(name.trim());
      await user.sendEmailVerification();

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(friendlyAuthErrorMessage(e));
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No signed-in user is available for verification.');
      }

      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw Exception(friendlyAuthErrorMessage(e));
    }
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(friendlyAuthErrorMessage(e));
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Stream<User?> get userChanges => _auth.userChanges();

  User? get currentUser => _auth.currentUser;

  bool get isSignedIn => _auth.currentUser != null;
}
