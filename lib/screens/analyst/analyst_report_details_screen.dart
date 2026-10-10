import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/analyst_report_service.dart';

class AnalystReportDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> report;

  const AnalystReportDetailsScreen({super.key, required this.report});

  @override
  State<AnalystReportDetailsScreen> createState() =>
      _AnalystReportDetailsScreenState();
}

class _AnalystReportDetailsScreenState
    extends State<AnalystReportDetailsScreen> {
  final AnalystReportService _reportService = AnalystReportService();

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

  bool _isExporting = false;

  Map<String, dynamic> get _data {
    final dynamic raw = widget.report['data'];

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _exportReport() async {
    if (_isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      await _reportService.exportReport(widget.report);
    } catch (error) {
      debugPrint('EXPORT REPORT ERROR: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Unable to export report. Please try again.'),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  String _formatDate(dynamic raw) {
    DateTime? date;

    if (raw is Timestamp) {
      date = raw.toDate();
    } else if (raw is DateTime) {
      date = raw;
    }

    if (date == null) {
      return 'Date not available';
    }

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}/'
        '${date.year} '
        '${twoDigits(date.hour)}:'
        '${twoDigits(date.minute)}';
  }

  String _purposeLabel(String? purpose) {
    switch (purpose) {
      case 'tourism':
        return 'Tourism';

      case 'business':
        return 'Business';

      case 'study':
        return 'Study';

      default:
        return purpose ?? 'Unknown';
    }
  }

  String _percentage(dynamic value) {
    final double number = value is num ? value.toDouble() : 0;

    return '${number.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final String reportTitle =
        widget.report['reportTitle'] as String? ?? 'Analytics Report';

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: _darkTextColor,
        elevation: 0,
        title: const Text(
          'Report Details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
          children: [
            _buildHeader(reportTitle),

            const SizedBox(height: 20),

            _buildReportInformation(),

            const SizedBox(height: 26),

            _buildReportContent(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _borderColor)),
          ),
          child: SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _isExporting ? null : _exportReport,
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.file_download_outlined),
              label: Text(_isExporting ? 'Exporting...' : 'Export Excel'),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE7F7F8), Color(0xFFF1F8FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBE8EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.table_chart_outlined,
              color: _primaryColor,
              size: 26,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Historical aggregated analytics snapshot',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REPORT INFORMATION
  // ---------------------------------------------------------------------------

  Widget _buildReportInformation() {
    final String destination =
        widget.report['destinationName'] as String? ?? 'All Destinations';

    final String purpose =
        widget.report['purposeLabel'] as String? ?? 'All Purposes';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Report Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _darkTextColor,
          ),
        ),

        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                icon: Icons.location_on_outlined,
                label: 'Destination',
                value: destination,
              ),

              const Divider(height: 24),

              _buildInfoRow(
                icon: Icons.luggage_outlined,
                label: 'Travel Purpose',
                value: purpose,
              ),

              const Divider(height: 24),

              _buildInfoRow(
                icon: Icons.schedule_outlined,
                label: 'Generated',
                value: _formatDate(widget.report['generatedAt']),
              ),

              const Divider(height: 24),

              _buildInfoRow(
                icon: Icons.description_outlined,
                label: 'Format',
                value: 'Excel (.xlsx)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: _primaryColor, size: 21),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10.5, color: Colors.black54),
              ),

              const SizedBox(height: 2),

              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _darkTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // REPORT TYPE
  // ---------------------------------------------------------------------------

  Widget _buildReportContent() {
    final String reportType = widget.report['reportType'] as String? ?? '';

    switch (reportType) {
      case AnalystReportService.destinationTrends:
        return _buildDestinationTrends();

      case AnalystReportService.purposeDistribution:
        return _buildPurposeDistribution();

      case AnalystReportService.checklistCompletion:
        return _buildChecklistCompletion();

      case AnalystReportService.requirementPatterns:
        return _buildRequirementPatterns();

      default:
        return _buildEmptyState('Report data is not available.');
    }
  }

  // ---------------------------------------------------------------------------
  // DESTINATION TRENDS
  // ---------------------------------------------------------------------------

  Widget _buildDestinationTrends() {
    final List<Map<String, dynamic>> destinations = _mapList(
      _data['destinations'],
    );

    final List<Map<String, dynamic>> monthlyActivity = _mapList(
      _data['monthlyActivity'],
    );

    final int totalTrips = destinations.fold<int>(
      0,
      (total, item) => total + (item['count'] as int? ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Destination Trends',
          'Trip activity captured when this report was generated.',
        ),

        const SizedBox(height: 12),

        _buildSummaryCard(
          icon: Icons.flight_takeoff_outlined,
          label: 'Total Trips',
          value: totalTrips.toString(),
        ),

        const SizedBox(height: 18),

        _buildSubheading('Trips by Destination'),

        const SizedBox(height: 10),

        if (destinations.isEmpty)
          _buildEmptyState('No destination data is available.')
        else
          _buildTableCard(
            children: [
              for (int index = 0; index < destinations.length; index++) ...[
                _buildValueRow(
                  title: destinations[index]['name'] as String? ?? '',
                  value: '${destinations[index]['count'] ?? 0} trips',
                  trailing: _percentage(destinations[index]['percentage']),
                ),

                if (index != destinations.length - 1) const Divider(height: 20),
              ],
            ],
          ),

        const SizedBox(height: 22),

        _buildSubheading('Monthly Departure Activity'),

        const SizedBox(height: 10),

        if (monthlyActivity.isEmpty)
          _buildEmptyState('No departure month data is available.')
        else
          _buildTableCard(
            children: [
              for (int index = 0; index < monthlyActivity.length; index++) ...[
                _buildValueRow(
                  title: monthlyActivity[index]['label'] as String? ?? '',
                  value: '${monthlyActivity[index]['count'] ?? 0} trips',
                ),

                if (index != monthlyActivity.length - 1)
                  const Divider(height: 20),
              ],
            ],
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PURPOSE DISTRIBUTION
  // ---------------------------------------------------------------------------

  Widget _buildPurposeDistribution() {
    final int total = _data['total'] as int? ?? 0;

    final Map<String, dynamic> counts = _data['counts'] is Map
        ? Map<String, dynamic>.from(_data['counts'] as Map)
        : <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Travel Purpose Distribution',
          'Aggregated travel purposes captured in this report.',
        ),

        const SizedBox(height: 12),

        _buildSummaryCard(
          icon: Icons.groups_outlined,
          label: 'Total Trips',
          value: total.toString(),
        ),

        const SizedBox(height: 18),

        _buildTableCard(
          children: [
            for (int index = 0; index < 3; index++) ...[
              Builder(
                builder: (context) {
                  const List<String> purposes = [
                    'tourism',
                    'business',
                    'study',
                  ];

                  final String purpose = purposes[index];

                  final int count = counts[purpose] as int? ?? 0;

                  final double percentage = total == 0
                      ? 0
                      : (count / total) * 100;

                  return _buildValueRow(
                    title: _purposeLabel(purpose),
                    value: '$count trips',
                    trailing: _percentage(percentage),
                  );
                },
              ),

              if (index != 2) const Divider(height: 20),
            ],
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CHECKLIST COMPLETION
  // ---------------------------------------------------------------------------

  Widget _buildChecklistCompletion() {
    final List<Map<String, dynamic>> destinationComparison = _mapList(
      _data['destinationComparison'],
    );

    final List<Map<String, dynamic>> purposeComparison = _mapList(
      _data['purposeComparison'],
    );

    final List<Map<String, dynamic>> requirements = _mapList(
      _data['requirementsNeedingAttention'],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Checklist Completion',
          'Aggregated preparation completion at the time of report generation.',
        ),

        const SizedBox(height: 12),

        _buildSummaryCard(
          icon: Icons.task_alt_outlined,
          label: 'Average Completion',
          value: _percentage(_data['overallCompletionRate']),
        ),

        const SizedBox(height: 10),

        _buildTableCard(
          children: [
            _buildValueRow(
              title: 'Trips with Checklists',
              value: '${_data['tripsWithChecklist'] ?? 0}',
            ),

            const Divider(height: 20),

            _buildValueRow(
              title: 'Completed Items',
              value: '${_data['completedChecklistItems'] ?? 0}',
            ),

            const Divider(height: 20),

            _buildValueRow(
              title: 'Incomplete Items',
              value: '${_data['incompleteChecklistItems'] ?? 0}',
            ),

            const Divider(height: 20),

            _buildValueRow(
              title: 'Total Checklist Items',
              value: '${_data['totalChecklistItems'] ?? 0}',
            ),
          ],
        ),

        if (destinationComparison.isNotEmpty) ...[
          const SizedBox(height: 22),

          _buildSubheading('Completion by Destination'),

          const SizedBox(height: 10),

          _buildTableCard(
            children: [
              for (
                int index = 0;
                index < destinationComparison.length;
                index++
              ) ...[
                _buildValueRow(
                  title: destinationComparison[index]['name'] as String? ?? '',
                  value:
                      '${destinationComparison[index]['tripCount'] ?? 0} trips',
                  trailing: _percentage(
                    destinationComparison[index]['completionRate'],
                  ),
                ),

                if (index != destinationComparison.length - 1)
                  const Divider(height: 20),
              ],
            ],
          ),
        ],

        if (purposeComparison.isNotEmpty) ...[
          const SizedBox(height: 22),

          _buildSubheading('Completion by Purpose'),

          const SizedBox(height: 10),

          _buildTableCard(
            children: [
              for (
                int index = 0;
                index < purposeComparison.length;
                index++
              ) ...[
                _buildValueRow(
                  title: _purposeLabel(
                    purposeComparison[index]['purpose'] as String?,
                  ),
                  value: '${purposeComparison[index]['tripCount'] ?? 0} trips',
                  trailing: _percentage(
                    purposeComparison[index]['completionRate'],
                  ),
                ),

                if (index != purposeComparison.length - 1)
                  const Divider(height: 20),
              ],
            ],
          ),
        ],

        const SizedBox(height: 22),

        _buildSubheading('Requirements for Further Investigation'),

        const SizedBox(height: 5),

        const Text(
          'Lower completion highlights patterns that may warrant further investigation. '
          'Completion rate alone does not prove that guidance is inadequate.',
          style: TextStyle(fontSize: 11, height: 1.45, color: Colors.black54),
        ),

        const SizedBox(height: 10),

        if (requirements.isEmpty)
          _buildEmptyState('No incomplete requirements were recorded.')
        else
          Column(
            children: [
              for (int index = 0; index < requirements.length; index++) ...[
                _buildRequirementCompletionCard(requirements[index]),

                if (index != requirements.length - 1)
                  const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildRequirementCompletionCard(Map<String, dynamic> item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['title'] as String? ?? 'Unnamed requirement',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _darkTextColor,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Completion ${_percentage(item['completionRate'])}',
            style: const TextStyle(
              fontSize: 11.5,
              color: _primaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Generated ${item['generated'] ?? 0} · '
            'Completed ${item['completed'] ?? 0} · '
            'Incomplete ${item['incomplete'] ?? 0}',
            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REQUIREMENT PATTERNS
  // ---------------------------------------------------------------------------

  Widget _buildRequirementPatterns() {
    final int analysedTrips = _data['analysedTrips'] as int? ?? 0;

    final List<Map<String, dynamic>> patterns = _mapList(
      _data['requirementPatterns'],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Requirement Patterns',
          'Requirements commonly generated within the selected traveller segment.',
        ),

        const SizedBox(height: 12),

        _buildSummaryCard(
          icon: Icons.fact_check_outlined,
          label: 'Analysed Trips',
          value: analysedTrips.toString(),
        ),

        const SizedBox(height: 18),

        if (patterns.isEmpty)
          _buildEmptyState('No requirement patterns are available.')
        else
          Column(
            children: [
              for (int index = 0; index < patterns.length; index++) ...[
                _buildRequirementPatternCard(patterns[index], analysedTrips),

                if (index != patterns.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildRequirementPatternCard(
    Map<String, dynamic> pattern,
    int analysedTrips,
  ) {
    final List<Map<String, dynamic>> destinations = _mapList(
      pattern['destinationBreakdown'],
    );

    final List<Map<String, dynamic>> purposes = _mapList(
      pattern['purposeBreakdown'],
    );

    return Container(
      width: double.infinity,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  pattern['title'] as String? ?? 'Unnamed requirement',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _darkTextColor,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Text(
                _percentage(pattern['percentage']),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          Text(
            'Generated for ${pattern['tripCount'] ?? 0} '
            'of $analysedTrips analysed trips',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),

          if (destinations.isNotEmpty) ...[
            const SizedBox(height: 10),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: destinations.map((item) {
                return _buildSmallChip(
                  '${item['name']} · '
                  '${item['tripCount']}',
                );
              }).toList(),
            ),
          ],

          if (purposes.isNotEmpty) ...[
            const SizedBox(height: 8),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: purposes.map((item) {
                return _buildSmallChip(
                  '${_purposeLabel(item['purpose'] as String?)} · '
                  '${item['tripCount']}',
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED UI
  // ---------------------------------------------------------------------------

  Widget _buildSectionTitle(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _darkTextColor,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          description,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildSubheading(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: _darkTextColor,
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _primaryColor, size: 22),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),

                const SizedBox(height: 2),

                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildValueRow({
    required String title,
    required String value,
    String? trailing,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _darkTextColor,
            ),
          ),
        ),

        const SizedBox(width: 10),

        Text(
          value,
          style: const TextStyle(fontSize: 11.5, color: Colors.black54),
        ),

        if (trailing != null) ...[
          const SizedBox(width: 12),

          Text(
            trailing,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _primaryColor,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSmallChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF486581),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.black38,
            size: 32,
          ),

          const SizedBox(height: 8),

          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
