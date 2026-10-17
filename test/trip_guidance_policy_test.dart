import 'package:flutter_test/flutter_test.dart';
import 'package:fyp/services/trip_guidance_policy.dart';

void main() {
  // ---------------------------------------------------------------------------
  // EXISTING LONG-STAY BOUNDARIES
  // ---------------------------------------------------------------------------
  // Check below, at and above each boundary for every affected purpose.
  const scenarios = [
    (country: 'japan', purpose: 'tourism', boundary: 90),
    (country: 'japan', purpose: 'business', boundary: 90),
    (country: 'australia', purpose: 'business', boundary: 90),
    (country: 'south_korea', purpose: 'tourism', boundary: 90),
    (country: 'south_korea', purpose: 'business', boundary: 90),
    (country: 'united_kingdom', purpose: 'tourism', boundary: 180),
    (country: 'united_kingdom', purpose: 'business', boundary: 180),
    (country: 'united_kingdom', purpose: 'study', boundary: 180),
  ];

  for (final scenario in scenarios) {
    for (final offset in [-1, 0, 1]) {
      final duration = scenario.boundary + offset;

      test('${scenario.country} ${scenario.purpose}, $duration days', () {
        final result = TripGuidancePolicy.guidanceFor(
          countryId: scenario.country,
          purpose: scenario.purpose,
          durationDays: duration,
        );

        expect(result, offset == 1 ? isNotNull : isNull);
      });
    }
  }

  // ---------------------------------------------------------------------------
  // CONTEXTS THAT STILL USE STORED RULE MATCHING
  // ---------------------------------------------------------------------------
  // These contexts must not accidentally acquire a new long-stay block.
  const normalContexts = [
    (country: 'japan', purpose: 'study'),
    (country: 'australia', purpose: 'tourism'),
    (country: 'australia', purpose: 'study'),
    (country: 'south_korea', purpose: 'study'),
    (country: 'united_states', purpose: 'tourism'),
    (country: 'united_states', purpose: 'business'),
    (country: 'united_states', purpose: 'study'),
  ];

  for (final scenario in normalContexts) {
    test('${scenario.country} ${scenario.purpose} remains rule-driven', () {
      expect(
        TripGuidancePolicy.guidanceFor(
          countryId: scenario.country,
          purpose: scenario.purpose,
          durationDays: 3650,
        ),
        isNull,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // GUIDANCE AND OFFICIAL REFERENCE OUTPUTS
  // ---------------------------------------------------------------------------
  // Match each blocked destination to its existing official reference.
  const references = {
    'japan': 'https://www.my.emb-japan.go.jp/itpr_en/visit.html',
    'australia':
        'https://immi.homeaffairs.gov.au/visas/getting-a-visa/visa-finder',
    'united_kingdom': 'https://www.gov.uk/check-uk-visa',
    'south_korea':
        'https://overseas.mofa.go.kr/my-en/brd/m_1914/view.do?seq=761536&page=1',
  };

  for (final reference in references.entries) {
    test('${reference.key} retains its official guidance', () {
      final result = TripGuidancePolicy.guidanceFor(
        countryId: reference.key,
        purpose: 'business',
        durationDays: 3650,
      )!;

      expect(result.officialUrl, reference.value);
      expect(result.message, contains('duration alone'));
      expect(result.buttonLabel, isNotEmpty);
      expect(result.failureMessage, isNotEmpty);
    });
  }

  test('UK study guidance retains its specific heading and explanation', () {
    final result = TripGuidancePolicy.guidanceFor(
      countryId: 'united_kingdom',
      purpose: 'study',
      durationDays: 181,
    )!;

    expect(result.title, 'Additional Study Visa Information Required');
    expect(result.message, contains('type of course'));
  });

  test('Japan business guidance retains its activity limitation', () {
    final result = TripGuidancePolicy.guidanceFor(
      countryId: 'japan',
      purpose: 'business',
      durationDays: 91,
    )!;

    expect(result.message, contains('no paid activities'));
  });

  test('South Korea keeps purpose-specific long-stay explanations', () {
    for (final purpose in ['tourism', 'business']) {
      final result = TripGuidancePolicy.guidanceFor(
        countryId: 'south_korea',
        purpose: purpose,
        durationDays: 91,
      )!;

      expect(result.message, contains('A $purpose stay'));
    }
  });
}
