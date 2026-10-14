import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/reminder.dart';
import '../../models/trip.dart';
import '../../services/reminder_service.dart';
import '../../services/trip_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/destination_photo.dart';
import '../add_trip_screen.dart';
import '../my_trips_screen.dart';
import '../packing_screen.dart';
import '../traveller_alerts_screen.dart';
import '../traveller_settings_screen.dart';
import '../trip_details_screen.dart';

class TravellerDashboard extends StatefulWidget {
  const TravellerDashboard({super.key});

  @override
  State<TravellerDashboard> createState() => _TravellerDashboardState();
}

class _TravellerDashboardState extends State<TravellerDashboard> {
  final _userService = UserService();
  final _tripService = TripService();
  final _reminderService = ReminderService();

  int _selectedIndex = 0;
  int _tripsRevision = 0;
  int _loadId = 0;
  bool _loading = true;
  bool _refreshing = false;
  bool _openingPage = false;
  bool _remindersUnavailable = false;
  String? _error;
  String _name = 'Traveller';
  List<Trip> _trips = [];
  List<Reminder> _reminders = [];
  int _completed = 0;
  int _total = 0;

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  List<Trip> get _upcomingTrips {
    final today = _day(DateTime.now());
    return _trips
        .where((trip) => !_day(trip.departureDate).isBefore(today))
        .toList();
  }

  Trip? get _nextTrip => _upcomingTrips.firstOrNull;

  double get _progress =>
      _total == 0 ? 0 : (_completed / _total).clamp(0.0, 1.0);

