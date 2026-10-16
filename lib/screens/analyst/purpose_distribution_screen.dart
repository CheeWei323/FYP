import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/analyst_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/role_ui_widgets.dart';
import '../../widgets/analyst/analytics_filter_card.dart';

class PurposeDistributionScreen extends StatefulWidget {
  const PurposeDistributionScreen({super.key});

  @override
  State<PurposeDistributionScreen> createState() =>
      _PurposeDistributionScreenState();
}

class _PurposeDistributionScreenState extends State<PurposeDistributionScreen> {
  final AnalystService _analystService = AnalystService();

  static const Color _tourismColor = AppColors.primary;
  static const Color _businessColor = Color(0xFFB07542);
  static const Color _studyColor = Color(0xFF567F7A);

  String? _selectedDestinationId;

  // Cached Firestore analytics.
  Map<String, dynamic>? _distributionData;
  String? _loadedDestinationId;

  List<Map<String, String>> _countries = [];

  bool _distributionLoading = true;
  bool _distributionError = false;
  bool _countriesLoading = true;
  bool _countriesError = false;

  // Prevent outdated requests from replacing current data.
  int _distributionRequestVersion = 0;
  int _countriesRequestVersion = 0;

  @override
  void initState() {
    super.initState();

    _loadDistribution();
    _loadCountries();
  }

  // ---------------------------------------------------------------------------
  // LOAD PURPOSE DISTRIBUTION
  // ---------------------------------------------------------------------------

