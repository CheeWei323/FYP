import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/country.dart';
import '../models/rule_activity_log.dart';
import '../models/travel_rule.dart';

class ContentManagerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Retrieves all destination countries, including disabled destinations.
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

  // Retrieves every rule belonging to a destination.
  // Inactive rules are included for Content Manager review.
  Future<List<TravelRule>> getRulesForCountry(String countryId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('travelRules')
        .where('countryId', isEqualTo: countryId)
        .get();

    final List<TravelRule> rules = snapshot.docs
        .map((document) => TravelRule.fromFirestore(document))
        .toList();

    rules.sort((a, b) {
      final int priorityComparison = a.priority.compareTo(b.priority);

      if (priorityComparison != 0) {
        return priorityComparison;
      }

      return a.title.compareTo(b.title);
    });

    return rules;
  }

  // Loads summary information for the Content Manager dashboard.
  Future<Map<String, int>> getOverview() async {
    final Future<QuerySnapshot<Map<String, dynamic>>> countriesFuture =
        _firestore.collection('countries').get();

    final Future<QuerySnapshot<Map<String, dynamic>>> rulesFuture = _firestore
        .collection('travelRules')
        .get();

    // Handle both reads together so simultaneous failures remain recoverable.
    final snapshots = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
      countriesFuture,
      rulesFuture,
    ]);
    final countriesSnapshot = snapshots[0];
    final rulesSnapshot = snapshots[1];

    final int enabledCountries = countriesSnapshot.docs
        .where((document) => document.data()['enabled'] == true)
        .length;

    final int activeRules = rulesSnapshot.docs
        .where((document) => document.data()['active'] == true)
        .length;

    final int pendingReviewRules = rulesSnapshot.docs
        .where((document) => document.data()['reviewStatus'] == 'pendingReview')
        .length;

    final int disabledRules = rulesSnapshot.docs.where((document) {
      final Map<String, dynamic> data = document.data();

      final String? reviewStatus = data['reviewStatus'] as String?;

      final bool active = data['active'] as bool? ?? true;

      // Backwards compatibility:
      // older inactive rules without reviewStatus
      // are treated as disabled.
      return reviewStatus == 'disabled' || (reviewStatus == null && !active);
    }).length;

    return {
      'countries': countriesSnapshot.docs.length,
      'enabledCountries': enabledCountries,
      'rules': rulesSnapshot.docs.length,
      'activeRules': activeRules,
      'pendingReviewRules': pendingReviewRules,
      'disabledRules': disabledRules,
    };
  }

  // Retrieves the most recent regulatory activity
  // for the Content Manager dashboard.
  Future<List<RuleActivityLog>> getRecentActivity({int limit = 5}) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('ruleActivityLogs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((document) => RuleActivityLog.fromFirestore(document))
        .toList();
  }

  // Retrieves the complete regulatory activity history
  // in newest-first order.
  Future<List<RuleActivityLog>> getActivityHistory() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('ruleActivityLogs')
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((document) => RuleActivityLog.fromFirestore(document))
        .toList();
  }

  // Retrieves the authenticated Content Manager information
  // used when recording regulatory activity.
  Future<Map<String, String>> _getCurrentManagerProfile() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user.');
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!snapshot.exists) {
      throw Exception('Content Manager profile not found.');
    }

    final Map<String, dynamic> data = snapshot.data() ?? {};

    if (data['role'] != 'contentManager') {
      throw Exception('Authenticated user is not a Content Manager.');
    }

    return {
      'uid': user.uid,
      'name': data['fullName'] as String? ?? 'Content Manager',
      'email': data['email'] as String? ?? user.email ?? '',
    };
  }

  // Creates activity data for regulatory traceability.
  Map<String, dynamic> _buildActivityLogData({
    required String action,
    required TravelRule rule,
    required Map<String, String> manager,
  }) {
    return {
      'action': action,
      'ruleId': rule.id,
      'ruleTitle': rule.title,
      'countryId': rule.countryId,
      'performedByUid': manager['uid'],
      'performedByName': manager['name'],
      'performedByEmail': manager['email'],
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  // Generates a readable and unique Firestore document ID
  // for a Content Manager-created travel rule.
  String _generateRuleId(TravelRule rule) {
    String titleSlug = rule.title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    if (titleSlug.isEmpty) {
      titleSlug = 'rule';
    }

    if (titleSlug.length > 35) {
      titleSlug = titleSlug.substring(0, 35);
    }

    final int timestamp = DateTime.now().millisecondsSinceEpoch;

    return '${rule.countryId}_'
        '${rule.category}_'
        '${titleSlug}_'
        '$timestamp';
  }

  // Creates a new regulatory rule.
  // New rules remain inactive and pending review.
  // The creation is recorded in the activity log.
  Future<void> createTravelRule(TravelRule rule) async {
    final Map<String, String> manager = await _getCurrentManagerProfile();

    final String ruleId = _generateRuleId(rule);

    final DocumentReference<Map<String, dynamic>> ruleRef = _firestore
        .collection('travelRules')
        .doc(ruleId);

    final DocumentReference<Map<String, dynamic>> logRef = _firestore
        .collection('ruleActivityLogs')
        .doc();

    final Map<String, dynamic> data = rule.toMap();

    data['active'] = false;
    data['reviewStatus'] = 'pendingReview';

    data['lastValidatedAt'] = FieldValue.serverTimestamp();

    final WriteBatch batch = _firestore.batch();

    batch.set(ruleRef, data);

    batch.set(logRef, {
      'action': 'created',
      'ruleId': ruleId,
      'ruleTitle': rule.title,
      'countryId': rule.countryId,
      'performedByUid': manager['uid'],
      'performedByName': manager['name'],
      'performedByEmail': manager['email'],
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Updates an existing regulatory rule.
  // The current publication/review status is preserved
  // and the update is recorded for traceability.
  Future<void> updateTravelRule(TravelRule rule) async {
    final Map<String, String> manager = await _getCurrentManagerProfile();

    final DocumentReference<Map<String, dynamic>> ruleRef = _firestore
        .collection('travelRules')
        .doc(rule.id);

    final DocumentReference<Map<String, dynamic>> logRef = _firestore
        .collection('ruleActivityLogs')
        .doc();

    final Map<String, dynamic> data = rule.toMap();

    data['lastValidatedAt'] = FieldValue.serverTimestamp();

    final WriteBatch batch = _firestore.batch();

    batch.update(ruleRef, data);

    batch.set(
      logRef,
      _buildActivityLogData(action: 'updated', rule: rule, manager: manager),
    );

    await batch.commit();
  }

  // Enables or disables a regulatory rule.
  // Enabling marks the rule as approved.
  // Disabling keeps the rule stored but excludes it
  // from future traveller checklist generation.
  Future<void> setTravelRuleActive({
    required TravelRule rule,
    required bool active,
  }) async {
    final Map<String, String> manager = await _getCurrentManagerProfile();

    final DocumentReference<Map<String, dynamic>> ruleRef = _firestore
        .collection('travelRules')
        .doc(rule.id);

    final DocumentReference<Map<String, dynamic>> logRef = _firestore
        .collection('ruleActivityLogs')
        .doc();

    final Map<String, dynamic> updates = {
      'active': active,
      'reviewStatus': active ? 'approved' : 'disabled',
    };

    if (active) {
      updates['lastValidatedAt'] = FieldValue.serverTimestamp();
    }

    final WriteBatch batch = _firestore.batch();

    batch.update(ruleRef, updates);

    batch.set(
      logRef,
      _buildActivityLogData(
        action: active ? 'enabled' : 'disabled',
        rule: rule,
        manager: manager,
      ),
    );

    await batch.commit();
  }
}
