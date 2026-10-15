import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/trip.dart';
import '../services/travel_route_service.dart';
import '../theme/app_theme.dart';
import 'place_search_screen.dart';

class TripMapScreen extends StatefulWidget {
  const TripMapScreen({super.key, required this.trip, this.service});

  final Trip trip;
  final TravelRouteService? service;

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  late final TravelRouteService _service;

  GoogleMapController? _map;
  final _mapKey = GlobalKey();

  TravelPlace? _origin;
  TravelPlace? _destination;
  List<TravelRoute> _routes = [];

  String _mode = 'DRIVE';
  String? _error;

  bool _loading = false;
  bool _picking = false;

  int _selected = 0;
  int _revision = 0;

  // ---------------------------------------------------------------------------
  // DESTINATIONS AND LIFECYCLE
  // ---------------------------------------------------------------------------
  static const _views = {
    'japan': CameraPosition(target: LatLng(36.2, 138.3), zoom: 4.5),
    'australia': CameraPosition(target: LatLng(-25.3, 133.8), zoom: 3.5),
    'united_states': CameraPosition(target: LatLng(39.8, -98.6), zoom: 3.2),
    'united_kingdom': CameraPosition(target: LatLng(55.4, -3.4), zoom: 5),
    'south_korea': CameraPosition(target: LatLng(36.0, 127.8), zoom: 6),
  };

  static const _names = {
    'japan': 'Japan',
    'australia': 'Australia',
    'united_states': 'United States',
    'united_kingdom': 'United Kingdom',
    'south_korea': 'South Korea',
  };

  // Accept country aliases already supported by the app.
  String get _countryId {
    final id = widget.trip.destinationCountryId.trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );

