import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/trip.dart';
import '../services/route_plan_service.dart';
import '../services/travel_route_service.dart';
import '../theme/app_theme.dart';
import 'place_search_screen.dart';

class TripMapScreen extends StatefulWidget {
  const TripMapScreen({
    super.key,
    required this.trip,
    this.service,
    this.planService,
  });

  final Trip trip;
  final TravelRouteService? service;
  final RoutePlanService? planService;

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  static const _maxStops = 5;

  final _stops = <TravelPlace>[];
  final _icons = <String, BitmapDescriptor>{};
  final _mapKey = GlobalKey();

  late final TravelRouteService _service;
  late final RoutePlanService _planService;

  SavedRoutePlan? _savedPlan;
  String? _planError;

  bool _planBusy = true;
  bool _planLoaded = false;
  bool _writingPlan = false;
  bool _edited = false;
  bool _allowPop = false;
  bool _leaveDialog = false;

  int _planRevision = 0;

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

  // Share services and check for an existing saved plan.
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? TravelRouteService();
    _planService = widget.planService ?? RoutePlanService();
    _loadPlan();
  }

  // Discard late results and release the service owned by this screen.
  @override
  void dispose() {
    _revision++;
    _planRevision++;
    _markerRevision++;
    _map = null;

    if (widget.service == null) {
      _service.dispose();
    }

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // SAVED ROUTE PLANS
  // ---------------------------------------------------------------------------
  // Keep edits unavailable until the saved record has been checked.
  bool get _busy => _loading || _picking || _planBusy || !_planLoaded;

  // Read the current order, including endpoints that are not selected yet.
  List<String?> get _draftIds => [
    _origin?.id,
    ..._stops.map((place) => place.id),
    _destination?.id,
  ];

  // Ignore refreshed Google data when comparing saved choices.
  bool get _hasChanges {
    if (!_edited) return false;

    if (_savedPlan != null) {
      return !_savedPlan!.matches(_mode, _draftIds);
    }

    return _origin != null || _destination != null || _stops.isNotEmpty;
  }

  // Invalidate geometry whenever the selected journey changes.
  void _clearRoutes() {
    _revision++;
    _routes = [];
    _selected = 0;
    _selectedLeg = null;
    _loading = false;
    _error = null;
  }

  // Mark manual changes without changing the saved record.
  void _markChanged() {
    _edited = true;
    _planError = null;
    _clearRoutes();
  }

  // Translate storage errors into traveller-facing messages.
  String _planMessage(Object error) {
    if (error is TravelRouteException) return error.message;
    if (error is StateError) return error.message.toString();
    if (error is FormatException) return error.message;

    return 'Could not access your saved route plan. Check your connection and retry.';
  }

  // Restore saved choices with fresh Places data.
  Future<void> _loadPlan() async {
    final revision = ++_planRevision;

    setState(() {
      _planBusy = true;
      _planLoaded = false;
      _planError = null;
    });

    try {
      final plan = await _planService.load(widget.trip);

      if (!mounted || revision != _planRevision) return;

      _savedPlan = plan;
      _planLoaded = true;

      final places = plan == null
          ? <TravelPlace>[]
          : await _service.restorePlaces(
              countryId: _countryId,
              placeIds: plan.placeIds,
            );

      if (!mounted || revision != _planRevision) return;

      setState(() {
        _origin = places.isEmpty ? null : places.first;
        _destination = places.isEmpty ? null : places.last;

        _stops
          ..clear()
          ..addAll(places.isEmpty ? [] : places.sublist(1, places.length - 1));

        _mode = plan?.travelMode ?? 'DRIVE';
        _edited = false;
        _clearRoutes();
      });

      _refreshMarkers();
    } catch (error) {
      if (mounted && revision == _planRevision) {
        setState(() => _planError = _planMessage(error));
      }
    } finally {
      if (mounted && revision == _planRevision) {
        setState(() => _planBusy = false);
      }
    }
  }

  // Save the ordered IDs and mode after validating a complete draft.
  Future<bool> _savePlan() async {
    if (_busy || _origin == null || _destination == null) {
      return false;
    }

    late final SavedRoutePlan plan;

    try {
      plan = SavedRoutePlan(
        countryId: widget.trip.destinationCountryId,
        travelMode: _mode,
        placeIds: _draftIds.cast<String>(),
      );
    } on FormatException catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return false;
    }

    setState(() {
      _planBusy = true;
      _writingPlan = true;
    });

    try {
      await _planService.save(widget.trip, plan);

      if (!mounted) return false;

      setState(() {
        _savedPlan = plan;
        _edited = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Route plan saved.')));

      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_planMessage(error))));
      }

      return false;
    } finally {
      if (mounted) {
        setState(() {
          _planBusy = false;
          _writingPlan = false;
        });
      }
    }
  }

  // Remove only the saved copy after explicit confirmation.
  Future<void> _deletePlan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete saved route plan?'),
        content: const Text('Your current draft will stay on this screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true || _busy) return;

    setState(() {
      _planBusy = true;
      _writingPlan = true;
    });

    try {
      await _planService.delete(widget.trip);

      if (!mounted) return;

      setState(() {
        _savedPlan = null;
        _edited = _visits.isNotEmpty;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved plan deleted. Your draft is still here.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_planMessage(error))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _planBusy = false;
          _writingPlan = false;
        });
      }
    }
  }

  // Prevent accidental loss of edited choices when leaving the planner.
  Future<void> _confirmLeave() async {
    if (_writingPlan || _leaveDialog) return;

    _leaveDialog = true;

    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unsaved route changes'),
        content: const Text('Save your changes before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: const Text('Discard changes'),
          ),
          if (_origin != null && _destination != null)
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.pop(dialogContext, 'save'),
              child: const Text('Save and leave'),
            ),
        ],
      ),
    );

    _leaveDialog = false;

    if (!mounted || choice == null) return;
    if (choice == 'save' && !await _savePlan()) return;
    if (!mounted) return;

    setState(() => _allowPop = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  // ---------------------------------------------------------------------------
  // PLACE AND ROUTE ACTIONS
  // ---------------------------------------------------------------------------
  // Keep visit numbers stable while endpoints are being selected.
  List<(int, TravelPlace)> get _visits => [
    if (_origin != null) (1, _origin!),
    for (int i = 0; i < _stops.length; i++) (i + 2, _stops[i]),
    if (_destination != null) (_stops.length + 2, _destination!),
  ];

  // Select an endpoint, add a stop, or replace an existing stop.
  Future<void> _choosePlace({bool? startingPoint, int? stopIndex}) async {
    if (_busy) return;

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

      _markChanged();
    });

    if (place != null) {
      _refreshMarkers();
      await _move(CameraUpdate.newLatLngZoom(place.position, 13));
    }
  }

  // Move or remove a stop without another route request.
  void _changeStop(int index, {int? direction}) {
    setState(() {
      if (direction == null) {
        _stops.removeAt(index);
      } else {
        final place = _stops.removeAt(index);
        _stops.insert(index + direction, place);
      }

      _markChanged();
    });

    _refreshMarkers();
  }

  // Reverse the complete journey and mark it as edited.
  void _swap() {
    setState(() {
      final previous = _origin;
      _origin = _destination;
      _destination = previous;

      final reversed = _stops.reversed.toList();

      _stops
        ..clear()
        ..addAll(reversed);

      _markChanged();
    });

    _refreshMarkers();
  }

  // Clear only the draft; the saved copy remains available.
  void _reset() {
    setState(() {
      _origin = null;
      _destination = null;
      _stops.clear();
      _markChanged();
    });

    _refreshMarkers();
    _move(CameraUpdate.newCameraPosition(_camera));
  }

  // Calculate the journey and initially focus its first section.
  Future<void> _findRoutes() async {
    if (_busy || _origin == null || _destination == null) {
      return;
    }

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

  // Show the complete route using the existing response.
  void _selectRoute(int index) {
    setState(() {
      _selected = index;
      _selectedLeg = null;
    });

    _refreshMarkers();
    _showRoute();
  }

  // Focus one section using the existing response.
  void _selectLeg(int index) {
    setState(() => _selectedLeg = index);

    _refreshMarkers();
    _showRoute();
  }

  // Keep original visit numbers for the selected section.
  List<(int, TravelPlace)> get _mapVisits {
    final visits = _visits;

    if (_selectedLeg == null || _routes.isEmpty) return visits;

    return visits.sublist(_selectedLeg!, _selectedLeg! + 2);
  }

  // Return the geometry currently displayed.
  List<LatLng> get _mapPoints {
    if (_routes.isEmpty) return const [];

    final route = _routes[_selected];

    return _selectedLeg == null
        ? route.points
        : route.legs[_selectedLeg!].points;
  }

  // Hide other sections when one segment is selected.
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
  // Combine repeat visits within the current map selection.
  Map<String, List<(int, TravelPlace)>> get _markerGroups {
    final groups = <String, List<(int, TravelPlace)>>{};

    for (final visit in _mapVisits) {
      (groups[visit.$2.id] ??= []).add(visit);
    }

    return groups;
  }

  // Draw numbered PNGs locally without an API request.
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

  // Cache icons and discard updates from an older selection.
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

  // Keep visit numbers available while marker images are prepared.
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
  // MAP CAMERA AND DISPLAY HELPERS
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

  // Preserve manual controls if automatic positioning fails.
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

  // Open attribution links using web URL schemes only.
  Future<void> _openCredit(String? value) async {
    final uri = Uri.tryParse(value ?? '');

    if (uri == null || !['https', 'http'].contains(uri.scheme)) {
      return;
    }

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

    return PopScope(
      canPop: !_writingPlan && (_allowPop || !_hasChanges),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Route Planning')),
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
                      const Text('Plan your journey, one place at a time.'),
                      const SizedBox(height: 14),
                      _planPanel(),
                      const SizedBox(height: 18),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Your places',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Add up to five stops in your visit order.',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 14),
                              _placeButton(
                                'Starting point',
                                _origin,
                                1,
                                () => _choosePlace(startingPoint: true),
                              ),
                              const SizedBox(height: 10),
                              for (int i = 0; i < _stops.length; i++)
                                _stopCard(i),
                              OutlinedButton.icon(
                                onPressed:
                                    _busy ||
                                        _stops.length >= _maxStops ||
                                        !_views.containsKey(_countryId)
                                    ? null
                                    : () => _choosePlace(),
                                icon: const Icon(
                                  Icons.add_location_alt_outlined,
                                ),
                                label: Text(
                                  'Add stop (${_stops.length}/$_maxStops)',
                                ),
                              ),
                              const SizedBox(height: 10),
                              _placeButton(
                                'Destination',
                                _destination,
                                _stops.length + 2,
                                () => _choosePlace(startingPoint: false),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  for (final mode in [
                                    (
                                      'DRIVE',
                                      'Drive',
                                      Icons.directions_car_outlined,
                                    ),
                                    (
                                      'WALK',
                                      'Walk',
                                      Icons.directions_walk_rounded,
                                    ),
                                  ])
                                    ChoiceChip(
                                      label: Text(mode.$2),
                                      avatar: Icon(mode.$3, size: 20),
                                      selected: _mode == mode.$1,
                                      showCheckmark: false,
                                      onSelected: _busy
                                          ? null
                                          : (_) => setState(() {
                                              _mode = mode.$1;
                                              _markChanged();
                                            }),
                                    ),
                                  Tooltip(
                                    message: 'Reverse route',
                                    child: TextButton.icon(
                                      onPressed:
                                          _busy ||
                                              (_origin == null &&
                                                  _destination == null &&
                                                  _stops.isEmpty)
                                          ? null
                                          : _swap,
                                      icon: const Icon(Icons.swap_vert_rounded),
                                      label: const Text('Reverse route'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed:
                            _busy || _origin == null || _destination == null
                            ? null
                            : _findRoutes,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.alt_route_rounded),
                        label: Text(
                          _loading ? 'Finding routes…' : 'Find routes',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed:
                            _busy ||
                                !_hasChanges ||
                                _origin == null ||
                                _destination == null
                            ? null
                            : _savePlan,
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: Text(
                          _savedPlan == null ? 'Save plan' : 'Save changes',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Saving keeps your places and visit order. '
                        'Find routes refreshes distance and time estimates.',
                        style: TextStyle(fontSize: 12),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        'Route preview',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        key: _mapKey,
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          height: (MediaQuery.sizeOf(context).height * 0.4)
                              .clamp(240.0, 360.0),
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
                              if (_routes.isNotEmpty) _fitRoute();
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
                            credit['provider'] as String? ??
                                'Map data provider',
                          ),
                        ),
                      if (_routes.isEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Choose your places, then find routes to see '
                          'your journey on the map.',
                        ),
                      ] else ...[
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
                              : 'Follows your stop order. Estimates exclude time spent at stops and live traffic.',
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
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
                        if (_mode == 'WALK' ||
                            _routes[_selected].warnings.isNotEmpty)
                          Card(
                            margin: const EdgeInsets.only(top: 14),
                            color: const Color(0xFFFFF4E6),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_mode == 'WALK')
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        'Walking routes are in beta and may omit '
                                        'sidewalks or pedestrian paths. Use caution.',
                                      ),
                                    ),
                                  for (final warning
                                      in _routes[_selected].warnings)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(warning),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 24),
                      _planOptions(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _planPanel() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _hasChanges
                  ? Icons.edit_note_rounded
                  : Icons.bookmark_border_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _planBusy
                    ? (_writingPlan ? 'Saving changes…' : 'Loading saved plan…')
                    : _planError != null
                    ? 'Plan unavailable'
                    : _hasChanges
                    ? 'Unsaved changes'
                    : _savedPlan == null
                    ? 'New route plan'
                    : 'Saved route plan',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (_planBusy) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(),
        ] else if (_planError != null) ...[
          const SizedBox(height: 8),
          Text(_planError!, style: const TextStyle(color: AppColors.danger)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _loadPlan, child: const Text('Retry')),
          ),
        ] else ...[
          const SizedBox(height: 6),
          Text(
            _hasChanges
                ? 'Your latest place or travel-mode changes have not been saved.'
                : _savedPlan == null
                ? 'Choose places below to start planning.'
                : 'Places restored. Find routes for current travel estimates.',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ],
    ),
  );

  Widget _placeButton(
    String label,
    TravelPlace? place,
    int number,
    VoidCallback onTap,
  ) => OutlinedButton(
    onPressed: _busy || !_views.containsKey(_countryId) ? null : onTap,
    style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(12)),
    child: Row(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: AppColors.primaryLight,
          foregroundColor: AppColors.primary,
          child: FittedBox(child: Text('$number')),
        ),
        const SizedBox(width: 10),
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
              const SizedBox(height: 3),
              Text(
                place?.label ?? 'Choose a place',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, size: 20),
      ],
    ),
  );

  Widget _stopCard(int index) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _placeButton(
        'Stop ${index + 1}',
        _stops[index],
        index + 2,
        () => _choosePlace(stopIndex: index),
      ),
      Wrap(
        alignment: WrapAlignment.end,
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Move stop ${index + 1} up',
            onPressed: _busy || index == 0
                ? null
                : () => _changeStop(index, direction: -1),
            icon: const Icon(Icons.arrow_upward_rounded, size: 20),
          ),
          IconButton(
            tooltip: 'Move stop ${index + 1} down',
            onPressed: _busy || index == _stops.length - 1
                ? null
                : () => _changeStop(index, direction: 1),
            icon: const Icon(Icons.arrow_downward_rounded, size: 20),
          ),
          IconButton(
            tooltip: 'Remove stop ${index + 1}',
            onPressed: _busy ? null : () => _changeStop(index),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    ],
  );

  Widget _mapSelectionSummary() {
    final leg = _selectedLeg;
    final places = _visits.map((visit) => visit.$2).toList();

    return Card(
      margin: const EdgeInsets.only(top: 12),
      color: AppColors.primaryLight,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              leg == null
                  ? 'Showing the complete route'
                  : 'Showing ${leg + 1} → ${leg + 2}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (leg != null) ...[
              const SizedBox(height: 8),
              _legPlaces(places[leg], places[leg + 1]),
            ],
            TextButton.icon(
              onPressed: leg == null ? null : () => _selectRoute(_selected),
              icon: const Icon(Icons.route_outlined),
              label: const Text('Show complete route'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legPlaces(TravelPlace start, TravelPlace end) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('From: ${start.label}', style: const TextStyle(fontSize: 13)),
      const SizedBox(height: 4),
      Text('To: ${end.label}', style: const TextStyle(fontSize: 13)),
    ],
  );

  Widget _journeyDetails() {
    final legs = _routes[_selected].legs;
    final places = _visits.map((visit) => visit.$2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        Text(
          'Between your stops',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        const Text('Tap a section to show only that part on the map.'),
        const SizedBox(height: 8),
        for (int i = 0; i < legs.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: _selectedLeg == i ? AppColors.primaryLight : Colors.white,
            clipBehavior: Clip.antiAlias,
            child: Semantics(
              button: true,
              selected: _selectedLeg == i,
              child: InkWell(
                onTap: () => _selectLeg(i),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _selectedLeg == i
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${i + 1} → ${i + 2}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _legPlaces(places[i], places[i + 1]),
                      const SizedBox(height: 10),
                      Text(
                        '${_distance(legs[i].distanceMeters)} · '
                        '${_duration(legs[i].durationSeconds)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Compare only the alternatives returned for the current request.
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
      margin: const EdgeInsets.only(bottom: 10),
      color: selected ? AppColors.primaryLight : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: () => _selectRoute(index),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _stops.isEmpty ? 'Route ${index + 1}' : 'Journey total',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${_distance(route.distanceMeters)} · ${_duration(route.durationSeconds)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                if (route.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    route.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
                if (_routes.length > 1 && (fastest || shortest)) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (fastest) _routeBadge('Shortest estimated time'),
                      if (shortest) _routeBadge('Shortest distance'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _routeBadge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    ),
  );

  Widget _planOptions() => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Plan options', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'Clearing the draft keeps your saved plan.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          Tooltip(
            message: 'Clear draft',
            child: OutlinedButton.icon(
              onPressed: _planBusy || !_planLoaded ? null : _reset,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Clear draft'),
            ),
          ),
          if (_savedPlan != null) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: _busy ? null : _deletePlan,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete saved plan'),
            ),
          ],
        ],
      ),
    ),
  );
}
