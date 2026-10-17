import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

// -----------------------------------------------------------------------------
// PACKING AUTHENTICATION ERRORS
// -----------------------------------------------------------------------------
// Let the packing screen distinguish sign-in failures from connection errors.
class PackingAuthenticationException implements Exception {
  const PackingAuthenticationException(this.message);

  final String message;

  @override
  String toString() => message;
}

// -----------------------------------------------------------------------------
// AUTHENTICATED PACKING REQUESTS
// -----------------------------------------------------------------------------
class PackingAiService {
  static const String _baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://fyp-g28m.onrender.com',
  );

  // Obtain the current Firebase ID token for each generation request.
  Future<Map<String, String>> _authenticatedHeaders() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw const PackingAuthenticationException(
        'Please sign in to generate packing suggestions.',
      );
    }

    try {
      final token = await user.getIdToken();

      if (token == null || token.isEmpty) {
        throw const PackingAuthenticationException(
          'Please sign in again to generate packing suggestions.',
        );
      }

      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
    } on FirebaseAuthException {
      throw const PackingAuthenticationException(
        'Could not verify your session. Check your connection and sign in again.',
      );
    }
  }

  // Send trip details with the user's ID token and read the returned items.
  Future<List<Map<String, dynamic>>> generatePackingItems({
    required String destination,
    required String purpose,
    required int durationDays,
    required DateTime departureDate,
  }) async {
    final Uri url = Uri.parse('$_baseUrl/api/packing/generate');
    final headers = await _authenticatedHeaders();

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({
        'destination': destination,
        'purpose': purpose.toLowerCase(),
        'durationDays': durationDays,
        'departureDate': departureDate.toIso8601String().split('T').first,
      }),
    );

    // Give the screen a specific message when the server rejects the session.
    if (response.statusCode == 401) {
      throw const PackingAuthenticationException(
        'Your session is invalid or expired. Please sign in again.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception('Packing generation failed: ${response.body}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final List<dynamic>? items = data['items'];

    if (items == null) {
      throw Exception('No packing items were returned.');
    }

    // Preserve the item structure expected by the existing packing screen.
    return items.map<Map<String, dynamic>>((item) {
      return {
        'name': item['name'].toString(),
        'category': item['category'].toString(),
        'quantity': item['quantity'] as int,
      };
    }).toList();
  }
}
