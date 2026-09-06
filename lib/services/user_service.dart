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

  Future<void> createTravellerProfileIfNeeded({
    required String uid,
    required String fullName,
    required String email,
  }) async {
    final DocumentReference<Map<String, dynamic>> userRef =
    _firestore.collection('users').doc(uid);

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
    await userRef.get();

    if (snapshot.exists) {
      return;
    }

    await userRef.set({
      'fullName': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'role': 'traveller',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}