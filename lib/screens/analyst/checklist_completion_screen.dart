import 'package:flutter/material.dart';

import '../../services/analyst_service.dart';

class ChecklistCompletionScreen extends StatefulWidget {
  const ChecklistCompletionScreen({super.key});

  @override
  State<ChecklistCompletionScreen> createState() =>
      _ChecklistCompletionScreenState();
}

class _ChecklistCompletionScreenState extends State<ChecklistCompletionScreen> {
  final AnalystService _analystService = AnalystService();

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

  late Future<Map<String, dynamic>> _analyticsFuture;

  @override
  void initState() {
    super.initState();

    _analyticsFuture = _analystService.getChecklistCompletionAnalytics();
  }

  Future<void> _refresh() async {
    final Future<Map<String, dynamic>> future = _analystService
        .getChecklistCompletionAnalytics();

    setState(() {
      _analyticsFuture = future;
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
          'Checklist Completion',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<Map<String, dynamic>>(
            future: _analyticsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                debugPrint(
                  'CHECKLIST ANALYTICS ERROR: '
                  '${snapshot.error}',
                );

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: const [
                    SizedBox(height: 130),
                    Center(child: Text('Unable to load checklist analytics.')),
                  ],
                );
              }

              final Map<String, dynamic> data = snapshot.data ?? {};

              final int total = data['totalRequirements'] as int? ?? 0;

              final int completed = data['completedRequirements'] as int? ?? 0;

              final int incomplete =
                  data['incompleteRequirements'] as int? ?? 0;

              final double rate = data['completionRate'] as double? ?? 0;

              final List<Map<String, dynamic>> destinations =
                  List<Map<String, dynamic>>.from(
                    data['destinations'] as List? ?? [],
                  );

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                children: [
                  _buildHeader(),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          icon: Icons.fact_check_outlined,
                          value: '$total',
                          label: 'Requirements',
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: _buildSummaryCard(
                          icon: Icons.task_alt_outlined,
                          value: '${rate.toStringAsFixed(1)}%',
                          label: 'Completion',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  _buildCompletionChart(
                    total: total,
                    completed: completed,
                    incomplete: incomplete,
                    rate: rate,
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    'Completion by Destination',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _darkTextColor,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Checklist completion across '
                    'the supported destinations.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),

                  const SizedBox(height: 16),

                  if (destinations.isEmpty)
                    _buildEmptyState()
                  else
                    for (final destination in destinations)
                      _buildDestinationCard(destination),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
      child: const Row(
        children: [
          Icon(Icons.task_alt_outlined, color: _primaryColor, size: 32),

          SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checklist Completion',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'Aggregated completion of generated '
                  'travel preparation requirements.',
                  style: TextStyle(
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

  Widget _buildSummaryCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: _primaryColor, size: 23),

          const SizedBox(height: 7),

          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: _darkTextColor,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionChart({
    required int total,
    required int completed,
    required int incomplete,
    required double rate,
  }) {
    final double progress = total == 0 ? 0 : completed / total;

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
            width: 170,
            height: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 20,
                    backgroundColor: const Color(0xFFE7ECEF),
                    color: _primaryColor,
                    strokeCap: StrokeCap.butt,
                  ),
                ),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${rate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: _darkTextColor,
                      ),
                    ),

                    const SizedBox(height: 2),

                    const Text(
                      'Completed',
                      style: TextStyle(fontSize: 10.5, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _buildLegendItem(
                  label: 'Completed',
                  value: completed,
                  color: _primaryColor,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _buildLegendItem(
                  label: 'Incomplete',
                  value: incomplete,
                  color: const Color(0xFFB7C3CA),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required String label,
    required int value,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),

        const SizedBox(width: 7),

        Text(
          '$label  $value',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: _darkTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationCard(Map<String, dynamic> destination) {
    final String name = destination['name'] as String? ?? '';

    final int total = destination['total'] as int? ?? 0;

    final int completed = destination['completed'] as int? ?? 0;

    final double rate = destination['completionRate'] as double? ?? 0;

    final double progress = total == 0 ? 0 : completed / total;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _darkTextColor,
                  ),
                ),
              ),

              Text(
                total == 0 ? 'No data' : '${rate.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xFFEAF0F3),
            ),
          ),

          const SizedBox(height: 6),

          Text(
            total == 0
                ? 'No generated requirements'
                : '$completed of $total requirements completed',
            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
          Icon(Icons.checklist_outlined, size: 38, color: Colors.black38),

          SizedBox(height: 8),

          Text('No checklist data available.'),
        ],
      ),
    );
  }
}
