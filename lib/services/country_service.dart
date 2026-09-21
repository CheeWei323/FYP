import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/country.dart';

class CountryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Retrieves destination countries that are currently enabled in the system.
  Future<List<Country>> getEnabledCountries() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _firestore
        .collection('countries')
        .where('enabled', isEqualTo: true)
        .get();

    final List<Country> countries = snapshot.docs
        .map((document) => Country.fromFirestore(document))
        .toList();

    // Keep destination names in alphabetical order for the traveller.
    countries.sort(
          (a, b) => a.name.compareTo(b.name),
    );

    return countries;
  }
}