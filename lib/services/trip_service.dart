import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/checklist_item.dart';
import '../models/travel_rule.dart';
import '../models/trip.dart';
import 'rule_service.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RuleService _ruleService = RuleService();

  // Creates a trip, applies the rule engine, and stores the generated checklist.
  Future<String> createTripWithChecklist({
    required String userId,
    required String countryId,
    required String purpose,
    required int durationDays,
    required DateTime departureDate,
  }) async {
    if (durationDays <= 0) {
      throw ArgumentError('Trip duration must be greater than zero.');
    }

    // Generate only the regulatory requirements applicable to this trip.
    final List<TravelRule> applicableRules =
    await _ruleService.getApplicableRules(
      countryId: countryId,
      purpose: purpose,
      durationDays: durationDays,
    );

    if (applicableRules.isEmpty) {
      throw Exception(
        'No applicable travel requirements were found for this trip.',
      );
    }

    final DocumentReference<Map<String, dynamic>> tripReference =
    _firestore.collection('trips').doc();

    final Trip trip = Trip(
      id: tripReference.id,
      userId: userId,
      destinationCountryId: countryId,
      purpose: purpose,
      durationDays: durationDays,
      departureDate: departureDate,
    );

    final WriteBatch batch = _firestore.batch();

    batch.set(
        tripReference,
        trip.toMap()
    );
    //Convert every matched regulatory rule into a trip specific checklist item.
    for (final TravelRule rule in applicableRules){
      final DocumentReference<Map<String, dynamic>> checklistReference =
          tripReference.collection('checklistItems').doc(rule.id);

      final ChecklistItem checklistItem = ChecklistItem(
          id: rule.id,
          sourceRuleId: rule.id,
          category: rule.category,
          title: rule.title,
          checklistLabel: rule.checklistLabel,
          description: rule.description,
          mandatory: rule.mandatory,
          officialUrl: rule.officialUrl,
          sourceName: rule.sourceName,
          priority: rule.priority,
          completed: false
      );
      batch.set(
          checklistReference,
          checklistItem.toMap()
      );
    }

    //Save tge trip and all generated checklist items as one atomic operation.
    await batch.commit();

    return tripReference.id;
  }
}