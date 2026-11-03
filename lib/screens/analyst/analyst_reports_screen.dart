import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/analyst_report_service.dart';
import '../../services/analyst_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/role_ui_widgets.dart';
import '../../widgets/analyst/analytics_filter_card.dart';
import 'analyst_report_details_screen.dart';

class AnalystReportsScreen extends StatefulWidget {
  final int reloadVersion;

  const AnalystReportsScreen({super.key, this.reloadVersion = 0});

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
  String? _exportingReportId;

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

  // Refresh history when returning to Reports without discarding the filters.
  @override
  void didUpdateWidget(covariant AnalystReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reloadVersion != oldWidget.reloadVersion) _loadHistory();
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
    if (_isGenerating || _exportingReportId != null) {
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
    if (_isGenerating || _exportingReportId != null) return;
    setState(() {
      _exportingReportId = report['reportId']?.toString() ?? '';
    });
    try {
      // Export the saved report snapshot through the existing Excel service.
      await _reportService.exportReport(report);
    } catch (_) {
      if (mounted) _showMessage('Unable to export report. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _exportingReportId = null;
        });
      }
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
    return RolePageBody(
      storageId: 'analyst-reports',
      onRefresh: _refresh,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        _buildSectionTitle(
          'Generate report',
          'Choose a report type and the relevant filters.',
        ),
        const SizedBox(height: 12),
        _buildGenerator(),
        const SizedBox(height: 24),
        _buildSectionTitle(
          'Report history',
          'Saved snapshots generated by your account.',
        ),
        const SizedBox(height: 12),
        _buildHistory(),
        const SizedBox(height: 24),
        _buildInformationCard(),
      ],
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
      title: "Your analytics reports",
      description:
          "Generate an Excel report or reopen a saved snapshot of aggregated travel data.",
      icon: Icons.description_outlined,
    );
  }

  // ---------------------------------------------------------------------------
  // GENERATE REPORT CARD
  // ---------------------------------------------------------------------------

  Widget _buildGenerator() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Report configuration',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey(_selectedReportType),
            initialValue: _selectedReportType,
            isExpanded: true,
            itemHeight: null,
            decoration: const InputDecoration(
              labelText: 'Report type',
              prefixIcon: Icon(Icons.analytics_outlined),
            ),
            items:
                [
                      AnalystReportService.destinationTrends,
                      AnalystReportService.purposeDistribution,
                      AnalystReportService.checklistCompletion,
                      AnalystReportService.requirementPatterns,
                    ]
                    .map(
                      (type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(_reportTypeLabel(type)),
                      ),
                    )
                    .toList(),
            onChanged: _isGenerating || _exportingReportId != null
                ? null
                : _changeReportType,
          ),
          if (_showDestinationFilter || _showPurposeFilter) ...[
            const SizedBox(height: 18),
            const Text(
              'Filters are optional and depend on the selected report type.',
            ),
            const SizedBox(height: 12),
            _buildFilters(),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isGenerating || _exportingReportId != null
                ? null
                : _generateReport,
            icon: _isGenerating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.file_download_outlined),
            label: Text(
              _isGenerating
                  ? 'Generating report...'
                  : 'Generate & export Excel',
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
      enabled: !_isGenerating && _exportingReportId == null,
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
    final id = report['reportId']?.toString() ?? '';
    final busy = _isGenerating || _exportingReportId != null;
    final exporting = _exportingReportId == id;
    return Container(
      key: ValueKey('saved-report-$id'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            report['reportTitle'] as String? ?? 'Analytics report',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDate(report['generatedAt']),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RoleBadge(
                label:
                    report['destinationName'] as String? ?? 'All destinations',
              ),
              RoleBadge(
                label: report['purposeLabel'] as String? ?? 'All purposes',
              ),
              const RoleBadge(label: 'Excel · .xlsx'),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : () => _viewReport(report),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('View report'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : () => _exportExcel(report),
                icon: exporting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.file_download_outlined),
                label: Text(exporting ? 'Exporting...' : 'Export Excel'),
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

  // ---------------------------------------------------------------------------
  // REPORT INFORMATION CARD
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
// REUSABLE REPORT ICON
// -----------------------------------------------------------------------------
