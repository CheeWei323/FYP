import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/trip.dart';
import '../../services/trip_service.dart';
import '../../services/user_service.dart';
import '../add_trip_screen.dart';
import '../checklist_screen.dart';
import '../my_trips_screen.dart';
import '../traveller_alerts_screen.dart';
import '../traveller_settings_screen.dart';

class TravellerDashboard extends StatefulWidget {
  const TravellerDashboard({
    super.key,
  });

  @override
  State<TravellerDashboard> createState() =>
      _TravellerDashboardState();
}

class _TravellerDashboardState
    extends State<TravellerDashboard> {
  final UserService _userService = UserService();
  final TripService _tripService = TripService();

  int _selectedIndex = 0;

  bool _isLoadingHome = true;
  String? _homeError;

  String _travellerName = 'Traveller';

  Trip? _upcomingTrip;

  int _completedRequirements = 0;
  int _totalRequirements = 0;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
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

  String get _firstName {
    final String cleaned =
    _travellerName.trim();

    if (cleaned.isEmpty) {
      return 'Traveller';
    }

    return cleaned.split(RegExp(r'\s+')).first;
  }

  double get _progressValue {
    if (_totalRequirements == 0) {
      return 0;
    }

    return _completedRequirements /
        _totalRequirements;
  }

  int get _progressPercent {
    return (_progressValue * 100).round();
  }

  int get _remainingRequirements {
    final int remaining =
        _totalRequirements -
            _completedRequirements;

    return remaining < 0 ? 0 : remaining;
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoadingHome = true;
      _homeError = null;
    });

    try {
      final User? currentUser =
          FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception(
          'No authenticated user was found.',
        );
      }

      final Map<String, dynamic>? profile =
      await _userService.getUserProfile(
        currentUser.uid,
      );

      final List<Trip> trips =
      await _tripService.getUserTrips(
        currentUser.uid,
      );

      final DateTime now = DateTime.now();

      final DateTime today = DateTime(
        now.year,
        now.month,
        now.day,
      );

      final List<Trip> upcomingTrips =
      trips.where((trip) {
        final DateTime departure = DateTime(
          trip.departureDate.year,
          trip.departureDate.month,
          trip.departureDate.day,
        );

        return !departure.isBefore(today);
      }).toList();

      upcomingTrips.sort(
            (a, b) => a.departureDate.compareTo(
          b.departureDate,
        ),
      );

      final Trip? upcomingTrip =
      upcomingTrips.isEmpty
          ? null
          : upcomingTrips.first;

      int completed = 0;
      int total = 0;

      if (upcomingTrip != null) {
        final Map<String, int> progress =
        await _tripService
            .getChecklistProgress(
          upcomingTrip.id,
        );

        completed =
            progress['completed'] ?? 0;

        total = progress['total'] ?? 0;
      }

      if (!mounted) return;

      setState(() {
        _travellerName =
            (profile?['fullName'] as String?)
                ?.trim() ??
                currentUser.displayName?.trim() ??
                'Traveller';

        _upcomingTrip = upcomingTrip;
        _completedRequirements = completed;
        _totalRequirements = total;

        _isLoadingHome = false;
      });
    } catch (e) {
      debugPrint(
        'TRAVELLER HOME ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoadingHome = false;
        _homeError =
        'Unable to load your dashboard.';
      });
    }
  }

  Future<void> _openAddTrip() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
        const AddTripScreen(),
      ),
    );

    if (!mounted) return;

    await _loadHomeData();
  }

  Future<void> _openUpcomingChecklist() async {
    final Trip? trip = _upcomingTrip;

    if (trip == null) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChecklistScreen(
              tripId: trip.id,
            ),
      ),
    );

    if (!mounted) return;

    await _loadHomeData();
  }

  void _changeTab(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      _loadHomeData();
    }
  }

  String get _pageTitle {
    switch (_selectedIndex) {
      case 1:
        return 'My Trips';
      case 2:
        return 'Alerts';
      case 3:
        return 'Settings';
      default:
        return 'TravelGuard MY';
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHome(),
      const MyTripsScreen(
        embedded: true,
      ),
      const TravellerAlertsScreen(),
      const TravellerSettingsScreen(),
    ];

    return Scaffold(
      backgroundColor:
      const Color(0xFFF7F9FB),

      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text(
          _pageTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF083B5C),
          ),
        ),
      ),

      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _changeTab,
        height: 70,
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),
            selectedIcon: Icon(
              Icons.home_rounded,
            ),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.luggage_outlined,
            ),
            selectedIcon: Icon(
              Icons.luggage_rounded,
            ),
            label: 'My Trips',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.notifications_none_rounded,
            ),
            selectedIcon: Icon(
              Icons.notifications_rounded,
            ),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.settings_outlined,
            ),
            selectedIcon: Icon(
              Icons.settings_rounded,
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildHome() {
    if (_isLoadingHome) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_homeError != null) {
      return RefreshIndicator(
        onRefresh: _loadHomeData,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 160),

            const Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: Colors.black45,
            ),

            const SizedBox(height: 18),

            Text(
              _homeError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Pull down to try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHomeData,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          18,
          20,
          18,
          110,
        ),
        children: [
          Text(
            'Hello, $_firstName!',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF102A43),
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Ready for your next trip?',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 24),

          if (_upcomingTrip != null &&
              _remainingRequirements > 0)
            _buildActionRequiredCard(),

          if (_upcomingTrip != null &&
              _remainingRequirements > 0)
            const SizedBox(height: 24),

          _buildUpcomingTripSection(),

          const SizedBox(height: 26),

          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF102A43),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon:
                  Icons.add_location_alt_outlined,
                  title: 'Create New Trip',
                  onTap: _openAddTrip,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _QuickActionCard(
                  icon:
                  Icons.luggage_outlined,
                  title: 'View My Trips',
                  onTap: () {
                    _changeTab(1);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionRequiredCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBE9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFC6C1),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFC62828),
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Action Required',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                    FontWeight.w700,
                    color: Color(0xFF9B1C1C),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'You have '
                      '$_remainingRequirements '
                      'travel requirement'
                      '${_remainingRequirements == 1 ? '' : 's'} '
                      'remaining for your upcoming trip.',
                  style: const TextStyle(
                    height: 1.4,
                    color: Color(0xFF6F1D1B),
                  ),
                ),

                const SizedBox(height: 12),

                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                    const Color(0xFFC62828),
                    foregroundColor:
                    Colors.white,
                  ),
                  onPressed:
                  _openUpcomingChecklist,
                  child: const Text(
                    'View Checklist',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingTripSection() {
    final Trip? trip = _upcomingTrip;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Text(
          'Upcoming Trip',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF102A43),
          ),
        ),

        const SizedBox(height: 12),

        if (trip == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE1E7EC),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.flight_takeoff_rounded,
                  size: 44,
                  color: Color(0xFF087F8C),
                ),

                const SizedBox(height: 14),

                const Text(
                  'No upcoming trip',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 7),

                const Text(
                  'Create a trip to receive '
                      'personalised travel requirements.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 16),

                FilledButton.icon(
                  onPressed: _openAddTrip,
                  icon: const Icon(
                    Icons.add_rounded,
                  ),
                  label: const Text(
                    'Create New Trip',
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE1E7EC),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color:
                        const Color(0xFFE8F6F7),
                        borderRadius:
                        BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: const Icon(
                        Icons.flight_rounded,
                        color:
                        Color(0xFF087F8C),
                      ),
                    ),

                    const SizedBox(width: 13),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Text(
                            _formatText(
                              trip.destinationCountryId,
                            ),
                            style:
                            const TextStyle(
                              fontSize: 20,
                              fontWeight:
                              FontWeight
                                  .w800,
                            ),
                          ),

                          const SizedBox(
                            height: 3,
                          ),

                          Text(
                            '${_formatText(trip.purpose)}'
                                ' • '
                                '${trip.durationDays} days',
                            style:
                            const TextStyle(
                              color:
                              Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 17,
                      color: Colors.black54,
                    ),

                    const SizedBox(width: 8),

                    Text(
                      'Departure: '
                          '${_formatDate(trip.departureDate)}',
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
                  children: [
                    const Text(
                      'Checklist Progress',
                      style: TextStyle(
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$_progressPercent%',
                      style: const TextStyle(
                        fontWeight:
                        FontWeight.w700,
                        color:
                        Color(0xFF087F8C),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 9),

                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(20),
                  child:
                  LinearProgressIndicator(
                    value: _progressValue,
                    minHeight: 8,
                    backgroundColor:
                    const Color(0xFFE5EEF0),
                    valueColor:
                    const AlwaysStoppedAnimation<
                        Color>(
                      Color(0xFF087F8C),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  '$_completedRequirements of '
                      '$_totalRequirements '
                      'requirements completed',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      _changeTab(1);
                    },
                    child: const Text(
                      'View Trip',
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        height: 112,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE1E7EC),
          ),
        ),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color:
                const Color(0xFFE8F6F7),
                borderRadius:
                BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                color:
                const Color(0xFF087F8C),
              ),
            ),

            const SizedBox(height: 10),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}