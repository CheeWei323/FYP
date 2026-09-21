import 'package:cloud_firestore/cloud_firestore.dart';

class ChecklistItem {
  final String id;
  final String sourceRuleId;
  final String category;
  final String title;
  final String checklistLabel;
  final String description;
  final bool mandatory;
  final String officialUrl;
  final String sourceName;
  final int priority;
  final bool completed;
  final DateTime? completedAt;

  const ChecklistItem({
    required this.id,
    required this.sourceRuleId,
    required this.category,
    required this.title,
    required this.checklistLabel,
    required this.description,
    required this.mandatory,
    required this.officialUrl,
    required this.sourceName,
    required this.priority,
    required this.completed,
    this.completedAt,
  });

  //Convert a Firestore checklist document into a ChecklistItem object
  factory ChecklistItem.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ){
    final Map<String, dynamic> data = document.data() ?? {};

    return ChecklistItem(
      id: document.id,
      sourceRuleId: data['sourceRuleId'] as String? ?? '',
      category: data['category'] as String? ?? '',
      title: data['title'] as String? ?? '',
      checklistLabel: data['checklistLabel'] as String? ?? '',
      description: data['description'] as String? ?? '',
      mandatory: data['mandatory'] as bool? ?? true,
      officialUrl: data['officialUrl'] as String? ?? '',
      sourceName: data['sourceName'] as String? ?? '',
      priority: (data['priority'] as num?)?.toInt() ?? 0,
      completed: data['completed'] as bool? ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Converts the checklist item into Firestore compatible data
  Map<String, dynamic> toMap() {
    return {
      'sourceRuleId': sourceRuleId,
      'category': category,
      'title': title,
      'checklistLabel': checklistLabel,
      'description': description,
      'mandatory': mandatory,
      'officialUrl': officialUrl,
      'sourceName': sourceName,
      'priority': priority,
      'completed': completed,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
    };
  }
}