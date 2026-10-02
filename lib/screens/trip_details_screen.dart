import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../services/trip_service.dart';
import 'checklist_screen.dart';
import 'packing_screen.dart';

class TripDetailsScreen extends StatefulWidget {
  final Trip trip;

  const TripDetailsScreen({
    super.key,
    required this.trip,
  });

  @override
  State<TripDetailsScreen> createState() =>
      _TripDetailsScreenState();
}

class _TripDetailsScreenState
    extends State<TripDetailsScreen> {
  final TripService _tripService =
  TripService();

  static const Color _primaryColor =
  Color(0xFF087F8C);

  static const Color _darkTextColor =
  Color(0xFF102A43);

  static const Color _backgroundColor =
  Color(0xFFF7F9FB);

  static const Color _borderColor =
  Color(0xFFE1E7EC);

  late Future<Map<String, int>>
  _progressFuture;

  @override
  void initState() {
    super.initState();

    _progressFuture = _loadProgress();
  }

  Future<Map<String, int>>
  _loadProgress() {
    return _tripService.getChecklistProgress(
      widget.trip.id,
    );
  }

  Future<void> _refreshProgress()
  async {
    final Future<Map<String, int>>
    refreshed = _loadProgress();

    setState(() {
      _progressFuture = refreshed;
    });

    await refreshed;
  }

  // Opens the personalised regulatory checklist.
  Future<void> _openChecklist() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChecklistScreen(
              tripId: widget.trip.id,
            ),
      ),
    );

    if (!mounted) return;

    // Refresh progress after returning from checklist.
    await _refreshProgress();
  }

  // Opens the editable contextual packing list.
  Future<void> _openPackingList()
  async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PackingScreen(
              trip: widget.trip,
            ),
      ),
    );
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
          : '${word[0].toUpperCase()}'
          '${word.substring(1)}',
    )
        .join(' ');
  }

  String _formatDate(DateTime date) {
    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  bool get _isPastTrip {
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime departure = DateTime(
      widget.trip.departureDate.year,
      widget.trip.departureDate.month,
      widget.trip.departureDate.day,
    );

    return departure.isBefore(today);
  }

  String get _departureStatus {
    if (_isPastTrip) {
      return 'Past trip';
    }

    final DateTime now = DateTime.now();

    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime departure = DateTime(
      widget.trip.departureDate.year,
      widget.trip.departureDate.month,
      widget.trip.departureDate.day,
    );

    final int days =
        departure.difference(today).inDays;

    if (days == 0) {
      return 'Departs today';
    }

    if (days == 1) {
      return 'Departs tomorrow';
    }

    return 'Departs in $days days';
  }

  @override
  Widget build(BuildContext context) {
    final Trip trip = widget.trip;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Trip Details',
          style: TextStyle(
            color: _darkTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProgress,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            18,
            18,
            18,
            36,
          ),
          children: [
            _buildTripHeader(trip),

            const SizedBox(height: 24),

            const Text(
              'Preparation Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _darkTextColor,
              ),
            ),

            const SizedBox(height: 12),

            _buildProgressCard(),

            const SizedBox(height: 26),

            const Text(
              'Prepare for Your Trip',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _darkTextColor,
              ),
            ),

            const SizedBox(height: 12),

            _buildFeatureCard(
              icon: Icons.fact_check_outlined,
              title: 'Travel Requirements',
              description:
              'Review your personalised regulatory '
                  'checklist and mark completed requirements.',
              actionText: 'View Requirements',
              onTap: _openChecklist,
            ),

            const SizedBox(height: 12),

            _buildFeatureCard(
              icon: Icons.luggage_outlined,
              title: 'Packing List',
              description:
              'Manage your packing items and get '
                  'contextual recommendations for this trip.',
              actionText: 'Open Packing List',
              onTap: _openPackingList,
            ),

            const SizedBox(height: 22),

            _buildOfficialSourceNote(),
          ],
        ),
      ),
    );
  }

  Widget _buildTripHeader(
      Trip trip,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE7F7F8),
            Color(0xFFF1F8FB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
        BorderRadius.circular(22),
        border: Border.all(
          color: const Color(
            0xFFCBE8EB,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              // Flutter Material icon.
              // This is not an emoji.
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.circular(
                    16,
                  ),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: _primaryColor,
                  size: 30,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatText(
                        trip.destinationCountryId,
                      ),
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight:
                        FontWeight.w800,
                        color: _darkTextColor,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '${_formatText(trip.purpose)}'
                          ' • '
                          '${trip.durationDays} days',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isPastTrip
                      ? const Color(
                    0xFFECEFF1,
                  )
                      : const Color(
                    0xFFDFF5EA,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    20,
                  ),
                ),
                child: Text(
                  _isPastTrip
                      ? 'Past'
                      : 'Upcoming',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w700,
                    color: _isPastTrip
                        ? const Color(
                      0xFF546E7A,
                    )
                        : const Color(
                      0xFF177245,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: _primaryColor,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Departure',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        _formatDate(
                          trip.departureDate,
                        ),
                        style: const TextStyle(
                          fontWeight:
                          FontWeight.w700,
                          color: _darkTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  _departureStatus,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w600,
                    color: _isPastTrip
                        ? Colors.black54
                        : _primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return FutureBuilder<
        Map<String, int>>(
      future: _progressFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return Container(
            height: 130,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(18),
              border: Border.all(
                color: _borderColor,
              ),
            ),
            child: const Center(
              child:
              CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(18),
              border: Border.all(
                color: _borderColor,
              ),
            ),
            child: const Text(
              'Unable to load checklist progress.',
              textAlign: TextAlign.center,
            ),
          );
        }

        final Map<String, int> progress =
            snapshot.data ?? {};

        final int completed =
            progress['completed'] ?? 0;

        final int total =
            progress['total'] ?? 0;

        final double value =
        total == 0
            ? 0
            : completed / total;

        final int percentage =
        (value * 100).round();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.circular(18),
            border: Border.all(
              color: _borderColor,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
                children: [
                  const Text(
                    'Checklist Progress',
                    style: TextStyle(
                      fontWeight:
                      FontWeight.w700,
                      color: _darkTextColor,
                    ),
                  ),

                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight:
                      FontWeight.w800,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              ClipRRect(
                borderRadius:
                BorderRadius.circular(20),
                child:
                LinearProgressIndicator(
                  value: value,
                  minHeight: 9,
                  backgroundColor:
                  const Color(
                    0xFFE5EEF0,
                  ),
                  valueColor:
                  const AlwaysStoppedAnimation<
                      Color>(
                    _primaryColor,
                  ),
                ),
              ),

              const SizedBox(height: 9),

              Text(
                '$completed of $total travel '
                    'requirements completed',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.circular(18),
            border: Border.all(
              color: _borderColor,
            ),
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color:
                  const Color(
                    0xFFE8F6F7,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    15,
                  ),
                ),
                child: Icon(
                  icon,
                  color: _primaryColor,
                  size: 25,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight:
                        FontWeight.w700,
                        color: _darkTextColor,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      actionText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight:
                        FontWeight.w700,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficialSourceNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FA),
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color: const Color(
            0xFFD8E6EE,
          ),
        ),
      ),
      child: const Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_outlined,
            size: 22,
            color: Color(0xFF0A5B83),
          ),

          SizedBox(width: 12),

          Expanded(
            child: Text(
              'Official government and authority '
                  'references are available inside '
                  'each travel requirement.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Color(0xFF334E68),
              ),
            ),
          ),
        ],
      ),
    );
  }
}