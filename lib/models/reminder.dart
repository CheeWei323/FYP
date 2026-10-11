import 'package:cloud_firestore/cloud_firestore.dart';

class Reminder {
  final String id;
  final String userId;
  final String tripId;
  final String title;
  final DateTime reminderAt;
  final bool completed;
  final int notificationId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Reminder({
    required this.id,
    required this.userId,
    required this.tripId,
    required this.title,
    required this.reminderAt,
    required this.completed,
    required this.notificationId,
    this.createdAt,
    this.updatedAt,
  });

  factory Reminder.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data() ?? <String, dynamic>{};

    final Timestamp? reminderTimestamp = data['reminderAt'] as Timestamp?;

    final Timestamp? createdTimestamp = data['createdAt'] as Timestamp?;

    final Timestamp? updatedTimestamp = data['updatedAt'] as Timestamp?;

    return Reminder(
      id: data['reminderId'] as String? ?? document.id,
      userId: data['userId'] as String? ?? '',
      tripId: data['tripId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      reminderAt: reminderTimestamp?.toDate() ?? DateTime.now(),
      completed: data['completed'] as bool? ?? false,
      notificationId: data['notificationId'] as int? ?? 0,
      createdAt: createdTimestamp?.toDate(),
      updatedAt: updatedTimestamp?.toDate(),
    );
  }
}
