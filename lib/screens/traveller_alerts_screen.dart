import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../models/trip.dart';
import '../services/reminder_service.dart';
import '../services/trip_service.dart';
import 'checklist_screen.dart';

class TravellerAlertsScreen extends StatefulWidget {
  const TravellerAlertsScreen({super.key});

  @override
  State<TravellerAlertsScreen> createState() => _TravellerAlertsScreenState();
}

class _TravellerAlertsScreenState extends State<TravellerAlertsScreen> {
  final ReminderService _reminderService = ReminderService();

  final TripService _tripService = TripService();

  late Future<_AlertsData> _alertsFuture;

  String _selectedFilter = 'upcoming';

  static const int _preparationAlertWindowDays = 30;

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

  @override
  void initState() {
    super.initState();

    _alertsFuture = _loadAlertsData();
  }

  // ---------------------------------------------------------------------------
  // ALERT DATA
  // ---------------------------------------------------------------------------

  Future<_AlertsData> _loadAlertsData() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user was found.');
    }

    final Future<List<Trip>> tripsFuture = _tripService.getUserTrips(
      currentUser.uid,
    );

    final Future<List<Reminder>> remindersFuture = _reminderService
        .getUserReminders(currentUser.uid);

    final List<Trip> trips = await tripsFuture;

    final List<Reminder> reminders = await remindersFuture;

    final List<Trip> activeTrips = trips
        .where((trip) => !_isPastTrip(trip))
        .toList();

    final List<Trip> preparationTrips = activeTrips
        .where(_isWithinPreparationAlertWindow)
        .toList();

    final Set<String> activeTripIds = activeTrips
        .map((trip) => trip.id)
        .toSet();

    final List<Future<_PreparationAlert?>> preparationFutures = preparationTrips
        .map((trip) async {
          final Map<String, int> progress = await _tripService
              .getChecklistProgress(trip.id);

          final int completed = progress['completed'] ?? 0;

          final int total = progress['total'] ?? 0;

          if (total == 0 || completed >= total) {
            return null;
          }

          return _PreparationAlert(
            trip: trip,
            completed: completed,
            total: total,
          );
        })
        .toList();

    final List<_PreparationAlert?> preparationResults = await Future.wait(
      preparationFutures,
    );

    final List<_PreparationAlert> preparationAlerts = preparationResults
        .whereType<_PreparationAlert>()
        .toList();

    preparationAlerts.sort(
      (first, second) =>
          first.trip.departureDate.compareTo(second.trip.departureDate),
    );

    // Active reminders are hidden once their
    // associated trip has passed.
    final List<Reminder> activeReminders = reminders
        .where(
          (reminder) =>
              !reminder.completed && activeTripIds.contains(reminder.tripId),
        )
        .toList();

    activeReminders.sort(
      (first, second) => first.reminderAt.compareTo(second.reminderAt),
    );

    // Completed reminders are retained as
    // a simple history even if the trip passed.
    final List<Reminder> completedReminders = reminders
        .where((reminder) => reminder.completed)
        .toList();

    completedReminders.sort(
      (first, second) => second.reminderAt.compareTo(first.reminderAt),
    );

    return _AlertsData(
      preparationAlerts: preparationAlerts,
      activeReminders: activeReminders,
      completedReminders: completedReminders,
    );
  }

  Future<void> _refresh() async {
    final Future<_AlertsData> refreshed = _loadAlertsData();

    setState(() {
      _alertsFuture = refreshed;
    });

    await refreshed;
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

    // Departure today is still treated
    // as an active/upcoming trip.
    return departure.isBefore(today);
  }

  bool _isWithinPreparationAlertWindow(Trip trip) {
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);

    final DateTime departure = DateTime(
      trip.departureDate.year,
      trip.departureDate.month,
      trip.departureDate.day,
    );

    final int daysUntilDeparture = departure.difference(today).inDays;

    return daysUntilDeparture >= 0 &&
        daysUntilDeparture <= _preparationAlertWindowDays;
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
    });
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  Future<void> _openChecklist(_PreparationAlert alert) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChecklistScreen(tripId: alert.trip.id),
      ),
    );

    if (!mounted) return;

    await _refresh();
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

  String _formatTime(DateTime date) {
    final int hour = date.hour;

    final int minute = date.minute;

    final String period = hour >= 12 ? 'PM' : 'AM';

    final int displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;

    final String minuteText = minute.toString().padLeft(2, '0');

    return '$displayHour:'
        '$minuteText '
        '$period';
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

  bool _isOverdue(Reminder reminder) {
    return !reminder.completed && reminder.reminderAt.isBefore(DateTime.now());
  }

  // ---------------------------------------------------------------------------
  // SCREEN
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _backgroundColor,
      child: SafeArea(
        child: FutureBuilder<_AlertsData>(
          future: _alertsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildErrorState();
            }

            final _AlertsData data =
                snapshot.data ??
                const _AlertsData(
                  preparationAlerts: [],
                  activeReminders: [],
                  completedReminders: [],
                );

            final int upcomingCount =
                data.preparationAlerts.length + data.activeReminders.length;

            final int completedCount = data.completedReminders.length;

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
                children: [
                  _buildHeader(),

                  const SizedBox(height: 22),

                  _buildFilterRow(
                    upcomingCount: upcomingCount,
                    completedCount: completedCount,
                  ),

                  const SizedBox(height: 20),

                  if (_selectedFilter == 'upcoming')
                    _buildUpcomingContent(data)
                  else
                    _buildCompletedContent(data.completedReminders),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE7F7F8), Color(0xFFF1F8FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBE8EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(15)),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: _primaryColor,
              size: 29,
            ),
          ),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Travel Alerts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'Automatic preparation alerts and '
                  'personal reminders for your trips.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTERS
  // ---------------------------------------------------------------------------

  Widget _buildFilterRow({
    required int upcomingCount,
    required int completedCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildFilterButton(
            value: 'upcoming',
            label: 'Upcoming',
            count: upcomingCount,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _buildFilterButton(
            value: 'completed',
            label: 'Completed',
            count: completedCount,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton({
    required String value,
    required String label,
    required int count,
  }) {
    final bool selected = _selectedFilter == value;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        _changeFilter(value);
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDFF3F5) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _primaryColor : _borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? _primaryColor : const Color(0xFF486581),
                ),
              ),
            ),

            const SizedBox(width: 7),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? Colors.white : const Color(0xFFF0F4F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? _primaryColor : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UPCOMING CONTENT
  // ---------------------------------------------------------------------------

  Widget _buildUpcomingContent(_AlertsData data) {
    if (data.preparationAlerts.isEmpty && data.activeReminders.isEmpty) {
      return _buildEmptyState(
        title: 'No upcoming alerts',
        message:
            'There are no outstanding travel '
            'requirements or active reminders '
            'for your upcoming trips.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.preparationAlerts.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Preparation Alerts',
            count: data.preparationAlerts.length,
          ),

          const SizedBox(height: 12),

          for (
            int index = 0;
            index < data.preparationAlerts.length;
            index++
          ) ...[
            _buildPreparationAlertCard(data.preparationAlerts[index]),

            if (index != data.preparationAlerts.length - 1)
              const SizedBox(height: 12),
          ],
        ],

        if (data.preparationAlerts.isNotEmpty &&
            data.activeReminders.isNotEmpty)
          const SizedBox(height: 26),

        if (data.activeReminders.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Personal Reminders',
            count: data.activeReminders.length,
          ),

          const SizedBox(height: 12),

          _buildReminderSection(reminders: data.activeReminders),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // COMPLETED CONTENT
  // ---------------------------------------------------------------------------

  Widget _buildCompletedContent(List<Reminder> reminders) {
    if (reminders.isEmpty) {
      return _buildEmptyState(
        title: 'No completed reminders',
        message:
            'Personal reminders marked as '
            'completed will appear here.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Completed Reminders',
          count: reminders.length,
        ),

        const SizedBox(height: 12),

        _buildReminderSection(reminders: reminders),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION HEADER
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader({required String title, required int count}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _darkTextColor,
            ),
          ),
        ),

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

  // ---------------------------------------------------------------------------
  // SYSTEM PREPARATION ALERT
  // ---------------------------------------------------------------------------

  Widget _buildPreparationAlertCard(_PreparationAlert alert) {
    final int incomplete = alert.total - alert.completed;

    final String destination = _formatText(alert.trip.destinationCountryId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0D8A8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4DC),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: Color(0xFFA86300),
                  size: 24,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$destination preparation incomplete',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _darkTextColor,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      incomplete == 1
                          ? '1 travel requirement is still incomplete.'
                          : '$incomplete travel requirements are still incomplete.',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE9BE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Action Needed',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF925800),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: Colors.black45,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    'Departure '
                    '${_formatDate(alert.trip.departureDate)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF486581),
                    ),
                  ),
                ),

                Text(
                  '${alert.completed}/${alert.total}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 13),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _openChecklist(alert);
              },
              icon: const Icon(Icons.checklist_rounded, size: 19),
              label: const Text(
                'View Checklist',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PERSONAL REMINDERS
  // ---------------------------------------------------------------------------

  Widget _buildReminderSection({required List<Reminder> reminders}) {
    return Column(
      children: [
        for (int index = 0; index < reminders.length; index++) ...[
          _buildReminderCard(reminders[index]),

          if (index != reminders.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    final bool overdue = _isOverdue(reminder);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: reminder.completed
                      ? const Color(0xFFEAF4EE)
                      : overdue
                      ? const Color(0xFFFDECEC)
                      : const Color(0xFFE8F6F7),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  reminder.completed
                      ? Icons.check_circle_outline_rounded
                      : overdue
                      ? Icons.schedule_rounded
                      : Icons.notifications_none_rounded,
                  color: reminder.completed
                      ? const Color(0xFF347A50)
                      : overdue
                      ? const Color(0xFFC62828)
                      : _primaryColor,
                  size: 24,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _darkTextColor,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      reminder.completed
                          ? 'Completed reminder'
                          : overdue
                          ? 'This reminder is overdue'
                          : 'Upcoming personal reminder',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: reminder.completed
                            ? const Color(0xFF347A50)
                            : overdue
                            ? const Color(0xFFC62828)
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              _buildReminderStatusBadge(reminder: reminder, overdue: overdue),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: Colors.black45,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    _formatDate(reminder.reminderAt),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF486581),
                    ),
                  ),
                ),

                const Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: Colors.black45,
                ),

                const SizedBox(width: 6),

                Text(
                  _formatTime(reminder.reminderAt),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF486581),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderStatusBadge({
    required Reminder reminder,
    required bool overdue,
  }) {
    late final String label;
    late final Color backgroundColor;
    late final Color textColor;

    if (reminder.completed) {
      label = 'Completed';

      backgroundColor = const Color(0xFFE4F3E9);

      textColor = const Color(0xFF347A50);
    } else if (overdue) {
      label = 'Overdue';

      backgroundColor = const Color(0xFFFDE7E7);

      textColor = const Color(0xFFC62828);
    } else {
      label = 'Upcoming';

      backgroundColor = const Color(0xFFDFF5EA);

      textColor = const Color(0xFF177245);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY / ERROR STATES
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState({required String title, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 34,
              color: _primaryColor,
            ),
          ),

          const SizedBox(height: 18),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _darkTextColor,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: const [
          SizedBox(height: 150),

          Icon(Icons.cloud_off_outlined, size: 58, color: Colors.black38),

          SizedBox(height: 18),

          Text(
            'Unable to load alerts',
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
}

// -----------------------------------------------------------------------------
// INTERNAL ALERT DATA
// -----------------------------------------------------------------------------

class _PreparationAlert {
  final Trip trip;
  final int completed;
  final int total;

  const _PreparationAlert({
    required this.trip,
    required this.completed,
    required this.total,
  });
}

class _AlertsData {
  final List<_PreparationAlert> preparationAlerts;

  final List<Reminder> activeReminders;

  final List<Reminder> completedReminders;

  const _AlertsData({
    required this.preparationAlerts,
    required this.activeReminders,
    required this.completedReminders,
  });
}
