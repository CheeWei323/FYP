import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../services/trip_service.dart';
import 'checklist_screen.dart';
import 'edit_trip_screen.dart';
import 'packing_screen.dart';
import '../services/reminder_service.dart';

class TripDetailsScreen extends StatefulWidget {
  final Trip trip;

  const TripDetailsScreen({super.key, required this.trip});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  final TripService _tripService = TripService();

  final ReminderService _reminderService = ReminderService();

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

  late Trip _trip;

  late Future<Map<String, int>> _progressFuture;

  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();

    _trip = widget.trip;

    _progressFuture = _loadProgress();
  }

  Future<Map<String, int>> _loadProgress() {
    return _tripService.getChecklistProgress(_trip.id);
  }

  Future<void> _refreshProgress() async {
    final Future<Map<String, int>> refreshed = _loadProgress();

    setState(() {
      _progressFuture = refreshed;
    });

    await refreshed;
  }

  Future<void> _openChecklist() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChecklistScreen(tripId: _trip.id),
      ),
    );

    if (!mounted) return;

    await _refreshProgress();
  }

  Future<void> _openPackingList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PackingScreen(trip: _trip)),
    );
  }

  Future<void> _addReminder() async {
    if (_isPastTrip) {
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final DateTime now = DateTime.now();

    final DateTime departureEnd = _departureEnd;

    if (!departureEnd.isAfter(now)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No future reminder time is available '
            'for this trip.',
          ),
        ),
      );

      return;
    }

    String reminderTitle = '';

    DateTime selectedDateTime = now.add(const Duration(hours: 1));

    if (selectedDateTime.isAfter(departureEnd)) {
      selectedDateTime = now.add(const Duration(minutes: 5));
    }

    bool isSaving = false;

    final bool? saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> selectDate() async {
              final DateTime today = DateTime(now.year, now.month, now.day);

              final DateTime lastDate = DateTime(
                _trip.departureDate.year,
                _trip.departureDate.month,
                _trip.departureDate.day,
              );

              final DateTime selectedDay = DateTime(
                selectedDateTime.year,
                selectedDateTime.month,
                selectedDateTime.day,
              );

              final DateTime initialDate = selectedDay.isAfter(lastDate)
                  ? lastDate
                  : selectedDay;

              final DateTime? picked = await showDatePicker(
                context: dialogContext,
                initialDate: initialDate,
                firstDate: today,
                lastDate: lastDate,
              );

              if (picked == null || !dialogContext.mounted) {
                return;
              }

              setDialogState(() {
                selectedDateTime = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  selectedDateTime.hour,
                  selectedDateTime.minute,
                );
              });
            }

            Future<void> selectTime() async {
              final TimeOfDay? picked = await showTimePicker(
                context: dialogContext,
                initialTime: TimeOfDay.fromDateTime(selectedDateTime),
              );

              if (picked == null || !dialogContext.mounted) {
                return;
              }

              setDialogState(() {
                selectedDateTime = DateTime(
                  selectedDateTime.year,
                  selectedDateTime.month,
                  selectedDateTime.day,
                  picked.hour,
                  picked.minute,
                );
              });
            }

            return AlertDialog(
              icon: const Icon(
                Icons.add_alert_outlined,
                color: _primaryColor,
                size: 32,
              ),
              title: const Text('Add Trip Reminder'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_formatText(_trip.destinationCountryId)}'
                      ' • '
                      '${_formatDate(_trip.departureDate)}',
                      style: const TextStyle(color: Colors.black54),
                    ),

                    const SizedBox(height: 18),

                    TextFormField(
                      maxLength: 120,
                      enabled: !isSaving,
                      onChanged: (value) {
                        reminderTitle = value;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Reminder',
                        hintText: 'e.g. Review passport documents',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 6),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isSaving ? null : selectDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(_formatDate(selectedDateTime)),
                      ),
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isSaving ? null : selectTime,
                        icon: const Icon(Icons.access_time_rounded),
                        label: Text(_formatTime(selectedDateTime)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          Navigator.pop(dialogContext, false);
                        },
                  child: const Text('Cancel'),
                ),

                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final String title = reminderTitle.trim();

                          if (title.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Enter a reminder title.'),
                              ),
                            );

                            return;
                          }

                          final DateTime current = DateTime.now();

                          if (!selectedDateTime.isAfter(current)) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Select a future reminder '
                                  'date and time.',
                                ),
                              ),
                            );

                            return;
                          }

                          if (selectedDateTime.isAfter(departureEnd)) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'The reminder must be '
                                  'scheduled on or before '
                                  'the departure date.',
                                ),
                              ),
                            );

                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            await _reminderService.createReminder(
                              userId: _trip.userId,
                              tripId: _trip.id,
                              title: title,
                              reminderAt: selectedDateTime,
                            );

                            if (!dialogContext.mounted) {
                              return;
                            }

                            Navigator.pop(dialogContext, true);
                          } catch (error) {
                            debugPrint(
                              'CREATE REMINDER ERROR: '
                              '$error',
                            );

                            if (!dialogContext.mounted) {
                              return;
                            }

                            setDialogState(() {
                              isSaving = false;
                            });

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Unable to create reminder.'),
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || !mounted) {
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Trip reminder added.')),
    );
  }

  Future<void> _editTrip() async {
    final Trip? updatedTrip = await Navigator.push<Trip>(
      context,
      MaterialPageRoute(builder: (context) => EditTripScreen(trip: _trip)),
    );

    if (updatedTrip == null || !mounted) {
      return;
    }

    setState(() {
      _trip = updatedTrip;
      _progressFuture = _loadProgress();
    });
  }

  Future<void> _deleteTrip() async {
    if (_isDeleting) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Color(0xFFC62828),
            size: 32,
          ),
          title: const Text('Delete Trip?', textAlign: TextAlign.center),
          content: const Text(
            'This will permanently remove this trip, '
            'its travel requirements, checklist progress '
            'and packing list.\n\n'
            'This action cannot be undone.',
            textAlign: TextAlign.center,
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
              child: const Text('Delete Trip'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await _tripService.deleteTrip(_trip.id);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('DELETE TRIP ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete the trip. Please try again.'),
        ),
      );
    }
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

  DateTime get _departureEnd {
    return DateTime(
      _trip.departureDate.year,
      _trip.departureDate.month,
      _trip.departureDate.day,
      23,
      59,
    );
  }

  bool get _isPastTrip {
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);

    final DateTime departure = DateTime(
      _trip.departureDate.year,
      _trip.departureDate.month,
      _trip.departureDate.day,
    );

    return departure.isBefore(today);
  }

  String get _departureStatus {
    if (_isPastTrip) {
      return 'Past trip';
    }

    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);

    final DateTime departure = DateTime(
      _trip.departureDate.year,
      _trip.departureDate.month,
      _trip.departureDate.day,
    );

    final int days = departure.difference(today).inDays;

    if (days == 0) {
      return 'Departs today';
    }

    if (days == 1) {
      return 'Departs tomorrow';
    }

    return 'Departs in $days days';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Trip Details',
          style: TextStyle(color: _darkTextColor, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: _isPastTrip
                ? 'Reminders unavailable for past trips'
                : 'Add trip reminder',
            onPressed: _isPastTrip || _isDeleting ? null : _addReminder,
            icon: const Icon(Icons.add_alert_outlined),
            color: _primaryColor,
          ),

          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProgress,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
          children: [
            _buildTripHeader(),

            const SizedBox(height: 24),

            const Text(
              'Travel Readiness',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _darkTextColor,
              ),
            ),

            const SizedBox(height: 12),

            _buildProgressCard(),

            const SizedBox(height: 26),

            const Text(
              'Prepare for Your Trip',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _darkTextColor,
              ),
            ),

            const SizedBox(height: 12),

            _buildFeatureCard(
              icon: Icons.fact_check_outlined,
              title: 'Travel Requirements',
              description:
                  'Review your personalised regulatory '
                  'checklist and mark completed requirements.',
              actionText: 'View Requirements',
              onTap: _openChecklist,
            ),

            const SizedBox(height: 12),

            _buildFeatureCard(
              icon: Icons.luggage_outlined,
              title: 'Packing List',
              description:
                  'Manage your packing items and get '
                  'contextual recommendations for this trip.',
              actionText: 'Open Packing List',
              onTap: _openPackingList,
            ),

            const SizedBox(height: 26),

            const Text(
              'Manage Trip',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _darkTextColor,
              ),
            ),

            const SizedBox(height: 12),

            _buildManageTripCard(),

            const SizedBox(height: 22),

            _buildOfficialSourceNote(),
          ],
        ),
      ),
    );
  }

  Widget _buildTripHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE7F7F8), Color(0xFFF1F8FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFCBE8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: _primaryColor,
                  size: 30,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatText(_trip.destinationCountryId),
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: _darkTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatText(_trip.purpose)}'
                      ' • '
                      '${_trip.durationDays} days',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isPastTrip
                      ? const Color(0xFFECEFF1)
                      : const Color(0xFFDFF5EA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isPastTrip ? 'Past' : 'Upcoming',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _isPastTrip
                        ? const Color(0xFF546E7A)
                        : const Color(0xFF177245),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: _primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Departure',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(_trip.departureDate),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _darkTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _departureStatus,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isPastTrip ? Colors.black54 : _primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return FutureBuilder<Map<String, int>>(
      future: _progressFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
            ),
            child: const Text(
              'Unable to calculate travel readiness.',
              textAlign: TextAlign.center,
            ),
          );
        }

        final Map<String, int> progress = snapshot.data ?? {};

        final int completed = progress['completed'] ?? 0;

        final int total = progress['total'] ?? 0;

        final double value = total == 0 ? 0 : completed / total;

        final int percentage = (value * 100).round();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.speed_outlined, color: _primaryColor, size: 23),

                  SizedBox(width: 9),

                  Text(
                    'Travel Readiness Score',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _darkTextColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  SizedBox(
                    width: 82,
                    height: 82,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 82,
                          height: 82,
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: 8,
                            backgroundColor: const Color(0xFFE5EEF0),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              _primaryColor,
                            ),
                          ),
                        ),

                        Text(
                          '$percentage%',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 18),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          total == 0
                              ? 'No requirements available'
                              : '$completed of $total requirements completed',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _darkTextColor,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          total == 0
                              ? 'The readiness score will be calculated when applicable travel requirements are available.'
                              : 'The score is calculated from your completed applicable travel requirements.',
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

              if (total > 0) ...[
                const SizedBox(height: 18),

                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE5EEF0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      _primaryColor,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F6FA),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF0A5B83),
                      size: 18,
                    ),

                    SizedBox(width: 9),

                    Expanded(
                      child: Text(
                        'This score reflects checklist completion only. '
                        'It does not guarantee entry, visa approval or '
                        'travel eligibility.',
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.4,
                          color: Color(0xFF486581),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6F7),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: _primaryColor, size: 25),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _darkTextColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      actionText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManageTripCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryColor,
                side: const BorderSide(color: Color(0xFF9BD2D7)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isDeleting ? null : _editTrip,
              icon: const Icon(Icons.edit_outlined),
              label: const Text(
                'Edit Trip',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC62828),
                side: const BorderSide(color: Color(0xFFE7B8B8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isDeleting ? null : _deleteTrip,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
              label: Text(
                _isDeleting ? 'Deleting Trip...' : 'Delete Trip',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialSourceNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E6EE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_outlined, size: 22, color: Color(0xFF0A5B83)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Official government and authority '
              'references are available inside '
              'each travel requirement.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Color(0xFF334E68),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