    return switch (id) {
      'us' || 'usa' => 'united_states',
      'uk' => 'united_kingdom',
      _ => id,
    };
  }

  String get _countryName =>
      _names[_countryId] ??
      widget.trip.destinationCountryId.replaceAll('_', ' ');

  CameraPosition get _camera =>
      _views[_countryId] ??
      const CameraPosition(target: LatLng(0, 0), zoom: 1.5);

  // Share one service between route planning and its place-selection screens.
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? TravelRouteService();
  }

  // Discard late results and release the service owned by this screen.
  @override
  void dispose() {
    _revision++;
    _map = null;

    if (widget.service == null) {
      _service.dispose();
    }

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // PLACE AND ROUTE ACTIONS
  // ---------------------------------------------------------------------------
  // Invalidate old routes whenever their places or travel mode change.
  void _clearRoutes() {
    _revision++;
    _routes = [];
    _selected = 0;
    _loading = false;
    _error = null;
  }

  // Open a country-filtered search and retain the current place if cancelled.
  Future<void> _choosePlace(bool startingPoint) async {
    if (_loading || _picking) return;

    setState(() => _picking = true);

    final place = await Navigator.push<TravelPlace>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceSearchScreen(
          countryId: _countryId,
          countryName: _countryName,
          title: startingPoint ? 'Starting point' : 'Destination',
          service: _service,
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _picking = false;

      if (place != null) {
        if (startingPoint) {
          _origin = place;
        } else {
          _destination = place;
        }

        _clearRoutes();
      }
    });

    if (place != null) {
      await _move(CameraUpdate.newLatLngZoom(place.position, 13));
    }
  }

  // Reverse the trip segment without reusing geometry from the old order.
  void _swap() {
    setState(() {
      final previous = _origin;
      _origin = _destination;
      _destination = previous;
      _clearRoutes();
    });
  }

  // Clear the draft route and restore the destination-country view.
  void _reset() {
    setState(() {
      _origin = null;
      _destination = null;
      _clearRoutes();
    });

    _move(CameraUpdate.newCameraPosition(_camera));
  }

  // Select the shortest estimated time among the options returned by Google.
  Future<void> _findRoutes() async {
    if (_loading || _origin == null || _destination == null) return;

    if (_origin!.id == _destination!.id) {
      setState(() => _error = 'Choose two different places.');
      return;
    }

    final revision = ++_revision;

    setState(() {
      _loading = true;
      _routes = [];
      _error = null;
    });

    try {
      final routes = await _service.computeRoutes(
        origin: _origin!,
        destination: _destination!,
        travelMode: _mode,
      );

      if (!mounted || revision != _revision) return;

      if (routes.isEmpty) {
        throw const TravelRouteException(
          'No routes found. Try different places.',
        );
      }

      int best = 0;

      for (int i = 1; i < routes.length; i++) {
        if (routes[i].durationSeconds < routes[best].durationSeconds) {
          best = i;
        }
      }

      setState(() {
        _routes = routes;
        _selected = best;
      });

      await _showRoute();
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(
          () => _error = error is TravelRouteException
              ? error.message
              : 'The route could not be loaded. Please try again.',
        );
      }
    } finally {
      if (mounted && revision == _revision) {
        setState(() => _loading = false);
      }
    }
  }

  // Switch the visible route without another billable API request.
  void _selectRoute(int index) {
    setState(() => _selected = index);
    _showRoute();
  }

  // ---------------------------------------------------------------------------
  // MAP CAMERA AND LABELS
  // ---------------------------------------------------------------------------
  // Bring the map into view so the calculated route is immediately visible.
  Future<void> _showRoute() async {
    final mapContext = _mapKey.currentContext;

    if (mapContext != null) {
      await Scrollable.ensureVisible(
        mapContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    }

    if (mounted) await _fitRoute();
  }

  // Leave manual controls usable if automatic camera positioning is unavailable.
  Future<void> _move(CameraUpdate update) async {
    try {
      if (mounted) await _map?.animateCamera(update);
    } catch (_) {
      debugPrint('ROUTE MAP CAMERA: automatic positioning unavailable.');
    }
  }

  // Fit the complete selected route within the visible map.
  Future<void> _fitRoute() async {
    if (_routes.isEmpty) return;

    final points = _routes[_selected].points;
    final south = points.map((p) => p.latitude).reduce(math.min);
    final north = points.map((p) => p.latitude).reduce(math.max);
    final west = points.map((p) => p.longitude).reduce(math.min);
    final east = points.map((p) => p.longitude).reduce(math.max);

    if (south == north && west == east) {
      await _move(CameraUpdate.newLatLngZoom(points.first, 15));
    } else {
      await _move(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(south, west),
            northeast: LatLng(north, east),
          ),
          32,
        ),
      );
    }
  }

  // Round estimates without implying exact arrival times.
  String _duration(double seconds) {
    final minutes = (seconds / 60).ceil();

    if (minutes < 1) return 'Under 1 min';
    if (minutes < 60) return '$minutes min';

    return '${minutes ~/ 60} hr ${minutes % 60} min';
  }

  String _distance(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';

  // Open provider attribution links using only web URL schemes.
  Future<void> _openCredit(String? value) async {
    final uri = Uri.tryParse(value ?? '');

    if (uri == null || !['https', 'http'].contains(uri.scheme)) return;

    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      debugPrint('ROUTE ATTRIBUTION: link unavailable.');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The provider link could not be opened.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final supportsMap =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    final credits = <String, Map<String, dynamic>>{
      for (final item in [...?_origin?.credits, ...?_destination?.credits])
        '${item['provider']}|${item['providerUri']}': item,
    }.values;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Planning'),
        actions: [
          IconButton(
            tooltip: 'Clear route',
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: !supportsMap
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Open the Android app to plan a route.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                children: [
                  Text(
                    _countryName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  const Text('Choose two places to compare travel options.'),
                  const SizedBox(height: 18),
                  _placeButton(
                    'Starting point',
                    _origin,
                    Icons.trip_origin_rounded,
                    () => _choosePlace(true),
                  ),
                  const SizedBox(height: 10),
                  _placeButton(
                    'Destination',
                    _destination,
                    Icons.place_outlined,
                    () => _choosePlace(false),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final mode in [
                        ('DRIVE', 'Drive', Icons.directions_car_outlined),
                        ('WALK', 'Walk', Icons.directions_walk_rounded),
                      ])
                        ChoiceChip(
                          label: Text(mode.$2),
                          avatar: Icon(mode.$3, size: 20),
                          selected: _mode == mode.$1,
                          showCheckmark: false,
                          onSelected: _loading
                              ? null
                              : (_) => setState(() {
                                  _mode = mode.$1;
                                  _clearRoutes();
                                }),
                        ),
                      IconButton(
                        tooltip: 'Swap starting point and destination',
                        onPressed:
                            _loading ||
                                (_origin == null && _destination == null)
                            ? null
                            : _swap,
                        icon: const Icon(Icons.swap_vert_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed:
                        _loading || _origin == null || _destination == null
                        ? null
                        : _findRoutes,
                    icon: const Icon(Icons.alt_route_rounded),
                    label: Text(_loading ? 'Finding routes…' : 'Find routes'),
                  ),
                  if (_loading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    key: _mapKey,
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: (MediaQuery.sizeOf(context).height * 0.4).clamp(
                        240.0,
                        360.0,
                      ),
                      child: GoogleMap(
                        initialCameraPosition: _camera,
                        mapToolbarEnabled: false,
                        myLocationButtonEnabled: false,
                        compassEnabled: true,
                        zoomControlsEnabled: true,
                        gestureRecognizers: {
                          Factory<OneSequenceGestureRecognizer>(
                            () => EagerGestureRecognizer(),
                          ),
                        },
                        onMapCreated: (controller) {
                          _map = controller;

                          if (_routes.isNotEmpty) {
                            _fitRoute();
                          }
                        },
                        markers: {
                          if (_origin != null)
                            Marker(
                              markerId: const MarkerId('origin'),
                              position: _origin!.position,
                              infoWindow: InfoWindow(
                                title: 'Starting point',
                                snippet: _origin!.label,
                              ),
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueGreen,
                              ),
                            ),
                          if (_destination != null)
                            Marker(
                              markerId: const MarkerId('destination'),
                              position: _destination!.position,
                              infoWindow: InfoWindow(
                                title: 'Destination',
                                snippet: _destination!.label,
                              ),
                            ),
                        },
                        polylines: {
                          for (int i = 0; i < _routes.length; i++)
                            Polyline(
                              polylineId: PolylineId('route_$i'),
                              points: _routes[i].points,
                              color: i == _selected
                                  ? AppColors.primary
                                  : const Color(0xFFAD9FB3),
                              width: i == _selected ? 6 : 3,
                              zIndex: i == _selected ? 1 : 0,
                              consumeTapEvents: true,
                              onTap: () => _selectRoute(i),
                            ),
                        },
                      ),
                    ),
                  ),
                  for (final credit in credits)
                    TextButton(
                      onPressed: () =>
                          _openCredit(credit['providerUri'] as String?),
                      child: Text(
                        credit['provider'] as String? ?? 'Map data provider',
                      ),
                    ),
                  if (_routes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      '${_routes.length} route option${_routes.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Compare distance and estimated time. Live traffic is not included.',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Google Maps',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF5E5E5E),
                        ),
                      ),
                    ),
                    for (int i = 0; i < _routes.length; i++) _routeCard(i),
                    if (_mode == 'WALK')
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'Walking routes are in beta and may omit sidewalks or pedestrian paths. Use caution.',
                        ),
                      ),
                    for (final warning in _routes[_selected].warnings)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(warning),
                      ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _placeButton(
    String label,
    TravelPlace? place,
    IconData icon,
    VoidCallback onTap,
  ) => OutlinedButton(
    onPressed: _loading || _picking || !_views.containsKey(_countryId)
        ? null
        : onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
                Text(
                  place?.label ?? 'Choose a place',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );

  Widget _routeCard(int index) {
    final route = _routes[index];

    final fastest = _routes.every(
      (item) => route.durationSeconds <= item.durationSeconds,
    );

    final shortest = _routes.every(
      (item) => route.distanceMeters <= item.distanceMeters,
    );

    return Card(
      color: index == _selected ? AppColors.primaryLight : Colors.white,
      child: ListTile(
        selected: index == _selected,
        leading: Icon(
          index == _selected
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
        ),
        title: Text('Route ${index + 1}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (route.description.isNotEmpty) Text(route.description),
            Text(
              '${_distance(route.distanceMeters)} · ${_duration(route.durationSeconds)}',
            ),
            if (_routes.length > 1)
              Wrap(
                spacing: 12,
                children: [
                  if (fastest)
                    const Text(
                      'Shortest estimated time',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  if (shortest)
                    const Text(
                      'Shortest distance',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                ],
              ),
          ],
        ),
        onTap: () => _selectRoute(index),
      ),
    );
  }
}
