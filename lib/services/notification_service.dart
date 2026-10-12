import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const NotificationDetails _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'travelguard_trip_reminders',
      'Trip Reminders',
      channelDescription: 'Personal travel preparation reminders.',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
  );

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) return;

    // Load timezone data and detect the phone's timezone.
    tz.initializeTimeZones();

    final TimezoneInfo deviceTimezone =
        await FlutterTimezone.getLocalTimezone();

    tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));

    // Uses the application's existing launcher icon.
    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _notifications.initialize(settings: settings);

    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // ANDROID PERMISSIONS
  // ---------------------------------------------------------------------------

  Future<bool> requestPermissions() async {
    await initialize();

    final AndroidFlutterLocalNotificationsPlugin? android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) {
      return false;
    }

    // Request permission to display notifications.
    final bool? notificationGranted = await android
        .requestNotificationsPermission();

    if (notificationGranted != true) {
      return false;
    }

    // Check whether exact notification scheduling is allowed.
    final bool? exactAllowed = await android.canScheduleExactNotifications();

    if (exactAllowed == true) {
      return true;
    }

    // Android may open a system settings page for this permission.
    await android.requestExactAlarmsPermission();

    return await android.canScheduleExactNotifications() == true;
  }

  // ---------------------------------------------------------------------------
  // SCHEDULE PERSONAL REMINDER
  // ---------------------------------------------------------------------------

  Future<void> scheduleReminder({
    required int notificationId,
    required String tripId,
    required String title,
    required String destination,
    required DateTime reminderAt,
  }) async {
    await initialize();

    if (notificationId <= 0) {
      throw ArgumentError('Notification ID must be positive.');
    }

    if (!reminderAt.isAfter(DateTime.now())) {
      throw ArgumentError('Reminder time must be in the future.');
    }

    final AndroidFlutterLocalNotificationsPlugin? android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final bool notificationsEnabled =
        await android?.areNotificationsEnabled() ?? false;

    final bool exactAllowed =
        await android?.canScheduleExactNotifications() ?? false;

    if (!notificationsEnabled || !exactAllowed) {
      throw StateError(
        'Notification or exact alarm permission is not granted.',
      );
    }

    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
      reminderAt,
      tz.local,
    );

    await _notifications.zonedSchedule(
      id: notificationId,
      title: 'TravelGuard MY Reminder',
      body: '$title - $destination',
      scheduledDate: scheduledDate,
      notificationDetails: _reminderDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: tripId,
    );
  }

  // ---------------------------------------------------------------------------
  // CANCEL PERSONAL REMINDER
  // ---------------------------------------------------------------------------

  Future<void> cancelReminder(int notificationId) async {
    await initialize();

    await _notifications.cancel(id: notificationId);
  }

  // ---------------------------------------------------------------------------
  // CHECK PENDING NOTIFICATIONS
  // ---------------------------------------------------------------------------

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    await initialize();

    return _notifications.pendingNotificationRequests();
  }
}
