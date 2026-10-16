import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/traveller_ui_widgets.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/country.dart';
import '../models/trip.dart';
import '../services/country_service.dart';
import '../services/trip_service.dart';

class EditTripScreen extends StatefulWidget {
  final Trip trip;

  const EditTripScreen({super.key, required this.trip});

  @override
  State<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends State<EditTripScreen> {
  final CountryService _countryService = CountryService();

  final TripService _tripService = TripService();

  final TextEditingController _durationController = TextEditingController();

  List<Country> _countries = [];

  Country? _selectedCountry;
  String? _selectedPurpose;
  DateTime? _departureDate;

  bool _isLoadingCountries = true;
  bool _isSaving = false;

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

  @override
  void initState() {
    super.initState();

    _selectedPurpose = widget.trip.purpose;

    _departureDate = widget.trip.departureDate;

    _durationController.text = widget.trip.durationDays.toString();

    _loadCountries();
  }

  @override
  void dispose() {
    _durationController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // COUNTRY
  // ---------------------------------------------------------------------------

  Future<void> _loadCountries() async {
    setState(() {
      _isLoadingCountries = true;
      _countryError = null;
    });

    try {
      final List<Country> countries = await _countryService
          .getEnabledCountries();

      countries.sort((a, b) => a.name.compareTo(b.name));

      Country? selectedCountry;

      for (final Country country in countries) {
        if (country.id == widget.trip.destinationCountryId) {
          selectedCountry = country;
          break;
        }
      }

      if (!mounted) return;

      setState(() {
        _countries = countries;
        _selectedCountry = selectedCountry;
        _isLoadingCountries = false;

        if (selectedCountry == null) {
          _countryError = 'The current destination is not available.';
        }
      });
    } catch (e) {
      debugPrint('EDIT TRIP COUNTRY ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoadingCountries = false;
        _countryError = 'Unable to load destination countries.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // DATE
  // ---------------------------------------------------------------------------

  Future<void> _selectDepartureDate() async {
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);

    final DateTime current = _departureDate ?? today;

    final DateTime currentDate = DateTime(
      current.year,
      current.month,
      current.day,
    );

    // If this is already a past trip,
    // allow the existing historical date.
    final DateTime firstDate = currentDate.isBefore(today)
        ? currentDate
        : today;

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: firstDate,
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
  // SAFEGUARDS
  // ---------------------------------------------------------------------------

  bool _requiresJapanLongStayGuidance(int durationDays) {
    return _selectedCountry?.id == 'japan' &&
        (_selectedPurpose == 'tourism' || _selectedPurpose == 'business') &&
        durationDays > 90;
  }

  bool _requiresAustraliaBusinessVisaGuidance(int durationDays) {
    return _selectedCountry?.id == 'australia' &&
        _selectedPurpose == 'business' &&
        durationDays > 90;
  }

  bool _requiresUkLongStayGuidance(int durationDays) {
    return _selectedCountry?.id == 'united_kingdom' && durationDays > 180;
  }

  bool _requiresSouthKoreaLongStayGuidance(int durationDays) {
    return _selectedCountry?.id == 'south_korea' &&
        (_selectedPurpose == 'tourism' || _selectedPurpose == 'business') &&
        durationDays > 90;
  }

  Future<void> _openUrl(String url, String errorMessage) async {
    try {
      final bool opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
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
      builder: (dialogContext) {
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
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);

                await _openUrl(
                  'https://www.my.emb-japan.go.jp/itpr_en/visit.html',
                  'Unable to open the Japan visa guidance.',
                );
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open Visa Guidance'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAustraliaGuidance() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
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
            '90 days may require a different visa depending '
            'on the activities you intend to undertake.\n\n'
            'TravelGuard MY cannot determine the appropriate '
            'visa from travel purpose and duration alone. '
            'Please check the official Australian Department '
            'of Home Affairs Visa Finder.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);

                await _openUrl(
                  'https://immi.homeaffairs.gov.au/visas/getting-a-visa/visa-finder',
                  'Unable to open the Australian Visa Finder.',
                );
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open Visa Finder'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showUkGuidance() async {
    String message;

    switch (_selectedPurpose) {
      case 'study':
        message =
            'Study in the United Kingdom for longer than '
            '180 days requires additional information about '
            'the type of course.\n\n'
            'TravelGuard MY cannot determine the correct '
            'visa from purpose and duration alone. Please '
            'use the official UK visa checker.';
        break;

      case 'business':
        message =
            'Business visits to the United Kingdom longer '
            'than 180 days cannot be reliably determined '
            'from travel purpose and duration alone.\n\n'
            'Please use the official UK visa checker to '
            'determine the appropriate immigration route.';
        break;

      case 'tourism':
      default:
        message =
            'A normal UK visitor stay is generally limited '
            'to up to 6 months.\n\n'
            'TravelGuard MY cannot generate a complete '
            'tourism checklist for a stay longer than '
            '180 days. Please use the official UK visa '
            'checker for further guidance.';
        break;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
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
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);

                await _openUrl(
                  'https://www.gov.uk/check-uk-visa',
                  'Unable to open the UK visa checker.',
                );
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open UK Visa Checker'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSouthKoreaGuidance() async {
    final String visitType = _selectedPurpose == 'business'
        ? 'business'
        : 'tourism';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
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
          content: Text(
            'K-ETA is intended for eligible short-term '
            'visits to South Korea of up to 90 days.\n\n'
            'A $visitType stay longer than 90 days may '
            'require a different visa. TravelGuard MY '
            'cannot determine the appropriate long-term '
            'visa from purpose and duration alone.\n\n'
            'Please refer to the official Embassy of the '
            'Republic of Korea in Malaysia visa guidance.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);

                await _openUrl(
                  'https://overseas.mofa.go.kr/my-en/brd/m_1914/view.do?seq=761536&page=1',
                  'Unable to open the South Korea visa guidance.',
                );
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
  // VALIDATION / CHANGE DETECTION
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

  bool _sameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  bool get _requirementsChanged {
    final int? duration = int.tryParse(_durationController.text.trim());

    if (_selectedCountry == null ||
        _selectedPurpose == null ||
        duration == null) {
      return false;
    }

    return _selectedCountry!.id != widget.trip.destinationCountryId ||
        _selectedPurpose != widget.trip.purpose ||
        duration != widget.trip.durationDays;
  }

  bool get _departureChanged {
    if (_departureDate == null) {
      return false;
    }

    return !_sameDate(_departureDate!, widget.trip.departureDate);
  }

  // ---------------------------------------------------------------------------
  // SAVE
  // ---------------------------------------------------------------------------

  Future<void> _saveChanges() async {
    if (_isSaving) return;

    FocusScope.of(context).unfocus();

    final String? validation = _validateTrip();

    if (validation != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(validation)));

      return;
    }

    final int duration = int.parse(_durationController.text.trim());

    if (_requiresJapanLongStayGuidance(duration)) {
      await _showJapanLongStayGuidance();
      return;
    }

    if (_requiresAustraliaBusinessVisaGuidance(duration)) {
      await _showAustraliaGuidance();
      return;
    }

    if (_requiresUkLongStayGuidance(duration)) {
      await _showUkGuidance();
      return;
    }

    if (_requiresSouthKoreaLongStayGuidance(duration)) {
      await _showSouthKoreaGuidance();
      return;
    }

    if (!_requirementsChanged && !_departureChanged) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No trip details were changed.')),
        );

      return;
    }

    final bool confirmed = await _showUpdateConfirmation();

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _tripService.updateTripWithChecklist(
        existingTrip: widget.trip,
        countryId: _selectedCountry!.id,
        purpose: _selectedPurpose!,
        durationDays: duration,
        departureDate: _departureDate!,
      );

      if (!mounted) return;

      final Trip updatedTrip = Trip(
        id: widget.trip.id,
        userId: widget.trip.userId,
        destinationCountryId: _selectedCountry!.id,
        purpose: _selectedPurpose!,
        durationDays: duration,
        departureDate: _departureDate!,
        createdAt: widget.trip.createdAt,
        updatedAt: DateTime.now(),
      );

      Navigator.pop(context, updatedTrip);
    } catch (e) {
      debugPrint('UPDATE TRIP ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update the trip. Please try again.'),
        ),
      );
    }
  }

  Future<bool> _showUpdateConfirmation() async {
    String message;

    if (_requirementsChanged) {
      message =
          'Changing the destination, purpose or duration '
          'will regenerate your travel requirements and '
          'reset the current checklist completion progress.\n\n'
          'Existing contextual packing recommendations '
          'will also be removed so that new recommendations '
          'can be generated for the updated trip.\n\n'
          'Manually added packing items will be kept.';
    } else {
      message =
          'Changing the departure date may affect contextual '
          'packing recommendations.\n\n'
          'Existing generated packing recommendations will '
          'be removed so that you can generate updated '
          'recommendations. Your travel requirements and '
          'checklist progress will be kept.\n\n'
          'Manually added packing items will also be kept.';
    }

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.edit_calendar_outlined,
            color: _primaryColor,
            size: 32,
          ),
          title: const Text('Update Trip?', textAlign: TextAlign.center),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Update Trip'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS
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
          'Edit Trip',
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

              const Text(
                'Trip Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _darkTextColor,
                ),
              ),

