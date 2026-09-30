import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/packing_item.dart';

class PackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Map<String, int> _categoryOrder = {
    'clothing': 1,
    'toiletries': 2,
    'electronics': 3,
    'healthComfort': 4,
    'activityEssentials': 5,
    'generalEssentials': 6,
    'other': 7,
  };

  // Retrieves all saved packing items belonging to a trip.
  Future<List<PackingItem>> getPackingItems(String tripId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('packingItems')
        .get();

    final List<PackingItem> items = snapshot.docs
        .map(
          (document) => PackingItem.fromFirestore(document),
    )
        .toList();

    // Groups items by category and then alphabetically by name.
    items.sort((a, b) {
      final int categoryA =
          _categoryOrder[a.category] ?? 99;

      final int categoryB =
          _categoryOrder[b.category] ?? 99;

      final int categoryComparison =
      categoryA.compareTo(categoryB);

      if (categoryComparison != 0) {
        return categoryComparison;
      }

      return a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      );
    });

    return items;
  }

  // Adds a packing item manually entered by the traveller.
  Future<String> addPackingItem({
    required String tripId,
    required String name,
    required String category,
    required int quantity,
  }) async {
    final DocumentReference<Map<String, dynamic>> itemReference =
    _firestore
        .collection('trips')
        .doc(tripId)
        .collection('packingItems')
        .doc();

    final PackingItem item = PackingItem(
      id: itemReference.id,
      name: name.trim(),
      category: category,
      quantity: quantity,
      packed: false,
      source: 'user',
    );

    await itemReference.set(
      item.toMap(),
    );

    return itemReference.id;
  }

  // Stores multiple Gemini-generated packing items atomically.
  Future<void> addGeneratedPackingItems({
    required String tripId,
    required List<PackingItem> items,
  }) async {
    final CollectionReference<Map<String, dynamic>>
    packingCollection = _firestore
        .collection('trips')
        .doc(tripId)
        .collection('packingItems');

    final WriteBatch batch = _firestore.batch();

    for (final PackingItem item in items) {
      final DocumentReference<Map<String, dynamic>>
      itemReference = packingCollection.doc();

      final PackingItem generatedItem = PackingItem(
        id: itemReference.id,
        name: item.name.trim(),
        category: item.category,
        quantity: item.quantity,
        packed: false,
        source: 'ai',
      );

      batch.set(
        itemReference,
        generatedItem.toMap(),
      );
    }

    await batch.commit();
  }

  // Updates traveller-editable packing item details.
  Future<void> updatePackingItem({
    required String tripId,
    required String itemId,
    required String name,
    required String category,
    required int quantity,
  }) async {
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('packingItems')
        .doc(itemId)
        .update({
      'name': name.trim(),
      'category': category,
      'quantity': quantity,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Updates whether an item has already been packed.
  Future<void> updatePackedStatus({
    required String tripId,
    required String itemId,
    required bool packed,
  }) async {
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('packingItems')
        .doc(itemId)
        .update({
      'packed': packed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Removes a packing item from the traveller's packing list.
  Future<void> deletePackingItem({
    required String tripId,
    required String itemId,
  }) async {
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('packingItems')
        .doc(itemId)
        .delete();
  }

  // Checks whether a trip already contains packing items.
  Future<bool> hasPackingItems(String tripId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('packingItems')
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }
}