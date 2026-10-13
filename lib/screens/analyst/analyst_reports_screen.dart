import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/analyst_report_service.dart';
import '../../services/analyst_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/analyst/analytics_filter_card.dart';
import 'analyst_report_details_screen.dart';

class AnalystReportsScreen extends StatefulWidget {
  const AnalystReportsScreen({super.key});

  @override
  State<AnalystReportsScreen> createState() => _AnalystReportsScreenState();
}

class _AnalystReportsScreenState extends State<AnalystReportsScreen> {
  final AnalystReportService _reportService = AnalystReportService();

  final AnalystService _analystService = AnalystService();

  String _selectedReportType = AnalystReportService.destinationTrends;

  String? _selectedDestinationId;
  String? _selectedPurpose;

  bool _isGenerating = false;

  // Cached Firestore data.
  List<Map<String, String>>? _countries;
  List<Map<String, dynamic>>? _reportHistory;

  bool _countriesError = false;
  bool _historyError = false;

  // Prevent outdated requests from replacing newer data.
  int _countriesRequestVersion = 0;
  int _historyRequestVersion = 0;

  @override
  void initState() {
    super.initState();

    _loadCountries();
    _loadHistory();
  }

  // ---------------------------------------------------------------------------
  // REPORT FILTER RULES
  // ---------------------------------------------------------------------------

  bool get _showDestinationFilter {
    return _selectedReportType == AnalystReportService.purposeDistribution ||
        _selectedReportType == AnalystReportService.checklistCompletion ||
        _selectedReportType == AnalystReportService.requirementPatterns;
  }

  bool get _showPurposeFilter {
    return _selectedReportType == AnalystReportService.destinationTrends ||
        _selectedReportType == AnalystReportService.checklistCompletion ||
        _selectedReportType == AnalystReportService.requirementPatterns;
  }

