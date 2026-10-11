import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../services/reminder_service.dart';

class TravellerAlertsScreen extends StatefulWidget {
  const TravellerAlertsScreen({super.key});

  @override
  State<TravellerAlertsScreen> createState() => _TravellerAlertsScreenState();
}

class _TravellerAlertsScreenState extends State<TravellerAlertsScreen> {
  final ReminderService _reminderService = ReminderService();

  late Future<List<Reminder>> _remindersFuture;

  String _selectedFilter = 'upcoming';

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

  @override
  void initState() {
    super.initState();

    _remindersFuture = _loadReminders();
  }

  // ---------------------------------------------------------------------------
  // REMINDER DATA
  // ---------------------------------------------------------------------------

  Future<List<Reminder>> _loadReminders() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user was found.');
    }

    return _reminderService.getUserReminders(currentUser.uid);
  }

  Future<void> _refresh() async {
    final Future<List<Reminder>> refreshed = _loadReminders();

    setState(() {
      _remindersFuture = refreshed;
    });

    await refreshed;
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
        child: FutureBuilder<List<Reminder>>(
          future: _remindersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildErrorState();
            }

            final List<Reminder> reminders = snapshot.data ?? [];

            final List<Reminder> upcomingReminders = reminders
                .where((reminder) => !reminder.completed)
                .toList();

            final List<Reminder> completedReminders = reminders
                .where((reminder) => reminder.completed)
                .toList();

            upcomingReminders.sort(
              (first, second) => first.reminderAt.compareTo(second.reminderAt),
            );

            completedReminders.sort(
              (first, second) => second.reminderAt.compareTo(first.reminderAt),
            );

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
                children: [
                  _buildHeader(),

                  const SizedBox(height: 22),

                  _buildFilterRow(
                    upcomingCount: upcomingReminders.length,
                    completedCount: completedReminders.length,
                  ),

                  const SizedBox(height: 18),

                  if (_selectedFilter == 'upcoming')
                    _buildReminderSection(
                      reminders: upcomingReminders,
                      emptyTitle: 'No upcoming reminders',
                      emptyMessage:
                          'Travel preparation reminders '
                          'for your upcoming trips will '
                          'appear here.',
                    )
                  else
                    _buildReminderSection(
                      reminders: completedReminders,
                      emptyTitle: 'No completed reminders',
                      emptyMessage:
                          'Reminders marked as completed '
                          'will appear here.',
                    ),
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
            child: Icon(
              Icons.notifications_active_outlined,
              color: _primaryColor,
              size: 29,
            ),
          ),

          SizedBox(width: 14),

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
                  'Keep track of travel preparation '
                  'reminders for your saved trips.',
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
  // REMINDER LIST
  // ---------------------------------------------------------------------------

  Widget _buildReminderSection({
    required List<Reminder> reminders,
    required String emptyTitle,
    required String emptyMessage,
  }) {
    if (reminders.isEmpty) {
      return _buildEmptyState(title: emptyTitle, message: emptyMessage);
    }

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
                          : 'Upcoming travel reminder',
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

              _buildStatusBadge(reminder: reminder, overdue: overdue),
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

  Widget _buildStatusBadge({
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
            'Unable to load reminders',
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
