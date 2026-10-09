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

  // ---------------------------------------------------------------------------
  // CHECKLIST COMPLETION ANALYTICS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getChecklistCompletionAnalytics() async {
    final Future<QuerySnapshot<Map<String, dynamic>>> tripsFuture = _firestore
        .collection('trips')
        .get();

    final Future<QuerySnapshot<Map<String, dynamic>>> countriesFuture =
        _firestore.collection('countries').get();

    final QuerySnapshot<Map<String, dynamic>> tripsSnapshot = await tripsFuture;

    final QuerySnapshot<Map<String, dynamic>> countriesSnapshot =
        await countriesFuture;

    // Country names are used only for aggregate display.
    final Map<String, String> countryNames = <String, String>{};

    for (final document in countriesSnapshot.docs) {
      final String name = document.data()['name'] as String? ?? document.id;

      countryNames[document.id] = name;
    }

    // Ensure all supported destinations can appear,
    // even when no checklist data exists yet.
    final Map<String, int> destinationTotals = <String, int>{};

    final Map<String, int> destinationCompleted = <String, int>{};

    for (final document in countriesSnapshot.docs) {
      destinationTotals[document.id] = 0;

      destinationCompleted[document.id] = 0;
    }

    int totalRequirements = 0;
    int completedRequirements = 0;

    // Read checklist items under each stored trip.
    // No traveller profile information is retrieved.
    for (final tripDocument in tripsSnapshot.docs) {
      final Map<String, dynamic> tripData = tripDocument.data();

      final String destinationId =
          tripData['destinationCountryId'] as String? ?? '';

      if (destinationId.isEmpty) {
        continue;
      }

      final QuerySnapshot<Map<String, dynamic>> checklistSnapshot =
          await _firestore
              .collection('trips')
              .doc(tripDocument.id)
              .collection('checklistItems')
              .get();

      for (final checklistDocument in checklistSnapshot.docs) {
        final bool completed =
            checklistDocument.data()['completed'] as bool? ?? false;

        totalRequirements++;

        destinationTotals[destinationId] =
            (destinationTotals[destinationId] ?? 0) + 1;

        if (completed) {
          completedRequirements++;

          destinationCompleted[destinationId] =
              (destinationCompleted[destinationId] ?? 0) + 1;
        }
      }
    }

    final int incompleteRequirements =
        totalRequirements - completedRequirements;

    final double completionRate = totalRequirements == 0
        ? 0
        : (completedRequirements / totalRequirements) * 100;

    final List<Map<String, dynamic>> destinationResults = countryNames.entries
        .map((MapEntry<String, String> entry) {
          final int total = destinationTotals[entry.key] ?? 0;

          final int completed = destinationCompleted[entry.key] ?? 0;

          final int incomplete = total - completed;

          final double rate = total == 0 ? 0 : (completed / total) * 100;

          return {
            'countryId': entry.key,
            'name': entry.value,
            'total': total,
            'completed': completed,
            'incomplete': incomplete,
            'completionRate': rate,
          };
        })
        .toList();

    destinationResults.sort((a, b) {
      final double rateA = a['completionRate'] as double? ?? 0;

      final double rateB = b['completionRate'] as double? ?? 0;

      final int rateCompare = rateB.compareTo(rateA);

      if (rateCompare != 0) {
        return rateCompare;
      }

      return (a['name'] as String).compareTo(b['name'] as String);
    });

    return {
      'totalRequirements': totalRequirements,
      'completedRequirements': completedRequirements,
      'incompleteRequirements': incompleteRequirements,
      'completionRate': completionRate,
      'destinations': destinationResults,
    };
  }
  // ---------------------------------------------------------------------------
  // PREPARATION REQUIREMENT ANALYTICS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getPreparationRequirementAnalytics() async {
    final QuerySnapshot<Map<String, dynamic>> tripsSnapshot = await _firestore
        .collection('trips')
        .get();

    final Map<String, int> categoryCounts = <String, int>{};
    final Map<String, int> requirementTitleCounts = <String, int>{};

    int totalRequirements = 0;

    for (final tripDocument in tripsSnapshot.docs) {
      final QuerySnapshot<Map<String, dynamic>> checklistSnapshot =
          await _firestore
              .collection('trips')
              .doc(tripDocument.id)
              .collection('checklistItems')
              .get();

      for (final checklistDocument in checklistSnapshot.docs) {
        final Map<String, dynamic> data = checklistDocument.data();

        String category = data['category'] as String? ?? '';

        final String title = data['title'] as String? ?? '';

        category = category.trim();

        if (category.isEmpty) {
          category = 'uncategorised';
        }

        totalRequirements++;

        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;

        if (title.trim().isNotEmpty) {
          final String cleanedTitle = title.trim();

          requirementTitleCounts[cleanedTitle] =
              (requirementTitleCounts[cleanedTitle] ?? 0) + 1;
        }
      }
    }

    final List<Map<String, dynamic>> categories = categoryCounts.entries.map((
      MapEntry<String, int> entry,
    ) {
      final double percentage = totalRequirements == 0
          ? 0
          : (entry.value / totalRequirements) * 100;

      return {
        'category': entry.key,
        'count': entry.value,
        'percentage': percentage,
      };
    }).toList();

    categories.sort((a, b) {
      final int countCompare = (b['count'] as int).compareTo(a['count'] as int);

      if (countCompare != 0) {
        return countCompare;
      }

      return (a['category'] as String).compareTo(b['category'] as String);
    });

    final List<Map<String, dynamic>> topRequirements = requirementTitleCounts
        .entries
        .map((MapEntry<String, int> entry) {
          final double percentage = totalRequirements == 0
              ? 0
              : (entry.value / totalRequirements) * 100;

          return {
            'title': entry.key,
            'count': entry.value,
            'percentage': percentage,
          };
        })
        .toList();

    topRequirements.sort((a, b) {
      final int countCompare = (b['count'] as int).compareTo(a['count'] as int);

      if (countCompare != 0) {
        return countCompare;
      }

      return (a['title'] as String).compareTo(b['title'] as String);
    });

    return {
      'totalRequirements': totalRequirements,
      'categoryCount': categories.length,
      'categories': categories,
      'topRequirements': topRequirements.take(5).toList(),
    };
  }
}
