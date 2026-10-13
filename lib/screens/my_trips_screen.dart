import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../services/trip_service.dart';
import 'trip_details_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/destination_photo.dart';

class MyTripsScreen extends StatefulWidget {
  final bool embedded;

  const MyTripsScreen({super.key, this.embedded = false});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  final TripService _tripService = TripService();

  late Future<List<Trip>> _tripsFuture;

  String _selectedFilter = 'all';

  bool _selectionMode = false;

  bool _isDeletingSelected = false;

  final Set<String> _selectedTripIds = <String>{};

  final Map<String, Future<Map<String, int>>> _progressCache = {};

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _borderColor = Color(0xFFE1E7EC);

  @override
  void initState() {
    super.initState();

    _tripsFuture = _fetchTrips();
  }

  Future<Map<String, int>> _getProgress(String tripId) {
    return _progressCache.putIfAbsent(
      tripId,
      () => _tripService.getChecklistProgress(tripId),
    );
  }

  // ---------------------------------------------------------------------------
  // TRIP DATA
  // ---------------------------------------------------------------------------

  Future<List<Trip>> _fetchTrips() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user was found.');
    }

    return _tripService.getUserTrips(currentUser.uid);
  }

  Future<void> _refreshTrips() async {
    final Future<List<Trip>> refreshedTrips = _fetchTrips();

    setState(() {
      _progressCache.clear();
      _tripsFuture = refreshedTrips;
    });

    await refreshedTrips;
  }

  Future<void> _openTrip(Trip trip) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TripDetailsScreen(trip: trip)),
    );

    if (!mounted) return;

    await _refreshTrips();
  }

  // ---------------------------------------------------------------------------
  // FORMATTERS
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

  String _formatText(String value) {
    if (value.isEmpty) {
      return value;
    }

    return value
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}'
                    '${word.substring(1)}',
        )
        .join(' ');
  }

  // ---------------------------------------------------------------------------
  // TRIP STATUS
  // ---------------------------------------------------------------------------

  bool _isPastTrip(Trip trip) {
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);

    final DateTime departure = DateTime(
      trip.departureDate.year,
      trip.departureDate.month,
      trip.departureDate.day,
    );

    // Trips departing today are still considered upcoming.
    return departure.isBefore(today);
  }

  // ---------------------------------------------------------------------------
  // FILTER
  // ---------------------------------------------------------------------------

  void _changeFilter(String filter) {
    if (_selectedFilter == filter) {
      return;
    }

    setState(() {
      _selectedFilter = filter;

      // Prevent hidden selected trips when switching filters.
      _selectionMode = false;
      _selectedTripIds.clear();
    });
  }

  // ---------------------------------------------------------------------------
  // MULTI-SELECTION
  // ---------------------------------------------------------------------------

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;

      if (!_selectionMode) {
        _selectedTripIds.clear();
      }
    });
  }

  void _toggleTripSelection(String tripId) {
    setState(() {
      if (_selectedTripIds.contains(tripId)) {
        _selectedTripIds.remove(tripId);
      } else {
        _selectedTripIds.add(tripId);
      }
    });
  }

  Future<void> _deleteSelectedTrips() async {
    if (_selectedTripIds.isEmpty || _isDeletingSelected) {
      return;
    }

    final int selectedCount = _selectedTripIds.length;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Color(0xFFC62828),
            size: 32,
          ),
          title: Text(
            selectedCount == 1
                ? 'Delete Selected Trip?'
                : 'Delete $selectedCount Trips?',
          ),
          content: Text(
            selectedCount == 1
                ? 'This will permanently delete the selected trip, '
                      'its travel requirements, packing list and '
                      'personal reminders. Scheduled phone notifications '
                      'for this trip will also be cancelled.'
                : 'This will permanently delete the selected trips, '
                      'their travel requirements, packing lists and '
                      'personal reminders. Scheduled phone notifications '
                      'will also be cancelled.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isDeletingSelected = true;
    });

    try {
      final List<String> tripIds = _selectedTripIds.toList();

      for (final String tripId in tripIds) {
        await _tripService.deleteTrip(tripId);
      }

      if (!mounted) return;

      setState(() {
        _selectedTripIds.clear();
        _selectionMode = false;
        _isDeletingSelected = false;
      });

      await _refreshTrips();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selectedCount == 1
                ? 'Trip deleted successfully.'
                : '$selectedCount trips deleted successfully.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('DELETE SELECTED TRIPS ERROR: $e');

      if (!mounted) return;

      setState(() {
        _selectedTripIds.clear();
        _selectionMode = false;
        _isDeletingSelected = false;
      });

      await _refreshTrips();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to delete all selected trips. '
            'Please try again.',
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // SCREEN
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final Widget content = Stack(
      children: [
        Container(
          color: AppColors.background,
          child: FutureBuilder<List<Trip>>(
            future: _tripsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _buildErrorState();
              }

              final List<Trip> trips = snapshot.data ?? [];

              if (trips.isEmpty) {
                return _buildEmptyState();
              }

              return _buildTripsList(trips);
            },
          ),
        ),

        // Keep delete action accessible without scrolling
        // through every trip card.
        if (_selectionMode)
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 16,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: _buildDeleteSelectedButton(),
              ),
            ),
          ),
      ],
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Trips')),
      body: content,
    );
  }

  // ---------------------------------------------------------------------------
  // ERROR STATE
  // ---------------------------------------------------------------------------

  Widget _buildErrorState() {
    return RefreshIndicator(
      onRefresh: _refreshTrips,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: const [
          SizedBox(height: 140),
          Icon(Icons.cloud_off_outlined, size: 58, color: Colors.black38),
          SizedBox(height: 18),
          Text(
            'Unable to load trips',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _darkTextColor,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Pull down to try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _refreshTrips,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 110),
          Center(
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F6F7),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.luggage_outlined,
                size: 40,
                color: _primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'No trips yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: _darkTextColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first trip from Home '
            'to generate personalised travel '
            'requirements and a packing list.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTERS
  // ---------------------------------------------------------------------------

  Widget _buildFilterChip({required String value, required String label}) {
    final bool selected = _selectedFilter == value;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        _changeFilter(value);
      },
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDFF3F5) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _primaryColor : _borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? _primaryColor : const Color(0xFF486581),
          ),
        ),
      ),
    );
  }

  Widget _buildTripControls() {
    return Row(
      children: [
        Expanded(
          child: _buildFilterChip(value: 'all', label: 'All'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildFilterChip(value: 'upcoming', label: 'Upcoming'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildFilterChip(value: 'past', label: 'Past'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TRIP LIST
  // ---------------------------------------------------------------------------

  Widget _buildTripsList(List<Trip> trips) {
    final List<Trip> upcomingTrips = trips
        .where((trip) => !_isPastTrip(trip))
        .toList();

    final List<Trip> pastTrips = trips.where(_isPastTrip).toList();

    // Upcoming trips are shown
    // with the nearest departure first.
    upcomingTrips.sort((a, b) => a.departureDate.compareTo(b.departureDate));

    // Past trips are shown
    // with the most recent first.
    pastTrips.sort((a, b) => b.departureDate.compareTo(a.departureDate));

    final bool showUpcoming =
        _selectedFilter == 'all' || _selectedFilter == 'upcoming';

    final bool showPast = _selectedFilter == 'all' || _selectedFilter == 'past';

    final bool noFilteredTrips =
        (_selectedFilter == 'upcoming' && upcomingTrips.isEmpty) ||
        (_selectedFilter == 'past' && pastTrips.isEmpty);

    return RefreshIndicator(
      onRefresh: _refreshTrips,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
        children: [
          _buildTripControls(),

          const SizedBox(height: 24),

          if (noFilteredTrips) ...[
            _buildNoFilteredTripsState(),

            const SizedBox(height: 16),
          ],

          if (showUpcoming && upcomingTrips.isNotEmpty) ...[
            _buildSectionHeader(
              title: 'Upcoming',
              count: upcomingTrips.length,
              showSelectionAction: true,
            ),

            const SizedBox(height: 12),

            ...upcomingTrips.map(
              (trip) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildTripCard(trip, past: false),
              ),
            ),
          ],

          if (showPast && pastTrips.isNotEmpty) ...[
            if (showUpcoming && upcomingTrips.isNotEmpty)
              const SizedBox(height: 16),

            _buildSectionHeader(
              title: 'Past Trips',
              count: pastTrips.length,

              // When Upcoming is not visible,
              // place Select beside Past Trips.
              showSelectionAction: !showUpcoming || upcomingTrips.isEmpty,
            ),

            const SizedBox(height: 12),

            ...pastTrips.map(
              (trip) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildTripCard(trip, past: true),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoFilteredTripsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.luggage_outlined, size: 40, color: Colors.black38),
          const SizedBox(height: 12),
          Text(
            _selectedFilter == 'upcoming'
                ? 'No upcoming trips'
                : 'No past trips',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: _darkTextColor,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION HEADER
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader({
    required String title,
    required int count,
    bool showSelectionAction = false,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _darkTextColor,
          ),
        ),

        const SizedBox(width: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F6F7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _primaryColor,
            ),
          ),
        ),

        const Spacer(),

        if (showSelectionAction)
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: _isDeletingSelected ? null : _toggleSelectionMode,
            icon: Icon(
              _selectionMode
                  ? Icons.close_rounded
                  : Icons.checklist_rtl_rounded,
              size: 19,
            ),
            label: Text(_selectionMode ? 'Cancel' : 'Select'),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TRIP CARD
  // ---------------------------------------------------------------------------

  Widget _buildTripCard(Trip trip, {required bool past}) {
    final bool selected = _selectedTripIds.contains(trip.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isDeletingSelected
              ? null
              : () {
                  if (_selectionMode) {
                    _toggleTripSelection(trip.id);
                  } else {
                    _openTrip(trip);
                  }
                },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------------------------------------------------------
              // LANDMARK IMAGE
              // ---------------------------------------------------------------
              DestinationPhoto(
                countryId: trip.destinationCountryId,
                height: 145,
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'TRIP DESTINATION',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.3,
                              ),
                            ),
                          ),

                          if (_selectionMode)
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary
                                    : const Color(0xCCFFFFFF),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                selected
                                    ? Icons.check_rounded
                                    : Icons.circle_outlined,
                                size: 21,
                                color: selected
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                            ),
                        ],
                      ),

                      const Spacer(),

                      Text(
                        _formatText(trip.destinationCountryId),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(color: Color(0x77000000), blurRadius: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ---------------------------------------------------------------
              // TRIP INFORMATION
              // ---------------------------------------------------------------
              Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Purpose and duration adapt to available width.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTripInfoChip(
                          Icons.explore_outlined,
                          _formatText(trip.purpose),
                        ),
                        _buildTripInfoChip(
                          Icons.schedule_outlined,
                          '${trip.durationDays} days',
                        ),
                      ],
                    ),

                    const SizedBox(height: 17),

                    // Departure date and trip status can wrap
                    // instead of overflowing on smaller phones.
                    Wrap(
                      spacing: 12,
                      runSpacing: 9,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 17,
                              color: AppColors.secondaryText,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(trip.departureDate),
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: past
                                ? const Color(0xFFF0F2F4)
                                : const Color(0xFFDFF5EA),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            past ? 'Past' : 'Upcoming',
                            style: TextStyle(
                              color: past
                                  ? const Color(0xFF607D8B)
                                  : AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Existing Firestore checklist progress.
                    _buildProgressSection(trip.id),

                    // Hide navigation buttons while selecting trips.
                    if (!_selectionMode) ...[
                      const SizedBox(height: 19),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openTrip(trip),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 19,
                          ),
                          label: const Text('View Trip'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------------
  // REUSABLE TRIP INFORMATION CHIP
  // -----------------------------------------------------------------------------

  Widget _buildTripInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DELETE SELECTED BUTTON
  // ---------------------------------------------------------------------------

  Widget _buildDeleteSelectedButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFC62828),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        onPressed: _selectedTripIds.isEmpty || _isDeletingSelected
            ? null
            : _deleteSelectedTrips,
        icon: _isDeletingSelected
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.delete_outline_rounded),
        label: Text(
          _isDeletingSelected
              ? 'Deleting...'
              : _selectedTripIds.isEmpty
              ? 'Select Trips to Delete'
              : 'Delete Selected '
                    '(${_selectedTripIds.length})',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CHECKLIST PROGRESS
  // ---------------------------------------------------------------------------

  Widget _buildProgressSection(String tripId) {
    return FutureBuilder<Map<String, int>>(
      future: _getProgress(tripId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 7),
          );
        }

        if (snapshot.hasError) {
          return const Text(
            'Unable to load checklist progress.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          );
        }

        final Map<String, int> progress = snapshot.data ?? {};

        final int completed = progress['completed'] ?? 0;

        final int total = progress['total'] ?? 0;

        final double progressValue = total == 0 ? 0 : completed / total;

        final int percentage = (progressValue * 100).round();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$completed of $total '
                    'requirements completed',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),

                const SizedBox(width: 10),

                Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 7,
                backgroundColor: const Color(0xFFE5EEF0),
                valueColor: const AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
            ),
          ],
        );
      },
    );
  }
}
