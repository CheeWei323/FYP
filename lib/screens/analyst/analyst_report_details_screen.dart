import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/analyst_report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/role_ui_widgets.dart';

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

  bool _isExporting = false;

  // ---------------------------------------------------------------------------
  // REPORT DATA
  // ---------------------------------------------------------------------------

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

  int _readInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _percentage(dynamic value) {
    return '${_readDouble(value).toStringAsFixed(1)}%';
  }

  // ---------------------------------------------------------------------------
  // TRIP COUNT LABELS
  // ---------------------------------------------------------------------------

  // Keep the displayed count from the saved report and use the correct unit.
  String _tripCount(dynamic value) {
    final count = _readInt(value);
    return '$count ${count == 1 ? 'trip' : 'trips'}';
  }

  // ---------------------------------------------------------------------------
  // EXPORT EXCEL
  // ---------------------------------------------------------------------------

  Future<void> _exportReport() async {
    if (_isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      // Preserve the existing report export implementation.
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

  // ---------------------------------------------------------------------------
  // FORMATTING HELPERS
  // ---------------------------------------------------------------------------

  String _formatDate(dynamic raw) {
    DateTime? date;

    if (raw is Timestamp) {
      date = raw.toDate().toLocal();
    } else if (raw is DateTime) {
      date = raw.toLocal();
    }

    if (date == null) {
      return 'Date not available';
    }

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}/'
        '${date.year} · '
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
    final String reportTitle =
        widget.report['reportTitle'] as String? ?? 'Analytics Report';

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,

        title: const Text(
          'Report Details',
          style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800),
        ),
      ),

      body: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),

          padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),

          children: [
            _buildHeader(reportTitle),

            const SizedBox(height: 27),

            _buildReportInformation(),

            const SizedBox(height: 28),

            _buildReportContent(),

            const SizedBox(height: 25),

            _buildInformationCard(),
          ],
        ),
      ),

      // Keep Excel export accessible while viewing a long report.
      bottomNavigationBar: SafeArea(
        top: false,

        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 11, 18, 14),

          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),

          child: FilledButton.icon(
            onPressed: _isExporting ? null : _exportReport,

            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),

            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,

                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.file_download_outlined, size: 20),

            label: Text(
              _isExporting ? 'Exporting Report...' : 'Export Excel',

              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REPORT HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader(String title) {
    return RoleIntroCard(
      eyebrow: 'SAVED REPORT',
      title: title,
      description:
          "These figures reflect the data captured when this report was generated.",
      icon: Icons.description_outlined,
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
        _buildSectionTitle(
          'Report Information',
          'Details of the selected analytics report.',
        ),

        const SizedBox(height: 14),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: _cardDecoration(),

          child: Column(
            children: [
              _buildInfoRow(
                icon: Icons.location_on_outlined,
                label: 'Destination',
                value: destination,
              ),

              const Divider(height: 25, color: AppColors.border),

              _buildInfoRow(
                icon: Icons.luggage_outlined,
                label: 'Travel Purpose',
                value: purpose,
              ),

              const Divider(height: 25, color: AppColors.border),

              _buildInfoRow(
                icon: Icons.schedule_outlined,
                label: 'Generated',
                value: _formatDate(widget.report['generatedAt']),
              ),

              const Divider(height: 25, color: AppColors.border),

              _buildInfoRow(
                icon: Icons.description_outlined,
                label: 'Export Format',
                value: 'Excel (.xlsx)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // REPORT INFORMATION ROW
  // ---------------------------------------------------------------------------

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,

      children: [
        _ReportDetailsIcon(icon: icon, size: 40),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 10.5,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                value,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SELECT REPORT TYPE
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
  // DESTINATION TRENDS REPORT
  // ---------------------------------------------------------------------------

  Widget _buildDestinationTrends() {
    final List<Map<String, dynamic>> destinations = _mapList(
      _data['destinations'],
    );

    final List<Map<String, dynamic>> monthlyActivity = _mapList(
      _data['monthlyActivity'],
    );

    // Scale monthly bars to the busiest month; the saved counts stay unchanged.
    final maximumMonthlyTrips = monthlyActivity.fold<int>(0, (maximum, item) {
      final count = _readInt(item['count']);
      return count > maximum ? count : maximum;
    });

    final int totalTrips = destinations.fold<int>(
      0,
      (total, item) => total + _readInt(item['count']),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildSectionTitle(
          'Destination Trends',
          'Trip activity captured when this report was generated.',
        ),

        const SizedBox(height: 15),

        _buildSummaryCard(
          icon: Icons.flight_takeoff_outlined,
          label: 'Total Trips',
          value: '$totalTrips',
        ),

        const SizedBox(height: 24),

        _buildSubheading('Trips by Destination'),

        const SizedBox(height: 11),

        if (destinations.isEmpty)
          _buildEmptyState('No destination data is available.')
        else
          _buildTableCard(
            children: [
              for (int index = 0; index < destinations.length; index++) ...[
                _buildValueRow(
                  title: destinations[index]['name'] as String? ?? 'Unknown',

                  value: _tripCount(destinations[index]['count']),

                  trailing: _percentage(destinations[index]['percentage']),
                  progress:
                      _readDouble(destinations[index]['percentage']) / 100,
                ),

                if (index != destinations.length - 1)
                  const Divider(height: 24, color: AppColors.border),
              ],
            ],
          ),

        const SizedBox(height: 25),

        _buildSubheading('Monthly Departure Activity'),
        const SizedBox(height: 6),
        const Text(
          'Bars compare trip counts against the busiest month in this report.',
          style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
        ),

        const SizedBox(height: 11),

        if (monthlyActivity.isEmpty)
          _buildEmptyState('No departure month data is available.')
        else
          _buildTableCard(
            children: [
              for (int index = 0; index < monthlyActivity.length; index++) ...[
                _buildValueRow(
                  title:
                      monthlyActivity[index]['label'] as String? ??
                      'Unknown Month',

                  value: _tripCount(monthlyActivity[index]['count']),
                  progress: maximumMonthlyTrips <= 0
                      ? 0.0
                      : _readInt(monthlyActivity[index]['count']) /
                            maximumMonthlyTrips,
                ),

                if (index != monthlyActivity.length - 1)
                  const Divider(height: 24, color: AppColors.border),
              ],
            ],
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TRAVEL PURPOSE DISTRIBUTION REPORT
  // ---------------------------------------------------------------------------

  Widget _buildPurposeDistribution() {
    final int total = _readInt(_data['total']);

    final Map<String, dynamic> counts = _data['counts'] is Map
        ? Map<String, dynamic>.from(_data['counts'] as Map)
        : <String, dynamic>{};

    const List<String> purposes = ['tourism', 'business', 'study'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildSectionTitle(
          'Travel Purpose Distribution',
          'Aggregated travel purposes captured in this report.',
        ),

        const SizedBox(height: 15),

        _buildSummaryCard(
          icon: Icons.groups_outlined,
          label: 'Total Trips',
          value: '$total',
        ),

        const SizedBox(height: 20),

        _buildSubheading('Trips by Travel Purpose'),

        const SizedBox(height: 11),

        _buildTableCard(
          children: [
            for (int index = 0; index < purposes.length; index++) ...[
              _buildValueRow(
                title: _purposeLabel(purposes[index]),

                value: _tripCount(counts[purposes[index]]),
                progress: total <= 0
                    ? 0.0
                    : _readInt(counts[purposes[index]]) / total,

                trailing: _percentage(
                  total <= 0
                      ? 0
                      : (_readInt(counts[purposes[index]]) / total) * 100,
                ),
              ),

              if (index != purposes.length - 1)
                const Divider(height: 24, color: AppColors.border),
            ],
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CHECKLIST COMPLETION REPORT
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
          'Aggregated preparation completion at the '
              'time of report generation.',
        ),

        const SizedBox(height: 15),

        _buildSummaryCard(
          icon: Icons.task_alt_outlined,
          label: 'Average Completion',
          value: _percentage(_data['overallCompletionRate']),
        ),

        const SizedBox(height: 14),

        _buildTableCard(
          children: [
            _buildValueRow(
              title: 'Trips with Checklists',
              value: '${_readInt(_data['tripsWithChecklist'])}',
            ),

            const Divider(height: 24, color: AppColors.border),

            _buildValueRow(
              title: 'Completed Items',
              value: '${_readInt(_data['completedChecklistItems'])}',
            ),

            const Divider(height: 24, color: AppColors.border),

            _buildValueRow(
              title: 'Incomplete Items',
              value: '${_readInt(_data['incompleteChecklistItems'])}',
            ),

            const Divider(height: 24, color: AppColors.border),

            _buildValueRow(
              title: 'Total Checklist Items',
              value: '${_readInt(_data['totalChecklistItems'])}',
            ),
          ],
        ),

        if (destinationComparison.isNotEmpty) ...[
          const SizedBox(height: 25),

          _buildSubheading('Completion by Destination'),

          const SizedBox(height: 11),

          _buildTableCard(
            children: [
              for (
                int index = 0;
                index < destinationComparison.length;
                index++
              ) ...[
                _buildValueRow(
                  title:
                      destinationComparison[index]['name'] as String? ??
                      'Unknown',

                  value: _tripCount(destinationComparison[index]['tripCount']),

                  trailing: _percentage(
                    destinationComparison[index]['completionRate'],
                  ),
                  progress:
                      _readDouble(
                        destinationComparison[index]['completionRate'],
                      ) /
                      100,
                ),

                if (index != destinationComparison.length - 1)
                  const Divider(height: 24, color: AppColors.border),
              ],
            ],
          ),
        ],

        if (purposeComparison.isNotEmpty) ...[
          const SizedBox(height: 25),

          _buildSubheading('Completion by Purpose'),

          const SizedBox(height: 11),

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

                  value: _tripCount(purposeComparison[index]['tripCount']),

                  trailing: _percentage(
                    purposeComparison[index]['completionRate'],
                  ),
                  progress:
                      _readDouble(purposeComparison[index]['completionRate']) /
                      100,
                ),

                if (index != purposeComparison.length - 1)
                  const Divider(height: 24, color: AppColors.border),
              ],
            ],
          ),
        ],

        const SizedBox(height: 25),

        _buildSubheading('Requirements for Further Investigation'),

        const SizedBox(height: 7),

        const Text(
          'Lower completion highlights patterns that may '
          'warrant further investigation. Completion rate '
          'alone does not prove that guidance is inadequate.',
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 11.5,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 13),

        if (requirements.isEmpty)
          _buildEmptyState('No incomplete requirements were recorded.')
        else
          Column(
            children: [
              for (int index = 0; index < requirements.length; index++) ...[
                _buildRequirementCompletionCard(requirements[index]),

                if (index != requirements.length - 1)
                  const SizedBox(height: 11),
              ],
            ],
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // REQUIREMENT COMPLETION CARD
  // ---------------------------------------------------------------------------

  Widget _buildRequirementCompletionCard(Map<String, dynamic> item) {
    final double completionRate = _readDouble(item['completionRate']);

    final double progress = (completionRate / 100).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            item['title'] as String? ?? 'Unnamed requirement',

            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 11),

          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),

                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.primaryLight,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(width: 11),

              Text(
                _percentage(completionRate),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            'Generated ${_readInt(item['generated'])} · '
            'Completed ${_readInt(item['completed'])} · '
            'Incomplete ${_readInt(item['incomplete'])}',

            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 10.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REQUIREMENT PATTERNS REPORT
  // ---------------------------------------------------------------------------

  Widget _buildRequirementPatterns() {
    final int analysedTrips = _readInt(_data['analysedTrips']);

    final List<Map<String, dynamic>> patterns = _mapList(
      _data['requirementPatterns'],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildSectionTitle(
          'Requirement Patterns',
          'Requirements commonly generated within '
              'the selected traveller segment.',
        ),

        const SizedBox(height: 15),

        _buildSummaryCard(
          icon: Icons.fact_check_outlined,
          label: 'Analysed Trips',
          value: '$analysedTrips',
        ),

        const SizedBox(height: 24),

        _buildSubheading('Commonly Generated Requirements'),

        const SizedBox(height: 11),

        if (patterns.isEmpty)
          _buildEmptyState('No requirement patterns are available.')
        else
          Column(
            children: [
              for (int index = 0; index < patterns.length; index++) ...[
                _buildRequirementPatternCard(
                  patterns[index],
                  analysedTrips,
                  index + 1,
                ),

                if (index != patterns.length - 1) const SizedBox(height: 11),
              ],
            ],
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // REQUIREMENT PATTERN CARD
  // ---------------------------------------------------------------------------

  Widget _buildRequirementPatternCard(
    Map<String, dynamic> pattern,
    int analysedTrips,
    int rank,
  ) {
    final List<Map<String, dynamic>> destinations = _mapList(
      pattern['destinationBreakdown'],
    );

    final List<Map<String, dynamic>> purposes = _mapList(
      pattern['purposeBreakdown'],
    );

    final double percentage = _readDouble(pattern['percentage']);

    final double progress = (percentage / 100).clamp(0.0, 1.0);

    final int tripCount = _readInt(pattern['tripCount']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,

                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),

                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  pattern['title'] as String? ?? 'Unnamed requirement',

                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),

                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.primaryLight,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(width: 11),

              Text(
                _percentage(percentage),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            'Generated for $tripCount of $analysedTrips '
            '${analysedTrips == 1 ? 'trip' : 'trips'}',

            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
            ),
          ),

          if (destinations.isNotEmpty) ...[
            const SizedBox(height: 15),

            _buildBreakdownLabel(
              icon: Icons.public_outlined,
              label: 'Destinations',
            ),

            const SizedBox(height: 8),

            Wrap(
              spacing: 7,
              runSpacing: 7,

              children: destinations.map((item) {
                return _buildSmallChip(
                  '${item['name'] ?? 'Unknown'} · '
                  '${_readInt(item['tripCount'])}',
                );
              }).toList(),
            ),
          ],

          if (purposes.isNotEmpty) ...[
            const SizedBox(height: 13),

            _buildBreakdownLabel(
              icon: Icons.work_outline_rounded,
              label: 'Travel Purposes',
            ),

            const SizedBox(height: 8),

            Wrap(
              spacing: 7,
              runSpacing: 7,

              children: purposes.map((item) {
                return _buildSmallChip(
                  '${_purposeLabel(item['purpose'] as String?)} · '
                  '${_readInt(item['tripCount'])}',
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED SECTION HEADING
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
  // SHARED SUBHEADING
  // ---------------------------------------------------------------------------

  Widget _buildSubheading(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.navy,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED SUMMARY CARD
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),

      child: Row(
        children: [
          _ReportDetailsIcon(icon: icon, size: 47),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
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
  // SHARED TABLE CARD
  // ---------------------------------------------------------------------------

  Widget _buildTableCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED VALUE ROW
  // ---------------------------------------------------------------------------

  Widget _buildValueRow({
    required String title,
    required String value,
    String? trailing,
    double? progress,
  }) {
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ],
    );
    final figure = Text(
      trailing ?? value,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useStackedLayout =
            constraints.maxWidth < 260 ||
            MediaQuery.textScalerOf(context).scale(14) > 20;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (useStackedLayout)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [details, const SizedBox(height: 8), figure],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 16),
                  figure,
                ],
              ),
            if (progress != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 9,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primaryLight,
                  semanticsLabel: title,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BREAKDOWN LABEL
  // ---------------------------------------------------------------------------

  Widget _buildBreakdownLabel({required IconData icon, required String label}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.secondaryText),

        const SizedBox(width: 6),

        Text(
          label,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CONTEXT CHIP
  // ---------------------------------------------------------------------------

  Widget _buildSmallChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),

      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),

      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),

      child: Column(
        children: [
          const _ReportDetailsIcon(icon: Icons.info_outline_rounded, size: 52),

          const SizedBox(height: 13),

          Text(
            message,
            textAlign: TextAlign.center,

            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HISTORICAL DATA INFORMATION
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
                  'Historical Analytics Snapshot',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                SizedBox(height: 7),

                Text(
                  'The information shown in this report '
                  'reflects the aggregated travel data '
                  'captured when the report was generated.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),

                SizedBox(height: 9),

                Text(
                  'Changes to travel records after report '
                  'generation are not automatically reflected '
                  'in this historical snapshot.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11.5,
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
}

// -----------------------------------------------------------------------------
// REUSABLE REPORT DETAILS ICON
// -----------------------------------------------------------------------------

class _ReportDetailsIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _ReportDetailsIcon({required this.icon, required this.size});

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
