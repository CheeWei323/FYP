import 'dart:math' as math;

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

  late Future<List<Map<String, dynamic>>> _monthlyTrendFuture;

  @override
  void initState() {
    super.initState();

    _trendsFuture = _analystService.getDestinationTrends();

    _monthlyTrendFuture = _analystService.getMonthlyDepartureTrend();
  }

  Future<void> _refresh() async {
    final Future<List<Map<String, dynamic>>> destinationFuture = _analystService
        .getDestinationTrends();

    final Future<List<Map<String, dynamic>>> monthlyFuture = _analystService
        .getMonthlyDepartureTrend();

    setState(() {
      _trendsFuture = destinationFuture;

      _monthlyTrendFuture = monthlyFuture;
    });

    await destinationFuture;
    await monthlyFuture;
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
            builder: (context, destinationSnapshot) {
              if (destinationSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (destinationSnapshot.hasError) {
                debugPrint(
                  'DESTINATION ANALYTICS ERROR: '
                  '${destinationSnapshot.error}',
                );

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
                  destinationSnapshot.data ?? [];

              final int totalTrips = destinations.fold<int>(0, (
                totalValue,
                item,
              ) {
                return totalValue + (item['count'] as int? ?? 0);
              });

              final int maximum = destinations.isEmpty
                  ? 0
                  : destinations
                        .map((item) => item['count'] as int? ?? 0)
                        .fold<int>(0, (currentMax, itemCount) {
                          return itemCount > currentMax
                              ? itemCount
                              : currentMax;
                        });

              final Map<String, dynamic>? topDestination =
                  totalTrips == 0 || destinations.isEmpty
                  ? null
                  : destinations.first;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                children: [
                  _buildHeader(totalTrips),

                  const SizedBox(height: 28),

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
                    'Compare stored trip volume across '
                    'the supported destinations.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (destinations.isEmpty)
                    _buildEmptyDestinationState()
                  else ...[
                    _buildBarChart(
                      destinations: destinations,
                      maximum: maximum,
                    ),

                    if (topDestination != null) ...[
                      const SizedBox(height: 18),

                      _buildTopDestinationCard(topDestination),
                    ],
                  ],

                  const SizedBox(height: 32),

                  const Text(
                    'Travel Activity Over Time',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _darkTextColor,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Monthly travel activity based on '
                    'stored trip departure dates.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 16),

                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _monthlyTrendFuture,
                    builder: (context, monthlySnapshot) {
                      if (monthlySnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const SizedBox(
                          height: 230,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (monthlySnapshot.hasError) {
                        debugPrint(
                          'MONTHLY TREND ERROR: '
                          '${monthlySnapshot.error}',
                        );

                        return _buildTrendErrorState();
                      }

                      final List<Map<String, dynamic>> monthlyData =
                          monthlySnapshot.data ?? [];

                      if (monthlyData.isEmpty) {
                        return _buildEmptyTrendState();
                      }

                      return _buildMonthlyTrendCard(monthlyData);
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

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
          const Icon(
            Icons.travel_explore_outlined,
            color: _primaryColor,
            size: 32,
          ),

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
                  totalTrips == 0
                      ? 'No stored trip data is currently available.'
                      : '$totalTrips stored '
                            '${totalTrips == 1 ? 'trip is' : 'trips are'} '
                            'included in the destination analysis.',
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

  // ---------------------------------------------------------------------------
  // DESTINATION BAR CHART
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // TOP DESTINATION
  // ---------------------------------------------------------------------------

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
                  '$itemCount '
                  '${itemCount == 1 ? 'trip' : 'trips'} · '
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

  // ---------------------------------------------------------------------------
  // MONTHLY TREND
  // ---------------------------------------------------------------------------

  Widget _buildMonthlyTrendCard(List<Map<String, dynamic>> monthlyData) {
    final int totalDepartures = monthlyData.fold<int>(0, (totalValue, item) {
      return totalValue + (item['count'] as int? ?? 0);
    });

    Map<String, dynamic> peakMonth = monthlyData.first;

    for (final item in monthlyData) {
      final int itemCount = item['count'] as int? ?? 0;

      final int currentPeak = peakMonth['count'] as int? ?? 0;

      if (itemCount > currentPeak) {
        peakMonth = item;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trips by Departure Month',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _darkTextColor,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      '$totalDepartures '
                      '${totalDepartures == 1 ? 'trip' : 'trips'} '
                      'with departure dates',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.show_chart_rounded, color: _primaryColor),
            ],
          ),

          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            height: 220,
            child: CustomPaint(
              painter: _MonthlyTrendPainter(
                data: monthlyData,
                lineColor: _primaryColor,
                textColor: _darkTextColor,
              ),
            ),
          ),

          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: _primaryColor,
                  size: 19,
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Peak Departure Month',
                        style: TextStyle(fontSize: 9.5, color: Colors.black54),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        '${peakMonth['label']} · '
                        '${peakMonth['count']} '
                        '${peakMonth['count'] == 1 ? 'trip' : 'trips'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _darkTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Departure trends describe when stored trips '
            'are scheduled to occur and do not represent '
            'the date the trip record was created.',
            style: TextStyle(fontSize: 9.5, height: 1.4, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY / ERROR STATES
  // ---------------------------------------------------------------------------

  Widget _buildEmptyDestinationState() {
    return Container(
      width: double.infinity,
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

  Widget _buildEmptyTrendState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.show_chart_rounded, size: 38, color: Colors.black38),

          SizedBox(height: 8),

          Text(
            'No departure-date trend data is available.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: const Text(
        'Unable to load monthly departure trends.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black54),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MONTHLY TREND PAINTER
// -----------------------------------------------------------------------------

class _MonthlyTrendPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  final Color lineColor;
  final Color textColor;

  const _MonthlyTrendPainter({
    required this.data,
    required this.lineColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      return;
    }

    const double leftPadding = 32;

    const double rightPadding = 10;

    const double topPadding = 16;

    const double bottomPadding = 38;

    final double chartWidth = size.width - leftPadding - rightPadding;

    final double chartHeight = size.height - topPadding - bottomPadding;

    final List<int> counts = data
        .map((item) => item['count'] as int? ?? 0)
        .toList();

    final int rawMaximum = counts.reduce(math.max);

    final int maximum = math.max(rawMaximum, 1);

    final Paint gridPaint = Paint()
      ..color = const Color(0xFFE6EBEF)
      ..strokeWidth = 1;

    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final Paint pointBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // -------------------------------------------------------------------------
    // HORIZONTAL GRID
    // -------------------------------------------------------------------------

    const int gridLines = 4;

    for (int index = 0; index <= gridLines; index++) {
      final double factor = index / gridLines;

      final double y = topPadding + chartHeight * factor;

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );

      final double gridValue = maximum * (1 - factor);

      final TextPainter labelPainter = TextPainter(
        text: TextSpan(
          text: gridValue.round().toString(),
          style: TextStyle(
            fontSize: 9,
            color: textColor.withValues(alpha: 0.5),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      labelPainter.paint(
        canvas,
        Offset(
          leftPadding - labelPainter.width - 6,
          y - labelPainter.height / 2,
        ),
      );
    }

    // -------------------------------------------------------------------------
    // DATA POINTS
    // -------------------------------------------------------------------------

    final List<Offset> points = <Offset>[];

    for (int index = 0; index < data.length; index++) {
      final double x = data.length == 1
          ? leftPadding + chartWidth / 2
          : leftPadding + chartWidth * index / (data.length - 1);

      final int itemCount = data[index]['count'] as int? ?? 0;

      final double y = topPadding + chartHeight * (1 - itemCount / maximum);

      points.add(Offset(x, y));
    }

    if (points.length == 1) {
      canvas.drawCircle(points.first, 5, pointPaint);

      canvas.drawCircle(points.first, 5, pointBorderPaint);
    } else {
      final Path path = Path();

      path.moveTo(points.first.dx, points.first.dy);

      for (int index = 1; index < points.length; index++) {
        path.lineTo(points[index].dx, points[index].dy);
      }

      canvas.drawPath(path, linePaint);

      for (final Offset point in points) {
        canvas.drawCircle(point, 4.5, pointPaint);

        canvas.drawCircle(point, 4.5, pointBorderPaint);
      }
    }

    // -------------------------------------------------------------------------
    // VALUE LABELS
    // -------------------------------------------------------------------------

    for (int index = 0; index < points.length; index++) {
      final String value = '${data[index]['count']}';

      final TextPainter valuePainter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: lineColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      valuePainter.paint(
        canvas,
        Offset(
          points[index].dx - valuePainter.width / 2,
          points[index].dy - valuePainter.height - 7,
        ),
      );
    }

    // -------------------------------------------------------------------------
    // MONTH LABELS
    // -------------------------------------------------------------------------

    final Set<int> labelIndices = _selectLabelIndices(data.length);

    for (final int index in labelIndices) {
      final String label = data[index]['shortLabel'] as String? ?? '';

      final TextPainter labelPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 8.5,
            color: textColor.withValues(alpha: 0.6),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final double x = points[index].dx - labelPainter.width / 2;

      labelPainter.paint(
        canvas,
        Offset(
          x.clamp(0.0, size.width - labelPainter.width),
          size.height - bottomPadding + 11,
        ),
      );
    }
  }

  Set<int> _selectLabelIndices(int itemCount) {
    if (itemCount <= 6) {
      return {for (int index = 0; index < itemCount; index++) index};
    }

    return {
      0,
      (itemCount * 0.25).floor(),
      (itemCount * 0.5).floor(),
      (itemCount * 0.75).floor(),
      itemCount - 1,
    };
  }

  @override
  bool shouldRepaint(covariant _MonthlyTrendPainter oldDelegate) {
    if (oldDelegate.data.length != data.length) {
      return true;
    }

    for (int index = 0; index < data.length; index++) {
      if (oldDelegate.data[index]['count'] != data[index]['count'] ||
          oldDelegate.data[index]['label'] != data[index]['label']) {
        return true;
      }
    }

    return false;
  }
}
