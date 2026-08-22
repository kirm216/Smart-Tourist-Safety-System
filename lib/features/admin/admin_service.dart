import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> isAdmin(String uid) async {
    try {
      final snapshot = await _firestore.collection('admins').doc(uid).get();
      return snapshot.exists;
    } on FirebaseException {
      return false;
    }
  }
}
