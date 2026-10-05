import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/country.dart';
import '../models/travel_rule.dart';

class ContentManagerService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // Retrieves all destination countries, including disabled destinations.
  Future<List<Country>> getAllCountries() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _firestore
        .collection('countries')
        .get();

    final List<Country> countries =
    snapshot.docs
        .map(
          (document) =>
          Country.fromFirestore(
            document,
          ),
    )
        .toList();

    countries.sort(
          (a, b) =>
          a.name.compareTo(
            b.name,
          ),
    );

    return countries;
  }

  // Retrieves every rule belonging to a destination.
  // Inactive rules are included for Content Manager review.
  Future<List<TravelRule>> getRulesForCountry(
      String countryId,
      ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _firestore
        .collection('travelRules')
        .where(
      'countryId',
      isEqualTo: countryId,
    )
        .get();

    final List<TravelRule> rules =
    snapshot.docs
        .map(
          (document) =>
          TravelRule.fromFirestore(
            document,
          ),
    )
        .toList();

    rules.sort(
          (a, b) {
        final int priorityComparison =
        a.priority.compareTo(
          b.priority,
        );

        if (priorityComparison != 0) {
          return priorityComparison;
        }

        return a.title.compareTo(
          b.title,
        );
      },
    );

    return rules;
  }

  // Loads summary information for the Content Manager dashboard.
  Future<Map<String, int>> getOverview() async {
    final Future<
        QuerySnapshot<Map<String, dynamic>>>
    countriesFuture =
    _firestore
        .collection('countries')
        .get();

    final Future<
        QuerySnapshot<Map<String, dynamic>>>
    rulesFuture =
    _firestore
        .collection('travelRules')
        .get();

    final QuerySnapshot<Map<String, dynamic>>
    countriesSnapshot =
    await countriesFuture;

    final QuerySnapshot<Map<String, dynamic>>
    rulesSnapshot =
    await rulesFuture;

    final int enabledCountries =
        countriesSnapshot.docs
            .where(
              (document) =>
          document.data()['enabled'] ==
              true,
        )
            .length;

    final int activeRules =
        rulesSnapshot.docs
            .where(
              (document) =>
          document.data()['active'] ==
              true,
        )
            .length;

    final int inactiveRules =
        rulesSnapshot.docs.length -
            activeRules;

    return {
      'countries':
      countriesSnapshot.docs.length,
      'enabledCountries':
      enabledCountries,
      'rules':
      rulesSnapshot.docs.length,
      'activeRules':
      activeRules,
      'inactiveRules':
      inactiveRules,
    };
  }

  // Generates a readable and unique Firestore document ID
  // for a Content Manager-created travel rule.
  String _generateRuleId(
      TravelRule rule,
      ) {
    String titleSlug = rule.title
        .trim()
        .toLowerCase()
        .replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    )
        .replaceAll(
      RegExp(r'^_+|_+$'),
      '',
    );

    if (titleSlug.isEmpty) {
      titleSlug = 'rule';
    }

    if (titleSlug.length > 35) {
      titleSlug =
          titleSlug.substring(
            0,
            35,
          );
    }

    final int timestamp =
        DateTime.now()
            .millisecondsSinceEpoch;

    return '${rule.countryId}_'
        '${rule.category}_'
        '${titleSlug}_'
        '$timestamp';
  }

  // Creates a new regulatory rule.
  // New rules are stored as inactive until reviewed and enabled.
  Future<void> createTravelRule(
      TravelRule rule,
      ) async {
    final String ruleId =
        _generateRuleId(
      rule,
    );

    final DocumentReference<
        Map<String, dynamic>> document =
    _firestore
        .collection(
      'travelRules',
    )
        .doc(ruleId);

    final Map<String, dynamic> data =
    rule.toMap();

    data['active'] = false;

    data['lastValidatedAt'] =
        FieldValue.serverTimestamp();

    await document.set(
      data,
    );
  }

// Updates the editable information of an existing regulatory rule.
// The existing active/inactive status is preserved.
  Future<void> updateTravelRule(
      TravelRule rule,
      ) async {
    final Map<String, dynamic> data =
    rule.toMap();

    data['lastValidatedAt'] =
        FieldValue.serverTimestamp();

    await _firestore
        .collection('travelRules')
        .doc(rule.id)
        .update(data);
  }

// Enables or disables a regulatory rule.
// Disabled rules remain stored for traceability but are not used
// by the traveller rule-based DSS.
  Future<void> setTravelRuleActive({
    required String ruleId,
    required bool active,
  }) async {
    final Map<String, dynamic> updates = {
      'active': active,
    };

    if (active) {
      updates['lastValidatedAt'] =
          FieldValue.serverTimestamp();
    }

    await _firestore
        .collection('travelRules')
        .doc(ruleId)
        .update(updates);
  }
}