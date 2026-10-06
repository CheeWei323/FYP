import 'package:cloud_firestore/cloud_firestore.dart';

class SystemUser {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SystemUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.createdAt,
    this.updatedAt,
  });

  factory SystemUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data() ?? {};

    return SystemUser(
      id: document.id,
      fullName: (data['fullName'] as String? ?? '').trim(),
      email: (data['email'] as String? ?? '').trim(),
      role: data['role'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
