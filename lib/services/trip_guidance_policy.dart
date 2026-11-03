// -----------------------------------------------------------------------------
// UNSUPPORTED TRIP GUIDANCE
// -----------------------------------------------------------------------------
// Keep the explanation and official reference together for both trip screens.
class TripGuidance {
  const TripGuidance({
    this.title = 'Additional Visa Information Required',
    required this.message,
    required this.officialUrl,
    required this.buttonLabel,
    required this.failureMessage,
  });

  final String title;
  final String message;
  final String officialUrl;
  final String buttonLabel;
  final String failureMessage;
}

// -----------------------------------------------------------------------------
// SHARED TRIP SAFEGUARDS
// -----------------------------------------------------------------------------
class TripGuidancePolicy {
  // Preserve the existing app boundaries before a trip is created or updated.
  // A null result allows normal rule matching; it does not guarantee eligibility.
  static TripGuidance? guidanceFor({
    required String countryId,
    required String purpose,
    required int durationDays,
  }) {
    final bool shortVisitPurpose =
        purpose == 'tourism' || purpose == 'business';

    if (countryId == 'japan' && shortVisitPurpose && durationDays > 90) {
      return TripGuidance(
        message: _japanMessage(purpose),
        officialUrl: 'https://www.my.emb-japan.go.jp/itpr_en/visit.html',
        buttonLabel: 'Open Visa Guidance',
        failureMessage: 'Unable to open the Japan visa guidance.',
      );
    }

    if (countryId == 'australia' &&
        purpose == 'business' &&
        durationDays > 90) {
      return const TripGuidance(
        message:
            'Business visits to Australia longer than '
            '90 days may require a different visa '
            'depending on the activities you intend '
            'to undertake.\n\n'
            'TravelGuard MY cannot determine the '
            'appropriate visa from travel purpose and '
            'duration alone. Please check the official '
            'Australian Department of Home Affairs '
            'Visa Finder for suitable visa options.',
        officialUrl:
            'https://immi.homeaffairs.gov.au/visas/getting-a-visa/visa-finder',
        buttonLabel: 'Open Visa Finder',
        failureMessage: 'Unable to open the Australian Visa Finder.',
      );
    }

    if (countryId == 'united_kingdom' && durationDays > 180) {
      return TripGuidance(
        title: purpose == 'study'
            ? 'Additional Study Visa Information Required'
            : 'Additional Visa Information Required',
        message: _ukMessage(purpose),
        officialUrl: 'https://www.gov.uk/check-uk-visa',
        buttonLabel: 'Open UK Visa Checker',
        failureMessage: 'Unable to open the UK visa checker.',
      );
    }

    if (countryId == 'south_korea' && shortVisitPurpose && durationDays > 90) {
      return TripGuidance(
        message: _southKoreaMessage(purpose),
        officialUrl:
            'https://overseas.mofa.go.kr/my-en/brd/m_1914/'
            'view.do?seq=761536&page=1',
        buttonLabel: 'Open Visa Guidance',
        failureMessage: 'Unable to open the South Korea visa guidance.',
      );
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // EXISTING GUIDANCE TEXT
  // ---------------------------------------------------------------------------
  // Use the same Japan explanation for creation and editing.
  static String _japanMessage(String purpose) {
    if (purpose == 'business') {
      return 'Malaysian travellers may visit Japan for '
          'short-term business purposes for up to 90 days '
          'without a visa when no paid activities are '
          'undertaken.\n\n'
          'A business stay longer than 90 days requires '
          'additional information about the intended '
          'activities. TravelGuard MY cannot determine the '
          'appropriate long-term status or visa from purpose '
          'and duration alone.\n\n'
          'Please refer to the official Embassy of Japan '
          'in Malaysia visa guidance.';
    }

    return 'Malaysian travellers may visit Japan for tourism '
        'for up to 90 days under the short-term visa '
        'exemption.\n\n'
        'A tourism stay longer than 90 days may require '
        'a different long-stay arrangement with additional '
        'eligibility requirements. TravelGuard MY cannot '
        'determine eligibility from purpose and duration '
        'alone.\n\n'
        'Please refer to the official Embassy of Japan '
        'in Malaysia visa guidance.';
  }

  // Keep the existing purpose-specific UK explanations in one place.
  static String _ukMessage(String purpose) {
    switch (purpose) {
      case 'business':
        return 'Business visits to the United Kingdom '
            'longer than 180 days cannot be reliably '
            'determined from travel purpose and '
            'duration alone.\n\n'
            'The Standard Visitor route normally '
            'permits eligible business activities '
            'for up to 6 months. A different visa '
            'may be required depending on the '
            'activities you intend to undertake.\n\n'
            'Please use the official UK visa checker '
            'to determine the appropriate immigration '
            'route.';
      case 'study':
        return 'Study in the United Kingdom for longer '
            'than 180 days requires additional '
            'information about the type of course.\n\n'
            'For example, an English language course '
            'lasting more than 6 months and up to '
            '11 months may use the Short-term study '
            'visa, while degree, Master\'s and PhD '
            'programmes normally require a Student '
            'visa.\n\n'
            'TravelGuard MY cannot determine the '
            'correct visa from purpose and duration '
            'alone. Please use the official UK visa '
            'checker.';
      default:
        return 'A normal UK Standard Visitor stay is '
            'generally limited to up to 6 months.\n\n'
            'TravelGuard MY cannot generate a complete '
            'tourism checklist for a stay longer than '
            '180 days using the current travel '
            'information. Please use the official UK '
            'visa checker for further guidance.';
    }
  }

  // Keep tourism and business explanations distinct for South Korea.
  static String _southKoreaMessage(String purpose) {
    if (purpose == 'business') {
      return 'K-ETA is intended for eligible short-term '
          'visits to South Korea of up to 90 days.\n\n'
          'A business stay longer than 90 days may '
          'require a different visa depending on the '
          'activities you intend to undertake. '
          'TravelGuard MY cannot determine the '
          'appropriate long-term visa from purpose '
          'and duration alone.\n\n'
          'Please refer to the official Embassy of '
          'the Republic of Korea in Malaysia visa '
          'guidance.';
    }

    return 'K-ETA is intended for eligible short-term '
        'visits to South Korea of up to 90 days.\n\n'
        'A tourism stay longer than 90 days '
        'requires additional immigration information '
        'and may require a different visa. '
        'TravelGuard MY cannot determine the '
        'appropriate long-term visa from purpose '
        'and duration alone.\n\n'
        'Please refer to the official Embassy of '
        'the Republic of Korea in Malaysia visa '
        'guidance.';
  }
}
