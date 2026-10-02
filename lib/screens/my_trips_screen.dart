import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../services/trip_service.dart';
import 'checklist_screen.dart';
import 'packing_screen.dart';

class MyTripsScreen extends StatefulWidget {
  final bool embedded;

  const MyTripsScreen({super.key, this.embedded = false});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  final TripService _tripService = TripService();

  late Future<List<Trip>> _tripsFuture;

  @override
  void initState() {
    super.initState();
    _tripsFuture = _fetchTrips();
  }

  // Retrieves trips belonging to the currently logged-in traveller.
  Future<List<Trip>> _fetchTrips() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('No authenticated user was found.');
    }

    return _tripService.getUserTrips(currentUser.uid);
  }

  Future<void> _refreshTrips() async {
    final Future<List<Trip>> refreshedTrips = _fetchTrips();

    setState(() {
      _tripsFuture = refreshedTrips;
    });

    await refreshedTrips;
  }

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _formatText(String value) {
    if (value.isEmpty) {
      return value;
    }

    return value
        .split('_')
        .map(
          (word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1)}',
    )
        .join(' ');
  }

  Widget _buildProgressSection(String tripId) {
    return FutureBuilder<Map<String, int>>(
      future: _tripService.getChecklistProgress(tripId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return const Text(
            'Unable to load checklist progress.',
          );
        }

        final Map<String, int> progress = snapshot.data ?? {};

        final int completed = progress['completed'] ?? 0;
        final int total = progress['total'] ?? 0;

        final double progressValue =
        total == 0 ? 0 : completed / total;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preparation progress: $completed of $total completed',
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progressValue,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content =
    FutureBuilder<List<Trip>>(
      future: _tripsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return RefreshIndicator(
            onRefresh: _refreshTrips,
            child: ListView(
              physics:
              const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 180),
                Center(
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 24,
                    ),
                    child: Text(
                      'Unable to load trips.\n'
                          '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final List<Trip> trips =
            snapshot.data ?? [];

        if (trips.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refreshTrips,
            child: ListView(
              physics:
              const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              children: const [
                SizedBox(height: 130),
                Icon(
                  Icons.luggage_outlined,
                  size: 64,
                  color: Color(0xFF087F8C),
                ),
                SizedBox(height: 18),
                Center(
                  child: Text(
                    'No trips yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Center(
                  child: Text(
                    'Create a trip to generate your '
                        'personalised travel requirements.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshTrips,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              110,
            ),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final Trip trip = trips[index];

              return Card(
                margin:
                const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatText(
                          trip.destinationCountryId,
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Purpose: '
                            '${_formatText(trip.purpose)}',
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Duration: '
                            '${trip.durationDays} days',
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Departure: '
                            '${_formatDate(trip.departureDate)}',
                      ),

                      const SizedBox(height: 16),

                      _buildProgressSection(trip.id),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ChecklistScreen(
                                      tripId: trip.id,
                                    ),
                              ),
                            );

                            if (mounted) {
                              setState(() {});
                            }
                          },
                          icon: const Icon(
                            Icons.checklist_rounded,
                          ),
                          label: const Text(
                            'View Checklist',
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PackingScreen(
                                      trip: trip,
                                    ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.luggage_outlined,
                          ),
                          label: const Text(
                            'Packing List',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
      ),
      body: content,
    );
  }
}