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

  // ---------------------------------------------------------------------------
  // DESTINATION TRENDS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getDestinationTrends() async {
    final Future<QuerySnapshot<Map<String, dynamic>>> tripsFuture = _firestore
        .collection('trips')
        .get();

    final Future<QuerySnapshot<Map<String, dynamic>>> countriesFuture =
        _firestore.collection('countries').get();

    final QuerySnapshot<Map<String, dynamic>> tripsSnapshot = await tripsFuture;

    final QuerySnapshot<Map<String, dynamic>> countriesSnapshot =
        await countriesFuture;

    final Map<String, int> tripCounts = <String, int>{};

    for (final document in tripsSnapshot.docs) {
      final String countryId =
          document.data()['destinationCountryId'] as String? ?? '';

      if (countryId.isEmpty) {
        continue;
      }

      tripCounts[countryId] = (tripCounts[countryId] ?? 0) + 1;
    }

    final int totalTrips = tripsSnapshot.docs.length;

    final List<Map<String, dynamic>> results = countriesSnapshot.docs.map((
      document,
    ) {
      final Map<String, dynamic> data = document.data();

      final String name = data['name'] as String? ?? document.id;

      final int count = tripCounts[document.id] ?? 0;

      final double percentage = totalTrips == 0
          ? 0
          : (count / totalTrips) * 100;

      return {
        'countryId': document.id,
        'name': name,
        'count': count,
        'percentage': percentage,
      };
    }).toList();

    results.sort((a, b) {
      final int countCompare = (b['count'] as int).compareTo(a['count'] as int);

      if (countCompare != 0) {
        return countCompare;
      }

      return (a['name'] as String).compareTo(b['name'] as String);
    });

    return results;
  }

  // ---------------------------------------------------------------------------
  // TRAVEL PURPOSE DISTRIBUTION
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getPurposeDistribution() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('trips')
        .get();

    final Map<String, int> counts = {'tourism': 0, 'business': 0, 'study': 0};

    for (final document in snapshot.docs) {
      final String purpose = document.data()['purpose'] as String? ?? '';

      if (counts.containsKey(purpose)) {
        counts[purpose] = counts[purpose]! + 1;
      }
    }

    final int total = counts.values.fold(
      0,
      (totalValue, itemCount) => totalValue + itemCount,
    );

    return {'total': total, 'counts': counts};
  }
}
