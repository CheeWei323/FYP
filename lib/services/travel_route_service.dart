import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

// -----------------------------------------------------------------------------
// TRAVEL DATA
// -----------------------------------------------------------------------------
class TravelSuggestion {
  const TravelSuggestion({required this.id, required this.label});

  final String id;
  final String label;
}

class TravelPlace {
  const TravelPlace({
    required this.id,
    required this.label,
    required this.position,
    this.credits = const [],
  });

  final String id;
  final String label;
  final LatLng position;
  final List<Map<String, dynamic>> credits;
}

// Store the estimates and map geometry between consecutive selected places.
class TravelRouteLeg {
  const TravelRouteLeg({
    required this.distanceMeters,
    required this.durationSeconds,
    this.points = const [],
  });

  final double distanceMeters;
  final double durationSeconds;
  final List<LatLng> points;
}

class TravelRoute {
  const TravelRoute({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
    this.description = '',
    this.warnings = const [],
    this.legs = const [],
  });

  final double distanceMeters;
  final double durationSeconds;
  final List<LatLng> points;
  final String description;
  final List<String> warnings;
  final List<TravelRouteLeg> legs;
}

class TravelRouteException implements Exception {
  const TravelRouteException(this.message);

  final String message;

  @override
  String toString() => message;
}

// -----------------------------------------------------------------------------
// AUTHENTICATED BACKEND REQUESTS
// -----------------------------------------------------------------------------
class TravelRouteService {
  TravelRouteService({
    http.Client? client,
    Future<String?> Function()? tokenProvider,
    String baseUrl = const String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: 'https://fyp-g28m.onrender.com',
    ),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _tokenProvider = tokenProvider ?? _readToken,
       _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final bool _ownsClient;
  final Future<String?> Function() _tokenProvider;
  final String _baseUrl;

  // Read Firebase's current ID token without exposing any Google server key.
  static Future<String?> _readToken() async =>
      FirebaseAuth.instance.currentUser?.getIdToken();

  // Use a fresh 128-bit token for each place-selection search session.
  static String newSessionToken() {
    final random = Random.secure();

    return base64UrlEncode(
      List.generate(16, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
  }

  // Allow time for a sleeping backend to start, then return a safe error message.
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final token = await _tokenProvider().timeout(const Duration(seconds: 15));

      if (token == null || token.isEmpty) {
        throw const TravelRouteException(
          'Please sign in to use route planning.',
        );
      }

      final response = await _client
          .post(
            Uri.parse('$_baseUrl/api/travel/$path'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 75));

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }

      if (response.statusCode != 200) {
        throw TravelRouteException(
          decoded['error'] is String
              ? decoded['error'] as String
              : 'Travel planning is unavailable. Please try again.',
        );
      }

      return decoded;
    } on TravelRouteException {
      rethrow;
    } on TimeoutException {
      throw const TravelRouteException(
        'The travel service is taking longer than expected. Please try again.',
      );
    } on FirebaseAuthException {
      throw const TravelRouteException('Please sign in again to plan a route.');
    } on FormatException {
      throw const TravelRouteException(
        'The travel service returned an unexpected response. Please try again.',
      );
    } catch (_) {
      throw const TravelRouteException(
        'Could not connect to the travel service. Check your connection and try again.',
      );
    }
  }

  // Validate arrays before converting backend results into application data.
  List<Map<String, dynamic>> _objects(dynamic value) {
    if (value is! List) {
      throw const FormatException('Expected a result list.');
    }

    return value.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException();
      }

      return item;
    }).toList();
  }

  // Search only within the selected trip's destination country.
  Future<List<TravelSuggestion>> searchPlaces({
    required String countryId,
    required String input,
    required String sessionToken,
  }) async {
    final data = await _post('places/autocomplete', {
      'countryId': countryId,
      'input': input,
      'sessionToken': sessionToken,
    });

    return _objects(data['places'])
        .map(
          (item) => TravelSuggestion(
            id: item['placeId'] as String,
            label: item['label'] as String,
          ),
        )
        .toList();
  }

  // Resolve a selected prediction and retain any required provider credits.
  Future<TravelPlace> resolvePlace({
    required String countryId,
    required TravelSuggestion suggestion,
    required String sessionToken,
  }) async {
    final data = await _post('places/details', {
      'countryId': countryId,
      'placeId': suggestion.id,
      'sessionToken': sessionToken,
    });

    return TravelPlace(
      id: data['placeId'] as String,
      label: suggestion.label,
      position: LatLng(
        (data['latitude'] as num).toDouble(),
        (data['longitude'] as num).toDouble(),
      ),
      credits: _objects(data['attributions'] ?? []),
    );
  }

  // Request a complete route through the traveller's ordered intermediate stops.
  Future<List<TravelRoute>> computeRoutes({
    required TravelPlace origin,
    required TravelPlace destination,
    required String travelMode,
    List<TravelPlace> stops = const [],
  }) async {
    final data = await _post('routes/compute', {
      'originPlaceId': origin.id,
      'destinationPlaceId': destination.id,
      'travelMode': travelMode,
      if (stops.isNotEmpty)
        'intermediatePlaceIds': stops.map((place) => place.id).toList(),
    });

    return _objects(data['routes']).map((item) {
      // Decode each section separately so the map can display it independently.
      final legs = _objects(item['legs'] ?? [])
          .map(
            (leg) => TravelRouteLeg(
              distanceMeters: (leg['distanceMeters'] as num).toDouble(),
              durationSeconds: (leg['durationSeconds'] as num).toDouble(),
              points: leg['encodedPolyline'] is String
                  ? decodePolyline(leg['encodedPolyline'] as String)
                  : const [],
            ),
          )
          .toList();

      // Require complete segment geometry before displaying a journey with stops.
      if (stops.isNotEmpty &&
          (legs.length != stops.length + 1 ||
              legs.any((leg) => leg.points.isEmpty))) {
        throw const TravelRouteException(
          'The complete journey is unavailable. Please try again after the travel service updates.',
        );
      }

      return TravelRoute(
        distanceMeters: (item['distanceMeters'] as num).toDouble(),
        durationSeconds: (item['durationSeconds'] as num).toDouble(),
        points: decodePolyline(item['encodedPolyline'] as String),
        description: item['description'] as String? ?? '',
        warnings: List<String>.from(item['warnings'] as List? ?? []),
        legs: legs,
      );
    }).toList();
  }

  // Decode Google's standard five-decimal polyline and reject broken geometry.
  static List<LatLng> decodePolyline(String encoded) {
    int index = 0, latitude = 0, longitude = 0;
    final points = <LatLng>[];

    int delta() {
      int result = 0, shift = 0, value;

      do {
        if (index >= encoded.length || shift > 30) {
          throw const FormatException();
        }

        value = encoded.codeUnitAt(index++) - 63;

        if (value < 0 || value > 63) {
          throw const FormatException();
        }

        result |= (value & 31) << shift;
        shift += 5;
      } while (value >= 32);

      return result.isOdd ? ~(result >> 1) : result >> 1;
    }

    while (index < encoded.length) {
      latitude += delta();
      longitude += delta();

      final lat = latitude / 1e5;
      final lng = longitude / 1e5;

      if (lat.abs() > 90 || lng.abs() > 180) {
        throw const FormatException();
      }

      points.add(LatLng(lat, lng));
    }

    if (points.length < 2) {
      throw const FormatException('Incomplete route.');
    }

    return List.unmodifiable(points);
  }

  // Close only a client created by this service.
  void dispose() {
    if (_ownsClient) _client.close();
  }
}
