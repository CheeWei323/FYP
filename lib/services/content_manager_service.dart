import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/country.dart';
import '../models/travel_rule.dart';

class ContentManagerService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // Retrieves all destination countries, including disabled destinations.
  Future<List<Country>> getAllCountries() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _firestore
        .collection('countries')
        .get();

    final List<Country> countries =
    snapshot.docs
        .map(
          (document) =>
          Country.fromFirestore(
            document,
          ),
    )
        .toList();

    countries.sort(
          (a, b) =>
          a.name.compareTo(
            b.name,
          ),
    );

    return countries;
  }

  // Retrieves every rule belonging to a destination.
  // Inactive rules are included for Content Manager review.
  Future<List<TravelRule>> getRulesForCountry(
      String countryId,
      ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _firestore
        .collection('travelRules')
        .where(
      'countryId',
      isEqualTo: countryId,
    )
        .get();

    final List<TravelRule> rules =
    snapshot.docs
        .map(
          (document) =>
          TravelRule.fromFirestore(
            document,
          ),
    )
        .toList();

    rules.sort(
          (a, b) {
        final int priorityComparison =
        a.priority.compareTo(
          b.priority,
        );

        if (priorityComparison != 0) {
          return priorityComparison;
        }

        return a.title.compareTo(
          b.title,
        );
      },
    );

    return rules;
  }

  // Loads summary information for the Content Manager dashboard.
  Future<Map<String, int>> getOverview() async {
    final Future<
        QuerySnapshot<Map<String, dynamic>>>
    countriesFuture =
    _firestore
        .collection('countries')
        .get();

    final Future<
        QuerySnapshot<Map<String, dynamic>>>
    rulesFuture =
    _firestore
        .collection('travelRules')
        .get();

    final QuerySnapshot<Map<String, dynamic>>
    countriesSnapshot =
    await countriesFuture;

    final QuerySnapshot<Map<String, dynamic>>
    rulesSnapshot =
    await rulesFuture;

    final int enabledCountries =
        countriesSnapshot.docs
            .where(
              (document) =>
          document.data()['enabled'] ==
              true,
        )
            .length;

    final int activeRules =
        rulesSnapshot.docs
            .where(
              (document) =>
          document.data()['active'] ==
              true,
        )
            .length;

    final int inactiveRules =
        rulesSnapshot.docs.length -
            activeRules;

    return {
      'countries':
      countriesSnapshot.docs.length,
      'enabledCountries':
      enabledCountries,
      'rules':
      rulesSnapshot.docs.length,
      'activeRules':
      activeRules,
      'inactiveRules':
      inactiveRules,
    };
  }
}