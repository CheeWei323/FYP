import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createTravellerProfile({
    required String uid,
    required String fullName,
    required String email,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'fullName': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'role': 'traveller',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}