import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trip.dart';

// -----------------------------------------------------------------------------
// SAVED PLAN DATA
// -----------------------------------------------------------------------------
// Persist the traveller's choices without storing Google map content.
class SavedRoutePlan {
  SavedRoutePlan({
    required this.countryId,
    required this.travelMode,
    required List<String> placeIds,
  }) : placeIds = List.unmodifiable(placeIds) {
    final validId = RegExp(r'^[A-Za-z0-9_-]{1,512}$');

    if (countryId.isEmpty ||
        !['DRIVE', 'WALK'].contains(travelMode) ||
        placeIds.length < 2 ||
        placeIds.length > 7 ||
        placeIds.any((id) => !validId.hasMatch(id))) {
      throw const FormatException('Invalid saved route plan.');
    }

    for (int i = 1; i < placeIds.length; i++) {
      if (placeIds[i] == placeIds[i - 1]) {
        throw const FormatException('Consecutive places must be different.');
      }
    }
  }

  final String countryId;
  final String travelMode;
  final List<String> placeIds;

  // Validate a stored plan before it reaches the map.
  factory SavedRoutePlan.fromMap(Map<String, dynamic> data) {
    if (data['schemaVersion'] != 1 ||
        data['countryId'] is! String ||
        data['travelMode'] is! String ||
        data['placeIds'] is! List ||
        (data['placeIds'] as List).any((id) => id is! String)) {
      throw const FormatException('This saved route plan cannot be opened.');
    }

    return SavedRoutePlan(
      countryId: data['countryId'] as String,
      travelMode: data['travelMode'] as String,
      placeIds: List<String>.from(data['placeIds'] as List),
    );
  }

  // Let Firestore supply the authoritative save time.
  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'countryId': countryId,
    'travelMode': travelMode,
    'placeIds': placeIds,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  // Compare choices independently of refreshed Google data.
  bool matches(String mode, List<String?> ids) {
    if (mode != travelMode || ids.length != placeIds.length) {
      return false;
    }

    for (int i = 0; i < ids.length; i++) {
      if (ids[i] != placeIds[i]) return false;
    }

    return true;
  }
}

// -----------------------------------------------------------------------------
// FIRESTORE STORAGE
// -----------------------------------------------------------------------------
class RoutePlanService {
  RoutePlanService({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  // Keep one private plan below its parent trip.
  DocumentReference<Map<String, dynamic>> _reference(String tripId) => _db
      .collection('trips')
      .doc(tripId)
      .collection('routePlans')
      .doc('current');

  // Reject deleted trips and stale screens after a destination change.
  void _checkTrip(Trip trip, DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw StateError('This trip is no longer available.');
    }

    if (data['userId'] != trip.userId ||
        data['destinationCountryId'] != trip.destinationCountryId) {
      throw StateError(
        'Trip details changed. Reopen the trip before planning.',
      );
    }
  }

  // Read the server so a failed load cannot silently overwrite a saved plan.
  Future<SavedRoutePlan?> load(Trip trip) async {
    final parent = await _db
        .collection('trips')
        .doc(trip.id)
        .get(const GetOptions(source: Source.server));

    _checkTrip(trip, parent);

    final snapshot = await _reference(
      trip.id,
    ).get(const GetOptions(source: Source.server));

    final data = snapshot.data();

    if (data == null) return null;

    final plan = SavedRoutePlan.fromMap(data);

    return plan.countryId == trip.destinationCountryId ? plan : null;
  }

  // Save atomically against the current parent trip.
  Future<void> save(Trip trip, SavedRoutePlan plan) async {
    if (plan.countryId != trip.destinationCountryId) {
      throw const FormatException(
        'The route belongs to a different destination.',
      );
    }

    await _db.runTransaction((transaction) async {
      final parent = _db.collection('trips').doc(trip.id);

      _checkTrip(trip, await transaction.get(parent));

      transaction.set(_reference(trip.id), plan.toMap());
    });
  }

  // Remove the saved plan without deleting the traveller's current draft.
  Future<void> delete(Trip trip) async {
    await _db.runTransaction((transaction) async {
      final parent = _db.collection('trips').doc(trip.id);

      _checkTrip(trip, await transaction.get(parent));

      transaction.delete(_reference(trip.id));
    });
  }
}