              const SizedBox(height: 16),

              _buildDestinationField(),

              const SizedBox(height: 20),

              _buildDepartureField(),

              const SizedBox(height: 20),

              _buildDurationField(),

              const SizedBox(height: 28),

              const Text(
                'Travel Purpose',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _darkTextColor,
                ),
              ),

              const SizedBox(height: 16),

              _buildPurposeSelector(),

              const SizedBox(height: 26),

              _buildInformationNote(),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveChanges,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving ? 'Updating Trip...' : 'Save Changes',
                    style: const TextStyle(fontWeight: FontWeight.w700),
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
    title: 'Update your trip',
    message:
        'Update your trip details. Changes to destination, purpose or duration can regenerate your checklist.',
  );

  Widget _buildDestinationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Destination',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 9),

        if (_isLoadingCountries)
          const Center(child: CircularProgressIndicator())
        else if (_countryError != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  _countryError!,
                  style: const TextStyle(color: Color(0xFFC62828)),
                ),
              ),
              TextButton(onPressed: _loadCountries, child: const Text('Retry')),
            ],
          )
        else
          DropdownButtonFormField<Country>(
            itemHeight: null,
            initialValue: _selectedCountry,
            isExpanded: true,
            decoration: _fieldDecoration(
              hintText: 'Select destination',
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
            items: _countries.map((country) {
              return DropdownMenuItem<Country>(
                value: country,
                child: Text(country.name),
              );
            }).toList(),
            onChanged: _isSaving
                ? null
                : (country) {
                    setState(() {
                      _selectedCountry = country;
                    });
                  },
          ),
      ],
    );
  }

  Widget _buildDepartureField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Departure Date',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 9),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isSaving ? null : _selectDepartureDate,
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _darkTextColor,
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
        const Text(
          'Duration of Stay',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _durationController,
          enabled: !_isSaving,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _fieldDecoration(
            hintText: 'Enter number of days',
            prefixIcon: const Icon(Icons.nights_stay_outlined),
            suffixIcon: const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(widthFactor: 1, child: Text('days')),
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
    onChanged: _isSaving
        ? null
        : (value) {
            setState(() => _selectedPurpose = value);
          },
  );

  Widget _buildInformationNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 21),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Changing destination, purpose or duration '
              'regenerates the travel requirements and '
              'resets checklist completion. Changing any '
              'trip context removes old generated packing '
              'recommendations. Manual packing items are kept.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
