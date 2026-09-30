import 'dart:convert';

import 'package:http/http.dart' as http;

class PackingAiService {
  static const String _baseUrl = 'http://10.0.2.2:3000';

  Future<List<Map<String, dynamic>>> generatePackingItems({
    required String destination,
    required String purpose,
    required int durationDays,
    required DateTime departureDate,
  }) async {
    final Uri url = Uri.parse(
      '$_baseUrl/api/packing/generate',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'destination': destination,
        'purpose': purpose.toLowerCase(),
        'durationDays': durationDays,
        'departureDate':
        departureDate.toIso8601String().split('T').first,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Packing generation failed: ${response.body}',
      );
    }

    final Map<String, dynamic> data =
    jsonDecode(response.body);

    final List<dynamic>? items = data['items'];

    if (items == null) {
      throw Exception(
        'No packing items were returned.',
      );
    }

    return items.map<Map<String, dynamic>>((item) {
      return {
        'name': item['name'].toString(),
        'category': item['category'].toString(),
        'quantity': item['quantity'] as int,
      };
    }).toList();
  }
}