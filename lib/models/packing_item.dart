import 'package:cloud_firestore/cloud_firestore.dart';

class PackingItem {
  final String id;
  final String name;
  final String category;
  final int quantity;
  final bool packed;
  final String source;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PackingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.packed,
    required this.source,
    this.createdAt,
    this.updatedAt,
  });

  factory PackingItem.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final Map<String, dynamic> data = document.data() ?? {};

    return PackingItem(
      id: document.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? 'other',
      quantity: data['quantity'] as int? ?? 1,
      packed: data['packed'] as bool? ?? false,
      source: data['source'] as String? ?? 'user',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'quantity': quantity,
      'packed': packed,
      'source': source,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  PackingItem copyWith({
    String? name,
    String? category,
    int? quantity,
    bool? packed,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PackingItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      packed: packed ?? this.packed,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}