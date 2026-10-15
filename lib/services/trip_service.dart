import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/checklist_item.dart';
import '../models/travel_rule.dart';
import '../models/trip.dart';
import 'rule_service.dart';
import '../models/reminder.dart';
import 'reminder_service.dart';
import 'notification_service.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final ReminderService _reminderService = ReminderService();

  final RuleService _ruleService = RuleService();

  // ---------------------------------------------------------------------------
  // CREATE TRIP
  // ---------------------------------------------------------------------------

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

    final List<TravelRule> applicableRules = await _ruleService
        .getApplicableRules(
          countryId: countryId,
          purpose: purpose,
          durationDays: durationDays,
        );

    if (applicableRules.isEmpty) {
      throw Exception(
        'No applicable travel requirements were found for this trip.',
      );
    }

    final DocumentReference<Map<String, dynamic>> tripReference = _firestore
        .collection('trips')
        .doc();

    final Trip trip = Trip(
      id: tripReference.id,
      userId: userId,
      destinationCountryId: countryId,
      purpose: purpose,
      durationDays: durationDays,
      departureDate: departureDate,
    );

    final WriteBatch batch = _firestore.batch();

    batch.set(tripReference, trip.toMap());

    for (final TravelRule rule in applicableRules) {
      final DocumentReference<Map<String, dynamic>> checklistReference =
          tripReference.collection('checklistItems').doc(rule.id);

      final ChecklistItem checklistItem = _checklistItemFromRule(rule);

      batch.set(checklistReference, checklistItem.toMap());
    }

    await batch.commit();

    return tripReference.id;
  }

  // ---------------------------------------------------------------------------
  // EDIT TRIP
  // ---------------------------------------------------------------------------

  Future<void> updateTripWithChecklist({
    required Trip existingTrip,
    required String countryId,
    required String purpose,
    required int durationDays,
    required DateTime departureDate,
  }) async {
    if (durationDays <= 0) {
      throw ArgumentError('Trip duration cannot be zero.');
    }

    final bool requirementsChanged =
        existingTrip.destinationCountryId != countryId ||
        existingTrip.purpose != purpose ||
        existingTrip.durationDays != durationDays;

    final bool departureChanged = !_isSameDate(
      existingTrip.departureDate,
      departureDate,
    );

    final bool packingContextChanged = requirementsChanged || departureChanged;

    if (!requirementsChanged && !departureChanged) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> tripReference = _firestore
        .collection('trips')
        .doc(existingTrip.id);

    List<TravelRule> applicableRules = [];

    QuerySnapshot<Map<String, dynamic>>? existingChecklistSnapshot;

    QuerySnapshot<Map<String, dynamic>>? generatedPackingSnapshot;

    // Destination, purpose and duration affect
    // the deterministic travel requirements.
    if (requirementsChanged) {
      applicableRules = await _ruleService.getApplicableRules(
        countryId: countryId,
        purpose: purpose,
        durationDays: durationDays,
      );

      if (applicableRules.isEmpty) {
        throw Exception(
          'No applicable travel requirements were found for this trip.',
        );
      }

      existingChecklistSnapshot = await tripReference
          .collection('checklistItems')
          .get();
    }

    // All four trip inputs are used by contextual
    // packing recommendations, including departure date.
    if (packingContextChanged) {
      generatedPackingSnapshot = await tripReference
          .collection('packingItems')
          .where('source', isEqualTo: 'ai')
          .get();
    }

    final WriteBatch batch = _firestore.batch();

    batch.update(tripReference, {
      'destinationCountryId': countryId,
      'purpose': purpose,
      'durationDays': durationDays,
      'departureDate': Timestamp.fromDate(departureDate),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Remove a saved route when its destination no longer matches the trip.
    if (existingTrip.destinationCountryId != countryId) {
      batch.delete(tripReference.collection('routePlans').doc('current'));
    }

    // Regenerate the regulatory checklist only
    // when rule-matching inputs changed.
    if (requirementsChanged) {
      final Set<String> newRuleIds = applicableRules
          .map((rule) => rule.id)
          .toSet();

      // Remove requirements that no longer apply.
      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in existingChecklistSnapshot!.docs) {
        if (!newRuleIds.contains(document.id)) {
          batch.delete(document.reference);
        }
      }

      // Create or overwrite applicable requirements.
      // Existing completion states are intentionally
      // reset because the trip conditions changed.
      for (final TravelRule rule in applicableRules) {
        final DocumentReference<Map<String, dynamic>> checklistReference =
            tripReference.collection('checklistItems').doc(rule.id);

        final ChecklistItem checklistItem = _checklistItemFromRule(rule);

        batch.set(checklistReference, checklistItem.toMap());
      }
    }

    // Remove only generated packing items.
    // Traveller-created manual items are preserved.
    if (packingContextChanged) {
      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in generatedPackingSnapshot!.docs) {
        batch.delete(document.reference);
      }
    }

    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // DELETE TRIP
  // ---------------------------------------------------------------------------

  Future<void> deleteTrip(String tripId) async {
    final DocumentReference<Map<String, dynamic>> tripReference = _firestore
        .collection('trips')
        .doc(tripId);

    // Retrieve the trip owner before deleting the trip.
    final DocumentSnapshot<Map<String, dynamic>> tripSnapshot =
        await tripReference.get();

    final String? userId = tripSnapshot.data()?['userId'] as String?;

    if (userId == null || userId.isEmpty) {
      throw StateError('Trip not found or owner unavailable.');
    }

    // Retrieve every reminder linked to this trip,
    // including completed reminders.
    final List<Reminder> tripReminders = await _reminderService
        .getTripReminders(userId: userId, tripId: tripId);

    // Retrieve checklist items.
    final QuerySnapshot<Map<String, dynamic>> checklistSnapshot =
        await tripReference.collection('checklistItems').get();

    // Retrieve packing items.
    final QuerySnapshot<Map<String, dynamic>> packingSnapshot =
        await tripReference.collection('packingItems').get();

    final WriteBatch batch = _firestore.batch();

    // Delete regulatory checklist items.
    for (final document in checklistSnapshot.docs) {
      batch.delete(document.reference);
    }

    // Delete generated and manual packing items.
    for (final document in packingSnapshot.docs) {
      batch.delete(document.reference);
    }

    // Delete all personal reminders linked to this trip.
    for (final Reminder reminder in tripReminders) {
      batch.delete(_firestore.collection('reminders').doc(reminder.id));
    }

    // Delete the private saved route together with its parent trip.
    batch.delete(tripReference.collection('routePlans').doc('current'));

    // Delete the parent trip in the same Firestore batch.
    batch.delete(tripReference);

    // Commit the Firestore deletions together.
    await batch.commit();

    // Cancel the corresponding Android notifications
    // only after the Firestore deletion succeeds.
    for (final Reminder reminder in tripReminders) {
      if (reminder.notificationId <= 0) {
        continue;
      }

      try {
        await NotificationService.instance.cancelReminder(
          reminder.notificationId,
        );
      } catch (error) {
        // Do not report a trip deletion failure after
        // the Firestore batch has already succeeded.
        debugPrint('CANCEL TRIP REMINDER NOTIFICATION ERROR: $error');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // RETRIEVE TRIPS
  // ---------------------------------------------------------------------------

  Future<List<Trip>> getUserTrips(String userId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('trips')
        .where('userId', isEqualTo: userId)
        .get();

    final List<Trip> trips = snapshot.docs
        .map((document) => Trip.fromFirestore(document))
        .toList();

    trips.sort((a, b) => a.departureDate.compareTo(b.departureDate));

    return trips;
  }

  // ---------------------------------------------------------------------------
  // CHECKLIST
  // ---------------------------------------------------------------------------

  Future<List<ChecklistItem>> getChecklistItems(String tripId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('checklistItems')
        .get();

    final List<ChecklistItem> checklistItems = snapshot.docs
        .map((document) => ChecklistItem.fromFirestore(document))
        .toList();

    checklistItems.sort((a, b) => a.priority.compareTo(b.priority));

    return checklistItems;
  }

  Future<Map<String, int>> getChecklistProgress(String tripId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('checklistItems')
        .get();

    final int totalItems = snapshot.docs.length;

    final int completedItems = snapshot.docs
        .where((document) => document.data()['completed'] == true)
        .length;

    return {'completed': completedItems, 'total': totalItems};
  }

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

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  ChecklistItem _checklistItemFromRule(TravelRule rule) {
    return ChecklistItem(
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
  }

  bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
