import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reminder.dart';

class ReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // CREATE REMINDER
  // ---------------------------------------------------------------------------

  Future<String> createReminder({
    required String userId,
    required String tripId,
    required String title,
    required DateTime reminderAt,
  }) async {
    final String cleanedTitle = title.trim();

    if (cleanedTitle.isEmpty) {
      throw ArgumentError('Reminder title cannot be empty.');
    }

    if (cleanedTitle.length > 120) {
      throw ArgumentError('Reminder title cannot exceed 120 characters.');
    }

    if (!reminderAt.isAfter(DateTime.now())) {
      throw ArgumentError('Reminder time must be in the future.');
    }

    final DocumentReference<Map<String, dynamic>> reference = _firestore
        .collection('reminders')
        .doc();

    final int notificationId = _createNotificationId(reference.id);

    await reference.set({
      'reminderId': reference.id,
      'userId': userId,
      'tripId': tripId,
      'title': cleanedTitle,
      'reminderAt': Timestamp.fromDate(reminderAt),
      'completed': false,
      'notificationId': notificationId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return reference.id;
  }

  // ---------------------------------------------------------------------------
  // RETRIEVE REMINDERS
  // ---------------------------------------------------------------------------

  Future<List<Reminder>> getUserReminders(String userId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('reminders')
        .where('userId', isEqualTo: userId)
        .get();

    final List<Reminder> reminders = snapshot.docs
        .map(Reminder.fromFirestore)
        .toList();

    reminders.sort(
      (first, second) => first.reminderAt.compareTo(second.reminderAt),
    );

    return reminders;
  }

  Future<List<Reminder>> getTripReminders({
    required String userId,
    required String tripId,
  }) async {
    final List<Reminder> reminders = await getUserReminders(userId);

    return reminders.where((reminder) => reminder.tripId == tripId).toList();
  }

  // ---------------------------------------------------------------------------
  // UPDATE REMINDER
  // ---------------------------------------------------------------------------

  Future<void> updateReminder({
    required String reminderId,
    required String title,
    required DateTime reminderAt,
  }) async {
    final String cleanedTitle = title.trim();

    if (cleanedTitle.isEmpty) {
      throw ArgumentError('Reminder title cannot be empty.');
    }

    if (cleanedTitle.length > 120) {
      throw ArgumentError('Reminder title cannot exceed 120 characters.');
    }

    if (!reminderAt.isAfter(DateTime.now())) {
      throw ArgumentError('Reminder time must be in the future.');
    }

    await _firestore.collection('reminders').doc(reminderId).update({
      'title': cleanedTitle,
      'reminderAt': Timestamp.fromDate(reminderAt),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // COMPLETION
  // ---------------------------------------------------------------------------

  Future<void> updateReminderCompletion({
    required String reminderId,
    required bool completed,
  }) async {
    await _firestore.collection('reminders').doc(reminderId).update({
      'completed': completed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // DELETE REMINDER
  // ---------------------------------------------------------------------------

  Future<void> deleteReminder(String reminderId) async {
    await _firestore.collection('reminders').doc(reminderId).delete();
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  int _createNotificationId(String reminderId) {
    int hash = 0;

    for (final int value in reminderId.codeUnits) {
      hash = ((hash * 31) + value) & 0x7FFFFFFF;
    }

    // Android notification IDs should
    // remain positive and non-zero.
    return hash == 0 ? 1 : hash;
  }
}
