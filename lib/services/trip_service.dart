import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/checklist_item.dart';
import '../models/travel_rule.dart';
import '../models/trip.dart';
import 'rule_service.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RuleService _ruleService = RuleService();

  // Creates a trip, applies the rule engine and stores the generated checklist.
  Future<String> createTripWithChecklist({
    required String userId,
    required String countryId,
    required String purpose,
    required int durationDays,
    required DateTime departureDate,
  }) async {
    if (durationDays <= 0) {
      throw ArgumentError('Trip duration cannot be zero.');
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
      trip.toMap(),
    );

    // Convert every matched regulatory rule into a trip-specific checklist item.
    for (final TravelRule rule in applicableRules) {
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
        completed: false,
      );

      batch.set(
        checklistReference,
        checklistItem.toMap(),
      );
    }

    // Save the trip and generated checklist items as one atomic operation.
    await batch.commit();

    return tripReference.id;
  }

  // Retrieves all trips belonging to the logged-in traveller.
  Future<List<Trip>> getUserTrips(String userId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _firestore
        .collection('trips')
        .where('userId', isEqualTo: userId)
        .get();

    final List<Trip> trips = snapshot.docs
        .map((document) => Trip.fromFirestore(document))
        .toList();

    // Display the nearest departure date first.
    trips.sort(
          (a, b) => a.departureDate.compareTo(b.departureDate),
    );

    return trips;
  }

  // Retrieves the generated checklist belonging to a specific trip.
  Future<List<ChecklistItem>> getChecklistItems(
      String tripId,
      ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('checklistItems')
        .get();

    final List<ChecklistItem> checklistItems = snapshot.docs
        .map((document) => ChecklistItem.fromFirestore(document))
        .toList();

    // Display checklist requirements according to their configured priority.
    checklistItems.sort(
          (a, b) => a.priority.compareTo(b.priority),
    );

    return checklistItems;
  }

  // Calculates the checklist completion progress for a specific trip.
  Future<Map<String, int>> getChecklistProgress(String tripId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('checklistItems')
        .get();

    final int totalItems = snapshot.docs.length;

    final int completedItems = snapshot.docs.where((document) {
      return document.data()['completed'] == true;
    }).length;

    return {
      'completed': completedItems,
      'total': totalItems,
    };
  }

  // Updates only the completion state of a traveller's checklist item.
  Future<void> updateChecklistItemCompletion({
    required String tripId,
    required String itemId,
    required bool completed,
  }) async {
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('checklistItems')
        .doc(itemId)
        .update({
      'completed': completed,
      'completedAt': completed ? FieldValue.serverTimestamp() : null,
    });
  }
}