import 'dart:async';

import 'package:flutter/material.dart';

import '../services/travel_route_service.dart';

class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({
    super.key,
    required this.countryId,
    required this.countryName,
    required this.title,
    required this.service,
  });

  final String countryId;
  final String countryName;
  final String title;
  final TravelRouteService service;

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final _controller = TextEditingController();

  String _sessionToken = TravelRouteService.newSessionToken();
  Timer? _debounce;

  int _revision = 0;
  bool _loading = false;
  bool _resolving = false;
  bool _searched = false;

  String? _error;
  List<TravelSuggestion> _results = [];

  // ---------------------------------------------------------------------------
  // SEARCH LIFECYCLE
  // ---------------------------------------------------------------------------
  // Stop delayed searches and discard responses after this screen closes.
  @override
  void dispose() {
    _debounce?.cancel();
    _revision++;
    _controller.dispose();
    super.dispose();
  }

  // Wait for a typing pause and invalidate results from older search text.
  void _changed(String value) {
    _debounce?.cancel();
    final revision = ++_revision;

    setState(() {
      _results = [];
      _error = null;
      _loading = false;
      _searched = false;
    });

    if (value.trim().length < 2) return;

    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => _search(value.trim(), revision),
    );
  }

  // Submit immediately when the keyboard search action or retry is pressed.
  void _searchNow() {
    _debounce?.cancel();
    final input = _controller.text.trim();

    if (input.length < 2 || _loading || _resolving) return;

    _search(input, ++_revision);
  }

  // Show only the response that belongs to the latest search text.
  Future<void> _search(String input, int revision) async {
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
    });

    try {
      final results = await widget.service.searchPlaces(
        countryId: widget.countryId,
        input: input,
        sessionToken: _sessionToken,
      );

      if (!mounted || revision != _revision) return;

      setState(() => _results = results);
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(
          () => _error = error is TravelRouteException
              ? error.message
              : 'Places could not be loaded. Please try again.',
        );
      }
    } finally {
      if (mounted && revision == _revision) {
        setState(() => _loading = false);
      }
    }
  }

  // Resolve one selection and return it to the route-planning screen.
  Future<void> _select(TravelSuggestion suggestion) async {
    if (_resolving) return;

    _debounce?.cancel();
    _revision++;

    setState(() {
      _resolving = true;
      _loading = false;
      _error = null;
    });

    try {
      final place = await widget.service.resolvePlace(
        countryId: widget.countryId,
        suggestion: suggestion,
        sessionToken: _sessionToken,
      );

      if (mounted) Navigator.pop(context, place);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _resolving = false;
        _sessionToken = TravelRouteService.newSessionToken();
        _error = error is TravelRouteException
            ? error.message
            : 'This place could not be selected. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('Search within ${widget.countryName}.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_resolving,
            maxLength: 200,
            textInputAction: TextInputAction.search,
            onChanged: _changed,
            onSubmitted: (_) => _searchNow(),
            decoration: InputDecoration(
              labelText: 'Search places',
              hintText: 'Station, hotel or landmark',
              counterText: '',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Clear search',
                onPressed: _resolving
                    ? null
                    : () {
                        _controller.clear();
                        _changed('');
                      },
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Align(
              alignment: Alignment.centerRight,
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
          ),
          if (_loading || _resolving) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(_resolving ? 'Confirming place…' : 'Searching places…'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: _searchNow,
              child: const Text('Try search again'),
            ),
          ],
          if (!_loading && !_resolving && _error == null && _results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                _controller.text.trim().length < 2
                    ? 'Enter at least two characters to find a place.'
                    : !_searched
                    ? 'Pause typing to search for places.'
                    : 'No matches found. Try a more specific place name.',
              ),
            ),
          for (final result in _results)
            Card(
              child: ListTile(
                enabled: !_resolving,
                leading: const Icon(Icons.place_outlined),
                title: Text(result.label),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _select(result),
              ),
            ),
        ],
      ),
    ),
  );
}
