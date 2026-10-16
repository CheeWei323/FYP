import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/traveller_ui_widgets.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/country.dart';
import '../services/country_service.dart';
import '../services/trip_service.dart';
import 'checklist_screen.dart';

class AddTripScreen extends StatefulWidget {
  const AddTripScreen({super.key});

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  final CountryService _countryService = CountryService();

  final TripService _tripService = TripService();

  final TextEditingController _durationController = TextEditingController();

  List<Country> _countries = [];

  Country? _selectedCountry;
  String? _selectedPurpose;
  DateTime? _departureDate;

  bool _isLoadingCountries = true;
  bool _isCreatingTrip = false;

  String? _countryError;

  static const Color _primaryColor = AppColors.primary;

  static const Color _darkTextColor = AppColors.navy;

  static const Color _backgroundColor = AppColors.background;

  static const Color _borderColor = AppColors.border;

  final List<Map<String, dynamic>> _purposes = [
    {'value': 'tourism', 'label': 'Tourism', 'icon': Icons.camera_alt_outlined},
    {
      'value': 'business',
      'label': 'Business',
      'icon': Icons.business_center_outlined,
    },
    {'value': 'study', 'label': 'Study', 'icon': Icons.school_outlined},
  ];

  // ---------------------------------------------------------------------------
  // JAPAN LONG-STAY TOURISM / BUSINESS SAFEGUARD
  // ---------------------------------------------------------------------------

  bool _requiresJapanLongStayGuidance(int durationDays) {
    return _selectedCountry?.id == 'japan' &&
        (_selectedPurpose == 'tourism' || _selectedPurpose == 'business') &&
        durationDays > 90;
  }