  // ---------------------------------------------------------------------------
  // LOAD FILTER COUNTRIES
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
        _countriesError = false;
      });
    } catch (error) {
      debugPrint('ANALYST REPORT FILTER ERROR: $error');

      if (!mounted || requestVersion != _countriesRequestVersion) {
        return;
      }

      setState(() {
        _countriesError = true;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // LOAD REPORT HISTORY
  // ---------------------------------------------------------------------------

  Future<void> _loadHistory() async {
    final int requestVersion = ++_historyRequestVersion;

    try {
      final List<Map<String, dynamic>> reports = await _reportService
          .getReportHistory();

      if (!mounted || requestVersion != _historyRequestVersion) {
        return;
      }

      setState(() {
        _reportHistory = reports;
        _historyError = false;
      });
    } catch (error) {
      debugPrint('ANALYST REPORT HISTORY ERROR: $error');

      if (!mounted || requestVersion != _historyRequestVersion) {
        return;
      }

      setState(() {
        _historyError = true;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  Future<void> _refresh() async {
    // Keep existing data visible while refreshing.
    await Future.wait<void>([_loadCountries(), _loadHistory()]);
  }

  // ---------------------------------------------------------------------------
  // RETRY HELPERS
  // ---------------------------------------------------------------------------

  void _retryCountries() {
    setState(() {
      _countriesError = false;
    });

    _loadCountries();
  }

  void _retryHistory() {
    setState(() {
      _historyError = false;
    });

    _loadHistory();
  }

  // ---------------------------------------------------------------------------
  // REPORT TYPE SELECTION
  // ---------------------------------------------------------------------------

  void _changeReportType(String? value) {
    if (value == null || value == _selectedReportType) {
      return;
    }

    setState(() {
      _selectedReportType = value;

      // Clear filters that do not apply to the selected
      // report type, preserving the existing report rules.
      if (!_showDestinationFilter) {
        _selectedDestinationId = null;
      }

      if (!_showPurposeFilter) {
        _selectedPurpose = null;
      }
    });
  }

  void _changeDestination(String? value) {
    setState(() {
      _selectedDestinationId = value;
    });
  }

  void _changePurpose(String? value) {
    setState(() {
      _selectedPurpose = value;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedDestinationId = null;
      _selectedPurpose = null;
    });
  }

  // ---------------------------------------------------------------------------
  // GENERATE AND EXPORT REPORT
  // ---------------------------------------------------------------------------

  Future<void> _generateReport() async {
    if (_isGenerating) {
      return;
    }

    // Capture the selected options for this generation.
    final String reportType = _selectedReportType;

    final String? destinationId = _showDestinationFilter
        ? _selectedDestinationId
        : null;

    final String? purpose = _showPurposeFilter ? _selectedPurpose : null;

    setState(() {
      _isGenerating = true;
    });

    try {
      // Preserve the existing report generation service.
      final Map<String, dynamic> report = await _reportService.generateReport(
        reportType: reportType,
        destinationId: destinationId,
        purpose: purpose,
      );

      if (!mounted) {
        return;
      }

      // Refresh saved report history after generation.
      await _loadHistory();

      if (!mounted) {
        return;
      }

      // Automatically export the generated Excel report.
      try {
        await _reportService.exportReport(report);

        if (!mounted) {
          return;
        }

        _showMessage('Report generated successfully.');
      } catch (error) {
        debugPrint('ANALYST REPORT EXPORT ERROR: $error');

        if (!mounted) {
          return;
        }

        _showMessage(
          'Report generated, but Excel export failed. '
          'You can try exporting it from Report History.',
        );
      }
    } catch (error) {
      debugPrint('GENERATE ANALYST REPORT ERROR: $error');

      if (!mounted) {
        return;
      }

      _showMessage('Unable to generate report. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // EXPORT EXISTING REPORT
  // ---------------------------------------------------------------------------

  Future<void> _exportExcel(Map<String, dynamic> report) async {
    try {
      await _reportService.exportReport(report);
    } catch (error) {
      debugPrint('EXPORT ANALYST REPORT ERROR: $error');

      if (!mounted) {
        return;
      }

      _showMessage('Unable to export report. Please try again.');
    }
  }

  // ---------------------------------------------------------------------------
  // VIEW REPORT DETAILS
  // ---------------------------------------------------------------------------

  Future<void> _viewReport(Map<String, dynamic> report) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalystReportDetailsScreen(report: report),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SNACKBAR
  // ---------------------------------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------
  // FORMATTING HELPERS
  // ---------------------------------------------------------------------------

  String _reportTypeLabel(String value) {
    switch (value) {
      case AnalystReportService.destinationTrends:
        return 'Destination Trends';

      case AnalystReportService.purposeDistribution:
        return 'Travel Purpose Distribution';

      case AnalystReportService.checklistCompletion:
        return 'Checklist Completion';

      case AnalystReportService.requirementPatterns:
        return 'Requirement Patterns';

      default:
        return value;
    }
  }

  String _formatDate(dynamic raw) {
    DateTime? date;

    if (raw is Timestamp) {
      date = raw.toDate().toLocal();
    } else if (raw is DateTime) {
      date = raw.toLocal();
    }

    if (date == null) {
      return 'Recently generated';
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
    // This screen is displayed inside AnalystDashboard,
    // which already provides its AppBar and bottom navigation.
    return ColoredBox(
      color: AppColors.background,

      child: SafeArea(
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
                'Generate Report',
                'Export aggregated analytics as an Excel report.',
              ),

              const SizedBox(height: 14),

              _buildGenerator(),

              const SizedBox(height: 28),

              _buildSectionTitle(
                'Report History',
                'Previously generated report snapshots.',
              ),

              const SizedBox(height: 14),

              _buildHistory(),

              const SizedBox(height: 25),

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              _ReportIcon(icon: Icons.description_outlined, size: 52),

              SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Analytics Reports',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    SizedBox(height: 7),

                    Text(
                      'Generate, export and review '
                      'historical aggregated analytics '
                      'reports.',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 13),

          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Icon(
                Icons.table_chart_outlined,
                color: AppColors.primary,
                size: 18,
              ),

              SizedBox(width: 9),

              Expanded(
                child: Text(
                  'Choose an analytics category and '
                  'apply relevant filters before '
                  'generating an Excel report.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GENERATE REPORT CARD
  // ---------------------------------------------------------------------------

  Widget _buildGenerator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Row(
            children: [
              _ReportIcon(icon: Icons.analytics_outlined, size: 43),

              SizedBox(width: 12),

              Expanded(
                child: Text(
                  'Report Configuration',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Text(
            'Report Type',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 9),

          DropdownButtonFormField<String>(
            key: ValueKey(_selectedReportType),
            initialValue: _selectedReportType,
            isExpanded: true,

            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.analytics_outlined,
                color: AppColors.primary,
              ),

              filled: true,
              fillColor: AppColors.background,

              contentPadding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 15,
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: AppColors.border),
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),

              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),

            items:
                [
                  AnalystReportService.destinationTrends,
                  AnalystReportService.purposeDistribution,
                  AnalystReportService.checklistCompletion,
                  AnalystReportService.requirementPatterns,
                ].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      _reportTypeLabel(value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),

            onChanged: _isGenerating ? null : _changeReportType,
          ),

          if (_showDestinationFilter || _showPurposeFilter) ...[
            const SizedBox(height: 19),

            const Divider(height: 1, color: AppColors.border),

            const SizedBox(height: 18),

            const Text(
              'Report Filters',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Filters are optional and depend on '
              'the selected report type.',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 13),

            _buildFilters(),
          ],

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,

            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),

              onPressed: _isGenerating ? null : _generateReport,

              icon: _isGenerating
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
                _isGenerating
                    ? 'Generating Report...'
                    : 'Generate & Export Excel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REPORT FILTERS
  // ---------------------------------------------------------------------------

  Widget _buildFilters() {
    if (_countries == null && !_countriesError) {
      return _buildStatusCard(
        icon: Icons.filter_alt_outlined,
        title: 'Loading Report Filters',
        message: 'Retrieving supported destination options...',
        isLoading: true,
        minimumHeight: 155,
      );
    }

    if (_countries == null && _countriesError) {
      return _buildStatusCard(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to Load Filters',
        message: 'Report filter options could not be retrieved.',
        minimumHeight: 155,
        onRetry: _retryCountries,
      );
    }

    // Preserve the existing reusable AnalyticsFilterCard.
    return AnalyticsFilterCard(
      countries: _countries ?? [],
      selectedDestinationId: _selectedDestinationId,
      selectedPurpose: _selectedPurpose,
      showDestination: _showDestinationFilter,
      showPurpose: _showPurposeFilter,
      onDestinationChanged: _changeDestination,
      onPurposeChanged: _changePurpose,
      onClear: _clearFilters,
    );
  }

  // ---------------------------------------------------------------------------
  // REPORT HISTORY
  // ---------------------------------------------------------------------------

  Widget _buildHistory() {
    final List<Map<String, dynamic>>? reports = _reportHistory;

    if (reports == null && _historyError) {
      return _buildStatusCard(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to Load Report History',
        message: 'Saved reports could not be retrieved.',
        minimumHeight: 205,
        onRetry: _retryHistory,
      );
    }

    if (reports == null) {
      return _buildStatusCard(
        icon: Icons.history_rounded,
        title: 'Loading Report History',
        message: 'Retrieving previously generated reports...',
        minimumHeight: 205,
        isLoading: true,
      );
    }

    if (reports.isEmpty) {
      return _buildStatusCard(
        icon: Icons.insert_drive_file_outlined,
        title: 'No Reports Generated Yet',
        message: 'Generated analytics reports will appear here.',
        minimumHeight: 205,
      );
    }

    return Column(
      children: [
        for (int index = 0; index < reports.length; index++) ...[
          _buildReportCard(reports[index]),

          if (index != reports.length - 1) const SizedBox(height: 11),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // INDIVIDUAL REPORT CARD
  // ---------------------------------------------------------------------------

  Widget _buildReportCard(Map<String, dynamic> report) {
    final String title = report['reportTitle'] as String? ?? 'Analytics Report';

    final String destination =
        report['destinationName'] as String? ?? 'All Destinations';

    final String purpose = report['purposeLabel'] as String? ?? 'All Purposes';

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
              const _ReportIcon(icon: Icons.table_chart_outlined, size: 46),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_outlined,
                          color: AppColors.secondaryText,
                          size: 14,
                        ),

                        const SizedBox(width: 5),

                        Expanded(
                          child: Text(
                            _formatDate(report['generatedAt']),
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Wrap(
            spacing: 7,
            runSpacing: 7,

            children: [
              _buildChip(destination, Icons.public_outlined),

              _buildChip(purpose, Icons.work_outline_rounded),

              _buildChip('Excel', Icons.table_chart_outlined),
            ],
          ),

          const SizedBox(height: 16),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,

                    side: const BorderSide(color: AppColors.border),

                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 12,
                    ),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),

                  onPressed: () {
                    _viewReport(report);
                  },

                  icon: const Icon(Icons.visibility_outlined, size: 17),

                  label: const Text(
                    'View Report',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,

                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 12,
                    ),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),

                  onPressed: () {
                    _exportExcel(report);
                  },

                  icon: const Icon(Icons.file_download_outlined, size: 17),

                  label: const Text(
                    'Export Excel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REPORT INFORMATION CHIP
  // ---------------------------------------------------------------------------

  Widget _buildChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),

      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(icon, color: AppColors.primary, size: 13),

          const SizedBox(width: 5),

          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REPORT INFORMATION CARD
  // ---------------------------------------------------------------------------

  Widget _buildInformationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FA),
        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: const Color(0xFFD8E6EE)),
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
                  'About Analytics Reports',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                SizedBox(height: 7),

                Text(
                  'Reports provide a snapshot of aggregated '
                  'travel activity at the time of generation.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),

                SizedBox(height: 9),

                Text(
                  'Previously generated reports can be viewed '
                  'or exported again from Report History.',
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

  // ---------------------------------------------------------------------------
  // LOADING / ERROR / EMPTY STATE
  // ---------------------------------------------------------------------------

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String message,
    bool isLoading = false,
    double minimumHeight = 180,
    VoidCallback? onRetry,
  }) {
    return Container(
      width: double.infinity,

      constraints: BoxConstraints(minHeight: minimumHeight),

      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          _ReportIcon(icon: icon, size: 52),

          const SizedBox(height: 13),

          Text(
            title,
            textAlign: TextAlign.center,

            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            message,
            textAlign: TextAlign.center,

            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              height: 1.5,
            ),
          ),

          if (isLoading) ...[
            const SizedBox(height: 17),

            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ],

          if (onRetry != null) ...[
            const SizedBox(height: 15),

            OutlinedButton.icon(
              onPressed: onRetry,

              icon: const Icon(Icons.refresh_rounded, size: 18),

              label: const Text('Try Again'),

              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// REUSABLE REPORT ICON
// -----------------------------------------------------------------------------

class _ReportIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _ReportIcon({required this.icon, required this.size});

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
