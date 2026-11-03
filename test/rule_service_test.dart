import 'package:flutter_test/flutter_test.dart';
import 'package:fyp/models/travel_rule.dart';
import 'package:fyp/services/rule_service.dart';

// -----------------------------------------------------------------------------
// CONTROLLED RULE FIXTURES
// -----------------------------------------------------------------------------
// Use fictional records to test selection without live travel advice or Firebase.
Map<String, dynamic> ruleData({
  String countryId = 'japan',
  bool active = true,
  String reviewStatus = 'approved',
  List<String> purposes = const ['tourism'],
  int minimum = 1,
  int? maximum,
  bool mandatory = true,
  int priority = 1,
}) => {
  'countryId': countryId,
  'title': 'Test requirement',
  'active': active,
  'reviewStatus': reviewStatus,
  'purposes': purposes,
  'minDurationDays': minimum,
  'maxDurationDays': maximum,
  'mandatory': mandatory,
  'priority': priority,
};

// Convert each fixture through the same parser used for Firestore records.
TravelRule fixture(String id, Map<String, dynamic> data) =>
    TravelRule.fromMap(id: id, data: data);

void main() {
  // ---------------------------------------------------------------------------
  // PUBLICATION AND LEGACY RECORDS
  // ---------------------------------------------------------------------------
  test('Only an explicitly active, approved record is published', () {
    final rule = fixture('approved', ruleData());

    expect(rule.active, isTrue);
    expect(rule.reviewStatus, 'approved');
    expect(rule.isPublished, isTrue);
  });

  for (final field in ['active', 'reviewStatus']) {
    test('Missing $field requires review instead of implicit approval', () {
      final data = ruleData()..remove(field);
      final rule = fixture('legacy', data);

      expect(rule.active, isFalse);
      expect(rule.reviewStatus, 'pendingReview');
      expect(rule.isPublished, isFalse);
    });
  }

  for (final status in ['pendingReview', 'disabled', 'unknown']) {
    test('An active flag cannot publish a $status record', () {
      final rule = fixture('unpublished', ruleData(reviewStatus: status));

      expect(rule.active, isFalse);
      expect(rule.isPublished, isFalse);
      expect(
        rule.reviewStatus,
        status == 'disabled' ? 'disabled' : 'pendingReview',
      );
    });
  }

  test('Inactive approved records require review', () {
    final rule = fixture('inactive', ruleData(active: false));

    expect(rule.isPublished, isFalse);
    expect(rule.reviewStatus, 'pendingReview');
  });

  // ---------------------------------------------------------------------------
  // PURPOSE AND DURATION BOUNDARIES
  // ---------------------------------------------------------------------------
  final service = RuleService(ruleLoader: (_) async => []);

  for (final days in [4, 5, 10, 11]) {
    test('Duration $days respects inclusive bounds of 5 to 10 days', () {
      final rule = fixture('bounded', ruleData(minimum: 5, maximum: 10));

      final expected = days == 5 || days == 10;
      final actual = service.matchesRule(
        rule: rule,
        selectedPurpose: 'tourism',
        tripDurationDays: days,
      );
      // Show returned values alongside the assertions for test evidence.
      // ignore: avoid_print
      print('Duration $days days: expected=$expected, actual=$actual');
      expect(actual, expected);
    });
  }

  test(
    'An all-purpose rule supports another travel purpose and no upper bound',
    () {
      final rule = fixture('all', ruleData(purposes: ['all']));

      expect(
        service.matchesRule(
          rule: rule,
          selectedPurpose: 'study',
          tripDurationDays: 365,
        ),
        isTrue,
      );
    },
  );

  test('A different purpose is rejected', () {
    expect(
      service.matchesRule(
        rule: fixture('tourism', ruleData()),
        selectedPurpose: 'business',
        tripDurationDays: 7,
      ),
      isFalse,
    );
  });

  test('A zero-day trip is rejected even if its stored minimum is zero', () {
    expect(
      service.matchesRule(
        rule: fixture('invalid-minimum', ruleData(minimum: 0)),
        selectedPurpose: 'tourism',
        tripDurationDays: 0,
      ),
      isFalse,
    );
  });

  // ---------------------------------------------------------------------------
  // COMPLETE SELECTION PIPELINE
  // ---------------------------------------------------------------------------
  test(
    'Selection preserves priority and includes applicable optional guidance',
    () async {
      final records = [
        fixture('optional', ruleData(mandatory: false, priority: 3)),
        fixture('pending', ruleData(reviewStatus: 'pendingReview')),
        fixture('other-country', ruleData(countryId: 'australia')),
        fixture('mandatory', ruleData(priority: 1)),
        fixture('wrong-purpose', ruleData(purposes: ['business'])),
        fixture('too-long', ruleData(maximum: 6)),
        fixture('disabled', ruleData(active: false, reviewStatus: 'disabled')),
      ];
      String? requestedCountry;
      final testedService = RuleService(
        ruleLoader: (countryId) async {
          requestedCountry = countryId;
          return records;
        },
      );

      final result = await testedService.getApplicableRules(
        countryId: 'japan',
        purpose: 'tourism',
        durationDays: 7,
      );

      final actualIds = result.map((rule) => rule.id).toList();
      const expectedIds = ['mandatory', 'optional'];
      // ignore: avoid_print
      print('Selection: expected=$expectedIds, actual=$actualIds');
      expect(requestedCountry, 'japan');
      expect(actualIds, expectedIds);
      expect(records.first.id, 'optional');
    },
  );

  test(
    'A destination with no published matching requirements returns no results',
    () async {
      final testedService = RuleService(
        ruleLoader: (_) async => [
          fixture('pending', ruleData(reviewStatus: 'pendingReview')),
        ],
      );

      expect(
        await testedService.getApplicableRules(
          countryId: 'japan',
          purpose: 'tourism',
          durationDays: 7,
        ),
        isEmpty,
      );
    },
  );
}
