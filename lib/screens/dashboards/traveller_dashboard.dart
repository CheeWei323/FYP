import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/trip.dart';
import '../../services/trip_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../add_trip_screen.dart';
import '../checklist_screen.dart';
import '../my_trips_screen.dart';
import '../traveller_alerts_screen.dart';
import '../traveller_settings_screen.dart';
import '../trip_details_screen.dart';
import '../../widgets/destination_photo.dart';

class TravellerDashboard extends StatefulWidget {
  const TravellerDashboard({super.key});

  @override
  State<TravellerDashboard> createState() => _TravellerDashboardState();
}

class _TravellerDashboardState extends State<TravellerDashboard> {
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

  // ---------------------------------------------------------------------------
  // FORMATTERS
  // ---------------------------------------------------------------------------

  String _formatText(String value) {
    if (value.isEmpty) return value;

    return value
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  String _formatDate(DateTime date) {
    const months = [
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

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String get _firstName {
    final name = _travellerName.trim();

    if (name.isEmpty) return 'Traveller';

    return name.split(RegExp(r'\s+')).first;
  }

  double get _progressValue {
    if (_totalRequirements == 0) return 0;

    return _completedRequirements / _totalRequirements;
  }

  int get _progressPercent => (_progressValue * 100).round();

  int get _remainingRequirements {
    final remaining = _totalRequirements - _completedRequirements;

    return remaining < 0 ? 0 : remaining;
  }

  String _departureStatus(DateTime departureDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final departure = DateTime(
      departureDate.year,
      departureDate.month,
      departureDate.day,
    );

    final days = departure.difference(today).inDays;

    if (days == 0) return 'Departing today';
    if (days == 1) return 'Tomorrow';

    return 'In $days days';
  }

  // ---------------------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------------------

  Future<void> _loadHomeData() async {
    if (!mounted) return;

    setState(() {
      _isLoadingHome = true;
      _homeError = null;
    });

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw StateError('No authenticated user was found.');
      }

      final profile = await _userService.getUserProfile(currentUser.uid);

      final trips = await _tripService.getUserTrips(currentUser.uid);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final upcomingTrips = trips.where((trip) {
        final departure = DateTime(
          trip.departureDate.year,
          trip.departureDate.month,
          trip.departureDate.day,
        );

        return !departure.isBefore(today);
      }).toList();

      upcomingTrips.sort(
        (first, second) => first.departureDate.compareTo(second.departureDate),
      );

      final Trip? upcomingTrip = upcomingTrips.isEmpty
          ? null
          : upcomingTrips.first;

      int completed = 0;
      int total = 0;

      if (upcomingTrip != null) {
        final progress = await _tripService.getChecklistProgress(
          upcomingTrip.id,
        );

        completed = progress['completed'] ?? 0;
        total = progress['total'] ?? 0;
      }

      if (!mounted) return;

      final String profileName =
          (profile?['fullName'] as String?)?.trim() ?? '';

      final String displayName = currentUser.displayName?.trim() ?? '';

      setState(() {
        _travellerName = profileName.isNotEmpty
            ? profileName
            : displayName.isNotEmpty
            ? displayName
            : 'Traveller';

        _upcomingTrip = upcomingTrip;
        _completedRequirements = completed;
        _totalRequirements = total;
        _isLoadingHome = false;
      });
    } catch (error) {
      debugPrint('TRAVELLER HOME ERROR: $error');

      if (!mounted) return;

      setState(() {
        _homeError = 'Unable to load your dashboard.';
        _isLoadingHome = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  Future<void> _openAddTrip() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTripScreen()),
    );

    if (!mounted) return;

    await _loadHomeData();
  }

  Future<void> _openUpcomingChecklist() async {
    final trip = _upcomingTrip;

    if (trip == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChecklistScreen(tripId: trip.id)),
    );

    if (!mounted) return;

    await _loadHomeData();
  }

  Future<void> _openUpcomingTrip(Trip trip) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)),
    );

    if (!mounted) return;

    await _loadHomeData();
  }

  void _changeTab(int index) {
    if (_selectedIndex == index) return;

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

  // ---------------------------------------------------------------------------
  // SCREEN
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _buildHome(),
      const MyTripsScreen(embedded: true),
      const TravellerAlertsScreen(),
      const TravellerSettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(_pageTitle)),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _changeTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.luggage_outlined),
            selectedIcon: Icon(Icons.luggage_rounded),
            label: 'My Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HOME
  // ---------------------------------------------------------------------------

  Widget _buildHome() {
    if (_isLoadingHome) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_homeError != null) {
      return RefreshIndicator(
        onRefresh: _loadHomeData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 110),
            const Icon(
              Icons.cloud_off_outlined,
              size: 54,
              color: AppColors.secondaryText,
            ),
            const SizedBox(height: 18),
            Text(
              _homeError!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('Pull down to try again.', textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHomeData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          22,
          AppSpacing.page,
          28,
        ),
        children: [
          const Text(
            'YOUR TRAVEL SPACE',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Welcome back, $_firstName',
            style: Theme.of(context).textTheme.headlineSmall,
          ),

          const SizedBox(height: 6),

          const Text(
            'Plan confidently and stay on top '
            'of your travel preparations.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 25),

          if (_upcomingTrip != null && _remainingRequirements > 0) ...[
            _buildPreparationNotice(),
            const SizedBox(height: 25),
          ],

          _sectionHeader(
            'Your Next Trip',
            action: _upcomingTrip == null ? null : () => _changeTab(1),
          ),

          const SizedBox(height: 13),

          _buildUpcomingTrip(),

          const SizedBox(height: 28),

          _sectionHeader('Quick Actions'),

          const SizedBox(height: 13),

          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {VoidCallback? action}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (action != null)
          TextButton(onPressed: action, child: const Text('See all')),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PREPARATION NOTICE
  // ---------------------------------------------------------------------------

  Widget _buildPreparationNotice() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF5DAB5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.assignment_late_outlined,
              color: Color(0xFF9A5B15),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preparation pending',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$_remainingRequirements '
                  'requirement'
                  '${_remainingRequirements == 1 ? '' : 's'} '
                  'still to complete for your next trip.',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _openUpcomingChecklist,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 40),
                    alignment: Alignment.centerLeft,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Review checklist'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UPCOMING TRIP CARD
  // ---------------------------------------------------------------------------

  Widget _buildUpcomingTrip() {
    final trip = _upcomingTrip;

    if (trip == null) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(
                  Icons.flight_takeoff_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 17),
              const Text(
                'No upcoming trips',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a trip to receive personalised '
                'requirements and preparation guidance.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondaryText, height: 1.5),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _openAddTrip,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create New Trip'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // This image-ready header will be reused
          // when local landmark photos are added.
          DestinationPhoto(
            countryId: trip.destinationCountryId,
            height: 165,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'NEXT DESTINATION',
                    style: TextStyle(
                      color: Color(0xDFFFFFFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Text(
                    _formatText(trip.destinationCountryId),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(color: Color(0x66000000), blurRadius: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    _infoChip(
                      Icons.work_outline_rounded,
                      _formatText(trip.purpose),
                    ),
                    _infoChip(
                      Icons.timelapse_rounded,
                      '${trip.durationDays} days',
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                Wrap(
                  spacing: 14,
                  runSpacing: 8,
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
                        const SizedBox(width: 7),
                        Text(
                          _formatDate(trip.departureDate),
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _departureStatus(trip.departureDate),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Checklist Progress',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '$_progressPercent%',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: _progressValue),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedValue, child) {
                      return LinearProgressIndicator(
                        value: animatedValue,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE5EEF0),
                        color: AppColors.primary,
                      );
                    },
                  ),
                ),

                const SizedBox(height: 9),

                Text(
                  '$_completedRequirements of '
                  '$_totalRequirements requirements completed',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openUpcomingTrip(trip),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                    label: const Text('View Trip'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
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
  // QUICK ACTIONS
  // ---------------------------------------------------------------------------

  Widget _buildQuickActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final createAction = _QuickActionCard(
          icon: Icons.add_location_alt_outlined,
          title: 'Create New Trip',
          onTap: _openAddTrip,
        );

        final tripsAction = _QuickActionCard(
          icon: Icons.luggage_outlined,
          title: 'View My Trips',
          onTap: () => _changeTab(1),
        );

        // Use full-width stacked cards only
        // on very narrow screens.
        if (constraints.maxWidth < 300) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [createAction, const SizedBox(height: 12), tripsAction],
          );
        }

        // Standard physical phones display
        // both quick actions side by side.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: createAction),
            const SizedBox(width: 12),
            Expanded(child: tripsAction),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// REUSABLE QUICK ACTION CARD
// -----------------------------------------------------------------------------

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
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 118),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 24),
                ),

                const SizedBox(height: 11),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
