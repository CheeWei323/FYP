import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/system_user.dart';
import '../models/country.dart';
import '../models/admin_activity_log.dart';

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

    // Attach error handlers to both reads before awaiting either result.
    final snapshots = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
      usersFuture,
      countriesFuture,
    ]);
    final usersSnapshot = snapshots[0];
    final countriesSnapshot = snapshots[1];

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

  Future<Map<String, String>> _getCurrentAdminIdentity() async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated administrator.');
    }

    final DocumentSnapshot<Map<String, dynamic>> profile = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!profile.exists) {
      throw Exception('Administrator profile was not found.');
    }

    final Map<String, dynamic> data = profile.data() ?? {};

    if (data['role'] != 'admin') {
      throw Exception('Administrator access is required.');
    }

    return {
      'uid': currentUser.uid,
      'name': (data['fullName'] as String? ?? '').trim(),
      'email': (data['email'] as String? ?? '').trim(),
    };
  }

  String _formatRoleLabel(String role) {
    switch (role) {
      case 'traveller':
        return 'Traveller';

      case 'contentManager':
        return 'Content Manager';

      case 'analyst':
        return 'Tourism Data Analyst';

      case 'admin':
        return 'System Administrator';

      default:
        return role;
    }
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

    final Map<String, String> administrator = await _getCurrentAdminIdentity();

    if (administrator['uid'] == user.id) {
      throw Exception('Administrators cannot change their own role.');
    }

    final DocumentReference<Map<String, dynamic>> userReference = _firestore
        .collection('users')
        .doc(user.id);

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await userReference
        .get();

    if (!snapshot.exists) {
      throw Exception('User account was not found.');
    }

    final Map<String, dynamic> data = snapshot.data() ?? {};

    final String currentRole = data['role'] as String? ?? '';

    if (currentRole == 'admin') {
      throw Exception('Administrator accounts cannot be modified.');
    }

    if (currentRole == newRole) {
      return;
    }

    final String fullName = (data['fullName'] as String? ?? '').trim();

    final String email = (data['email'] as String? ?? '').trim();

    final String targetName = fullName.isNotEmpty
        ? fullName
        : email.isNotEmpty
        ? email
        : user.id;

    final DocumentReference<Map<String, dynamic>> logReference = _firestore
        .collection('adminActivityLogs')
        .doc();

    final WriteBatch batch = _firestore.batch();

    batch.update(userReference, {
      'role': newRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(logReference, {
      'action': 'roleChanged',
      'targetId': user.id,
      'targetName': targetName,
      'details':
          '${_formatRoleLabel(currentRole)} '
          '→ '
          '${_formatRoleLabel(newRole)}',
      'performedByUid': administrator['uid'],
      'performedByName': administrator['name'],
      'performedByEmail': administrator['email'],
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // DESTINATION MANAGEMENT
  // ---------------------------------------------------------------------------

  // Retrieves all supported destinations, including disabled destinations.
  Future<List<Country>> getAllCountries() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('countries')
        .get();

    final List<Country> countries = snapshot.docs
        .map((document) => Country.fromFirestore(document))
        .toList();

    countries.sort((a, b) => a.name.compareTo(b.name));

    return countries;
  }

  // Enables or disables a supported destination.
  // At least one destination must remain enabled so that
  // travellers can continue creating trips.
  Future<void> setCountryEnabled({
    required Country country,
    required bool enabled,
  }) async {
    final Map<String, String> administrator = await _getCurrentAdminIdentity();

    final DocumentReference<Map<String, dynamic>> countryReference = _firestore
        .collection('countries')
        .doc(country.id);

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await countryReference.get();

    if (!snapshot.exists) {
      throw Exception('Destination was not found.');
    }

    final Map<String, dynamic> data = snapshot.data() ?? {};

    final bool currentEnabled = data['enabled'] as bool? ?? false;

    if (currentEnabled == enabled) {
      return;
    }

    if (!enabled) {
      final QuerySnapshot<Map<String, dynamic>> enabledSnapshot =
          await _firestore
              .collection('countries')
              .where('enabled', isEqualTo: true)
              .get();

      final bool targetCurrentlyEnabled = enabledSnapshot.docs.any(
        (document) => document.id == country.id,
      );

      if (targetCurrentlyEnabled && enabledSnapshot.docs.length <= 1) {
        throw StateError('At least one destination must remain enabled.');
      }
    }

    final String countryName = (data['name'] as String? ?? '').trim();

    final String targetName = countryName.isNotEmpty ? countryName : country.id;

    final DocumentReference<Map<String, dynamic>> logReference = _firestore
        .collection('adminActivityLogs')
        .doc();

    final WriteBatch batch = _firestore.batch();

    batch.update(countryReference, {
      'enabled': enabled,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    batch.set(logReference, {
      'action': enabled ? 'destinationEnabled' : 'destinationDisabled',
      'targetId': country.id,
      'targetName': targetName,
      'details': enabled
          ? 'Destination enabled for new traveller trips.'
          : 'Destination disabled for new traveller trips.',
      'performedByUid': administrator['uid'],
      'performedByName': administrator['name'],
      'performedByEmail': administrator['email'],
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // ADMINISTRATIVE ACTIVITY
  // ---------------------------------------------------------------------------

  Future<List<AdminActivityLog>> getRecentActivity({int limit = 4}) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('adminActivityLogs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((document) => AdminActivityLog.fromFirestore(document))
        .toList();
  }

  Future<List<AdminActivityLog>> getActivityHistory() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('adminActivityLogs')
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((document) => AdminActivityLog.fromFirestore(document))
        .toList();
  }
}
