import 'package:cloud_firestore/cloud_firestore.dart';

class AnalystService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // ANALYTICS FILTERS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, String>>> getAnalyticsFilterCountries() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('countries')
        .get();

    final List<Map<String, String>> countries = snapshot.docs.map((document) {
      final String name = document.data()['name'] as String? ?? document.id;

      return {'id': document.id, 'name': name};
    }).toList();

    countries.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

    return countries;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _getFilteredTrips({
    String? destinationId,
    String? purpose,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('trips')
        .get();

    return snapshot.docs.where((document) {
      final Map<String, dynamic> data = document.data();

      final String tripDestination =
          data['destinationCountryId'] as String? ?? '';

      final String tripPurpose = data['purpose'] as String? ?? '';

      final bool destinationMatches =
          destinationId == null || tripDestination == destinationId;

      final bool purposeMatches = purpose == null || tripPurpose == purpose;

      return destinationMatches && purposeMatches;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // ANALYTICS OVERVIEW
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getOverview() async {
    final Future<QuerySnapshot<Map<String, dynamic>>> tripsFuture = _firestore
        .collection('trips')
        .get();

    final Future<QuerySnapshot<Map<String, dynamic>>> countriesFuture =
        _firestore.collection('countries').get();

    // Join both reads so a failed refresh handles either query's error.
    final snapshots = await Future.wait([tripsFuture, countriesFuture]);
    final tripsSnapshot = snapshots[0];
    final countriesSnapshot = snapshots[1];

    final int totalTrips = tripsSnapshot.docs.length;

    final Set<String> travellerIds = <String>{};

    for (final document in tripsSnapshot.docs) {
      final String userId = document.data()['userId'] as String? ?? '';

      if (userId.isNotEmpty) {
        travellerIds.add(userId);
      }
    }

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

    final Map<String, String> countryNames = <String, String>{};

    for (final document in countriesSnapshot.docs) {
      final String name = document.data()['name'] as String? ?? '';

      countryNames[document.id] = name.isEmpty ? document.id : name;
    }

    String? topDestinationId;
    int highestTripCount = 0;

    destinationCounts.forEach((String countryId, int itemCount) {
      if (itemCount > highestTripCount) {
        highestTripCount = itemCount;
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

  Future<List<Map<String, dynamic>>> getDestinationTrends({
    String? destinationId,
    String? purpose,
  }) async {
    final Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    tripsFuture = _getFilteredTrips(
      destinationId: destinationId,
      purpose: purpose,
    );

    final Future<QuerySnapshot<Map<String, dynamic>>> countriesFuture =
        _firestore.collection('countries').get();

    // Join both reads so a failed refresh handles either query's error.
    final readResults = await Future.wait<Object>([
      tripsFuture,
      countriesFuture,
    ]);
    final tripDocuments =
        readResults[0] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
    final countriesSnapshot =
        readResults[1] as QuerySnapshot<Map<String, dynamic>>;

    final Map<String, int> tripCounts = <String, int>{};

    for (final document in tripDocuments) {
      final String countryId =
          document.data()['destinationCountryId'] as String? ?? '';

      if (countryId.isEmpty) {
        continue;
      }

      tripCounts[countryId] = (tripCounts[countryId] ?? 0) + 1;
    }

    final int totalTrips = tripDocuments.length;

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> countryDocuments =
        destinationId == null
        ? countriesSnapshot.docs
        : countriesSnapshot.docs
              .where((document) => document.id == destinationId)
              .toList();

    final List<Map<String, dynamic>> results = countryDocuments.map((document) {
      final Map<String, dynamic> data = document.data();

      final String name = data['name'] as String? ?? document.id;

      final int itemCount = tripCounts[document.id] ?? 0;

      final double percentage = totalTrips == 0
          ? 0
          : (itemCount / totalTrips) * 100;

      return {
        'countryId': document.id,
        'name': name,
        'count': itemCount,
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
  // MONTHLY DEPARTURE TREND
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getMonthlyDepartureTrend({
    String? destinationId,
    String? purpose,
  }) async {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> tripDocuments =
        await _getFilteredTrips(destinationId: destinationId, purpose: purpose);

    final Map<DateTime, int> monthlyCounts = <DateTime, int>{};

    for (final document in tripDocuments) {
      final dynamic rawDepartureDate = document.data()['departureDate'];

      DateTime? departureDate;

      if (rawDepartureDate is Timestamp) {
        departureDate = rawDepartureDate.toDate();
      } else if (rawDepartureDate is DateTime) {
        departureDate = rawDepartureDate;
      } else if (rawDepartureDate is String) {
        departureDate = DateTime.tryParse(rawDepartureDate);
      }

      if (departureDate == null) {
        continue;
      }

      final DateTime monthKey = DateTime(
        departureDate.year,
        departureDate.month,
      );

      monthlyCounts[monthKey] = (monthlyCounts[monthKey] ?? 0) + 1;
    }

    if (monthlyCounts.isEmpty) {
      return [];
    }

    final List<DateTime> recordedMonths = monthlyCounts.keys.toList()..sort();

    final DateTime firstMonth = recordedMonths.first;

    final DateTime lastMonth = recordedMonths.last;

    final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];

    DateTime currentMonth = firstMonth;

    while (!currentMonth.isAfter(lastMonth)) {
      results.add({
        'year': currentMonth.year,
        'month': currentMonth.month,
        'label': _formatMonthLabel(currentMonth),
        'shortLabel': _formatShortMonthLabel(currentMonth),
        'count': monthlyCounts[currentMonth] ?? 0,
      });

      currentMonth = DateTime(
        currentMonth.month == 12 ? currentMonth.year + 1 : currentMonth.year,
        currentMonth.month == 12 ? 1 : currentMonth.month + 1,
      );
    }

    return results;
  }

  String _formatMonthLabel(DateTime date) {
    const List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatShortMonthLabel(DateTime date) {
    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} '
        '${date.year.toString().substring(2)}';
  }

  // ---------------------------------------------------------------------------
  // TRAVEL PURPOSE DISTRIBUTION
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getPurposeDistribution({
    String? destinationId,
    String? purpose,
  }) async {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> tripDocuments =
        await _getFilteredTrips(destinationId: destinationId, purpose: purpose);

    final Map<String, int> counts = {'tourism': 0, 'business': 0, 'study': 0};

    for (final document in tripDocuments) {
      final String tripPurpose = document.data()['purpose'] as String? ?? '';

      if (counts.containsKey(tripPurpose)) {
        counts[tripPurpose] = counts[tripPurpose]! + 1;
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

  Future<Map<String, dynamic>> getChecklistCompletionAnalytics({
    String? destinationId,
    String? purpose,
  }) async {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> tripDocuments =
        await _getFilteredTrips(destinationId: destinationId, purpose: purpose);

    final QuerySnapshot<Map<String, dynamic>> countriesSnapshot =
        await _firestore.collection('countries').get();

    final Map<String, String> countryNames = <String, String>{};

    for (final document in countriesSnapshot.docs) {
      final String name = document.data()['name'] as String? ?? document.id;

      countryNames[document.id] = name;
    }

    final List<Future<QuerySnapshot<Map<String, dynamic>>>> checklistFutures =
        tripDocuments.map((tripDocument) {
          return _firestore
              .collection('trips')
              .doc(tripDocument.id)
              .collection('checklistItems')
              .get();
        }).toList();

    final List<QuerySnapshot<Map<String, dynamic>>> checklistSnapshots =
        await Future.wait(checklistFutures);

    int totalChecklistItems = 0;
    int completedChecklistItems = 0;

    int tripsWithChecklist = 0;
    double overallTripRateTotal = 0;

    final Map<String, double> destinationRateTotals = <String, double>{};

    final Map<String, int> destinationTripCounts = <String, int>{};

    final Map<String, double> purposeRateTotals = <String, double>{};

    final Map<String, int> purposeTripCounts = <String, int>{};

    final Map<String, Map<String, dynamic>> requirementStatistics =
        <String, Map<String, dynamic>>{};

    for (int index = 0; index < tripDocuments.length; index++) {
      final QueryDocumentSnapshot<Map<String, dynamic>> tripDocument =
          tripDocuments[index];

      final QuerySnapshot<Map<String, dynamic>> checklistSnapshot =
          checklistSnapshots[index];

      final Map<String, dynamic> tripData = tripDocument.data();

      final String destination =
          tripData['destinationCountryId'] as String? ?? '';

      final String tripPurpose = tripData['purpose'] as String? ?? '';

      final int tripChecklistTotal = checklistSnapshot.docs.length;

      if (tripChecklistTotal == 0) {
        continue;
      }

      int tripCompleted = 0;

      for (final checklistDocument in checklistSnapshot.docs) {
        final Map<String, dynamic> itemData = checklistDocument.data();

        final bool completed = itemData['completed'] as bool? ?? false;

        totalChecklistItems++;

        if (completed) {
          completedChecklistItems++;
          tripCompleted++;
        }

        final String sourceRuleId = (itemData['sourceRuleId'] as String? ?? '')
            .trim();

        String title = (itemData['title'] as String? ?? '').trim();

        if (title.isEmpty) {
          title = (itemData['checklistLabel'] as String? ?? '').trim();
        }

        if (title.isEmpty) {
          title = 'Unnamed requirement';
        }

        final String requirementKey = sourceRuleId.isNotEmpty
            ? sourceRuleId
            : 'title:${title.toLowerCase()}';

        final Map<String, dynamic> statistics = requirementStatistics
            .putIfAbsent(
              requirementKey,
              () => {
                'sourceRuleId': sourceRuleId,
                'title': title,
                'generated': 0,
                'completed': 0,
              },
            );

        statistics['generated'] = (statistics['generated'] as int) + 1;

        if (completed) {
          statistics['completed'] = (statistics['completed'] as int) + 1;
        }
      }

      final double tripCompletionRate =
          (tripCompleted / tripChecklistTotal) * 100;

      tripsWithChecklist++;
      overallTripRateTotal += tripCompletionRate;

      if (destination.isNotEmpty) {
        destinationRateTotals[destination] =
            (destinationRateTotals[destination] ?? 0) + tripCompletionRate;

        destinationTripCounts[destination] =
            (destinationTripCounts[destination] ?? 0) + 1;
      }

      if (tripPurpose.isNotEmpty) {
        purposeRateTotals[tripPurpose] =
            (purposeRateTotals[tripPurpose] ?? 0) + tripCompletionRate;

        purposeTripCounts[tripPurpose] =
            (purposeTripCounts[tripPurpose] ?? 0) + 1;
      }
    }

    final int incompleteChecklistItems =
        totalChecklistItems - completedChecklistItems;

    final double overallCompletionRate = tripsWithChecklist == 0
        ? 0
        : overallTripRateTotal / tripsWithChecklist;

    final List<Map<String, dynamic>> destinationComparison =
        destinationRateTotals.entries.map((entry) {
          final int tripCount = destinationTripCounts[entry.key] ?? 0;

          final double completionRate = tripCount == 0
              ? 0
              : entry.value / tripCount;

          return {
            'countryId': entry.key,
            'name': countryNames[entry.key] ?? entry.key,
            'tripCount': tripCount,
            'completionRate': completionRate,
          };
        }).toList();

    destinationComparison.sort((a, b) {
      final int rateCompare = (a['completionRate'] as double).compareTo(
        b['completionRate'] as double,
      );

      if (rateCompare != 0) {
        return rateCompare;
      }

      return (a['name'] as String).compareTo(b['name'] as String);
    });

    final List<Map<String, dynamic>> purposeComparison = purposeRateTotals
        .entries
        .map((entry) {
          final int tripCount = purposeTripCounts[entry.key] ?? 0;

          final double completionRate = tripCount == 0
              ? 0
              : entry.value / tripCount;

          return {
            'purpose': entry.key,
            'tripCount': tripCount,
            'completionRate': completionRate,
          };
        })
        .toList();

    purposeComparison.sort((a, b) {
      final int rateCompare = (a['completionRate'] as double).compareTo(
        b['completionRate'] as double,
      );

      if (rateCompare != 0) {
        return rateCompare;
      }

      return (a['purpose'] as String).compareTo(b['purpose'] as String);
    });

    final List<Map<String, dynamic>> requirementsNeedingAttention =
        requirementStatistics.values
            .where((statistics) {
              final int generated = statistics['generated'] as int? ?? 0;

              final int completed = statistics['completed'] as int? ?? 0;

              return generated > 0 && completed < generated;
            })
            .map((statistics) {
              final int generated = statistics['generated'] as int? ?? 0;

              final int completed = statistics['completed'] as int? ?? 0;

              final int incomplete = generated - completed;

              final double completionRate = generated == 0
                  ? 0
                  : (completed / generated) * 100;

              return {
                'sourceRuleId': statistics['sourceRuleId'],
                'title': statistics['title'],
                'generated': generated,
                'completed': completed,
                'incomplete': incomplete,
                'completionRate': completionRate,
              };
            })
            .toList();

    requirementsNeedingAttention.sort((a, b) {
      final int rateCompare = (a['completionRate'] as double).compareTo(
        b['completionRate'] as double,
      );

      if (rateCompare != 0) {
        return rateCompare;
      }

      final int generatedCompare = (b['generated'] as int).compareTo(
        a['generated'] as int,
      );

      if (generatedCompare != 0) {
        return generatedCompare;
      }

      return (a['title'] as String).compareTo(b['title'] as String);
    });

    return {
      'overallCompletionRate': overallCompletionRate,
      'completedChecklistItems': completedChecklistItems,
      'incompleteChecklistItems': incompleteChecklistItems,
      'totalChecklistItems': totalChecklistItems,
      'tripsWithChecklist': tripsWithChecklist,
      'destinationComparison': destinationComparison,
      'purposeComparison': purposeComparison,
      'requirementsNeedingAttention': requirementsNeedingAttention,
    };
  }

  // ---------------------------------------------------------------------------
  // REQUIREMENT PATTERN ANALYTICS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getPreparationRequirementAnalytics({
    String? destinationId,
    String? purpose,
  }) async {
    final Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    tripsFuture = _getFilteredTrips(
      destinationId: destinationId,
      purpose: purpose,
    );

    final Future<QuerySnapshot<Map<String, dynamic>>> countriesFuture =
        _firestore.collection('countries').get();

    // Join both reads so a failed refresh handles either query's error.
    final readResults = await Future.wait<Object>([
      tripsFuture,
      countriesFuture,
    ]);
    final tripDocuments =
        readResults[0] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
    final countriesSnapshot =
        readResults[1] as QuerySnapshot<Map<String, dynamic>>;

    // -------------------------------------------------------------------------
    // COUNTRY NAMES
    // -------------------------------------------------------------------------

    final Map<String, String> countryNames = <String, String>{};

    for (final document in countriesSnapshot.docs) {
      final String name = document.data()['name'] as String? ?? document.id;

      countryNames[document.id] = name;
    }

    // -------------------------------------------------------------------------
    // LOAD CHECKLISTS
    // -------------------------------------------------------------------------

    final List<Future<QuerySnapshot<Map<String, dynamic>>>> checklistFutures =
        tripDocuments.map((tripDocument) {
          return _firestore
              .collection('trips')
              .doc(tripDocument.id)
              .collection('checklistItems')
              .get();
        }).toList();

    final List<QuerySnapshot<Map<String, dynamic>>> checklistSnapshots =
        await Future.wait(checklistFutures);

    int analysedTrips = 0;

    final Map<String, int> requirementTripCounts = <String, int>{};

    final Map<String, String> requirementTitles = <String, String>{};

    final Map<String, Map<String, int>> requirementDestinationCounts =
        <String, Map<String, int>>{};

    final Map<String, Map<String, int>> requirementPurposeCounts =
        <String, Map<String, int>>{};

    // -------------------------------------------------------------------------
    // ANALYSE EACH TRIP
    // -------------------------------------------------------------------------

    for (int index = 0; index < tripDocuments.length; index++) {
      final QueryDocumentSnapshot<Map<String, dynamic>> tripDocument =
          tripDocuments[index];

      final QuerySnapshot<Map<String, dynamic>> checklistSnapshot =
          checklistSnapshots[index];

      if (checklistSnapshot.docs.isEmpty) {
        continue;
      }

      analysedTrips++;

      final Map<String, dynamic> tripData = tripDocument.data();

      final String countryId =
          tripData['destinationCountryId'] as String? ?? '';

      final String tripPurpose = tripData['purpose'] as String? ?? '';

      // A requirement should only contribute once
      // to the frequency of a single trip.
      final Set<String> seenRequirementKeys = <String>{};

      for (final checklistDocument in checklistSnapshot.docs) {
        final Map<String, dynamic> itemData = checklistDocument.data();

        final String sourceRuleId = (itemData['sourceRuleId'] as String? ?? '')
            .trim();

        String title = (itemData['title'] as String? ?? '').trim();

        if (title.isEmpty) {
          title = (itemData['checklistLabel'] as String? ?? '').trim();
        }

        if (title.isEmpty) {
          title = 'Unnamed requirement';
        }

        final String requirementKey = sourceRuleId.isNotEmpty
            ? sourceRuleId
            : 'title:${title.toLowerCase()}';

        requirementTitles.putIfAbsent(requirementKey, () => title);

        // Prevent duplicate checklist items inside the
        // same trip from inflating the frequency.
        if (!seenRequirementKeys.add(requirementKey)) {
          continue;
        }

        requirementTripCounts[requirementKey] =
            (requirementTripCounts[requirementKey] ?? 0) + 1;

        // ---------------------------------------------------------------------
        // DESTINATION CONTEXT
        // ---------------------------------------------------------------------

        if (countryId.isNotEmpty) {
          final Map<String, int> destinationCounts =
              requirementDestinationCounts.putIfAbsent(
                requirementKey,
                () => <String, int>{},
              );

          destinationCounts[countryId] =
              (destinationCounts[countryId] ?? 0) + 1;
        }

        // ---------------------------------------------------------------------
        // PURPOSE CONTEXT
        // ---------------------------------------------------------------------

        if (tripPurpose.isNotEmpty) {
          final Map<String, int> purposeCounts = requirementPurposeCounts
              .putIfAbsent(requirementKey, () => <String, int>{});

          purposeCounts[tripPurpose] = (purposeCounts[tripPurpose] ?? 0) + 1;
        }
      }
    }

    // -------------------------------------------------------------------------
    // BUILD REQUIREMENT RESULTS
    // -------------------------------------------------------------------------

    final List<Map<String, dynamic>>
    requirementPatterns = requirementTripCounts.entries.map((entry) {
      final String requirementKey = entry.key;

      final int tripCount = entry.value;

      final double percentage = analysedTrips == 0
          ? 0
          : (tripCount / analysedTrips) * 100;

      // ---------------------------------------------------------------------
      // DESTINATION BREAKDOWN
      // ---------------------------------------------------------------------

      final Map<String, int> rawDestinationCounts =
          requirementDestinationCounts[requirementKey] ?? <String, int>{};

      final List<Map<String, dynamic>> destinationBreakdown =
          rawDestinationCounts.entries.map((destinationEntry) {
            return {
              'countryId': destinationEntry.key,
              'name':
                  countryNames[destinationEntry.key] ?? destinationEntry.key,
              'tripCount': destinationEntry.value,
            };
          }).toList();

      destinationBreakdown.sort((a, b) {
        final int countCompare = (b['tripCount'] as int).compareTo(
          a['tripCount'] as int,
        );

        if (countCompare != 0) {
          return countCompare;
        }

        return (a['name'] as String).compareTo(b['name'] as String);
      });

      // ---------------------------------------------------------------------
      // PURPOSE BREAKDOWN
      // ---------------------------------------------------------------------

      final Map<String, int> rawPurposeCounts =
          requirementPurposeCounts[requirementKey] ?? <String, int>{};

      final List<Map<String, dynamic>> purposeBreakdown = rawPurposeCounts
          .entries
          .map((purposeEntry) {
            return {
              'purpose': purposeEntry.key,
              'tripCount': purposeEntry.value,
            };
          })
          .toList();

      purposeBreakdown.sort((a, b) {
        final int countCompare = (b['tripCount'] as int).compareTo(
          a['tripCount'] as int,
        );

        if (countCompare != 0) {
          return countCompare;
        }

        return (a['purpose'] as String).compareTo(b['purpose'] as String);
      });

      return {
        'requirementKey': requirementKey,
        'title': requirementTitles[requirementKey] ?? 'Unnamed requirement',
        'tripCount': tripCount,
        'percentage': percentage,
        'destinationBreakdown': destinationBreakdown,
        'purposeBreakdown': purposeBreakdown,
      };
    }).toList();

    // Most frequently generated requirements first.
    requirementPatterns.sort((a, b) {
      final int countCompare = (b['tripCount'] as int).compareTo(
        a['tripCount'] as int,
      );

      if (countCompare != 0) {
        return countCompare;
      }

      return (a['title'] as String).compareTo(b['title'] as String);
    });

    return {
      'analysedTrips': analysedTrips,
      'requirementPatterns': requirementPatterns,
    };
  }
}
