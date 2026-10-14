import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../models/trip.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';
import '../services/trip_service.dart';
import '../theme/app_theme.dart';
import 'trip_details_screen.dart';

class TravellerAlertsScreen extends StatefulWidget {
  const TravellerAlertsScreen({super.key});

  @override
  State<TravellerAlertsScreen> createState() => _TravellerAlertsScreenState();
}

class _TravellerAlertsScreenState extends State<TravellerAlertsScreen>
    with WidgetsBindingObserver {
  final _tripService = TripService();
  final _reminderService = ReminderService();

  static const _preparationWindowDays = 30;

  _NotificationsData? _data;
  int _selectedTab = 0;
  int _requestId = 0;
  bool _loading = true;
  bool _refreshing = false;
  bool _openingTrip = false;
  bool _savingReminder = false;
  String? _error;
  String? _busyReminderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _busyReminderId == null &&
        !_openingTrip) {
      _load();
    }
  }

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  int _daysUntil(DateTime date) {
    final now = DateTime.now();
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  }

  Future<List<Reminder>?> _readReminders(String uid) async {
    try {
      return await _reminderService.getUserReminders(uid);
    } catch (error) {
      debugPrint('NOTIFICATION REMINDERS ERROR: $error');
      return null;
    }
  }

  Future<_NotificationsData> _fetchData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No authenticated traveller.');

    final results = await Future.wait<Object?>([
      _tripService.getUserTrips(user.uid),
      _readReminders(user.uid),
    ]);

    final trips =
        (results[0] as List<Trip>)
            .where((trip) => _daysUntil(trip.departureDate) >= 0)
            .toList()
          ..sort((a, b) => a.departureDate.compareTo(b.departureDate));

    final savedReminders = results[1] as List<Reminder>?;
    final tripMap = {for (final trip in trips) trip.id: trip};

    final reminders =
        (savedReminders ?? <Reminder>[])
            .where(
              (reminder) =>
                  !reminder.completed && tripMap.containsKey(reminder.tripId),
            )
            .map(
              (reminder) => _ReminderAlert(
                reminder: reminder,
                trip: tripMap[reminder.tripId]!,
              ),
            )
            .toList()
          ..sort(
            (a, b) => a.reminder.reminderAt.compareTo(b.reminder.reminderAt),
          );

    bool preparationUnavailable = false;

    final preparation = await Future.wait(
      trips
          .where(
            (trip) => _daysUntil(trip.departureDate) <= _preparationWindowDays,
          )
          .map((trip) async {
            try {
              final progress = await _tripService.getChecklistProgress(trip.id);
              final completed = progress['completed'] ?? 0;
              final total = progress['total'] ?? 0;

              if (total == 0 || completed >= total) return null;

              return _PreparationAlert(
                trip: trip,
                completed: completed,
                total: total,
              );
            } catch (error) {
              debugPrint('NOTIFICATION PREPARATION ERROR: $error');
              preparationUnavailable = true;
              return null;
            }
          }),
    );

    return _NotificationsData(
      reminders: reminders,
      preparation: preparation.whereType<_PreparationAlert>().toList(),
      remindersUnavailable: savedReminders == null,
      preparationUnavailable: preparationUnavailable,
    );
  }

  Future<bool> _load() async {
    if (!mounted) return false;
    final request = ++_requestId;

    setState(() {
      _loading = _data == null;
      _refreshing = _data != null;
      _error = null;
    });

    try {
      final data = await _fetchData();

      if (!mounted || request != _requestId) return false;

      setState(() {
        _data = data;
        _loading = false;
        _refreshing = false;
      });

      return true;
    } catch (error) {
      debugPrint('NOTIFICATIONS LOAD ERROR: $error');

      if (!mounted || request != _requestId) return false;

      setState(() {
        _error = _data == null
            ? 'Your notifications could not be loaded. Please try again.'
            : 'The screen could not refresh. Showing the last loaded information.';
        _loading = false;
        _refreshing = false;
      });

      return false;
    }
  }

  Future<void> _refresh() async {
    if (_busyReminderId != null || _openingTrip) return;
    await _load();
  }

  Future<void> _openTrip(Trip trip) async {
    if (_openingTrip || _busyReminderId != null) return;
    _openingTrip = true;

    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => TripDetailsScreen(trip: trip)),
      );

      if (mounted) await _load();
    } finally {
      _openingTrip = false;
    }
  }

  Future<void> _feedback(
    String title,
    String message, {
    bool warning = false,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        icon: Icon(
          warning ? Icons.info_outline_rounded : Icons.error_outline_rounded,
          color: warning ? AppColors.primary : AppColors.danger,
          size: 38,
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(Reminder reminder) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            scrollable: true,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.danger,
              size: 38,
            ),
            title: const Text('Delete reminder?', textAlign: TextAlign.center),
            content: Text(
              'Remove "${reminder.title}"?\n\nIts scheduled phone notification will also be cancelled.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _updateReminder(
    _ReminderAlert alert, {
    bool delete = false,
  }) async {
    if (_busyReminderId != null || _refreshing || _error != null) return;

    final reminder = alert.reminder;
    setState(() => _busyReminderId = reminder.id);

    bool saved = false;
    final action = delete ? 'deleted' : 'completed';

    try {
      if (delete && !await _confirmDelete(reminder)) return;
      if (!mounted) return;

      setState(() => _savingReminder = true);

      if (delete) {
        await _reminderService.deleteReminder(reminder.id);
      } else {
        await _reminderService.updateReminderCompletion(
          reminderId: reminder.id,
          completed: true,
        );
      }

      saved = true;

      // Cancel only after Firebase accepts the change, even if this page closes.
      bool cancelled = true;

      if (reminder.notificationId > 0) {
        try {
          await NotificationService.instance.cancelReminder(
            reminder.notificationId,
          );
        } catch (error) {
          cancelled = false;
          debugPrint('NOTIFICATION CANCELLATION ERROR: $error');
        }
      }

      if (!mounted) return;

      // Keep a successfully saved change visible even when a refresh fails.
      ++_requestId;

      setState(() {
        final data = _data!;
        _data = _NotificationsData(
          reminders: data.reminders
              .where((entry) => entry.reminder.id != reminder.id)
              .toList(),
          preparation: data.preparation,
          remindersUnavailable: data.remindersUnavailable,
          preparationUnavailable: data.preparationUnavailable,
        );
      });

      final refreshed = await _load();

      if (!mounted) return;
      setState(() => _savingReminder = false);

      if (!cancelled || !refreshed) {
        final messages = <String>[
          'The reminder was $action.',
          if (!cancelled)
            'Its scheduled phone notification could not be cancelled.',
          if (!refreshed)
            'The screen could not refresh. Pull down to try again.',
        ];

        await _feedback(
          'Reminder $action',
          messages.join('\n\n'),
          warning: true,
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Reminder $action.')));
      }
    } catch (error) {
      debugPrint('REMINDER ACTION ERROR: $error');

      if (mounted) setState(() => _savingReminder = false);

      await _feedback(
        saved
            ? 'Reminder $action'
            : 'Unable to ${delete ? 'delete' : 'complete'} reminder',
        saved
            ? 'Your change was saved. Pull down to refresh the screen.'
            : 'The change could not be saved. Check your connection and try again.',
        warning: saved,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyReminderId = null;
          _savingReminder = false;
        });
      }
    }
  }

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

  bool get _actionsEnabled =>
      _busyReminderId == null && !_refreshing && _error == null;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Loading notifications',
        ),
      );
    }

    final data = _data;

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Text(
                'Stay one step ahead.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your personal reminders and upcoming travel requirements, together.',
              ),
              const SizedBox(height: 22),
              if (_refreshing) ...[
                const LinearProgressIndicator(minHeight: 3),
                const SizedBox(height: 16),
              ],
              if (_error != null) ...[
                _notice(_error!),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busyReminderId == null ? _refresh : null,
                  child: const Text('Try again'),
                ),
                const SizedBox(height: 20),
              ],
              if (data != null) ...[
                _tabs(data),
                const SizedBox(height: 22),
                if (_selectedTab == 0)
                  ..._reminderContent(data)
                else
                  ..._preparationContent(data),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabs(_NotificationsData data) => LayoutBuilder(
    builder: (context, constraints) {
      final buttons = [
        _tab(
          0,
          'Reminders',
          data.remindersUnavailable ? null : data.reminders.length,
        ),
        _tab(
          1,
          'Preparation',
          data.preparationUnavailable ? null : data.preparation.length,
        ),
      ];

      if (MediaQuery.textScalerOf(context).scale(14) > 20 ||
          constraints.maxWidth < 280) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [buttons[0], const SizedBox(height: 10), buttons[1]],
        );
      }

      return Row(
        children: [
          Expanded(child: buttons[0]),
          const SizedBox(width: 10),
          Expanded(child: buttons[1]),
        ],
      );
    },
  );

  Widget _tab(int index, String label, int? count) {
    final selected = _selectedTab == index;
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations || media.accessibleNavigation;

    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _selectedTab = index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Text(
                count == null ? label : '$label ($count)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.secondaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _reminderContent(_NotificationsData data) {
    final now = DateTime.now();
    final overdue = <_ReminderAlert>[];
    final today = <_ReminderAlert>[];
    final upcoming = <_ReminderAlert>[];

    for (final entry in data.reminders) {
      final time = entry.reminder.reminderAt;

      if (time.isBefore(now)) {
        overdue.add(entry);
      } else if (_day(time) == _day(now)) {
        today.add(entry);
      } else {
        upcoming.add(entry);
      }
    }

    return [
      const Text(
        'Reminders you added from Trip Details appear here until completed.',
      ),
      const SizedBox(height: 16),
      if (data.remindersUnavailable)
        _notice('Personal reminders could not load. Pull down to try again.'),
      if (data.reminders.isEmpty && !data.remindersUnavailable)
        _empty(
          Icons.notifications_none_rounded,
          'No pending reminders',
          'Open a trip from Trips and use its reminder icon to add a personal reminder.',
        ),
      ..._reminderGroup('Overdue', overdue, overdue: true),
      ..._reminderGroup('Today', today),
      ..._reminderGroup('Upcoming', upcoming),
    ];
  }

  List<Widget> _reminderGroup(
    String title,
    List<_ReminderAlert> entries, {
    bool overdue = false,
  }) {
    if (entries.isEmpty) return [];

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          '$title (${entries.length})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      for (final entry in entries) ...[
        _reminderCard(entry, overdue: overdue),
        const SizedBox(height: 14),
      ],
    ];
  }

  Widget _reminderCard(_ReminderAlert alert, {required bool overdue}) {
    final reminder = alert.reminder;
    final busy = _busyReminderId == reminder.id && _savingReminder;
    final time = TimeOfDay.fromDateTime(reminder.reminderAt).format(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cardTitle(
              overdue
                  ? Icons.schedule_rounded
                  : Icons.notifications_none_rounded,
              reminder.title,
              '${_label(alert.trip.destinationCountryId)} · ${_label(alert.trip.purpose)}',
            ),
            const SizedBox(height: 14),
            _tag(
              overdue
                  ? 'Overdue'
                  : _daysUntil(reminder.reminderAt) == 0
                  ? 'Today'
                  : 'Upcoming',
              warm: overdue,
            ),
            const SizedBox(height: 12),
            Text('${_date(reminder.reminderAt)} · $time'),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _actionsEnabled ? () => _updateReminder(alert) : null,
              child: Text(
                busy ? 'Updating…' : 'Mark as complete',
                textAlign: TextAlign.center,
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _actionsEnabled
                      ? () => _openTrip(alert.trip)
                      : null,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('View trip'),
                ),
                TextButton.icon(
                  onPressed: _actionsEnabled
                      ? () => _updateReminder(alert, delete: true)
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _preparationContent(_NotificationsData data) => [
    const Text(
      'Trips departing within the next 30 days appear here when requirements remain unchecked.',
    ),
    const SizedBox(height: 16),
    if (data.preparationUnavailable) ...[
      _notice(
        'Some preparation alerts could not load. Pull down to try again.',
      ),
      const SizedBox(height: 14),
    ],
    if (data.preparation.isEmpty && !data.preparationUnavailable)
      _empty(
        Icons.fact_check_outlined,
        'No preparation alerts',
        'No unchecked requirements were found for trips departing within the next 30 days.',
      ),
    for (final alert in data.preparation) ...[
      _preparationCard(alert),
      const SizedBox(height: 14),
    ],
  ];

  Widget _preparationCard(_PreparationAlert alert) {
    final trip = alert.trip;
    final days = _daysUntil(trip.departureDate);
    final progress = (alert.completed / alert.total).clamp(0.0, 1.0);
    final remaining = alert.total - alert.completed;

    final departure = days == 0
        ? 'Departs today'
        : days == 1
        ? 'Departs tomorrow'
        : 'Departs in $days days';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cardTitle(
              Icons.fact_check_outlined,
              _label(trip.destinationCountryId),
              '${_date(trip.departureDate)} · ${_label(trip.purpose)}',
            ),
            const SizedBox(height: 14),
            _tag(departure, warm: days <= 7),
            const SizedBox(height: 16),
            Text(
              '$remaining requirement${remaining == 1 ? '' : 's'} still to check',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: AppColors.primaryLight,
                semanticsLabel: 'Requirements completed',
              ),
            ),
            const SizedBox(height: 8),
            Text('${alert.completed} of ${alert.total} requirements checked'),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _actionsEnabled ? () => _openTrip(trip) : null,
              child: const Text(
                'Review trip requirements',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardTitle(IconData icon, String title, String subtitle) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: AppColors.primary, size: 24),
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
    ],
  );

  Widget _tag(String text, {bool warm = false}) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: warm ? const Color(0xFFFFEAD7) : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  Widget _notice(String text) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEAD7),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );

  Widget _empty(IconData icon, String title, String description) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(description, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _ReminderAlert {
  const _ReminderAlert({required this.reminder, required this.trip});

  final Reminder reminder;
  final Trip trip;
}

class _PreparationAlert {
  const _PreparationAlert({
    required this.trip,
    required this.completed,
    required this.total,
  });

  final Trip trip;
  final int completed;
  final int total;
}

class _NotificationsData {
  const _NotificationsData({
    required this.reminders,
    required this.preparation,
    this.remindersUnavailable = false,
    this.preparationUnavailable = false,
  });

  final List<_ReminderAlert> reminders;
  final List<_PreparationAlert> preparation;
  final bool remindersUnavailable;
  final bool preparationUnavailable;
}