  Future<void> _openJapanVisaGuidance() async {
    final Uri uri = Uri.parse(
      'https://www.my.emb-japan.go.jp/itpr_en/visit.html',
    );

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open the Japan visa guidance.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('JAPAN VISA GUIDANCE ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the Japan visa guidance.'),
        ),
      );
    }
  }

  Future<void> _showJapanLongStayGuidance() async {
    String message;

    if (_selectedPurpose == 'business') {
      message =
          'Malaysian travellers may visit Japan for '
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
    } else {
      message =
          'Malaysian travellers may visit Japan for tourism '
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

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.info_outline_rounded,
            color: _primaryColor,
            size: 32,
          ),
          title: const Text(
            'Additional Visa Information Required',
            textAlign: TextAlign.center,
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                await _openJapanVisaGuidance();
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open Visa Guidance'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // AUSTRALIA LONG BUSINESS-STAY SAFEGUARD
  // ---------------------------------------------------------------------------

  bool _requiresAustraliaBusinessVisaGuidance(int durationDays) {
    return _selectedCountry?.id == 'australia' &&
        _selectedPurpose == 'business' &&
        durationDays > 90;
  }

  Future<void> _openAustraliaVisaFinder() async {
    final Uri uri = Uri.parse(
      'https://immi.homeaffairs.gov.au/visas/getting-a-visa/visa-finder',
    );

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open the Australian Visa Finder.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('AUSTRALIA VISA FINDER ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the Australian Visa Finder.'),
        ),
      );
    }
  }

  Future<void> _showAustraliaBusinessVisaGuidance() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.info_outline_rounded,
            color: _primaryColor,
            size: 32,
          ),
          title: const Text(
            'Additional Visa Information Required',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Business visits to Australia longer than '
            '90 days may require a different visa '
            'depending on the activities you intend '
            'to undertake.\n\n'
            'TravelGuard MY cannot determine the '
            'appropriate visa from travel purpose and '
            'duration alone. Please check the official '
            'Australian Department of Home Affairs '
            'Visa Finder for suitable visa options.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                await _openAustraliaVisaFinder();
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open Visa Finder'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UNITED KINGDOM LONG-STAY SAFEGUARD
  // ---------------------------------------------------------------------------

  bool _requiresUkLongStayGuidance(int durationDays) {
    return _selectedCountry?.id == 'united_kingdom' && durationDays > 180;
  }

  Future<void> _openUkVisaChecker() async {
    final Uri uri = Uri.parse('https://www.gov.uk/check-uk-visa');

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the UK visa checker.')),
        );
      }
    } catch (e) {
      debugPrint('UK VISA CHECKER ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the UK visa checker.')),
      );
    }
  }

  Future<void> _showUkLongStayGuidance() async {
    String title;
    String message;

    switch (_selectedPurpose) {
      case 'business':
        title = 'Additional Visa Information Required';

        message =
            'Business visits to the United Kingdom '
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
        break;

      case 'study':
        title = 'Additional Study Visa Information Required';

        message =
            'Study in the United Kingdom for longer '
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
        break;

      case 'tourism':
      default:
        title = 'Additional Visa Information Required';

        message =
            'A normal UK Standard Visitor stay is '
            'generally limited to up to 6 months.\n\n'
            'TravelGuard MY cannot generate a complete '
            'tourism checklist for a stay longer than '
            '180 days using the current travel '
            'information. Please use the official UK '
            'visa checker for further guidance.';
        break;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.info_outline_rounded,
            color: _primaryColor,
            size: 32,
          ),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                await _openUkVisaChecker();
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open UK Visa Checker'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SOUTH KOREA LONG-STAY SAFEGUARD
  // ---------------------------------------------------------------------------

  bool _requiresSouthKoreaLongStayGuidance(int durationDays) {
    return _selectedCountry?.id == 'south_korea' &&
        (_selectedPurpose == 'tourism' || _selectedPurpose == 'business') &&
        durationDays > 90;
  }

  Future<void> _openSouthKoreaVisaGuidance() async {
    final Uri uri = Uri.parse(
      'https://overseas.mofa.go.kr/my-en/brd/m_1914/'
      'view.do?seq=761536&page=1',
    );

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open the South Korea visa guidance.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('SOUTH KOREA VISA GUIDANCE ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the South Korea visa guidance.'),
        ),
      );
    }
  }

  Future<void> _showSouthKoreaLongStayGuidance() async {
    String message;

    if (_selectedPurpose == 'business') {
      message =
          'K-ETA is intended for eligible short-term '
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
    } else {
      message =
          'K-ETA is intended for eligible short-term '
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

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.info_outline_rounded,
            color: _primaryColor,
            size: 32,
          ),
          title: const Text(
            'Additional Visa Information Required',
            textAlign: TextAlign.center,
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                await _openSouthKoreaVisaGuidance();
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open Visa Guidance'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SCREEN LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // COUNTRY DATA
  // ---------------------------------------------------------------------------

  Future<void> _loadCountries() async {
    setState(() {
      _isLoadingCountries = true;
      _countryError = null;
    });

    try {
      final List<Country> countries = await _countryService
          .getEnabledCountries();

      if (!mounted) return;

      countries.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _countries = countries;
        _isLoadingCountries = false;
      });
    } catch (e) {
      debugPrint('LOAD COUNTRIES ERROR: $e');

      if (!mounted) return;

      setState(() {
        _countryError = 'Unable to load destination countries.';
        _isLoadingCountries = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // DATE SELECTION
  // ---------------------------------------------------------------------------

  Future<void> _selectDepartureDate() async {
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);

    final DateTime initialDate =
        _departureDate ?? today.add(const Duration(days: 1));

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: DateTime(now.year + 5, 12, 31),
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _departureDate = selectedDate;
    });
  }

  // ---------------------------------------------------------------------------
  // VALIDATION
  // ---------------------------------------------------------------------------

  String? _validateTrip() {
    if (_selectedCountry == null) {
      return 'Please select a destination country.';
    }

    if (_selectedPurpose == null) {
      return 'Please select a travel purpose.';
    }

    if (_departureDate == null) {
      return 'Please select a departure date.';
    }

    final int? duration = int.tryParse(_durationController.text.trim());

    if (duration == null || duration <= 0) {
      return 'Please enter a valid trip duration.';
    }

    if (duration > 3650) {
      return 'Please enter a trip duration of 3650 days or less.';
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // DSS CHECKLIST GENERATION
  // ---------------------------------------------------------------------------

  Future<void> _generateChecklist() async {
    if (_isCreatingTrip) {
      return;
    }

    FocusScope.of(context).unfocus();

    final String? validationMessage = _validateTrip();

    if (validationMessage != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(validationMessage)));

      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No authenticated user was found.')),
      );

      return;
    }

    final int duration = int.parse(_durationController.text.trim());

    // Japan tourism and business stays longer than 90 days
    // require additional immigration information that cannot
    // be determined reliably from purpose and duration alone.
    if (_requiresJapanLongStayGuidance(duration)) {
      await _showJapanLongStayGuidance();
      return;
    }

    // Australia business visits longer than 90 days cannot be
    // reliably matched using purpose and duration alone.
    if (_requiresAustraliaBusinessVisaGuidance(duration)) {
      await _showAustraliaBusinessVisaGuidance();
      return;
    }

    // UK visits longer than 180 days require additional
    // immigration information that the current inputs do not provide.
    if (_requiresUkLongStayGuidance(duration)) {
      await _showUkLongStayGuidance();
      return;
    }

    // South Korea tourism and business visits longer than 90 days
    // cannot be reliably matched using K-ETA rules alone because
    // the appropriate long-term visa depends on the intended activity.
    if (_requiresSouthKoreaLongStayGuidance(duration)) {
      await _showSouthKoreaLongStayGuidance();
      return;
    }

    setState(() {
      _isCreatingTrip = true;
    });

    try {
      final String tripId = await _tripService.createTripWithChecklist(
        userId: user.uid,
        countryId: _selectedCountry!.id,
        purpose: _selectedPurpose!,
        durationDays: duration,
        departureDate: _departureDate!,
      );

      if (!mounted) return;

      setState(() {
        _isCreatingTrip = false;
      });

      // Opens the generated checklist for the newly created trip.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChecklistScreen(tripId: tripId),
        ),
      );
    } catch (e) {
      debugPrint('CREATE TRIP ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isCreatingTrip = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to generate the travel checklist.'),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // DISPLAY HELPERS
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime date) {
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

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.black45),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primaryColor, width: 1.7),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Add New Trip',
          style: TextStyle(color: _darkTextColor, fontWeight: FontWeight.w700),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIntroCard(),

              const SizedBox(height: 26),

              const _SectionTitle(
                title: 'Trip Details',
                subtitle: 'Tell us where and when you are travelling.',
              ),

              const SizedBox(height: 16),

              _buildDestinationField(),

              const SizedBox(height: 20),

              _buildDepartureDateField(),

              const SizedBox(height: 20),

              _buildDurationField(),

              const SizedBox(height: 28),

              const _SectionTitle(
                title: 'Travel Purpose',
                subtitle: 'Select the main purpose of this trip.',
              ),

              const SizedBox(height: 16),

              _buildPurposeSelector(),

              const SizedBox(height: 28),

              _buildInformationNote(),

              const SizedBox(height: 24),

              _buildGenerateButton(),

              const SizedBox(height: 14),

              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Travel requirements are generated '
                    'from validated destination rules. '
                    'Contextual packing recommendations '
                    'are available after the trip is created.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() => const TravellerIntroCard(
    icon: Icons.flight_takeoff_rounded,
    title: 'Prepare your next trip',
    message:
        'Your destination, purpose and stay determine the requirements prepared for you.',
  );

  Widget _buildDestinationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(label: 'Destination', icon: Icons.public_rounded),

        const SizedBox(height: 9),

        if (_isLoadingCountries)
          Container(
            height: 58,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_countryError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD1CC)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFC62828),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    _countryError!,
                    style: const TextStyle(color: Color(0xFF8A1C1C)),
                  ),
                ),

                TextButton(
                  onPressed: _loadCountries,
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<Country>(
            itemHeight: null,
            initialValue: _selectedCountry,
            isExpanded: true,
            decoration: _fieldDecoration(
              hintText: 'Select destination country',
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
            items: _countries.map((country) {
              return DropdownMenuItem<Country>(
                value: country,
                child: Text(country.name, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: _isCreatingTrip
                ? null
                : (Country? country) {
                    setState(() {
                      _selectedCountry = country;
                    });
                  },
          ),
      ],
    );
  }

  Widget _buildDepartureDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(
          label: 'Departure Date',
          icon: Icons.calendar_month_outlined,
        ),

        const SizedBox(height: 9),

        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _isCreatingTrip ? null : _selectDepartureDate,
            child: InputDecorator(
              decoration: _fieldDecoration(
                hintText: 'Select departure date',
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                suffixIcon: const Icon(Icons.chevron_right_rounded),
              ),
              child: Text(
                _departureDate == null
                    ? 'Select departure date'
                    : _formatDate(_departureDate!),
                style: TextStyle(
                  color: _departureDate == null
                      ? Colors.black45
                      : _darkTextColor,
                  fontWeight: _departureDate == null
                      ? FontWeight.w400
                      : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(
          label: 'Duration of Stay',
          icon: Icons.timelapse_rounded,
        ),

        const SizedBox(height: 9),

        TextField(
          controller: _durationController,
          enabled: !_isCreatingTrip,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _fieldDecoration(
            hintText: 'Enter number of days',
            prefixIcon: const Icon(Icons.nights_stay_outlined),
            suffixIcon: const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                widthFactor: 1,
                child: Text('days', style: TextStyle(color: Colors.black54)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPurposeSelector() => TripPurposeSelector(
    options: _purposes
        .map(
          (purpose) => (
            value: purpose['value'] as String,
            label: purpose['label'] as String,
            icon: purpose['icon'] as IconData,
          ),
        )
        .toList(),
    value: _selectedPurpose,
    onChanged: _isCreatingTrip
        ? null
        : (value) {
            setState(() => _selectedPurpose = value);
          },
  );

  Widget _buildInformationNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: AppColors.primary, size: 22),

          SizedBox(width: 12),

          Expanded(
            child: Text(
              'TravelGuard MY matches your '
              'destination, purpose and duration '
              'against validated travel rules. '
              'If more information is required, '
              'the system will direct you to the '
              'relevant official guidance.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: _isCreatingTrip ? null : _generateChecklist,
        icon: _isCreatingTrip
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.auto_awesome_outlined),
        label: Text(
          _isCreatingTrip
              ? 'Generating Checklist...'
              : 'Generate Travel Checklist',
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// REUSABLE UI COMPONENTS
// -----------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final IconData icon;

  const _FieldLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryText,
          ),
        ),
      ),
    ],
  );
}
