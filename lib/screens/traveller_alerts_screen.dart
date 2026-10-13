import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../models/trip.dart';
import '../services/reminder_service.dart';
import '../services/trip_service.dart';
import 'checklist_screen.dart';
import 'trip_details_screen.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

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

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

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

  Future<void> _showReminderFeedback({
    required String title,
    required String message,
    required IconData icon,
    Color iconColor = AppColors.primary,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: iconColor == AppColors.danger
                  ? const Color(0xFFFFECEB)
                  : const Color(0xFFFFF4DC),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: iconColor, size: 29),
          ),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('OK'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completeReminder(_ReminderAlert alert) async {
    final Reminder reminder = alert.reminder;

    if (_busyReminderIds.contains(reminder.id)) {
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() {
      _busyReminderIds.add(reminder.id);
    });

    bool reminderCompleted = false;
    bool notificationCancelled = true;

    try {
      // Mark the reminder as completed in Firestore.
      await _reminderService.updateReminderCompletion(
        reminderId: reminder.id,
        completed: true,
      );

      reminderCompleted = true;

      // Cancel the matching scheduled Android notification.
      try {
        await NotificationService.instance.cancelReminder(
          reminder.notificationId,
        );
      } catch (error) {
        notificationCancelled = false;

        debugPrint('CANCEL COMPLETED REMINDER NOTIFICATION ERROR: $error');
      }

      if (!mounted) return;

      await _refresh();

      if (!mounted) return;

      if (notificationCancelled) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Reminder completed successfully.')),
        );
      } else {
        await _showReminderFeedback(
          title: 'Reminder Completed',
          message:
              'The reminder was completed, but its scheduled '
              'phone notification could not be cancelled. '
              'Please review your notification settings.',
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFA86300),
        );
      }
    } catch (error) {
      await _showReminderFeedback(
        title: reminderCompleted
            ? 'Reminder Completed'
            : 'Unable to Complete Reminder',
        message: reminderCompleted
            ? 'The reminder was completed, but the alerts '
                  'list could not refresh. Please try refreshing '
                  'the screen.'
            : 'The reminder could not be completed. '
                  'Please check your connection and try again.',
        icon: reminderCompleted
            ? Icons.warning_amber_rounded
            : Icons.error_outline_rounded,
        iconColor: reminderCompleted
            ? const Color(0xFFA86300)
            : AppColors.danger,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyReminderIds.remove(reminder.id);
        });
      }
    }
  }

  Future<void> _deleteReminder(_ReminderAlert alert) async {
    final Reminder reminder = alert.reminder;

    if (_busyReminderIds.contains(reminder.id)) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFFFECEB),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.danger,
              size: 29,
            ),
          ),

          title: const Text('Delete Reminder?', textAlign: TextAlign.center),

          content: Text(
            'Are you sure you want to delete '
            '"${reminder.title}"?\n\n'
            'This reminder will be permanently removed. '
            'Its scheduled phone notification will also '
            'be cancelled.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
              height: 1.5,
            ),
          ),

          actionsAlignment: MainAxisAlignment.center,

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),

            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete'),
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
      _busyReminderIds.add(reminder.id);
    });

    bool reminderDeleted = false;
    bool notificationCancelled = true;

    try {
      // Delete the reminder document from Firestore.
      await _reminderService.deleteReminder(reminder.id);

      reminderDeleted = true;

      // Cancel the corresponding Android notification.
      try {
        await NotificationService.instance.cancelReminder(
          reminder.notificationId,
        );
      } catch (error) {
        notificationCancelled = false;

        debugPrint('CANCEL DELETED REMINDER NOTIFICATION ERROR: $error');
      }

      if (!mounted) return;

      await _refresh();

      if (!mounted) return;

      if (notificationCancelled) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Reminder deleted successfully.')),
        );
      } else {
        await _showReminderFeedback(
          title: 'Reminder Deleted',
          message:
              'The reminder was deleted, but its scheduled '
              'phone notification could not be cancelled. '
              'Please review your notification settings.',
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFA86300),
        );
      }
    } catch (error) {
      await _showReminderFeedback(
        title: reminderDeleted
            ? 'Reminder Deleted'
            : 'Unable to Delete Reminder',
        message: reminderDeleted
            ? 'The reminder was deleted, but the alerts '
                  'list could not refresh. Please try refreshing '
                  'the screen.'
            : 'The reminder could not be deleted. '
                  'Please check your connection and try again.',
        icon: reminderDeleted
            ? Icons.warning_amber_rounded
            : Icons.error_outline_rounded,
        iconColor: reminderDeleted ? const Color(0xFFA86300) : AppColors.danger,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyReminderIds.remove(reminder.id);
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
              return _buildLoadingState();
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
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
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.primary,
                  size: 27,
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
                        color: AppColors.navy,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    SizedBox(height: 6),

                    Text(
                      'Stay informed about your trip preparation '
                      'and personal reminders.',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 15),

          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppColors.primary,
                size: 18,
              ),

              SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Preparation alerts appear for trips departing '
                  'within the next 30 days when travel '
                  'requirements remain incomplete.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
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

    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        await _changeTab(value);
      },
      child: AnimatedContainer(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
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
                  color: selected ? AppColors.primary : AppColors.secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            const SizedBox(width: 8),

            Container(
              constraints: const BoxConstraints(minWidth: 24),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? Colors.white : AppColors.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
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
    final String destination = _formatText(alert.trip.destinationCountryId);

    final int remaining = alert.total - alert.completed;

    final double progress = alert.total == 0
        ? 0
        : (alert.completed / alert.total).clamp(0.0, 1.0);

    final int percentage = (progress * 100).round();

    // ---------------------------------------------------------
    // DEPARTURE COUNTDOWN
    // ---------------------------------------------------------

    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);

    final DateTime departure = DateTime(
      alert.trip.departureDate.year,
      alert.trip.departureDate.month,
      alert.trip.departureDate.day,
    );

    final int daysRemaining = departure.difference(today).inDays;

    final bool isUrgent = daysRemaining <= 7;

    final String departureStatus = daysRemaining == 0
        ? 'Departs Today'
        : daysRemaining == 1
        ? '1 Day Left'
        : '$daysRemaining Days Left';

    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUrgent ? const Color(0xFFF0D8A8) : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------------------------------------------
          // DESTINATION AND ALERT TITLE
          // ---------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isUrgent
                      ? const Color(0xFFFFF4DC)
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.fact_check_outlined,
                  color: isUrgent ? const Color(0xFFA86300) : AppColors.primary,
                  size: 24,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 5),

                    const Text(
                      'Travel preparation incomplete',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ---------------------------------------------------
          // DEPARTURE STATUS
          // ---------------------------------------------------
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? const Color(0xFFFFF4DC)
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 15,
                      color: isUrgent
                          ? const Color(0xFFA86300)
                          : AppColors.primary,
                    ),

                    const SizedBox(width: 6),

                    Text(
                      departureStatus,
                      style: TextStyle(
                        color: isUrgent
                            ? const Color(0xFFA86300)
                            : AppColors.primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  remaining == 1
                      ? '1 requirement left'
                      : '$remaining requirements left',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 17),

          // ---------------------------------------------------
          // CHECKLIST PROGRESS
          // ---------------------------------------------------
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Checklist Progress',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              Text(
                '$percentage%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 11),

          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, animatedProgress, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: animatedProgress,
                  minHeight: 9,
                  backgroundColor: const Color(0xFFE5EEF0),
                  color: AppColors.primary,
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          Text(
            '${alert.completed} of ${alert.total} requirements completed',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 18),

          // ---------------------------------------------------
          // DEPARTURE DATE
          // ---------------------------------------------------
          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: AppColors.primary,
                size: 18,
              ),

              const SizedBox(width: 9),

              Expanded(
                child: Text(
                  'Departure: ${_formatDate(alert.trip.departureDate)}',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          // ---------------------------------------------------
          // VIEW CHECKLIST BUTTON
          // ---------------------------------------------------
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _openChecklist(alert);
              },
              icon: const Icon(Icons.checklist_rounded, size: 19),
              label: const Text('View Checklist'),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: overdue ? const Color(0xFFE7B8B8) : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -----------------------------------------------------
          // REMINDER HEADER
          // -----------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: overdue
                      ? const Color(0xFFFDECEC)
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  overdue
                      ? Icons.notification_important_outlined
                      : Icons.notifications_none_rounded,
                  color: overdue ? AppColors.danger : AppColors.primary,
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
                        color: AppColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      destination,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // -----------------------------------------------------
          // REMINDER STATUS
          // -----------------------------------------------------
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: overdue
                      ? const Color(0xFFFDECEC)
                      : const Color(0xFFEAF7F1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      overdue
                          ? Icons.warning_amber_rounded
                          : Icons.schedule_outlined,
                      color: overdue ? AppColors.danger : AppColors.success,
                      size: 16,
                    ),

                    const SizedBox(width: 6),

                    Text(
                      overdue ? 'Overdue' : 'Upcoming',
                      style: TextStyle(
                        color: overdue ? AppColors.danger : AppColors.success,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          // -----------------------------------------------------
          // REMINDER DATE AND TIME
          // -----------------------------------------------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REMINDER SCHEDULE',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 18,
                  runSpacing: 10,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          color: AppColors.primary,
                          size: 18,
                        ),

                        const SizedBox(width: 8),

                        Text(
                          _formatDate(reminder.reminderAt),
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),

                        const SizedBox(width: 8),

                        Text(
                          _formatTime(reminder.reminderAt),
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 17),

          // -----------------------------------------------------
          // COMPLETE REMINDER
          // -----------------------------------------------------
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy
                  ? null
                  : () {
                      _completeReminder(alert);
                    },
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 19),
              label: Text(busy ? 'Updating Reminder...' : 'Mark as Complete'),
            ),
          ),

          const SizedBox(height: 10),

          // -----------------------------------------------------
          // VIEW TRIP AND DELETE ACTIONS
          // -----------------------------------------------------
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () {
                            _openTrip(alert);
                          },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('View Trip'),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              SizedBox(
                width: 48,
                height: 48,
                child: IconButton.outlined(
                  tooltip: 'Delete reminder',
                  onPressed: busy
                      ? null
                      : () {
                          _deleteReminder(alert);
                        },
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
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

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.primary,
                size: 34,
              ),
            ),

            const SizedBox(height: 23),

            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),

            const SizedBox(height: 19),

            const Text(
              'Loading Travel Alerts',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Checking your preparation alerts '
              'and personal reminders...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(23),
            ),
            child: Icon(icon, color: AppColors.primary, size: 35),
          ),

          const SizedBox(height: 19),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 9),

          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12.5,
              height: 1.55,
            ),
          ),

          const SizedBox(height: 20),

          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.swipe_down_alt_rounded,
                color: AppColors.primary,
                size: 18,
              ),

              SizedBox(width: 7),

              Flexible(
                child: Text(
                  'Pull down to refresh',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.cloud_off_outlined,
                        color: AppColors.primary,
                        size: 36,
                      ),
                    ),

                    const SizedBox(height: 21),

                    const Text(
                      'Unable to Load Alerts',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Your travel alerts could not be retrieved. '
                      'Please check your internet connection '
                      'and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 23),

                    SizedBox(
                      width: 180,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _refresh();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 19),
                        label: const Text('Try Again'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
