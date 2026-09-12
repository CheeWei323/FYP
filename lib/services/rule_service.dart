import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/travel_rule.dart';

class RuleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Retrieves active rules belonging to the selected destination.
  Future<List<TravelRule>> getRulesForCountry(String countryId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _firestore
        .collection('travelRules')
        .where('countryId', isEqualTo: countryId)
        .get();

    final List<TravelRule> rules = snapshot.docs
        .map((document) => TravelRule.fromFirestore(document))
        .where((rule) => rule.active)
        .toList();

    // Display applicable requirements according to their configured priority.
    rules.sort(
          (a, b) => a.priority.compareTo(b.priority),
    );

    return rules;
  }

  // Evaluates whether a rule applies to the traveller's purpose and duration.
  bool matchesRule({
    required TravelRule rule,
    required String selectedPurpose,
    required int tripDurationDays,
  }) {
    final bool purposeMatches =
        rule.purposes.contains('all') ||
            rule.purposes.contains(selectedPurpose);

    final bool minimumDurationMatches =
        tripDurationDays >= rule.minDurationDays;

    final bool maximumDurationMatches =
        rule.maxDurationDays == null ||
            tripDurationDays <= rule.maxDurationDays!;

    return purposeMatches &&
        minimumDurationMatches &&
        maximumDurationMatches;
  }

  // Returns the personalised requirements that match the trip conditions.
  Future<List<TravelRule>> getApplicableRules({
    required String countryId,
    required String purpose,
    required int durationDays,
  }) async {
    final List<TravelRule> countryRules =
    await getRulesForCountry(countryId);

    return countryRules.where((rule) {
      return matchesRule(
        rule: rule,
        selectedPurpose: purpose,
        tripDurationDays: durationDays,
      );
    }).toList();
  }
}