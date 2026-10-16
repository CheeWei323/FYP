import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/analyst_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/role_ui_widgets.dart';

class DestinationTrendsScreen extends StatefulWidget {
  const DestinationTrendsScreen({super.key});

  @override
  State<DestinationTrendsScreen> createState() =>
      _DestinationTrendsScreenState();
}

class _DestinationTrendsScreenState extends State<DestinationTrendsScreen> {
  final AnalystService _analystService = AnalystService();

  // Cached Firestore analytics.
  List<Map<String, dynamic>>? _destinations;
  List<Map<String, dynamic>>? _monthlyTrends;

  bool _destinationError = false;
  bool _monthlyError = false;

  // Prevent older requests from overwriting newer data.
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadTrends();
  }

  // ---------------------------------------------------------------------------
  // LOAD ANALYTICS
  // ---------------------------------------------------------------------------

  Future<void> _loadTrends() async {
    final int requestVersion = ++_requestVersion;

    List<Map<String, dynamic>>? updatedDestinations;
    List<Map<String, dynamic>>? updatedMonthlyTrends;

    bool destinationFailed = false;
    bool monthlyFailed = false;

    Future<void> fetchDestinations() async {
      try {
        updatedDestinations = await _analystService.getDestinationTrends();
      } catch (error) {
        destinationFailed = true;
        debugPrint('DESTINATION ANALYTICS ERROR: $error');
      }
    }

    Future<void> fetchMonthlyTrends() async {
      try {
        updatedMonthlyTrends = await _analystService.getMonthlyDepartureTrend();
      } catch (error) {
        monthlyFailed = true;
        debugPrint('MONTHLY TREND ERROR: $error');
      }
    }

    // Fetch both analytics datasets concurrently.
    await Future.wait<void>([fetchDestinations(), fetchMonthlyTrends()]);

    if (!mounted || requestVersion != _requestVersion) {
      return;
    }

    final bool hadCachedData = _destinations != null || _monthlyTrends != null;

    setState(() {
      if (updatedDestinations != null) {
        _destinations = updatedDestinations;
      }

      if (updatedMonthlyTrends != null) {
        _monthlyTrends = updatedMonthlyTrends;
      }

      _destinationError = destinationFailed;
      _monthlyError = monthlyFailed;
    });

    // Keep existing data visible if refreshing fails.
    if (hadCachedData && (destinationFailed || monthlyFailed)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Some analytics could not be refreshed. '
            'Previously loaded data is still displayed.',
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  Future<void> _refresh() async {
    await _loadTrends();
  }

  // ---------------------------------------------------------------------------
  // DATA HELPERS
  // ---------------------------------------------------------------------------

  int _getCount(Map<String, dynamic> item) {
    final dynamic value = item['count'];

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  double _getPercentage(Map<String, dynamic> item) {
    final dynamic value = item['percentage'];

    if (value is num) {
      return value.toDouble();
    }

    return 0;
  }

  Map<String, dynamic>? _getTopDestination(
    List<Map<String, dynamic>> destinations,
  ) {
    if (destinations.isEmpty) {
      return null;
    }

    Map<String, dynamic> top = destinations.first;

    for (final Map<String, dynamic> item in destinations) {
      if (_getCount(item) > _getCount(top)) {
        top = item;
      }
    }

    return _getCount(top) > 0 ? top : null;
  }

  // ---------------------------------------------------------------------------
  // SHARED CARD DECORATION
  // ---------------------------------------------------------------------------

  BoxDecoration _cardDecoration({Color color = Colors.white}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN SCREEN
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,

        title: const Text(
          'Destination Trends',
          style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800),
        ),
      ),

      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,

          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),

            padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),

            children: [
              _buildHeader(),

              const SizedBox(height: 27),

              _buildSectionTitle(
                'Trips by Destination',
                'Compare stored trip volume across '
                    'the supported destinations.',
              ),

              const SizedBox(height: 15),

              _buildDestinationSection(),

              const SizedBox(height: 29),

              _buildSectionTitle(
                'Travel Activity Over Time',
                'Monthly travel activity based on '
                    'stored trip departure dates.',
              ),

              const SizedBox(height: 15),

              _buildMonthlySection(),

              const SizedBox(height: 26),

              _buildInformationCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION TITLE
  // ---------------------------------------------------------------------------

  Widget _buildSectionTitle(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          description,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return const RoleIntroCard(
      eyebrow: 'TRAVEL ANALYTICS',
      title: "Destination trends",
      description:
          "Compare destination popularity and monthly departure patterns.",
      icon: Icons.public_rounded,
    );
  }

  // ---------------------------------------------------------------------------
  // DESTINATION SECTION
  // ---------------------------------------------------------------------------

  Widget _buildDestinationSection() {
    final List<Map<String, dynamic>>? destinations = _destinations;

    if (destinations == null && _destinationError) {
      return _buildStatusCard(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to Load Destinations',
        message: 'Destination analytics could not be retrieved.',
        onRetry: _loadTrends,
      );
    }

    if (destinations == null) {
      return _buildStatusCard(
        icon: Icons.public_outlined,
        title: 'Loading Destination Trends',
        message: 'Retrieving aggregated trip statistics...',
        isLoading: true,
      );
    }

    if (destinations.isEmpty) {
      return _buildStatusCard(
        icon: Icons.travel_explore_outlined,
        title: 'No Destination Data',
        message:
            'No stored trip data is currently available '
            'for destination analysis.',
      );
    }

    final int maximum = destinations.fold<int>(
      0,
      (current, item) => math.max(current, _getCount(item)),
    );

    final Map<String, dynamic>? topDestination = _getTopDestination(
      destinations,
    );

    return Column(
      children: [
        _buildBarChart(destinations: destinations, maximum: maximum),

        if (topDestination != null) ...[
          const SizedBox(height: 16),

          _buildTopDestinationCard(topDestination),
        ],
      ],
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
      padding: const EdgeInsets.fromLTRB(16, 19, 16, 19),
      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Destination Distribution',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 22),
            ],
          ),

          const SizedBox(height: 5),

          const Text(
            'Number of trips recorded for each destination',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 11),
          ),

          const SizedBox(height: 22),

          for (int index = 0; index < destinations.length; index++) ...[
            _buildBarRow(destination: destinations[index], maximum: maximum),

            if (index != destinations.length - 1) const SizedBox(height: 21),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DESTINATION BAR ROW
  // ---------------------------------------------------------------------------

  Widget _buildBarRow({
    required Map<String, dynamic> destination,
    required int maximum,
  }) {
    final name = destination['name'] as String? ?? 'Unknown';
    final count = _getCount(destination);
    final percentage = _getPercentage(destination);
    final factor = maximum <= 0 ? 0.0 : (count / maximum).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: factor,
            minHeight: 12,
            backgroundColor: AppColors.primaryLight,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$count trips · ${percentage.toStringAsFixed(1)}% of all trips',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TOP DESTINATION CARD
  // ---------------------------------------------------------------------------

  Widget _buildTopDestinationCard(Map<String, dynamic> destination) {
    final String name = destination['name'] as String? ?? 'Unknown';

    final int count = _getCount(destination);

    final double percentage = _getPercentage(destination);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),

      child: Row(
        children: [
          const _TrendsIcon(icon: Icons.trending_up_rounded, size: 47),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'MOST POPULAR DESTINATION',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  '$count '
                  '${count == 1 ? 'trip' : 'trips'} · '
                  '${percentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
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
  // MONTHLY TREND SECTION
  // ---------------------------------------------------------------------------

  Widget _buildMonthlySection() {
    final List<Map<String, dynamic>>? monthlyData = _monthlyTrends;

    if (monthlyData == null && _monthlyError) {
      return _buildStatusCard(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to Load Monthly Trends',
        message:
            'Monthly departure statistics could not '
            'be retrieved.',
        onRetry: _loadTrends,
      );
    }

    if (monthlyData == null) {
      return _buildStatusCard(
        icon: Icons.show_chart_rounded,
        title: 'Loading Monthly Trends',
        message: 'Retrieving departure-date statistics...',
        isLoading: true,
      );
    }

    if (monthlyData.isEmpty) {
      return _buildStatusCard(
        icon: Icons.calendar_month_outlined,
        title: 'No Departure Data',
        message: 'No departure-date trend data is available.',
      );
    }

    return _buildMonthlyTrendCard(monthlyData);
  }

  // ---------------------------------------------------------------------------
  // MONTHLY TREND CARD
  // ---------------------------------------------------------------------------

  Widget _buildMonthlyTrendCard(List<Map<String, dynamic>> monthlyData) {
    final int totalDepartures = monthlyData.fold<int>(
      0,
      (total, item) => total + _getCount(item),
    );

    Map<String, dynamic> peakMonth = monthlyData.first;

    for (final Map<String, dynamic> item in monthlyData) {
      if (_getCount(item) > _getCount(peakMonth)) {
        peakMonth = item;
      }
    }

    final String peakLabel = '${peakMonth['label'] ?? 'Unknown'}';

    final int peakCount = _getCount(peakMonth);

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(16, 19, 16, 17),

      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Trips by Departure Month',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      '$totalDepartures '
                      '${totalDepartures == 1 ? 'trip' : 'trips'} '
                      'with departure dates',
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.show_chart_rounded,
                color: AppColors.primary,
                size: 23,
              ),
            ],
          ),

          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            height: 220,

            child: RepaintBoundary(
              child: CustomPaint(
                painter: _MonthlyTrendPainter(
                  data: monthlyData,
                  lineColor: AppColors.primary,
                  textColor: AppColors.navy,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),

            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.border),
            ),

            child: Row(
              children: [
                const _TrendsIcon(
                  icon: Icons.calendar_month_outlined,
                  size: 40,
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const Text(
                        'Peak Departure Month',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 10.5,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        '$peakLabel · '
                        '$peakCount '
                        '${peakCount == 1 ? 'trip' : 'trips'}',
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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
  // ANALYTICS INFORMATION
  // ---------------------------------------------------------------------------

  Widget _buildInformationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),

      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 24),

          SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'Understanding Departure Trends',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                SizedBox(height: 7),

                Text(
                  'Departure trends describe when stored trips '
                  'are scheduled to occur. They do not represent '
                  'the date a trip record was created.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.5,
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
  // LOADING / ERROR / EMPTY CARD
  // ---------------------------------------------------------------------------

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String message,
    bool isLoading = false,
    VoidCallback? onRetry,
  }) {
    return RoleStatusCard(
      title: title,
      message: message,
      icon: icon,
      loading: isLoading,
      onRetry: onRetry,
    );
  }
}

// -----------------------------------------------------------------------------
// REUSABLE ICON
// -----------------------------------------------------------------------------

class _TrendsIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _TrendsIcon({required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,

      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(13),
      ),

      child: Icon(icon, color: AppColors.primary, size: size * 0.51),
    );
  }
}

