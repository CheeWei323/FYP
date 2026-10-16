import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../services/trip_service.dart';
import 'trip_details_screen.dart';
import 'add_trip_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/traveller_ui_widgets.dart';
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

  static const Color _primaryColor = AppColors.primary;

  static const Color _darkTextColor = AppColors.navy;

  static const Color _borderColor = AppColors.border;

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

    try {
      await refreshedTrips;
    } catch (error) {
      debugPrint('TRIPS REFRESH ERROR: $error');
    }
  }

  // Open trip creation from the empty state and refresh on return.
  Future<void> _createTrip() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTripScreen()),
    );
    if (mounted) await _refreshTrips();
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
          // Keep the deletion confirmation centred and scrollable.
          scrollable: true,
          actionsAlignment: MainAxisAlignment.center,
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

  // Show the trip list and keep selection actions below the scrollable content.
  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        // Load trips and show the appropriate loading, error or empty state.
        Expanded(
          child: ColoredBox(
            color: AppColors.background,
            child: FutureBuilder<List<Trip>>(
              future: _tripsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) return _buildErrorState();

                final trips = snapshot.data ?? <Trip>[];
                if (trips.isEmpty) return _buildEmptyState();

                return _buildTripsList(trips);
              },
            ),
          ),
        ),

        // Reserve space for the delete button so it cannot cover a trip card.
        if (_selectionMode)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: _buildDeleteSelectedButton(),
              ),
            ),
          ),
      ],
    );

    // Reuse the dashboard app bar when this screen is embedded in Trips.
    if (widget.embedded) return content;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Trips')),
      body: content,
    );
  }

  // ---------------------------------------------------------------------------
  // ERROR STATE
  // ---------------------------------------------------------------------------

  Widget _buildErrorState() => RefreshIndicator(
    onRefresh: _refreshTrips,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 32, 18, 32),
      children: [
        TravellerStatusCard(
          icon: Icons.cloud_off_outlined,
          title: 'Unable to load trips',
          message: 'Check your connection and try again.',
          actionText: 'Retry',
          onAction: _refreshTrips,
        ),
      ],
    ),
  );

  Widget _buildEmptyState() => RefreshIndicator(
    onRefresh: _refreshTrips,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 32, 18, 32),
      children: [
        TravellerStatusCard(
          icon: Icons.luggage_outlined,
          title: 'No trips yet',
          message:
              'Create a trip to organise your requirements, packing, route plan and reminders.',
          actionText: 'Create a trip',
          onAction: _createTrip,
        ),
      ],
    ),
  );

  // Indicate the current trip filter without relying on colour alone.

  Widget _buildFilterChip({required String value, required String label}) {
    final selected = _selectedFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.primaryLight,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.secondaryText,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),

      // Keep the active selection stable while deletion is in progress.
      onSelected: _isDeletingSelected ? null : (_) => _changeFilter(value),
    );
  }

  // Let filters wrap when the screen or text size needs more space.
  Widget _buildTripControls() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFilterChip(value: 'all', label: 'All'),
        _buildFilterChip(value: 'upcoming', label: 'Upcoming'),
        _buildFilterChip(value: 'past', label: 'Past'),
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
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          // Introduce the trip workspace before its filters.
          Text(
            'Your journeys, together.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Open a trip to review its details and travel requirements.',
          ),
          const SizedBox(height: 20),
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

  // Show a trip group count and its selection action without squeezing text.
  Widget _buildSectionHeader({
    required String title,
    required int count,
    bool showSelectionAction = false,
  }) {
    final heading = Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    if (!showSelectionAction) return heading;

    final selectionButton = TextButton.icon(
      onPressed: _isDeletingSelected ? null : _toggleSelectionMode,
      icon: Icon(
        _selectionMode ? Icons.close_rounded : Icons.checklist_rtl_rounded,
        size: 20,
      ),
      label: Text(_selectionMode ? 'Cancel' : 'Select'),
    );

    // Move the selection action below the heading for larger text.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (MediaQuery.textScalerOf(context).scale(14) > 20 ||
            constraints.maxWidth < 300) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: selectionButton),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: heading),
            const SizedBox(width: 10),
            selectionButton,
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TRIP CARD
  // ---------------------------------------------------------------------------

  // Show trip details or toggle selection when a traveller taps a trip card.
  Widget _buildTripCard(Trip trip, {required bool past}) {
    final selected = _selectedTripIds.contains(trip.id);
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations || media.accessibleNavigation;

    final imageHeight = (media.textScaler.scale(23) * 2.8 + 90).clamp(
      160.0,
      300.0,
    );

    // Animate selection while respecting reduced-motion settings.
    return AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // A tap either opens this trip or changes its selection state.
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Keep the destination title readable over its photograph.
              DestinationPhoto(
                countryId: trip.destinationCountryId,
                height: imageHeight,
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'TRIP DESTINATION',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                height: 1.1,
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
                                shape: BoxShape.circle,
                                color: selected
                                    ? AppColors.primary
                                    : const Color(0xCCFFFFFF),
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
                      Text(
                        _formatText(trip.destinationCountryId),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Allow trip dates and metadata to wrap naturally.
              Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                          '${trip.durationDays} day'
                          '${trip.durationDays == 1 ? '' : 's'}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Departure: ${_formatDate(trip.departureDate)}',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: past
                              ? AppColors.background
                              : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          past ? 'Past' : 'Upcoming',
                          style: TextStyle(
                            color: past
                                ? AppColors.secondaryText
                                : AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildProgressSection(trip.id),

                    // Hide navigation while the traveller is selecting trips.
                    if (!_selectionMode) ...[
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => _openTrip(trip),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                        label: const Text(
                          'View trip',
                          textAlign: TextAlign.center,
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

  // Show selection count and prevent empty or repeated delete requests.
  Widget _buildDeleteSelectedButton() {
    final label = _isDeletingSelected
        ? 'Deleting...'
        : _selectedTripIds.isEmpty
        ? 'Select trips to delete'
        : 'Delete selected (${_selectedTripIds.length})';

    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
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
      label: Text(label, textAlign: TextAlign.center),
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
                backgroundColor: AppColors.primaryLight,
                valueColor: const AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
            ),
          ],
        );
      },
    );
  }
}
