import 'package:cloud_firestore/cloud_firestore.dart';

class TravelRule {
  final String id;
  final String countryId;
  final String category;
  final String title;
  final String checklistLabel;
  final String description;
  final List<String> purposes;
  final int minDurationDays;
  final int? maxDurationDays;
  final bool mandatory;
  final String officialUrl;
  final String sourceName;
  final bool active;
  final String reviewStatus;
  final int priority;
  final DateTime? lastValidatedAt;

  const TravelRule({
    required this.id,
    required this.countryId,
    required this.category,
    required this.title,
    required this.checklistLabel,
    required this.description,
    required this.purposes,
    required this.minDurationDays,
    this.maxDurationDays,
    required this.mandatory,
    required this.officialUrl,
    required this.sourceName,
    required this.active,
    this.reviewStatus = 'approved',
    required this.priority,
    this.lastValidatedAt,
  });

  // Converts a Firestore rule document into a TravelRule object.
  factory TravelRule.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data() ?? {};

    final bool active = data['active'] as bool? ?? true;

    final String reviewStatus =
        data['reviewStatus'] as String? ?? (active ? 'approved' : 'disabled');

    return TravelRule(
      id: document.id,
      countryId: data['countryId'] as String? ?? '',
      category: data['category'] as String? ?? '',
      title: data['title'] as String? ?? '',
      checklistLabel: data['checklistLabel'] as String? ?? '',
      description: data['description'] as String? ?? '',
      purposes: List<String>.from(data['purposes'] as List<dynamic>? ?? []),
      minDurationDays: (data['minDurationDays'] as num?)?.toInt() ?? 1,
      maxDurationDays: (data['maxDurationDays'] as num?)?.toInt(),
      mandatory: data['mandatory'] as bool? ?? true,
      officialUrl: data['officialUrl'] as String? ?? '',
      sourceName: data['sourceName'] as String? ?? '',
      active: active,
      reviewStatus: reviewStatus,
      priority: (data['priority'] as num?)?.toInt() ?? 0,
      lastValidatedAt: (data['lastValidatedAt'] as Timestamp?)?.toDate(),
    );
  }

  //Convert the rule into Firestore compatible data
  Map<String, dynamic> toMap() {
    return {
      'countryId': countryId,
      'category': category,
      'title': title,
      'checklistLabel': checklistLabel,
      'description': description,
      'purposes': purposes,
      'minDurationDays': minDurationDays,
      'maxDurationDays': maxDurationDays,
      'mandatory': mandatory,
      'officialUrl': officialUrl,
      'sourceName': sourceName,
      'active': active,
      'reviewStatus': reviewStatus,
      'priority': priority,
      'lastValidatedAt': lastValidatedAt != null
          ? Timestamp.fromDate(lastValidatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
