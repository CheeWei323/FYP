import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../services/trip_service.dart';
import 'trip_details_screen.dart';

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

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

  @override
  void initState() {
    super.initState();
    _tripsFuture = _fetchTrips();
  }

  // Retrieves trips belonging to the currently logged-in traveller.
  Future<List<Trip>> _fetchTrips() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user was found.');
    }

    return _tripService.getUserTrips(currentUser.uid);
  }

  // Refreshes the trip list after returning from another screen.
  Future<void> _refreshTrips() async {
    final Future<List<Trip>> refreshedTrips = _fetchTrips();

    setState(() {
      _tripsFuture = refreshedTrips;
    });

    await refreshedTrips;
  }

  // Opens the selected trip's detail screen.
  Future<void> _openTrip(Trip trip) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TripDetailsScreen(trip: trip)),
    );

    if (!mounted) return;

    await _refreshTrips();
  }

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

  // Determines whether the trip departure date has already passed.
  bool _isPastTrip(Trip trip) {
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);

    final DateTime departure = DateTime(
      trip.departureDate.year,
      trip.departureDate.month,
      trip.departureDate.day,
    );

    return departure.isBefore(today);
  }

  void _changeFilter(String filter) {
    if (_selectedFilter == filter) {
      return;
    }

    setState(() {
      _selectedFilter = filter;
    });
  }

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
                ? 'This will permanently remove the selected trip, '
                      'its travel requirements and packing list.'
                : 'This will permanently remove the selected trips, '
                      'their travel requirements and packing lists.',
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

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      color: _backgroundColor,
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
    );

    // Embedded mode is used inside the Traveller bottom navigation.
    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Trips',
          style: TextStyle(color: _darkTextColor, fontWeight: FontWeight.w700),
        ),
      ),
      body: content,
    );
  }

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

  Widget _buildFilterChip({required String value, required String label}) {
    final bool selected = _selectedFilter == value;

    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      selectedColor: const Color(0xFFDFF3F5),
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? _primaryColor : _borderColor),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: selected ? _primaryColor : const Color(0xFF486581),
        ),
      ),
      onSelected: (_) {
        _changeFilter(value);
      },
    );
  }

  Widget _buildTripControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip(value: 'all', label: 'All'),
                  _buildFilterChip(value: 'upcoming', label: 'Upcoming'),
                  _buildFilterChip(value: 'past', label: 'Past'),
                ],
              ),
            ),

            const SizedBox(width: 8),

            TextButton.icon(
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
        ),

        if (_selectionMode) ...[
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
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
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTripsList(List<Trip> trips) {
    final List<Trip> upcomingTrips = trips
        .where((trip) => !_isPastTrip(trip))
        .toList();

    final List<Trip> pastTrips = trips.where(_isPastTrip).toList();

    // Upcoming trips: nearest departure first.
    upcomingTrips.sort((a, b) => a.departureDate.compareTo(b.departureDate));

    // Past trips: most recent first.
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

          const SizedBox(height: 20),

          if (noFilteredTrips) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _borderColor),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.luggage_outlined,
                    size: 40,
                    color: Colors.black38,
                  ),

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
            ),

            const SizedBox(height: 16),
          ],
          if (showUpcoming && upcomingTrips.isNotEmpty) ...[
            _buildSectionHeader(title: 'Upcoming', count: upcomingTrips.length),

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

            _buildSectionHeader(title: 'Past Trips', count: pastTrips.length),

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

  Widget _buildSectionHeader({required String title, required int count}) {
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
      ],
    );
  }

  Widget _buildTripCard(Trip trip, {required bool past}) {
    final bool selected = _selectedTripIds.contains(trip.id);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? _primaryColor : _borderColor,
          width: selected ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (_selectionMode) {
              _toggleTripSelection(trip.id);
            } else {
              _openTrip(trip);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Material icon used instead of country flag emoji.
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F7F8),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.location_on_outlined,
                        size: 27,
                        color: _primaryColor,
                      ),
                    ),

                    const SizedBox(width: 13),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatText(trip.destinationCountryId),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: _darkTextColor,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            '${_formatText(trip.purpose)}'
                            ' • '
                            '${trip.durationDays} days',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_selectionMode)
                      Checkbox(
                        value: selected,
                        activeColor: _primaryColor,
                        onChanged: (_) {
                          _toggleTripSelection(trip.id);
                        },
                      )
                    else
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.black38,
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: Colors.black45,
                    ),

                    const SizedBox(width: 7),

                    Text(
                      _formatDate(trip.departureDate),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF486581),
                      ),
                    ),

                    const Spacer(),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
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
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: past
                              ? const Color(0xFF607D8B)
                              : const Color(0xFF177245),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 17),

                _buildProgressSection(trip.id),

                if (!_selectionMode) ...[
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      onPressed: () => _openTrip(trip),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                      label: const Text(
                        'View Trip',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(String tripId) {
    return FutureBuilder<Map<String, int>>(
      future: _tripService.getChecklistProgress(tripId),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$completed of $total '
                  'requirements completed',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),

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