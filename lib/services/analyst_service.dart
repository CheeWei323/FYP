import 'package:cloud_firestore/cloud_firestore.dart';

class AnalystService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // ANALYTICS OVERVIEW
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getOverview() async {
    final Future<QuerySnapshot<Map<String, dynamic>>> tripsFuture = _firestore
        .collection('trips')
        .get();

    final Future<QuerySnapshot<Map<String, dynamic>>> countriesFuture =
        _firestore.collection('countries').get();

    final QuerySnapshot<Map<String, dynamic>> tripsSnapshot = await tripsFuture;

    final QuerySnapshot<Map<String, dynamic>> countriesSnapshot =
        await countriesFuture;

    // -------------------------------------------------------------------------
    // TOTAL TRIPS
    // -------------------------------------------------------------------------

    final int totalTrips = tripsSnapshot.docs.length;

    // -------------------------------------------------------------------------
    // UNIQUE TRAVELLERS
    // -------------------------------------------------------------------------

    final Set<String> travellerIds = <String>{};

    for (final document in tripsSnapshot.docs) {
      final String userId = document.data()['userId'] as String? ?? '';

      if (userId.isNotEmpty) {
        travellerIds.add(userId);
      }
    }

    // -------------------------------------------------------------------------
    // DESTINATION COUNTS
    // -------------------------------------------------------------------------

    final Map<String, int> destinationCounts = <String, int>{};

    for (final document in tripsSnapshot.docs) {
      final String destinationId =
          document.data()['destinationCountryId'] as String? ?? '';

      if (destinationId.isEmpty) {
        continue;
      }

      destinationCounts[destinationId] =
          (destinationCounts[destinationId] ?? 0) + 1;
    }

    // -------------------------------------------------------------------------
    // COUNTRY NAME LOOKUP
    // -------------------------------------------------------------------------

    final Map<String, String> countryNames = <String, String>{};

    for (final document in countriesSnapshot.docs) {
      final String name = document.data()['name'] as String? ?? '';

      countryNames[document.id] = name.isEmpty ? document.id : name;
    }

    // -------------------------------------------------------------------------
    // TOP DESTINATION
    // -------------------------------------------------------------------------

    String? topDestinationId;
    int highestTripCount = 0;

    destinationCounts.forEach((String countryId, int count) {
      if (count > highestTripCount) {
        highestTripCount = count;

        topDestinationId = countryId;
      }
    });

    final String topDestination = topDestinationId == null
        ? 'No trip data'
        : countryNames[topDestinationId] ?? topDestinationId!;

    return {
      'totalTrips': totalTrips,
      'uniqueTravellers': travellerIds.length,
      'topDestination': topDestination,
      'topDestinationTrips': highestTripCount,
      'supportedDestinations': countriesSnapshot.docs.length,
    };
  }
}
