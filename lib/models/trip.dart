import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  final String id;
  final String userId;
  final String destinationCountryId;
  final String purpose;
  final int durationDays;
  final DateTime departureDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Trip({
    required this.id,
    required this.userId,
    required this.destinationCountryId,
    required this.purpose,
    required this.durationDays,
    required this.departureDate,
    this.createdAt,
    this.updatedAt,
  });

  // Converts a Firestore trip document into a Trip object.
  factory Trip.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final Map<String, dynamic> data = document.data() ?? {};

    return Trip(
      id: document.id,
      userId: data['userId'] as String? ?? '',
      destinationCountryId: data['destinationCountryId'] as String? ?? '',
      purpose: data['purpose'] as String? ?? '',
      durationDays: (data['durationDays'] as num?)?.toInt() ?? 1,
      departureDate: (data['departureDate'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  //Convert the trip into Firestore copatible data
  Map<String, dynamic> toMap(){
    return {
      'userId': userId,
      'destinationCountryId': destinationCountryId,
      'purpose': purpose,
      'durationDays': durationDays,
      'departureDate': Timestamp.fromDate(departureDate),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!): FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!): FieldValue.serverTimestamp(),
    };
  }
}
