import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/system_user.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ---------------------------------------------------------------------------
  // SYSTEM OVERVIEW
  // ---------------------------------------------------------------------------

  Future<Map<String, int>> getOverview() async {
    final Future<QuerySnapshot<Map<String, dynamic>>> usersFuture = _firestore
        .collection('users')
        .get();

    final Future<QuerySnapshot<Map<String, dynamic>>> countriesFuture =
        _firestore.collection('countries').get();

    final QuerySnapshot<Map<String, dynamic>> usersSnapshot = await usersFuture;

    final QuerySnapshot<Map<String, dynamic>> countriesSnapshot =
        await countriesFuture;

    int countRole(String role) {
      return usersSnapshot.docs
          .where((document) => document.data()['role'] == role)
          .length;
    }

    final int enabledCountries = countriesSnapshot.docs
        .where((document) => document.data()['enabled'] == true)
        .length;

    return {
      'users': usersSnapshot.docs.length,
      'travellers': countRole('traveller'),
      'contentManagers': countRole('contentManager'),
      'analysts': countRole('analyst'),
      'admins': countRole('admin'),
      'countries': countriesSnapshot.docs.length,
      'enabledCountries': enabledCountries,
    };
  }

  // ---------------------------------------------------------------------------
  // USER ACCOUNTS
  // ---------------------------------------------------------------------------

  Future<List<SystemUser>> getUsers() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .get();

    final List<SystemUser> users = snapshot.docs
        .map((document) => SystemUser.fromFirestore(document))
        .toList();

    users.sort((a, b) {
      final String aName = a.fullName.toLowerCase();

      final String bName = b.fullName.toLowerCase();

      final int comparison = aName.compareTo(bName);

      if (comparison != 0) {
        return comparison;
      }

      return a.email.toLowerCase().compareTo(b.email.toLowerCase());
    });

    return users;
  }

  // ---------------------------------------------------------------------------
  // USER ROLE MANAGEMENT
  // ---------------------------------------------------------------------------

  // Changes the role of a non-administrator account.
  // Administrator roles cannot be assigned through the client application.
  Future<void> updateUserRole({
    required SystemUser user,
    required String newRole,
  }) async {
    const Set<String> allowedRoles = {'traveller', 'contentManager', 'analyst'};

    if (!allowedRoles.contains(newRole)) {
      throw Exception('Invalid user role.');
    }

    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated administrator.');
    }

    if (currentUser.uid == user.id) {
      throw Exception('Administrators cannot change their own role.');
    }

    if (user.role == 'admin') {
      throw Exception('Administrator accounts cannot be modified.');
    }

    if (user.role == newRole) {
      return;
    }

    await _firestore.collection('users').doc(user.id).update({
      'role': newRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
