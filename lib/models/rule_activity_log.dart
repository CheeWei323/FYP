import 'package:cloud_firestore/cloud_firestore.dart';

class RuleActivityLog {
  final String id;
  final String action;
  final String ruleId;
  final String ruleTitle;
  final String countryId;
  final String performedByUid;
  final String performedByName;
  final String performedByEmail;
  final DateTime? timestamp;

  const RuleActivityLog({
    required this.id,
    required this.action,
    required this.ruleId,
    required this.ruleTitle,
    required this.countryId,
    required this.performedByUid,
    required this.performedByName,
    required this.performedByEmail,
    this.timestamp,
  });

  factory RuleActivityLog.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data() ?? {};

    return RuleActivityLog(
      id: document.id,
      action: data['action'] as String? ?? '',
      ruleId: data['ruleId'] as String? ?? '',
      ruleTitle: data['ruleTitle'] as String? ?? '',
      countryId: data['countryId'] as String? ?? '',
      performedByUid: data['performedByUid'] as String? ?? '',
      performedByName: data['performedByName'] as String? ?? '',
      performedByEmail: data['performedByEmail'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}
