import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

// -----------------------------------------------------------------------------
// AUTHENTICATED AGGREGATE REQUESTS
// -----------------------------------------------------------------------------
class AnalystService {
  // Tests supply a client and token; normal calls use the signed-in Firebase user.
  AnalystService({
    http.Client? client,
    Future<String?> Function()? tokenProvider,
    String baseUrl = const String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: 'https://fyp-g28m.onrender.com',
    ),
  }) : _client = client,
       _tokenProvider = tokenProvider ?? _readToken,
       _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  final http.Client? _client;
  final Future<String?> Function() _tokenProvider;
  final String _baseUrl;

  // Obtain the current ID token without storing it in application data.
  static Future<String?> _readToken() async =>
      FirebaseAuth.instance.currentUser?.getIdToken();

  // Restore decimal types expected by existing charts after JSON transport.
  dynamic _normalise(dynamic value, [String? key]) {
    if (value is num &&
        const {
          'percentage',
          'completionRate',
          'overallCompletionRate',
        }.contains(key)) {
      return value.toDouble();
    }
    if (value is List) {
      return value.map((item) => _normalise(item)).toList();
    }
    if (value is Map<String, dynamic>) {
      return value.map((name, item) => MapEntry(name, _normalise(item, name)));
    }
    return value;
  }

  // Request aggregates only; the client never reads trip or checklist collections.
  Future<dynamic> _query(
    String metric, {
    String? destinationId,
    String? purpose,
  }) async {
    final token = await _tokenProvider().timeout(const Duration(seconds: 15));
    if (token == null || token.isEmpty) {
      throw Exception('Please sign in to view analytics.');
    }
    final post = _client?.post ?? http.post;
    final response = await post(
      Uri.parse('$_baseUrl/api/analytics/query'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'metric': metric,
        'destinationId': destinationId,
        'purpose': purpose,
      }),
    ).timeout(const Duration(seconds: 90));
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected analytics response.');
    }
    if (response.statusCode != 200) {
      throw Exception(
        decoded['error'] is String
            ? decoded['error']
            : 'Analytics could not be loaded.',
      );
    }
    return _normalise(decoded['data']);
  }

  // Check the top-level shape before handing aggregate values to a screen.
  Future<Map<String, dynamic>> _object(
    String metric, {
    String? destinationId,
    String? purpose,
  }) async {
    final data = await _query(
      metric,
      destinationId: destinationId,
      purpose: purpose,
    );
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected aggregate totals.');
    }
    return data;
  }

  // Check each aggregate row instead of accepting arbitrary JSON structures.
  Future<List<Map<String, dynamic>>> _rows(
    String metric, {
    String? destinationId,
    String? purpose,
  }) async {
    final data = await _query(
      metric,
      destinationId: destinationId,
      purpose: purpose,
    );
    if (data is! List) {
      throw const FormatException('Expected aggregate rows.');
    }
    return data.map((row) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('Invalid aggregate row.');
      }
      return row;
    }).toList();
  }

  // Load the public destination labels used by analytics filters.
  Future<List<Map<String, String>>> getAnalyticsFilterCountries() async =>
      (await _rows('countries'))
          .map(
            (row) => {'id': row['id'] as String, 'name': row['name'] as String},
          )
          .toList();

  // Preserve the existing service interface for dashboards and report snapshots.
  Future<Map<String, dynamic>> getOverview() => _object('overview');

  // Load destination counts and their share of selected trips.
  Future<List<Map<String, dynamic>>> getDestinationTrends({
    String? destinationId,
    String? purpose,
  }) => _rows('destinations', destinationId: destinationId, purpose: purpose);

  // Load a complete sequence of departure months, including zero-count gaps.
  Future<List<Map<String, dynamic>>> getMonthlyDepartureTrend({
    String? destinationId,
    String? purpose,
  }) => _rows('monthly', destinationId: destinationId, purpose: purpose);

  // Load counts for the three supported purposes.
  Future<Map<String, dynamic>> getPurposeDistribution({
    String? destinationId,
    String? purpose,
  }) => _object('purpose', destinationId: destinationId, purpose: purpose);

  // Load per-trip completion averages and requirement completion summaries.
  Future<Map<String, dynamic>> getChecklistCompletionAnalytics({
    String? destinationId,
    String? purpose,
  }) => _object('completion', destinationId: destinationId, purpose: purpose);

  // Load requirement frequency, counted at most once per requirement per trip.
  Future<Map<String, dynamic>> getPreparationRequirementAnalytics({
    String? destinationId,
    String? purpose,
  }) => _object('requirements', destinationId: destinationId, purpose: purpose);
}