// -----------------------------------------------------------------------------
// MONTHLY DEPARTURE LINE CHART PAINTER
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

  int _count(Map<String, dynamic> item) {
    final dynamic value = item['count'];
    return value is num ? value.toInt() : 0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      return;
    }

    const double leftPadding = 32;
    const double rightPadding = 12;
    const double topPadding = 18;
    const double bottomPadding = 38;

    final double chartWidth = size.width - leftPadding - rightPadding;

    final double chartHeight = size.height - topPadding - bottomPadding;

    if (chartWidth <= 0 || chartHeight <= 0) {
      return;
    }

    final List<int> counts = data.map((item) => _count(item)).toList();

    final int maximum = math.max(counts.reduce(math.max), 1);

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
            color: textColor.withValues(alpha: 0.55),
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

    final List<Offset> points = [];

    for (int index = 0; index < data.length; index++) {
      final double x = data.length == 1
          ? leftPadding + chartWidth / 2
          : leftPadding + chartWidth * index / (data.length - 1);

      final int itemCount = _count(data[index]);

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
    // DATA VALUE LABELS
    // -------------------------------------------------------------------------

    for (int index = 0; index < points.length; index++) {
      final TextPainter valuePainter = TextPainter(
        text: TextSpan(
          text: '${_count(data[index])}',
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
            color: textColor.withValues(alpha: 0.65),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final double x = points[index].dx - labelPainter.width / 2;

      labelPainter.paint(
        canvas,
        Offset(
          x.clamp(0.0, math.max(0.0, size.width - labelPainter.width)),
          size.height - bottomPadding + 11,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // SELECT VISIBLE MONTH LABELS
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // REPAINT ONLY WHEN CHART DATA CHANGES
  // ---------------------------------------------------------------------------

  @override
  bool shouldRepaint(covariant _MonthlyTrendPainter oldDelegate) {
    if (oldDelegate.lineColor != lineColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.data.length != data.length) {
      return true;
    }

    for (int index = 0; index < data.length; index++) {
      if (oldDelegate.data[index]['count'] != data[index]['count'] ||
          oldDelegate.data[index]['label'] != data[index]['label'] ||
          oldDelegate.data[index]['shortLabel'] != data[index]['shortLabel']) {
        return true;
      }
    }

    return false;
  }
}