  String get _firstName => _name.trim().split(RegExp(r'\s+')).first;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // A reminder failure should not prevent travellers from opening their trips.
  Future<List<Reminder>?> _fetchReminders(String uid) async {
    try {
      return await _reminderService.getUserReminders(uid);
    } catch (error) {
      debugPrint('DASHBOARD REMINDERS ERROR: $error');
      return null;
    }
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (!mounted) return;
    final request = ++_loadId;
    setState(() {
      _loading = showLoading;
      _refreshing = !showLoading;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('No authenticated traveller.');

      final results = await Future.wait<Object?>([
        _userService.getUserProfile(user.uid),
        _tripService.getUserTrips(user.uid),
        _fetchReminders(user.uid),
      ]);
      final profile = results[0] as Map<String, dynamic>?;
      final trips = results[1] as List<Trip>;
      final reminders = results[2] as List<Reminder>?;
      trips.sort((a, b) => a.departureDate.compareTo(b.departureDate));

      final today = _day(DateTime.now());
      final activeTrips = trips
          .where((trip) => !_day(trip.departureDate).isBefore(today))
          .toList();
      final next = activeTrips.firstOrNull;
      final progress = next == null
          ? <String, int>{'completed': 0, 'total': 0}
          : await _tripService.getChecklistProgress(next.id);
      final activeIds = activeTrips.map((trip) => trip.id).toSet();
      final pendingReminders =
          (reminders ?? <Reminder>[])
              .where(
                (reminder) =>
                    !reminder.completed && activeIds.contains(reminder.tripId),
              )
              .toList()
            ..sort((a, b) => a.reminderAt.compareTo(b.reminderAt));
      final profileName = (profile?['fullName'] as String?)?.trim() ?? '';
      final displayName = user.displayName?.trim() ?? '';

      if (!mounted || request != _loadId) return;
      setState(() {
        _name = profileName.isNotEmpty
            ? profileName
            : displayName.isNotEmpty
            ? displayName
            : 'Traveller';
        _trips = trips;
        _reminders = pendingReminders;
        _remindersUnavailable = reminders == null;
        _completed = progress['completed'] ?? 0;
        _total = progress['total'] ?? 0;
        _loading = false;
        _refreshing = false;
      });
    } catch (error) {
      debugPrint('TRAVELLER DASHBOARD ERROR: $error');
      if (!mounted || request != _loadId) return;
      setState(() {
        _error = 'Your travel information could not be loaded.';
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _openPage(Widget page) async {
    if (_openingPage) return;
    _openingPage = true;
    try {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page));
      if (mounted) {
        setState(() => _tripsRevision++);
        await _loadData(showLoading: false);
      }
    } finally {
      _openingPage = false;
    }
  }

  void _changeTab(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    if (index == 0 || index == 2) _loadData();
  }

  Future<void> _openNotifications() => _openPage(
    Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const TravellerAlertsScreen(),
    ),
  );

  String _label(String value) => value
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  String _date(DateTime date) {
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

  String _departure(Trip trip) {
    final days = _day(
      trip.departureDate,
    ).difference(_day(DateTime.now())).inDays;
    if (days == 0) return 'Departing today';
    if (days == 1) return 'Departing tomorrow';
    return 'Departing in $days days';
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['TravelGuard MY', 'Trips', 'Packing', 'Profile'];
    final Widget page;
    switch (_selectedIndex) {
      case 1:
        page = MyTripsScreen(key: ValueKey(_tripsRevision), embedded: true);
      case 3:
        page = const TravellerSettingsScreen();
      default:
        page = _buildDataPage();
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.background,
        title: Text(titles[_selectedIndex]),
        actions: [
          if (_selectedIndex == 1)
            IconButton(
              tooltip: 'Create trip',
              onPressed: () => _openPage(const AddTripScreen()),
              icon: const Icon(Icons.add_rounded),
            ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: _openNotifications,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(top: false, child: page),
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
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.backpack_outlined),
            selectedIcon: Icon(Icons.backpack_rounded),
            label: 'Packing',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildDataPage() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final content = _error != null
        ? <Widget>[
            _message(
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load your travel space',
              description: _error!,
              button: 'Try again',
              onPressed: () => _loadData(),
            ),
          ]
        : _selectedIndex == 2
        ? _prepareContent()
        : _homeContent();

    return RefreshIndicator(
      onRefresh: () => _loadData(showLoading: false),
      child: ListView(
        key: PageStorageKey(_selectedIndex == 2 ? 'prepare' : 'home'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          if (_refreshing) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 16),
          ],
          ...content,
        ],
      ),
    );
  }

  List<Widget> _homeContent() {
    final trip = _nextTrip;
    final remaining = (_total - _completed).clamp(0, _total);
    return [
      Text(
        'Hello, $_firstName.',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 6),
      const Text('Your next journey starts with a little preparation.'),
      const SizedBox(height: 24),
      _heading('Your next trip', action: () => _changeTab(1)),
      const SizedBox(height: 12),
      if (trip == null)
        _message(
          icon: Icons.flight_takeoff_rounded,
          title: 'Where are you heading next?',
          description:
              'Create a trip to organise your requirements, packing and reminders.',
          button: 'Create a trip',
          onPressed: () => _openPage(const AddTripScreen()),
        )
      else
        _tripCard(trip),
      if (trip != null && remaining > 0) ...[
        const SizedBox(height: 14),
        _ActionTile(
          icon: Icons.assignment_outlined,
          title: 'Review travel requirements',
          subtitle:
              '$remaining requirement${remaining == 1 ? '' : 's'} still to check for ${_label(trip.destinationCountryId)}.',
          onTap: () => _openPage(TripDetailsScreen(trip: trip)),
          warm: true,
        ),
      ],
      const SizedBox(height: 26),
      _heading('Reminders', action: _openNotifications),
      const SizedBox(height: 12),
      if (_remindersUnavailable)
        _ActionTile(
          icon: Icons.cloud_off_outlined,
          title: 'Reminders are unavailable',
          subtitle: 'Open Notifications to try loading them again.',
          onTap: _openNotifications,
        )
      else if (_reminders.isEmpty)
        _ActionTile(
          icon: Icons.notifications_none_rounded,
          title: 'No pending reminders',
          subtitle: trip == null
              ? 'Create a trip to add a personal reminder.'
              : 'Add a reminder from your trip details.',
          onTap: () => trip == null
              ? _openPage(const AddTripScreen())
              : _openPage(TripDetailsScreen(trip: trip)),
        )
      else
        for (final reminder in _reminders.take(3)) ...[
          _reminderTile(reminder),
          const SizedBox(height: 10),
        ],
      const SizedBox(height: 26),
      _heading('Make your next move'),
      const SizedBox(height: 12),
      _ActionTile(
        icon: Icons.add_location_alt_outlined,
        title: 'Create a trip',
        subtitle: 'Choose your destination, purpose and travel dates.',
        onTap: () => _openPage(const AddTripScreen()),
      ),
      const SizedBox(height: 12),
      _ActionTile(
        icon: Icons.backpack_outlined,
        title: 'Organise your packing',
        subtitle:
            'Open Packing to manage packing lists for your upcoming trips.',
        onTap: () => _changeTab(2),
      ),
    ];
  }

  Widget _tripCard(Trip trip) {
    final imageHeight = (MediaQuery.textScalerOf(context).scale(30) * 2 + 70)
        .clamp(170.0, 300.0);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DestinationPhoto(
            countryId: trip.destinationCountryId,
            height: imageHeight,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  _label(trip.destinationCountryId),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _departure(trip),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_date(trip.departureDate)} · ${_label(trip.purpose)} · ${trip.durationDays} day${trip.durationDays == 1 ? '' : 's'}',
                ),
                const SizedBox(height: 20),
                Text(
                  'Requirements completed',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                if (_total > 0) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 8,
                      backgroundColor: AppColors.primaryLight,
                      semanticsLabel: 'Requirements completed',
                      semanticsValue: '${(_progress * 100).round()} percent',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$_completed of $_total checked · ${(_progress * 100).round()}%',
                  ),
                ] else
                  const Text(
                    'No requirements available. Open the trip to review its details.',
                  ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => _openPage(TripDetailsScreen(trip: trip)),
                  child: const Text('View trip', textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reminderTile(Reminder reminder) {
    final trip = _trips.firstWhere((trip) => trip.id == reminder.tripId);
    final overdue = reminder.reminderAt.isBefore(DateTime.now());
    final time = TimeOfDay.fromDateTime(reminder.reminderAt).format(context);
    return _ActionTile(
      icon: overdue ? Icons.schedule_rounded : Icons.notifications_none_rounded,
      title: reminder.title,
      subtitle:
          '${overdue ? 'Overdue · ' : ''}${_date(reminder.reminderAt)} · $time\n${_label(trip.destinationCountryId)}',
      onTap: () => _openPage(TripDetailsScreen(trip: trip)),
      warm: overdue,
    );
  }

  List<Widget> _prepareContent() {
    final trips = _upcomingTrips;
    return [
      Text(
        'Pack for your next journey.',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text('Choose an upcoming trip to organise its packing list.'),
      const SizedBox(height: 24),
      if (trips.isEmpty) ...[
        _message(
          icon: Icons.backpack_outlined,
          title: 'Your packing starts with a trip',
          description:
              'Create a trip to get started. You can find earlier trips in the Trips tab.',
          button: 'Create a trip',
          onPressed: () => _openPage(const AddTripScreen()),
        ),
        TextButton(
          onPressed: () => _changeTab(1),
          child: const Text('Browse saved trips'),
        ),
      ] else
        for (final trip in trips) ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _label(trip.destinationCountryId),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_date(trip.departureDate)} · ${_label(trip.purpose)} · ${trip.durationDays} day${trip.durationDays == 1 ? '' : 's'}',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => _openPage(PackingScreen(trip: trip)),
                    child: const Text(
                      'Open packing list',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
    ];
  }

  Widget _heading(String title, {VoidCallback? action}) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (action != null)
        TextButton(onPressed: action, child: const Text('View all')),
    ],
  );

  Widget _message({
    required IconData icon,
    required String title,
    required String description,
    required String button,
    required VoidCallback onPressed,
  }) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 42, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(description, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onPressed,
            child: Text(button, textAlign: TextAlign.center),
          ),
        ],
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.warm = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool warm;

  @override
  Widget build(BuildContext context) => Material(
    color: warm ? const Color(0xFFFFF0E2) : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: warm ? AppColors.accent : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 5),
                  Text(subtitle),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.secondaryText,
            ),
          ],
        ),
      ),
    ),
  );
}