  Future<void> _loadDistribution() async {
    final int requestVersion = ++_distributionRequestVersion;
    final String? requestedDestination = _selectedDestinationId;

    setState(() {
      _distributionLoading = true;
      _distributionError = false;
    });

    try {
      final Map<String, dynamic> data = await _analystService
          .getPurposeDistribution(destinationId: requestedDestination);

      if (!mounted || requestVersion != _distributionRequestVersion) {
        return;
      }

      setState(() {
        _distributionData = data;
        _loadedDestinationId = requestedDestination;
        _distributionLoading = false;
        _distributionError = false;
      });
    } catch (error) {
      debugPrint('PURPOSE ANALYTICS ERROR: $error');

      if (!mounted || requestVersion != _distributionRequestVersion) {
        return;
      }

      setState(() {
        _distributionLoading = false;
        _distributionError = true;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // LOAD DESTINATION FILTER OPTIONS
  // ---------------------------------------------------------------------------

  Future<void> _loadCountries() async {
    final int requestVersion = ++_countriesRequestVersion;

    try {
      final List<Map<String, String>> countries = await _analystService
          .getAnalyticsFilterCountries();

      if (!mounted || requestVersion != _countriesRequestVersion) {
        return;
      }

      setState(() {
        _countries = countries;
        _countriesLoading = false;
        _countriesError = false;
      });
    } catch (error) {
      debugPrint('PURPOSE FILTER COUNTRIES ERROR: $error');

      if (!mounted || requestVersion != _countriesRequestVersion) {
        return;
      }

      setState(() {
        _countriesLoading = false;
        _countriesError = true;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  Future<void> _refresh() async {
    await Future.wait<void>([_loadDistribution(), _loadCountries()]);
  }

  // ---------------------------------------------------------------------------
  // CHANGE DESTINATION FILTER
  // ---------------------------------------------------------------------------

  void _changeDestination(String? destinationId) {
    if (_selectedDestinationId == destinationId) {
      return;
    }

    setState(() {
      _selectedDestinationId = destinationId;
    });

    // Fetch statistics for the newly selected destination.
    // Older requests are ignored by the request-version check.
    _loadDistribution();
  }

  void _clearFilters() {
    _changeDestination(null);
  }

  // ---------------------------------------------------------------------------
  // DATA HELPERS
  // ---------------------------------------------------------------------------

  int _readInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  Map<String, int> _readPurposeCounts(dynamic rawCounts) {
    final Map<String, int> counts = {};

    if (rawCounts is Map) {
      for (final entry in rawCounts.entries) {
        if (entry.key is String) {
          counts[entry.key as String] = _readInt(entry.value);
        }
      }
    }

    return counts;
  }

  String _purposeLabel(String purpose) {
    switch (purpose) {
      case 'tourism':
        return 'Tourism';

      case 'business':
        return 'Business';

      case 'study':
        return 'Study';

      default:
        return purpose;
    }
  }

  double _percentage(int count, int total) {
    if (total <= 0) {
      return 0;
    }

    return (count / total) * 100;
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
    final bool hasCurrentData =
        _distributionData != null &&
        _loadedDestinationId == _selectedDestinationId;

    final Map<String, dynamic>? currentData = hasCurrentData
        ? _distributionData
        : null;

    final int total = _readInt(currentData?['total']);

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,

        title: const Text(
          'Travel Purpose Distribution',
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
              _buildHeader(total: total, hasData: hasCurrentData),

              const SizedBox(height: 26),

              _buildSectionTitle(
                'Filter Analytics',
                'Select a destination to compare '
                    'travel purposes for a specific country.',
              ),

              const SizedBox(height: 13),

              _buildFilters(),

              const SizedBox(height: 27),

              _buildSectionTitle(
                'Purpose Distribution',
                _selectedDestinationId == null
                    ? 'Understand why travellers are travelling '
                          'across all supported destinations.'
                    : 'Understand why travellers are travelling '
                          'to the selected destination.',
              ),

              const SizedBox(height: 15),

              _buildDistributionContent(currentData),

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

  Widget _buildHeader({required int total, required bool hasData}) {
    String description;

    if (!hasData && _distributionLoading) {
      description = 'Loading travel purpose analytics...';
    } else if (!hasData && _distributionError) {
      description = 'Travel purpose analytics are temporarily unavailable.';
    } else if (total == 0) {
      description = 'No trips match the current destination filter.';
    } else {
      description =
          '$total stored '
          '${total == 1 ? 'trip is' : 'trips are'} '
          'included in the current distribution.';
    }

    return RoleIntroCard(
      eyebrow: 'TRAVEL ANALYTICS',
      title: "Travel purpose distribution",
      description: description,
      icon: Icons.donut_large_rounded,
    );
  }

  // ---------------------------------------------------------------------------
  // DESTINATION FILTER
  // ---------------------------------------------------------------------------

  Widget _buildFilters() {
    if (_countriesLoading && _countries.isEmpty) {
      return _buildStatusCard(
        icon: Icons.filter_alt_outlined,
        title: 'Loading Destinations',
        message: 'Retrieving available destination filters...',
        isLoading: true,
        minimumHeight: 155,
      );
    }

    if (_countriesError && _countries.isEmpty) {
      return _buildStatusCard(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to Load Filters',
        message: 'The destination filter options could not be retrieved.',
        minimumHeight: 155,
        onRetry: _loadCountries,
      );
    }

    // Preserve the original AnalyticsFilterCard integration.
    return AnalyticsFilterCard(
      countries: _countries,
      selectedDestinationId: _selectedDestinationId,
      selectedPurpose: null,
      showDestination: true,
      showPurpose: false,
      onDestinationChanged: _changeDestination,
      onPurposeChanged: (_) {},
      onClear: _clearFilters,
    );
  }

  // ---------------------------------------------------------------------------
  // DISTRIBUTION CONTENT
  // ---------------------------------------------------------------------------

  Widget _buildDistributionContent(Map<String, dynamic>? data) {
    if (data == null && _distributionError) {
      return _buildStatusCard(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to Load Distribution',
        message:
            'Travel purpose analytics could not be retrieved. '
            'Please try again.',
        minimumHeight: 310,
        onRetry: _loadDistribution,
      );
    }

    final bool isLoading = data == null;

    final int total = _readInt(data?['total']);

    final Map<String, int> counts = _readPurposeCounts(data?['counts']);

    return Column(
      children: [
        _buildDonutSection(counts: counts, total: total, isLoading: isLoading),

        const SizedBox(height: 17),

        _buildDistributionSummary(
          counts: counts,
          total: total,
          isLoading: isLoading,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // DONUT CHART
  // ---------------------------------------------------------------------------

  Widget _buildDonutSection({
    required Map<String, int> counts,
    required int total,
    required bool isLoading,
  }) {
    final slices = [
      _PurposeSlice(
        purpose: 'tourism',
        count: counts['tourism'] ?? 0,
        color: _tourismColor,
      ),
      _PurposeSlice(
        purpose: 'business',
        count: counts['business'] ?? 0,
        color: _businessColor,
      ),
      _PurposeSlice(
        purpose: 'study',
        count: counts['study'] ?? 0,
        color: _studyColor,
      ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Travel purpose breakdown',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isLoading
                ? 'Loading trip distribution...'
                : '$total stored ${total == 1 ? 'trip' : 'trips'} match these filters.',
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox.square(
              dimension: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      size: const Size(190, 190),
                      painter: _DonutChartPainter(slices: slices, total: total),
                    ),
                  ),
                  if (isLoading)
                    const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(
                      Icons.travel_explore_rounded,
                      size: 36,
                      color: AppColors.primary,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          for (final slice in slices) ...[
            _buildLegendRow(slice: slice, total: total, isLoading: isLoading),
            if (slice != slices.last)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DONUT LEGEND
  // ---------------------------------------------------------------------------

  Widget _buildLegendRow({
    required _PurposeSlice slice,
    required int total,
    required bool isLoading,
  }) {
    final percentage = _percentage(slice.count, total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: slice.color,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _purposeLabel(slice.purpose),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isLoading
              ? 'Loading...'
              : '${slice.count} trips · ${percentage.toStringAsFixed(1)}%',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // LEADING PURPOSE SUMMARY
  // ---------------------------------------------------------------------------

  Widget _buildDistributionSummary({
    required Map<String, int> counts,
    required int total,
    required bool isLoading,
  }) {
    String leadingPurpose = 'tourism';
    int leadingCount = 0;

    // Preserve the original leading-purpose calculation.
    counts.forEach((purpose, count) {
      if (count > leadingCount) {
        leadingPurpose = purpose;
        leadingCount = count;
      }
    });

    final double percentage = _percentage(leadingCount, total);

    final String heading = isLoading
        ? 'Loading Analytics'
        : total == 0
        ? 'No Data'
        : _purposeLabel(leadingPurpose);

    String details;

    if (isLoading) {
      details = 'Retrieving the leading travel purpose...';
    } else if (total == 0) {
      details = 'No matching trips';
    } else {
      details =
          '$leadingCount of $total '
          '${total == 1 ? 'trip' : 'trips'} · '
          '${percentage.toStringAsFixed(1)}%';
    }

    String explanation;

    if (isLoading) {
      explanation =
          'The leading purpose will appear when analytics finish loading.';
    } else if (total == 0) {
      explanation = 'No stored trips match the selected destination.';
    } else if (_selectedDestinationId == null) {
      explanation =
          '${_purposeLabel(leadingPurpose)} is currently '
          'the most common travel purpose across '
          'the stored trip records.';
    } else {
      explanation =
          '${_purposeLabel(leadingPurpose)} is currently '
          'the most common travel purpose for '
          'the selected destination.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const _PurposeIcon(icon: Icons.insights_outlined, size: 47),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'LEADING TRAVEL PURPOSE',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  heading,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  details,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  explanation,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11.5,
                    height: 1.45,
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
  // DATA INFORMATION
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
                  'Understanding the Distribution',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                SizedBox(height: 7),

                Text(
                  'The chart displays aggregated travel purpose '
                  'counts based on stored trip records. '
                  'Destination filters apply to the displayed '
                  'statistics without showing individual '
                  'traveller information.',
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
  // LOADING / ERROR CARD
  // ---------------------------------------------------------------------------

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String message,
    bool isLoading = false,
    double minimumHeight = 180,
    VoidCallback? onRetry,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minimumHeight),
      child: RoleStatusCard(
        title: title,
        message: message,
        icon: icon,
        loading: isLoading,
        onRetry: onRetry,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// REUSABLE ICON
// -----------------------------------------------------------------------------

class _PurposeIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _PurposeIcon({required this.icon, required this.size});

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
// DONUT CHART DATA
// -----------------------------------------------------------------------------

class _PurposeSlice {
  final String purpose;
  final int count;
  final Color color;

  const _PurposeSlice({
    required this.purpose,
    required this.count,
    required this.color,
  });
}

// -----------------------------------------------------------------------------
// DONUT CHART PAINTER
// -----------------------------------------------------------------------------

class _DonutChartPainter extends CustomPainter {
  final List<_PurposeSlice> slices;
  final int total;

  const _DonutChartPainter({required this.slices, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);

    // Leave room around the outer edge for the stroke.
    const double strokeWidth = 27;

    final double radius =
        math.min(size.width, size.height) / 2 - strokeWidth / 2 - 3;

    final Rect chartRect = Rect.fromCircle(center: center, radius: radius);

    final Paint backgroundPaint = Paint()
      ..color = AppColors.primaryLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Background track.
    canvas.drawArc(chartRect, 0, math.pi * 2, false, backgroundPaint);

    if (total <= 0) {
      return;
    }

    double startAngle = -math.pi / 2;

    const double gap = 0.025;

    for (final _PurposeSlice slice in slices) {
      if (slice.count <= 0) {
        continue;
      }

      final double fullSweep = (slice.count / total) * math.pi * 2;

      final double sweepAngle = math.max(0, fullSweep - gap);

      final Paint slicePaint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(chartRect, startAngle, sweepAngle, false, slicePaint);

      startAngle += fullSweep;
    }
  }

  // ---------------------------------------------------------------------------
  // REPAINT ONLY WHEN CHART DATA CHANGES
  // ---------------------------------------------------------------------------

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    if (oldDelegate.total != total ||
        oldDelegate.slices.length != slices.length) {
      return true;
    }

    for (int index = 0; index < slices.length; index++) {
      if (oldDelegate.slices[index].purpose != slices[index].purpose ||
          oldDelegate.slices[index].count != slices[index].count ||
          oldDelegate.slices[index].color != slices[index].color) {
        return true;
      }
    }

    return false;
  }
}
