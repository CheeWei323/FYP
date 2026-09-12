import 'package:cloud_firestore/cloud_firestore.dart';

class Country {
  final String id;
  final String name;
  final String code;
  final bool enabled;
  final String flagCode;
  final DateTime? lastUpdated;

  const Country({
    required this.id,
    required this.name,
    required this.code,
    required this.enabled,
    required this.flagCode,
    this.lastUpdated,
  });

  // Converts a Firestore country document into a Country object.
  factory Country.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,) {
    final Map<String, dynamic> data = document.data() ?? {};

    return Country(
      id: document.id,
      name: data['name'] as String? ?? '',
      code: data['code'] as String? ?? '',
      enabled: data['enabled'] as bool? ?? false,
      flagCode: data['flagCode'] as String? ?? '',
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }
  // Convert the Country object into data that can be stored in Firestore.
  Map<String, dynamic> toMap(){
    return{
      'name': name,
      'code': code,
      'enabled': enabled,
      'flagCode': flagCode,
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : FieldValue.serverTimestamp()
    };
  }
}