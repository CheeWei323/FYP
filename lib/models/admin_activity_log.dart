import 'package:cloud_firestore/cloud_firestore.dart';

class AdminActivityLog {
  final String id;
  final String action;
  final String targetId;
  final String targetName;
  final String details;
  final String performedByUid;
  final String performedByName;
  final String performedByEmail;
  final DateTime? timestamp;

  const AdminActivityLog({
    required this.id,
    required this.action,
    required this.targetId,
    required this.targetName,
    required this.details,
    required this.performedByUid,
    required this.performedByName,
    required this.performedByEmail,
    this.timestamp,
  });

  factory AdminActivityLog.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data() ?? {};

    return AdminActivityLog(
      id: document.id,
      action: data['action'] as String? ?? '',
      targetId: data['targetId'] as String? ?? '',
      targetName: data['targetName'] as String? ?? '',
      details: data['details'] as String? ?? '',
      performedByUid: data['performedByUid'] as String? ?? '',
      performedByName: data['performedByName'] as String? ?? '',
      performedByEmail: data['performedByEmail'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}
