import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../models/trip.dart';
import '../services/reminder_service.dart';
import '../services/trip_service.dart';
import 'checklist_screen.dart';
import 'trip_details_screen.dart';

class TravellerAlertsScreen extends StatefulWidget {
  const TravellerAlertsScreen({super.key});

  @override
  State<TravellerAlertsScreen> createState() => _TravellerAlertsScreenState();
}

class _TravellerAlertsScreenState extends State<TravellerAlertsScreen> {
  final TripService _tripService = TripService();

  final ReminderService _reminderService = ReminderService();

  late Future<_AlertsData> _alertsFuture;

  String _selectedTab = 'upcoming';

  final Set<String> _busyReminderIds = <String>{};

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
  // DATA
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

    activeTrips.sort(
      (first, second) => first.departureDate.compareTo(second.departureDate),
    );

    // Only near-term trips generate automatic
    // checklist preparation alerts.
    final List<Trip> preparationTrips = activeTrips
        .where(_isWithinPreparationAlertWindow)
        .toList();

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

    // Map trips by ID so each reminder can
    // display its related destination.
    final Map<String, Trip> activeTripMap = {
      for (final Trip trip in activeTrips) trip.id: trip,
    };

    // Only incomplete reminders belonging to
    // current/upcoming trips appear.
    final List<_ReminderAlert> reminderAlerts = reminders
        .where(
          (reminder) =>
              !reminder.completed && activeTripMap.containsKey(reminder.tripId),
        )
        .map(
          (reminder) => _ReminderAlert(
            reminder: reminder,
            trip: activeTripMap[reminder.tripId]!,
          ),
        )
        .toList();

    reminderAlerts.sort(
      (first, second) =>
          first.reminder.reminderAt.compareTo(second.reminder.reminderAt),
    );

    return _AlertsData(
      preparationAlerts: preparationAlerts,
      reminderAlerts: reminderAlerts,
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
  // DATE LOGIC
  // ---------------------------------------------------------------------------

  bool _isPastTrip(Trip trip) {
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);

    final DateTime departure = DateTime(
      trip.departureDate.year,
      trip.departureDate.month,
      trip.departureDate.day,
    );

    // Departure today is still active.
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

  bool _isReminderOverdue(Reminder reminder) {
    return reminder.reminderAt.isBefore(DateTime.now());
  }

  // ---------------------------------------------------------------------------
  // TAB
  // ---------------------------------------------------------------------------

  Future<void> _changeTab(String tab) async {
    if (_selectedTab != tab) {
      setState(() {
        _selectedTab = tab;
      });
    }

    // Reload when the user changes tabs so newly
    // created reminders are picked up.
    await _refresh();
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

  Future<void> _openTrip(_ReminderAlert alert) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripDetailsScreen(trip: alert.trip),
      ),
    );

    if (!mounted) return;

