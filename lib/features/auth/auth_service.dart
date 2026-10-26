import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_error_messages.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _digitalTouristIdCharacters =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

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
      await _initializeTouristProfile(user);
      await user.sendEmailVerification();

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(friendlyAuthErrorMessage(e));
    }
  }

  Future<void> _initializeTouristProfile(User user) async {
    final profileReference = _firestore.collection('users').doc(user.uid);
    final profileSnapshot = await profileReference.get();
    final profile = profileSnapshot.data() ?? <String, dynamic>{};
    final existingId = profile['digitalTouristId'];
    final digitalTouristId =
        existingId is String && existingId.trim().isNotEmpty
        ? existingId
        : await _generateUniqueDigitalTouristId();

    final profileFields = <String, Object?>{
      'digitalTouristId': digitalTouristId,
    };
    if (profile['fullName'] is! String ||
        (profile['fullName'] as String).trim().isEmpty) {
      profileFields['fullName'] = user.displayName ?? '';
    }
    if (profile['email'] is! String ||
        (profile['email'] as String).trim().isEmpty) {
      profileFields['email'] = user.email ?? '';
    }
    final approvalStatus = profile['approvalStatus'];
    if (approvalStatus is! String || approvalStatus.trim().isEmpty) {
      profileFields['approvalStatus'] = 'pending';
    }

    await profileReference.set(profileFields, SetOptions(merge: true));
  }

  Future<String> _generateUniqueDigitalTouristId() async {
    final random = Random.secure();
    for (var attempt = 0; attempt < 5; attempt++) {
      final suffix = List.generate(
        8,
        (_) =>
            _digitalTouristIdCharacters[random.nextInt(
              _digitalTouristIdCharacters.length,
            )],
      ).join();
      final candidate = 'DTID-$suffix';
      final matches = await _firestore
          .collection('users')
          .where('digitalTouristId', isEqualTo: candidate)
          .limit(1)
          .get();
      if (matches.docs.isEmpty) return candidate;
    }

    throw Exception('Unable to generate a unique Digital Tourist ID.');
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
