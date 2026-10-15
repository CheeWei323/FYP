import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../services/trip_service.dart';
import 'checklist_screen.dart';
import 'edit_trip_screen.dart';
import 'packing_screen.dart';
import '../services/reminder_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/trip_overview_card.dart';
import '../widgets/trip_preparation_widgets.dart';
import 'trip_map_screen.dart';

class TripDetailsScreen extends StatefulWidget {
  final Trip trip;

  const TripDetailsScreen({super.key, required this.trip});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  final TripService _tripService = TripService();

  final ReminderService _reminderService = ReminderService();

  static const Color _darkTextColor = AppColors.navy;

  static const Color _backgroundColor = AppColors.background;

  late Trip _trip;

  late Future<Map<String, int>> _progressFuture;

  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();

    _trip = widget.trip;

    _progressFuture = _loadProgress();
  }

  // ---------------------------------------------------------------------------
  // LOAD READINESS
  // ---------------------------------------------------------------------------
  // Listen immediately; the card still receives any error when it builds.
  Future<Map<String, int>> _loadProgress() {
    final Future<Map<String, int>> progress = _tripService.getChecklistProgress(
      _trip.id,
    );

    progress.ignore();
    return progress;
  }

  // ---------------------------------------------------------------------------
  // REFRESH READINESS
  // ---------------------------------------------------------------------------
  // Let the card show read failures without throwing from pull-to-refresh.
  Future<void> _refreshProgress() async {
    if (!mounted) return;

    final Future<Map<String, int>> refreshed = _loadProgress();

    setState(() {
      _progressFuture = refreshed;
    });

    try {
      await refreshed;
    } catch (error) {
      debugPrint('READINESS REFRESH ERROR: $error');
    }
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

  // ---------------------------------------------------------------------------
  // OPEN DESTINATION MAP
  // ---------------------------------------------------------------------------
  // Keep the map tied to the selected trip, including any saved destination edits.
  Future<void> _openDestinationMap() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (context) => TripMapScreen(trip: _trip)),
    );
  }

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
          icon: Icon(icon, color: iconColor, size: 38),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(message, textAlign: TextAlign.center),
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

  Future<void> _addReminder() async {
    if (_isPastTrip || _isDeleting) return;

    final DateTime now = DateTime.now();
    final DateTime departureEnd = _departureEnd;

    // -----------------------------------------------------------
    // CHECK WHETHER FUTURE REMINDERS ARE STILL POSSIBLE
    // -----------------------------------------------------------

    if (!departureEnd.isAfter(now)) {
      await _showReminderFeedback(
        title: 'Reminder Unavailable',
        message:
            'No future reminder time is available '
            'for this trip.',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    final formKey = GlobalKey<FormState>();

    String reminderTitle = '';
    String? dateTimeError;
    String? saveError;

    bool isSaving = false;

    // Suggest a time one hour from now.
    DateTime selectedDateTime = now.add(const Duration(hours: 1));

    if (selectedDateTime.isAfter(departureEnd)) {
      selectedDateTime = now.add(const Duration(minutes: 5));
    }

    // Save notification information for use after
    // the dialog has closed.
    ({int notificationId, String title, DateTime reminderAt})? createdReminder;

    // -----------------------------------------------------------
    // ADD REMINDER DIALOG
    // -----------------------------------------------------------

    final bool? saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            // ---------------------------------------------------
            // SELECT DATE
            // ---------------------------------------------------

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

                dateTimeError = null;
              });
            }

            // ---------------------------------------------------
            // SELECT TIME
            // ---------------------------------------------------

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

                dateTimeError = null;
              });
            }

            // ---------------------------------------------------
            // DIALOG CONTENT
            // ---------------------------------------------------

            return AlertDialog(
              scrollable: true,
              icon: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.add_alert_outlined,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),

              title: const Text(
                'Add Trip Reminder',
                textAlign: TextAlign.center,
              ),

              content: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trip context.
                    Center(
                      child: Text(
                        '${_formatText(_trip.destinationCountryId)}'
                        ' • '
                        '${_formatDate(_trip.departureDate)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // -------------------------------------------
                    // REMINDER TITLE
                    // -------------------------------------------
                    const Text(
                      'Reminder Title',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 9),

                    TextFormField(
                      enabled: !isSaving,
                      maxLength: 120,
                      maxLines: 2,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Review passport documents',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                      ),
                      onChanged: (value) {
                        reminderTitle = value;
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a reminder title.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 10),

                    // -------------------------------------------
                    // REMINDER DATE
                    // -------------------------------------------
                    const Text(
                      'Reminder Date',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 9),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isSaving ? null : selectDate,
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                        label: Text(_formatDate(selectedDateTime)),
                      ),
                    ),

                    const SizedBox(height: 17),

                    // -------------------------------------------
                    // REMINDER TIME
                    // -------------------------------------------
                    const Text(
                      'Reminder Time',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 9),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isSaving ? null : selectTime,
                        icon: const Icon(Icons.access_time_rounded, size: 19),
                        label: Text(_formatTime(selectedDateTime)),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // -------------------------------------------
                    // DATE/TIME VALIDATION
                    // -------------------------------------------
                    if (dateTimeError != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.danger,
                            size: 17,
                          ),

                          const SizedBox(width: 7),

                          Expanded(
                            child: Text(
                              dateTimeError!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                    ],

                    // -------------------------------------------
                    // SAVE ERROR
                    // -------------------------------------------
                    if (saveError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F0),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          saveError!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                    ],

                    // -------------------------------------------
                    // INFORMATION NOTE
                    // -------------------------------------------
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F6FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),

                          SizedBox(width: 9),

                          Expanded(
                            child: Text(
                              'Choose a future date and time '
                              'on or before your trip departure date.',
                              style: TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 11.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // -------------------------------------------------
              // ACTION BUTTONS
              // -------------------------------------------------
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
                          // Validate the title first.
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }

                          final DateTime current = DateTime.now();

                          // Validate the selected date/time.
                          if (!selectedDateTime.isAfter(current)) {
                            setDialogState(() {
                              dateTimeError =
                                  'Please select a future '
                                  'reminder date and time.';
                            });

                            return;
                          }

                          if (selectedDateTime.isAfter(departureEnd)) {
                            setDialogState(() {
                              dateTimeError =
                                  'The reminder must be '
                                  'scheduled on or before '
                                  'the departure date.';
                            });

                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                            saveError = null;
                            dateTimeError = null;
                          });

                          try {
                            // Create reminder in Firestore.
                            final result = await _reminderService
                                .createReminder(
                                  userId: _trip.userId,
                                  tripId: _trip.id,
                                  title: reminderTitle.trim(),
                                  reminderAt: selectedDateTime,
                                );

                            createdReminder = (
                              notificationId: result.notificationId,
                              title: reminderTitle.trim(),
                              reminderAt: selectedDateTime,
                            );

                            if (!dialogContext.mounted) {
                              return;
                            }

                            Navigator.pop(dialogContext, true);
                          } catch (error) {
                            debugPrint('CREATE REMINDER ERROR: $error');

                            if (!dialogContext.mounted) {
                              return;
                            }

                            setDialogState(() {
                              isSaving = false;
                              saveError =
                                  'Unable to save the reminder. '
                                  'Please try again.';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Reminder'),
                ),
              ],
            );
          },
        );
      },
    );

    // -----------------------------------------------------------
    // STOP IF CANCELLED
    // -----------------------------------------------------------

    if (saved != true || !mounted) {
      return;
    }

    final reminder = createdReminder;

    if (reminder == null) {
      await _showReminderFeedback(
        title: 'Reminder Saved',
        message:
            'The reminder was saved, but its notification '
            'details are unavailable.',
        icon: Icons.info_outline_rounded,
      );

      return;
    }

    // -----------------------------------------------------------
    // SCHEDULE ANDROID NOTIFICATION
    // -----------------------------------------------------------

    bool notificationScheduled = false;

    try {
      final bool permissionGranted = await NotificationService.instance
          .requestPermissions();

      if (permissionGranted) {
        await NotificationService.instance.scheduleReminder(
          notificationId: reminder.notificationId,
          tripId: _trip.id,
          title: reminder.title,
          destination: _formatText(_trip.destinationCountryId),
          reminderAt: reminder.reminderAt,
        );

        notificationScheduled = true;
      }
    } catch (error) {
      debugPrint('SCHEDULE REMINDER NOTIFICATION ERROR: $error');
    }

    if (!mounted) return;

    // -----------------------------------------------------------
    // CENTRED RESULT DIALOG
    // -----------------------------------------------------------

    if (notificationScheduled) {
      await _showReminderFeedback(
        title: 'Reminder Created',
        message:
            'Your reminder has been saved successfully.\n\n'
            'A phone notification has also been scheduled '
            'for the selected date and time.',
        icon: Icons.check_circle_outline_rounded,
        iconColor: AppColors.success,
      );
    } else {
      await _showReminderFeedback(
        title: 'Reminder Saved',
        message:
            'Your reminder was saved successfully, but '
            'the phone notification could not be scheduled.\n\n'
            'Please check notification and exact alarm '
            'permissions in your Android settings.',
        icon: Icons.notifications_off_outlined,
        iconColor: const Color(0xFF9A5B15),
      );
    }
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
            'its travel requirements, checklist progress, '
            'packing list and personal reminders.\n\n'
            'Any scheduled phone notifications for this '
            'trip will also be cancelled.\n\n'
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
      // Keep reminder creation in the clearly labelled preparation card.
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Trip Details',
          style: TextStyle(color: _darkTextColor, fontWeight: FontWeight.w700),
        ),
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

            // Open the existing preparation tools for this selected trip.
            _buildFeatureCard(
              icon: Icons.fact_check_outlined,
              title: 'Travel Requirements',
              description:
                  'Review the requirements that apply to this trip. '
                  'Checking or unchecking an item updates your readiness score.',
              actionText: 'View Requirements',
              onTap: _openChecklist,
            ),

            const SizedBox(height: 12),

            _buildFeatureCard(
              icon: Icons.luggage_outlined,
              title: 'Packing List',
              description: 'Manage the packing list saved for this trip.',
              actionText: 'Open Packing List',
              onTap: _openPackingList,
            ),

            const SizedBox(height: 12),

            _buildFeatureCard(
              icon: Icons.map_outlined,
              title: 'Route Planning',
              description:
                  'Choose places and compare route options by distance and estimated travel time.',
              actionText: 'Plan a Route',
              onTap: _openDestinationMap,
            ),

            const SizedBox(height: 12),

            _buildFeatureCard(
              icon: Icons.add_alert_outlined,
              title: 'Trip Reminder',
              description: _isPastTrip
                  ? 'New reminders are unavailable for past trips.'
                  : 'Set a personal reminder for a preparation task before departure.',
              actionText: _isPastTrip
                  ? 'Unavailable for past trips'
                  : 'Add Reminder',
              enabled: !_isPastTrip,
              onTap: _addReminder,
            ),

            const SizedBox(height: 12),

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

  // ---------------------------------------------------------------------------
  // TRIP OVERVIEW
  // ---------------------------------------------------------------------------
  // Pass the current trip to the shared header, including any saved edits.
  Widget _buildTripHeader() {
    return TripOverviewCard(
      countryId: _trip.destinationCountryId,
      destination: _formatText(_trip.destinationCountryId),
      purpose: _formatText(_trip.purpose),
      durationDays: _trip.durationDays,
      departureDateLabel: _formatDate(_trip.departureDate),
      departureStatus: _departureStatus,
      isPastTrip: _isPastTrip,
    );
  }

  // ---------------------------------------------------------------------------
  // READINESS CARD
  // ---------------------------------------------------------------------------
  // Display progress from the existing checklist service with a retry action.
  Widget _buildProgressCard() {
    return TripReadinessCard(
      progressFuture: _progressFuture,
      onRetry: _refreshProgress,
    );
  }

  // ---------------------------------------------------------------------------
  // PREPARATION ACTIONS
  // ---------------------------------------------------------------------------
  // Disable actions during deletion and unavailable reminders for past trips.
  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required String actionText,
    required VoidCallback onTap,
    bool enabled = true,
    Color iconBackground = AppColors.primaryLight,
  }) {
    return TripActionCard(
      icon: icon,
      title: title,
      description: description,
      actionText: actionText,
      iconBackground: iconBackground,
      onTap: _isDeleting || !enabled ? null : onTap,
    );
  }

  Widget _buildManageTripCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -----------------------------------------------------
          // EDIT TRIP
          // -----------------------------------------------------
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isDeleting ? null : _editTrip,
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text('Edit Trip'),
            ),
          ),

          const SizedBox(height: 14),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 10),

          // -----------------------------------------------------
          // DELETE TRIP
          // -----------------------------------------------------
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isDeleting ? null : _deleteTrip,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                minimumSize: const Size(0, 48),
                side: const BorderSide(color: Color(0xFFE7B8B8), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: _isDeleting
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.danger,
                      ),
                    )
                  : const Icon(Icons.delete_outline_rounded, size: 20),
              label: Text(
                _isDeleting ? 'Deleting Trip...' : 'Delete Trip',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
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
