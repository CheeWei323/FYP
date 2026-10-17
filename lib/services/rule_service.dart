import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/travel_rule.dart';

// -----------------------------------------------------------------------------
// REGULATORY REQUIREMENT SELECTION
// -----------------------------------------------------------------------------
class RuleService {
  // Replace the loader in tests to check selection without a Firebase connection.
  RuleService({Future<List<TravelRule>> Function(String countryId)? ruleLoader})
    : _ruleLoader = ruleLoader ?? _loadCountryRules;

  final Future<List<TravelRule>> Function(String countryId) _ruleLoader;

  // Load destination records before applying the publication checks below.
  static Future<List<TravelRule>> _loadCountryRules(String countryId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('travelRules')
        .where('countryId', isEqualTo: countryId)
        .get();

    return snapshot.docs
        .map((document) => TravelRule.fromFirestore(document))
        .toList();
  }

  // Return only published destination rules in their configured priority order.
  Future<List<TravelRule>> getRulesForCountry(String countryId) async {
    final countryRules = await _ruleLoader(countryId);
    final rules = countryRules
        .where((rule) => rule.countryId == countryId && rule.isPublished)
        .toList();

    rules.sort((a, b) => a.priority.compareTo(b.priority));
    return rules;
  }

  // Match published rules against purpose and inclusive duration boundaries.
  bool matchesRule({
    required TravelRule rule,
    required String selectedPurpose,
    required int tripDurationDays,
  }) {
    if (!rule.isPublished || tripDurationDays < 1) {
      return false;
    }

    final bool purposeMatches =
        rule.purposes.contains('all') ||
        rule.purposes.contains(selectedPurpose);

    final bool minimumDurationMatches =
        tripDurationDays >= rule.minDurationDays;

    final bool maximumDurationMatches =
        rule.maxDurationDays == null ||
        tripDurationDays <= rule.maxDurationDays!;

    return purposeMatches && minimumDurationMatches && maximumDurationMatches;
  }

  // Select the published requirements applicable to the traveller's trip.
  Future<List<TravelRule>> getApplicableRules({
    required String countryId,
    required String purpose,
    required int durationDays,
  }) async {
    final countryRules = await getRulesForCountry(countryId);

    return countryRules.where((rule) {
      return matchesRule(
        rule: rule,
        selectedPurpose: purpose,
        tripDurationDays: durationDays,
      );
    }).toList();
  }
}
