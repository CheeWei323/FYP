import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/trip.dart';
import '../theme/app_theme.dart';

class TripMapScreen extends StatelessWidget {
  final Trip trip;

  const TripMapScreen({super.key, required this.trip});

  // ---------------------------------------------------------------------------
  // DESTINATION CAMERA POSITIONS
  // ---------------------------------------------------------------------------
  // These country-level views are starting positions, not selected route stops.
  static const Map<String, CameraPosition> _countryViews = {
    'japan': CameraPosition(target: LatLng(36.2, 138.3), zoom: 4.5),
    'australia': CameraPosition(target: LatLng(-25.3, 133.8), zoom: 3.5),
    'united_states': CameraPosition(target: LatLng(39.8, -98.6), zoom: 3.2),
    'united_kingdom': CameraPosition(target: LatLng(55.4, -3.4), zoom: 5),
    'south_korea': CameraPosition(target: LatLng(36.0, 127.8), zoom: 6),
  };

  static const Map<String, String> _countryNames = {
    'japan': 'Japan',
    'australia': 'Australia',
    'united_states': 'United States',
    'united_kingdom': 'United Kingdom',
    'south_korea': 'South Korea',
  };

  // ---------------------------------------------------------------------------
  // DESTINATION NORMALISATION
  // ---------------------------------------------------------------------------
  // Accept the same country aliases used by the destination-photo widget.
  String get _countryId {
    final String id = trip.destinationCountryId.trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );

    return switch (id) {
      'us' || 'usa' => 'united_states',
      'uk' => 'united_kingdom',
      _ => id,
    };
  }

  // Fall back to a world view if a destination has no configured camera yet.
  CameraPosition get _initialCamera =>
      _countryViews[_countryId] ??
      const CameraPosition(target: LatLng(0, 0), zoom: 1.5);

  String get _destinationName =>
      _countryNames[_countryId] ??
      trip.destinationCountryId.replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    final bool supportsMap =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return Scaffold(
      appBar: AppBar(title: const Text('Destination Map')),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _destinationName,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Zoom in to explore places around your destination.',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: supportsMap
                  ? GoogleMap(
                      initialCameraPosition: _initialCamera,
                      mapToolbarEnabled: false,
                      myLocationButtonEnabled: false,
                      compassEnabled: true,
                      zoomControlsEnabled: true,
                    )
                  : const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Open the Android app to explore the destination map.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
