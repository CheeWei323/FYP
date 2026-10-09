import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/analyst_service.dart';

class PurposeDistributionScreen extends StatefulWidget {
  const PurposeDistributionScreen({super.key});

  @override
  State<PurposeDistributionScreen> createState() =>
      _PurposeDistributionScreenState();
}

class _PurposeDistributionScreenState extends State<PurposeDistributionScreen> {
  final AnalystService _analystService = AnalystService();

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

  static const Color _tourismColor = Color(0xFF087F8C);

  static const Color _businessColor = Color(0xFF3E6C9E);

  static const Color _studyColor = Color(0xFF8AA9B8);

  late Future<Map<String, dynamic>> _distributionFuture;

  @override
  void initState() {
    super.initState();

    _distributionFuture = _analystService.getPurposeDistribution();
  }

  Future<void> _refresh() async {
    final Future<Map<String, dynamic>> future = _analystService
        .getPurposeDistribution();

    setState(() {
      _distributionFuture = future;
    });

    await future;
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

  Color _purposeColor(String purpose) {
    switch (purpose) {
      case 'tourism':
        return _tourismColor;

      case 'business':
        return _businessColor;

      case 'study':
        return _studyColor;

      default:
        return Colors.grey;
    }
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
          'Travel Purpose Distribution',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<Map<String, dynamic>>(
            future: _distributionFuture,
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
                    Center(
                      child: Text('Unable to load travel purpose analytics.'),
                    ),
                  ],
                );
              }

              final Map<String, dynamic> data = snapshot.data ?? {};

              final int total = data['total'] as int? ?? 0;

              final Map<String, int> counts = Map<String, int>.from(
                data['counts'] as Map? ?? <String, int>{},
              );

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                children: [
                  _buildHeader(total),

                  const SizedBox(height: 24),

                  const Text(
                    'Purpose Distribution',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _darkTextColor,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Share of stored trips by primary travel purpose.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),

                  const SizedBox(height: 16),

                  _buildDonutSection(counts: counts, total: total),

                  const SizedBox(
                    height: 18,
                  ),

                  _buildDistributionSummary(
                    counts: counts,
                    total: total,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int total) {
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
            Icons.donut_large_outlined,
            color: _primaryColor,
            size: 32,
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Travel Purpose',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  '$total stored trips included '
                  'in the current distribution.',
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

  Widget _buildDonutSection({
    required Map<String, int> counts,
    required int total,
  }) {
    final List<_PurposeSlice> slices = [
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 190,
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(190, 190),
                  painter: _DonutChartPainter(slices: slices, total: total),
                ),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: _darkTextColor,
                      ),
                    ),

                    const SizedBox(height: 2),

                    const Text(
                      'Total Trips',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          for (int index = 0; index < slices.length; index++) ...[
            _buildLegendRow(slice: slices[index], total: total),
            if (index != slices.length - 1) const Divider(height: 22),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendRow({required _PurposeSlice slice, required int total}) {
    final double percentage = total == 0 ? 0 : (slice.count / total) * 100;

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _purposeColor(slice.purpose),
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            _purposeLabel(slice.purpose),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _darkTextColor,
            ),
          ),
        ),

        Text(
          '${slice.count}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _darkTextColor,
          ),
        ),

        const SizedBox(width: 12),

        SizedBox(
          width: 54,
          child: Text(
            '${percentage.toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionSummary({
    required Map<String, int> counts,
    required int total,
  }) {
    String leadingPurpose = 'tourism';
    int leadingCount = 0;

    counts.forEach(
          (purpose, itemCount) {
        if (itemCount > leadingCount) {
          leadingPurpose = purpose;
          leadingCount = itemCount;
        }
      },
    );

    final double percentage =
    total == 0
        ? 0
        : (leadingCount / total) * 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        18,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFF1F6FA,
        ),
        borderRadius:
        BorderRadius.circular(
          17,
        ),
        border: Border.all(
          color: const Color(
            0xFFD8E6EE,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(
                0xFFE8F6F7,
              ),
              borderRadius:
              BorderRadius.circular(
                13,
              ),
            ),
            child: const Icon(
              Icons.insights_outlined,
              color: _primaryColor,
            ),
          ),

          const SizedBox(
            width: 13,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Leading Purpose',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  _purposeLabel(
                    leadingPurpose,
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight:
                    FontWeight.w800,
                    color:
                    _darkTextColor,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  '$leadingCount of $total trips · '
                      '${percentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(
                      0xFF486581,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  total == 0
                      ? 'No stored trip data is currently available.'
                      : '${_purposeLabel(leadingPurpose)} is currently '
                      'the most common travel purpose in the '
                      'stored trip records.',
                  style: const TextStyle(
                    fontSize: 11.5,
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
}

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

class _DonutChartPainter extends CustomPainter {
  final List<_PurposeSlice> slices;
  final int total;

  const _DonutChartPainter({required this.slices, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);

    final double radius = math.min(size.width, size.height) / 2;

    final Rect chartRect = Rect.fromCircle(center: center, radius: radius - 6);

    final Paint backgroundPaint = Paint()
      ..color = const Color(0xFFEAF0F3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.butt;

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

      final Paint paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(chartRect, startAngle, sweepAngle, false, paint);

      startAngle += fullSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    if (oldDelegate.total != total) {
      return true;
    }

    if (oldDelegate.slices.length != slices.length) {
      return true;
    }

    for (int index = 0; index < slices.length; index++) {
      if (oldDelegate.slices[index].count != slices[index].count ||
          oldDelegate.slices[index].color != slices[index].color) {
        return true;
      }
    }

    return false;
  }
}
