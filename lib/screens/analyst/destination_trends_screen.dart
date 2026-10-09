import 'package:flutter/material.dart';

import '../../services/analyst_service.dart';

class DestinationTrendsScreen extends StatefulWidget {
  const DestinationTrendsScreen({super.key});

  @override
  State<DestinationTrendsScreen> createState() =>
      _DestinationTrendsScreenState();
}

class _DestinationTrendsScreenState extends State<DestinationTrendsScreen> {
  final AnalystService _analystService = AnalystService();

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

  static const Color _barColor = Color(0xFF2F5F98);

  late Future<List<Map<String, dynamic>>> _trendsFuture;

  @override
  void initState() {
    super.initState();

    _trendsFuture = _analystService.getDestinationTrends();
  }

  Future<void> _refresh() async {
    final Future<List<Map<String, dynamic>>> future = _analystService
        .getDestinationTrends();

    setState(() {
      _trendsFuture = future;
    });

    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: _darkTextColor,
        elevation: 0,
        title: const Text(
          'Destination Trends',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _trendsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: const [
                    SizedBox(height: 130),
                    Center(child: Text('Unable to load destination trends.')),
                  ],
                );
              }

              final List<Map<String, dynamic>> destinations =
                  snapshot.data ?? [];

              final int totalTrips = destinations.fold<int>(
                0,
                (totalValue, item) => totalValue + (item['count'] as int? ?? 0),
              );

              final int maximum = destinations.isEmpty
                  ? 0
                  : destinations
                        .map((item) => item['count'] as int? ?? 0)
                        .fold<int>(
                          0,
                          (currentMax, itemCount) =>
                              itemCount > currentMax ? itemCount : currentMax,
                        );

              final Map<String, dynamic>? topDestination = destinations.isEmpty
                  ? null
                  : destinations.first;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                children: [
                  _buildHeader(totalTrips),

                  const SizedBox(height: 24),

                  const Text(
                    'Trips by Destination',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _darkTextColor,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Comparison of stored trips across '
                    'the five supported destinations.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),

                  const SizedBox(height: 16),

                  if (destinations.isEmpty)
                    _buildEmptyState()
                  else ...[
                    _buildBarChart(
                      destinations: destinations,
                      maximum: maximum,
                    ),

                    const SizedBox(height: 18),

                    if (topDestination != null)
                      _buildTopDestinationCard(topDestination),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int totalTrips) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE7F7F8), Color(0xFFF1F8FB)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBE8EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.public_outlined, color: _primaryColor, size: 32),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Destination Trends',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  '$totalTrips stored trips analysed across '
                  'the supported destinations.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart({
    required List<Map<String, dynamic>> destinations,
    required int maximum,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          for (int index = 0; index < destinations.length; index++) ...[
            _buildBarRow(destination: destinations[index], maximum: maximum),
            if (index != destinations.length - 1) const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }

  Widget _buildBarRow({
    required Map<String, dynamic> destination,
    required int maximum,
  }) {
    final String name = destination['name'] as String? ?? '';

    final int itemCount = destination['count'] as int? ?? 0;

    final double percentage = destination['percentage'] as double? ?? 0;

    final double barFactor = maximum == 0 ? 0 : itemCount / maximum;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 102,
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _darkTextColor,
                ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF0F3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),

                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 22,
                        width: constraints.maxWidth * barFactor,
                        decoration: BoxDecoration(
                          color: _barColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(width: 9),

            SizedBox(
              width: 28,
              child: Text(
                '$itemCount',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _primaryColor,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 5),

        Padding(
          padding: const EdgeInsets.only(left: 112),
          child: Text(
            '${percentage.toStringAsFixed(1)}% of all trips',
            style: const TextStyle(fontSize: 9.5, color: Colors.black45),
          ),
        ),
      ],
    );
  }

  Widget _buildTopDestinationCard(Map<String, dynamic> destination) {
    final String name = destination['name'] as String? ?? 'Unknown';

    final int itemCount = destination['count'] as int? ?? 0;

    final double percentage = destination['percentage'] as double? ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E6EE)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F7),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.trending_up_rounded, color: _primaryColor),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top Destination',
                  style: TextStyle(fontSize: 10.5, color: Colors.black54),
                ),

                const SizedBox(height: 3),

                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  '$itemCount trips · '
                  '${percentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF486581),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.travel_explore_outlined, size: 38, color: Colors.black38),
          SizedBox(height: 8),
          Text('No trip data available.'),
        ],
      ),
    );
  }
}