    await _refresh();
  }

  // ---------------------------------------------------------------------------
  // REMINDER ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _completeReminder(_ReminderAlert alert) async {
    final String reminderId = alert.reminder.id;

    if (_busyReminderIds.contains(reminderId)) {
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() {
      _busyReminderIds.add(reminderId);
    });

    try {
      await _reminderService.updateReminderCompletion(
        reminderId: reminderId,
        completed: true,
      );

      if (!mounted) return;

      await _refresh();

      messenger.showSnackBar(
        const SnackBar(content: Text('Reminder completed.')),
      );
    } catch (error) {
      debugPrint('COMPLETE REMINDER ERROR: $error');

      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to complete reminder.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyReminderIds.remove(reminderId);
        });
      }
    }
  }

  Future<void> _deleteReminder(_ReminderAlert alert) async {
    final String reminderId = alert.reminder.id;

    if (_busyReminderIds.contains(reminderId)) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Color(0xFFC62828),
            size: 32,
          ),
          title: const Text('Delete Reminder?'),
          content: const Text(
            'This personal reminder will be '
            'permanently deleted.',
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

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() {
      _busyReminderIds.add(reminderId);
    });

    try {
      await _reminderService.deleteReminder(reminderId);

      if (!mounted) return;

      await _refresh();

      messenger.showSnackBar(
        const SnackBar(content: Text('Reminder deleted.')),
      );
    } catch (error) {
      debugPrint('DELETE REMINDER ERROR: $error');

      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to delete reminder.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyReminderIds.remove(reminderId);
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // FORMATTERS
  // ---------------------------------------------------------------------------

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

  String _formatTime(DateTime date) {
    final int hour = date.hour;

    final String period = hour >= 12 ? 'PM' : 'AM';

    final int displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;

    final String minute = date.minute.toString().padLeft(2, '0');

    return '$displayHour:$minute $period';
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
              debugPrint(
                'TRAVELLER ALERTS ERROR: '
                '${snapshot.error}',
              );

              return _buildErrorState();
            }

            final _AlertsData data =
                snapshot.data ??
                const _AlertsData(preparationAlerts: [], reminderAlerts: []);

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
                children: [
                  _buildHeader(),

                  const SizedBox(height: 20),

                  _buildTabRow(
                    upcomingCount: data.preparationAlerts.length,
                    reminderCount: data.reminderAlerts.length,
                  ),

                  const SizedBox(height: 22),

                  if (_selectedTab == 'upcoming')
                    _buildUpcomingContent(data.preparationAlerts)
                  else
                    _buildReminderContent(data.reminderAlerts),
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
      child: const Row(
        children: [
          Icon(
            Icons.notifications_active_outlined,
            color: _primaryColor,
            size: 32,
          ),

          SizedBox(width: 14),

          Expanded(
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
                  'Review preparation alerts and '
                  'personal trip reminders.',
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
  // TABS
  // ---------------------------------------------------------------------------

  Widget _buildTabRow({
    required int upcomingCount,
    required int reminderCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildTabButton(
            value: 'upcoming',
            label: 'Upcoming',
            count: upcomingCount,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _buildTabButton(
            value: 'reminders',
            label: 'Reminders',
            count: reminderCount,
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required String value,
    required String label,
    required int count,
  }) {
    final bool selected = _selectedTab == value;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        await _changeTab(value);
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
  // UPCOMING PREPARATION ALERTS
  // ---------------------------------------------------------------------------

  Widget _buildUpcomingContent(List<_PreparationAlert> alerts) {
    if (alerts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.fact_check_outlined,
        title: 'No preparation alerts',
        message:
            'Your upcoming trips currently have '
            'no outstanding preparation alerts.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preparation Alerts',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _darkTextColor,
          ),
        ),

        const SizedBox(height: 5),

        const Text(
          'One alert is shown for each near-term trip '
          'with incomplete travel requirements.',
          style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black54),
        ),

        const SizedBox(height: 14),

        for (int index = 0; index < alerts.length; index++) ...[
          _buildPreparationCard(alerts[index]),

          if (index != alerts.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildPreparationCard(_PreparationAlert alert) {
    final int incomplete = alert.total - alert.completed;

    final String destination = _formatText(alert.trip.destinationCountryId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0D8A8)),
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
            ],
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: Colors.black45,
              ),

              const SizedBox(width: 7),

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

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _openChecklist(alert);
              },
              icon: const Icon(Icons.checklist_rounded),
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
  // REMINDERS
  // ---------------------------------------------------------------------------

  Widget _buildReminderContent(List<_ReminderAlert> alerts) {
    if (alerts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.add_alert_outlined,
        title: 'No active reminders',
        message:
            'Use the reminder icon in Trip Details '
            'to create a personal reminder.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personal Reminders',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _darkTextColor,
          ),
        ),

        const SizedBox(height: 5),

        const Text(
          'Reminders created from your active trips '
          'appear here once each.',
          style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black54),
        ),

        const SizedBox(height: 14),

        for (int index = 0; index < alerts.length; index++) ...[
          _buildReminderCard(alerts[index]),

          if (index != alerts.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildReminderCard(_ReminderAlert alert) {
    final Reminder reminder = alert.reminder;

    final bool overdue = _isReminderOverdue(reminder);

    final bool busy = _busyReminderIds.contains(reminder.id);

    final String destination = _formatText(alert.trip.destinationCountryId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: overdue ? const Color(0xFFE7B8B8) : _borderColor,
        ),
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
                  color: overdue
                      ? const Color(0xFFFDECEC)
                      : const Color(0xFFE8F6F7),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  overdue
                      ? Icons.notification_important_outlined
                      : Icons.notifications_none_rounded,
                  color: overdue ? const Color(0xFFC62828) : _primaryColor,
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
                      destination,
                      style: const TextStyle(
                        fontSize: 12.5,
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
                  color: overdue
                      ? const Color(0xFFFDE7E7)
                      : const Color(0xFFDFF5EA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  overdue ? 'Overdue' : 'Upcoming',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: overdue
                        ? const Color(0xFFC62828)
                        : const Color(0xFF177245),
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

                const SizedBox(width: 7),

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

          const SizedBox(height: 13),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          _openTrip(alert);
                        },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('View Trip', maxLines: 1),
                ),
              ),

              const SizedBox(width: 8),

              IconButton.outlined(
                tooltip: 'Complete reminder',
                onPressed: busy
                    ? null
                    : () {
                        _completeReminder(alert);
                      },
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 19),
              ),

              const SizedBox(width: 8),

              IconButton.outlined(
                tooltip: 'Delete reminder',
                onPressed: busy
                    ? null
                    : () {
                        _deleteReminder(alert);
                      },
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: Color(0xFFC62828),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY / ERROR
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
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
            child: Icon(icon, size: 34, color: _primaryColor),
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
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 130),

          Icon(Icons.cloud_off_outlined, size: 56, color: Colors.black38),

          SizedBox(height: 18),

          Text(
            'Unable to load alerts',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
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
// INTERNAL DATA
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

class _ReminderAlert {
  final Reminder reminder;

  final Trip trip;

  const _ReminderAlert({required this.reminder, required this.trip});
}

class _AlertsData {
  final List<_PreparationAlert> preparationAlerts;

  final List<_ReminderAlert> reminderAlerts;

  const _AlertsData({
    required this.preparationAlerts,
    required this.reminderAlerts,
  });
}
