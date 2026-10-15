import 'dart:math' as math;
import 'dart:ui' as ui;

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
  static const _maxStops = 5;

  final _stops = <TravelPlace>[];
  final _icons = <String, BitmapDescriptor>{};
  final _mapKey = GlobalKey();

  late final TravelRouteService _service;

  GoogleMapController? _map;
  TravelPlace? _origin;
  TravelPlace? _destination;

  List<TravelRoute> _routes = [];

  String _mode = 'DRIVE';
  String? _error;

  bool _loading = false;
  bool _picking = false;

  int? _selectedLeg;
  int _selected = 0;
  int _revision = 0;
  int _markerRevision = 0;

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

  // Share one service between planning and place-selection screens.
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? TravelRouteService();
  }

  // Discard late results and release the service owned by this screen.
  @override
  void dispose() {
    _revision++;
    _markerRevision++;
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
    _selectedLeg = null;
    _loading = false;
    _error = null;
  }

  // Keep visit numbers stable while endpoints are still being selected.
  List<(int, TravelPlace)> get _visits => [
    if (_origin != null) (1, _origin!),
    for (int i = 0; i < _stops.length; i++) (i + 2, _stops[i]),
    if (_destination != null) (_stops.length + 2, _destination!),
  ];

  // Select an endpoint, add a stop, or replace an existing stop.
  Future<void> _choosePlace({bool? startingPoint, int? stopIndex}) async {
    if (_loading || _picking) return;

    if (startingPoint == null &&
        stopIndex == null &&
        _stops.length >= _maxStops) {
      return;
    }

    setState(() => _picking = true);

    final place = await Navigator.push<TravelPlace>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceSearchScreen(
          countryId: _countryId,
          countryName: _countryName,
          title: startingPoint == true
              ? 'Starting point'
              : startingPoint == false
              ? 'Destination'
              : stopIndex == null
              ? 'Add stop'
              : 'Stop ${stopIndex + 1}',
          service: _service,
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _picking = false;

      if (place == null) return;

      if (startingPoint == true) {
        _origin = place;
      } else if (startingPoint == false) {
        _destination = place;
      } else if (stopIndex != null) {
        _stops[stopIndex] = place;
      } else {
        _stops.add(place);
      }

      _clearRoutes();
    });

    if (place != null) {
      _refreshMarkers();
      await _move(CameraUpdate.newLatLngZoom(place.position, 13));
    }
  }

  // Move or remove a stop without automatically making another API request.
  void _changeStop(int index, {int? direction}) {
    setState(() {
      if (direction == null) {
        _stops.removeAt(index);
      } else {
        final place = _stops.removeAt(index);
        _stops.insert(index + direction, place);
      }

      _clearRoutes();
    });

    _refreshMarkers();
  }

  // Reverse the complete journey, including the intermediate stops.
  void _swap() {
    setState(() {
      final previous = _origin;
      _origin = _destination;
      _destination = previous;

      final reversed = _stops.reversed.toList();

      _stops
        ..clear()
        ..addAll(reversed);

      _clearRoutes();
    });

    _refreshMarkers();
  }

  // Clear the draft route and restore the destination-country view.
  void _reset() {
    setState(() {
      _origin = null;
      _destination = null;
      _stops.clear();
      _clearRoutes();
    });

    _refreshMarkers();
    _move(CameraUpdate.newCameraPosition(_camera));
  }

  // Calculate the journey and initially focus its first section when stops exist.
  Future<void> _findRoutes() async {
    if (_loading || _origin == null || _destination == null) return;

    final places = _visits.map((visit) => visit.$2).toList();

    for (int i = 1; i < places.length; i++) {
      if (places[i].id == places[i - 1].id) {
        setState(() => _error = 'Consecutive places must be different.');
        return;
      }
    }

    final revision = ++_revision;

    setState(() {
      _loading = true;
      _selectedLeg = null;
      _routes = [];
      _error = null;
    });

    try {
      final routes = await _service.computeRoutes(
        origin: _origin!,
        destination: _destination!,
        travelMode: _mode,
        stops: List.unmodifiable(_stops),
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
        _selectedLeg = _stops.isEmpty ? null : 0;
      });

      _refreshMarkers();
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

  // Show the complete route without requesting new data.
  void _selectRoute(int index) {
    setState(() {
      _selected = index;
      _selectedLeg = null;
    });

    _refreshMarkers();
    _showRoute();
  }

  // Focus one section of the existing journey.
  void _selectLeg(int index) {
    setState(() => _selectedLeg = index);

    _refreshMarkers();
    _showRoute();
  }

  // Keep original visit numbers while showing the selected section's endpoints.
  List<(int, TravelPlace)> get _mapVisits {
    final visits = _visits;

    if (_selectedLeg == null || _routes.isEmpty) return visits;

    return visits.sublist(_selectedLeg!, _selectedLeg! + 2);
  }

  // Return the geometry currently displayed on the map.
  List<LatLng> get _mapPoints {
    if (_routes.isEmpty) return const [];

    final route = _routes[_selected];

    return _selectedLeg == null
        ? route.points
        : route.legs[_selectedLeg!].points;
  }

  // Hide other sections when a segment card is selected.
  Set<Polyline> get _polylines {
    if (_routes.isEmpty) return {};

    if (_selectedLeg != null) {
      return {
        Polyline(
          polylineId: PolylineId('leg_$_selectedLeg'),
          points: _mapPoints,
          color: AppColors.primary,
          width: 6,
        ),
      };
    }

    return {
      for (int i = 0; i < _routes.length; i++)
        Polyline(
          polylineId: PolylineId('route_$i'),
          points: _routes[i].points,
          color: i == _selected ? AppColors.primary : const Color(0xFFAD9FB3),
          width: i == _selected ? 6 : 3,
          zIndex: i == _selected ? 1 : 0,
          consumeTapEvents: true,
          onTap: () => _selectRoute(i),
        ),
    };
  }

  // ---------------------------------------------------------------------------
  // NUMBERED MARKERS
  // ---------------------------------------------------------------------------
  // Combine repeat visits only when they belong to the current map selection.
  Map<String, List<(int, TravelPlace)>> get _markerGroups {
    final groups = <String, List<(int, TravelPlace)>>{};

    for (final visit in _mapVisits) {
      (groups[visit.$2.id] ??= []).add(visit);
    }

    return groups;
  }

  // Draw numbered PNGs locally without another dependency or API request.
  Future<BitmapDescriptor> _numberIcon(String label, double ratio) async {
    const size = 48.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(ratio);

    canvas.drawCircle(const Offset(24, 24), 22, Paint()..color = Colors.white);

    canvas.drawCircle(
      const Offset(24, 24),
      19,
      Paint()..color = AppColors.primary,
    );

    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: label.length > 1 ? 12 : 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 38);

    painter.paint(
      canvas,
      Offset((size - painter.width) / 2, (size - painter.height) / 2),
    );

    final picture = recorder.endRecording();

    final image = await picture.toImage(
      (size * ratio).ceil(),
      (size * ratio).ceil(),
    );

    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

      if (bytes == null) {
        throw const FormatException('Marker image unavailable.');
      }

      return BitmapDescriptor.bytes(
        bytes.buffer.asUint8List(),
        width: size,
        height: size,
      );
    } finally {
      image.dispose();
      picture.dispose();
      painter.dispose();
    }
  }

  // Cache icons and discard updates from an older map selection.
  Future<void> _refreshMarkers() async {
    final revision = ++_markerRevision;
    final ratio = MediaQuery.devicePixelRatioOf(context);

    try {
      for (final group in _markerGroups.values) {
        final label = group.map((visit) => visit.$1).join(',');
        final key = '$label@$ratio';

        if (!_icons.containsKey(key)) {
          _icons[key] = await _numberIcon(label, ratio);
        }

        if (!mounted || revision != _markerRevision) return;
      }

      if (mounted && revision == _markerRevision) {
        setState(() {});
      }
    } catch (_) {
      debugPrint('ROUTE MARKERS: using standard map markers.');
    }
  }

  // Keep visit numbers in titles while marker images are being prepared.
  Set<Marker> get _markers {
    final ratio = MediaQuery.devicePixelRatioOf(context);

    return {
      for (final group in _markerGroups.values)
        Marker(
          markerId: MarkerId(group.first.$2.id),
          position: group.first.$2.position,
          anchor: const Offset(0.5, 0.5),
          icon:
              _icons['${group.map((v) => v.$1).join(',')}@$ratio'] ??
              BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(
            title: 'Visit ${group.map((v) => v.$1).join(', ')}',
            snippet: group.first.$2.label,
          ),
        ),
    };
  }

  // ---------------------------------------------------------------------------
  // MAP CAMERA AND LABELS
  // ---------------------------------------------------------------------------
  // Bring the selected section or complete route into view.
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

  // Keep manual map controls usable if automatic positioning fails.
  Future<void> _move(CameraUpdate update) async {
    try {
      if (mounted) await _map?.animateCamera(update);
    } catch (_) {
      debugPrint('ROUTE MAP CAMERA: automatic positioning unavailable.');
    }
  }

  // Fit the camera to the geometry currently displayed.
  Future<void> _fitRoute() async {
    if (_routes.isEmpty) return;

    final points = _mapPoints;

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
      for (final visit in _visits)
        for (final item in visit.$2.credits)
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
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _countryName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose your start and destination. Add up to five stops in the order you want to visit them.',
                    ),
                    const SizedBox(height: 18),
                    _placeButton(
                      'Starting point',
                      _origin,
                      1,
                      () => _choosePlace(startingPoint: true),
                    ),
                    const SizedBox(height: 12),
                    for (int i = 0; i < _stops.length; i++) _stopCard(i),
                    OutlinedButton.icon(
                      onPressed:
                          _loading ||
                              _picking ||
                              _stops.length >= _maxStops ||
                              !_views.containsKey(_countryId)
                          ? null
                          : () => _choosePlace(),
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: Text('Add stop (${_stops.length}/$_maxStops)'),
                    ),
                    const SizedBox(height: 12),
                    _placeButton(
                      'Destination',
                      _destination,
                      _stops.length + 2,
                      () => _choosePlace(startingPoint: false),
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
                            onSelected: _loading || _picking
                                ? null
                                : (_) => setState(() {
                                    _mode = mode.$1;
                                    _clearRoutes();
                                  }),
                          ),
                        IconButton(
                          tooltip: 'Reverse route',
                          onPressed:
                              _loading ||
                                  _picking ||
                                  (_origin == null &&
                                      _destination == null &&
                                      _stops.isEmpty)
                              ? null
                              : _swap,
                          icon: const Icon(Icons.swap_vert_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed:
                          _loading ||
                              _picking ||
                              _origin == null ||
                              _destination == null
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
                          markers: _markers,
                          polylines: _polylines,
                        ),
                      ),
                    ),
                    if (_routes.isNotEmpty && _stops.isNotEmpty)
                      _mapSelectionSummary(),
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
                        _stops.isEmpty
                            ? '${_routes.length} route option${_routes.length == 1 ? '' : 's'}'
                            : 'Your complete route',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _stops.isEmpty
                            ? 'Compare distance and estimated time. Live traffic is not included.'
                            : 'Follows your stop order. Travel estimates exclude time spent at stops and live traffic.',
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
                      if (_stops.isNotEmpty) _journeyDetails(),
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
      ),
    );
  }

  Widget _placeButton(
    String label,
    TravelPlace? place,
    int number,
    VoidCallback onTap,
  ) => OutlinedButton(
    onPressed: _loading || _picking || !_views.containsKey(_countryId)
        ? null
        : onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(radius: 16, child: FittedBox(child: Text('$number'))),
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

  Widget _stopCard(int index) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          _placeButton(
            'Stop ${index + 1}',
            _stops[index],
            index + 2,
            () => _choosePlace(stopIndex: index),
          ),
          Wrap(
            spacing: 8,
            children: [
              IconButton(
                tooltip: 'Move stop ${index + 1} up',
                onPressed: _loading || _picking || index == 0
                    ? null
                    : () => _changeStop(index, direction: -1),
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              IconButton(
                tooltip: 'Move stop ${index + 1} down',
                onPressed: _loading || _picking || index == _stops.length - 1
                    ? null
                    : () => _changeStop(index, direction: 1),
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
              IconButton(
                tooltip: 'Remove stop ${index + 1}',
                onPressed: _loading || _picking
                    ? null
                    : () => _changeStop(index),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _mapSelectionSummary() {
    final leg = _selectedLeg;
    final places = _visits.map((visit) => visit.$2).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            leg == null
                ? 'Showing the complete route'
                : 'Showing ${leg + 1} → ${leg + 2}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (leg != null)
            Text('${places[leg].label} → ${places[leg + 1].label}'),
          TextButton.icon(
            onPressed: leg == null ? null : () => _selectRoute(_selected),
            icon: const Icon(Icons.route_outlined),
            label: const Text('Show complete route'),
          ),
        ],
      ),
    );
  }

  Widget _journeyDetails() {
    final legs = _routes[_selected].legs;
    final places = _visits.map((visit) => visit.$2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Between your stops',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        const Text('Tap a section to show only that part on the map.'),
        for (int i = 0; i < legs.length; i++)
          Card(
            color: _selectedLeg == i ? AppColors.primaryLight : Colors.white,
            child: ListTile(
              selected: _selectedLeg == i,
              leading: Icon(
                _selectedLeg == i
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
              ),
              title: Text('${i + 1} → ${i + 2}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${places[i].label} → ${places[i + 1].label}'),
                  const SizedBox(height: 6),
                  Text(
                    '${_distance(legs[i].distanceMeters)} · ${_duration(legs[i].durationSeconds)}',
                  ),
                ],
              ),
              onTap: () => _selectLeg(i),
            ),
          ),
      ],
    );
  }

  Widget _routeCard(int index) {
    final route = _routes[index];
    final selected = index == _selected && _selectedLeg == null;

    final fastest = _routes.every(
      (item) => route.durationSeconds <= item.durationSeconds,
    );

    final shortest = _routes.every(
      (item) => route.distanceMeters <= item.distanceMeters,
    );

    return Card(
      color: selected ? AppColors.primaryLight : Colors.white,
      child: ListTile(
        selected: selected,
        leading: Icon(
          selected
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
        ),
        title: Text(_stops.isEmpty ? 'Route ${index + 1}' : 'Journey total'),
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
