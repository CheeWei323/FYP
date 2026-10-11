import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/analyst_report_service.dart';
import '../../services/analyst_service.dart';
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

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

  String _selectedReportType = AnalystReportService.destinationTrends;

  String? _selectedDestinationId;
  String? _selectedPurpose;

  bool _isGenerating = false;

  late Future<List<Map<String, String>>> _countriesFuture;

  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();

    _countriesFuture = _analystService.getAnalyticsFilterCountries();

    _historyFuture = _reportService.getReportHistory();
  }

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

  Future<void> _refresh() async {
    final Future<List<Map<String, String>>> countries = _analystService
        .getAnalyticsFilterCountries();

    final Future<List<Map<String, dynamic>>> history = _reportService
        .getReportHistory();

    setState(() {
      _countriesFuture = countries;

      _historyFuture = history;
    });

    await countries;
    await history;
  }

  void _changeReportType(String? value) {
    if (value == null) {
      return;
    }

    setState(() {
      _selectedReportType = value;

      // Clear filters that are not applicable
      // to the newly selected report type.
      if (!_showDestinationFilter) {
        _selectedDestinationId = null;
      }

      if (!_showPurposeFilter) {
        _selectedPurpose = null;
      }
    });
  }

  Future<void> _generateReport() async {
    if (_isGenerating) {
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final Map<String, dynamic> report = await _reportService.generateReport(
        reportType: _selectedReportType,
        destinationId: _showDestinationFilter ? _selectedDestinationId : null,
        purpose: _showPurposeFilter ? _selectedPurpose : null,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _historyFuture = _reportService.getReportHistory();
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Report generated successfully.')),
        );

      await _reportService.exportReport(report);
    } catch (error) {
      debugPrint('GENERATE ANALYST REPORT ERROR: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Unable to generate report. Please try again.'),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _exportExcel(Map<String, dynamic> report) async {
    try {
      await _reportService.exportReport(report);
    } catch (error) {
      debugPrint('EXPORT ANALYST REPORT ERROR: $error');

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
    }
  }

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
    if (raw is! Timestamp) {
      return 'Recently generated';
    }

    final DateTime date = raw.toDate();

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}/'
        '${date.year} · '
        '${twoDigits(date.hour)}:'
        '${twoDigits(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _backgroundColor,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
            children: [
              _buildHeader(),

              const SizedBox(height: 26),

              const Text(
                'Generate Report',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _darkTextColor,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Export aggregated analytics as an Excel report.',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),

              const SizedBox(height: 14),

              _buildGenerator(),

              const SizedBox(height: 30),

              const Text(
                'Report History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _darkTextColor,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Previously generated report snapshots.',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),

              const SizedBox(height: 14),

              _buildHistory(),
            ],
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBE8EB)),
      ),
      child: const Row(
        children: [
          Icon(Icons.description_outlined, color: _primaryColor, size: 32),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analytics Reports',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Generate and access historical '
                  'aggregated analytics reports.',
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

  Widget _buildGenerator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedReportType,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Report Type',
              prefixIcon: const Icon(Icons.analytics_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
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
            onChanged: _changeReportType,
          ),

          if (_showDestinationFilter || _showPurposeFilter) ...[
            const SizedBox(height: 14),

            FutureBuilder<List<Map<String, String>>>(
              future: _countriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                return AnalyticsFilterCard(
                  countries: snapshot.data ?? [],
                  selectedDestinationId: _selectedDestinationId,
                  selectedPurpose: _selectedPurpose,
                  showDestination: _showDestinationFilter,
                  showPurpose: _showPurposeFilter,
                  onDestinationChanged: (value) {
                    setState(() {
                      _selectedDestinationId = value;
                    });
                  },
                  onPurposeChanged: (value) {
                    setState(() {
                      _selectedPurpose = value;
                    });
                  },
                  onClear: () {
                    setState(() {
                      _selectedDestinationId = null;

                      _selectedPurpose = null;
                    });
                  },
                );
              },
            ),
          ],

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
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
                  : const Icon(Icons.file_download_outlined),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _isGenerating ? 'Generating...' : 'Generate & Export Excel',
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _buildHistoryError();
        }

        final List<Map<String, dynamic>> reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return _buildEmptyHistory();
        }

        return Column(
          children: [
            for (int index = 0; index < reports.length; index++) ...[
              _buildReportCard(reports[index]),

              if (index != reports.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  void _viewReport(Map<String, dynamic> report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalystReportDetailsScreen(report: report),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final String destination =
        report['destinationName'] as String? ?? 'All Destinations';

    final String purpose = report['purposeLabel'] as String? ?? 'All Purposes';

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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.table_chart_outlined,
                  color: _primaryColor,
                  size: 21,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report['reportTitle'] as String? ?? 'Analytics Report',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _darkTextColor,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _formatDate(report['generatedAt']),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildChip(destination),
              _buildChip(purpose),
              _buildChip('Excel'),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    _viewReport(report);
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('View Report', maxLines: 1, softWrap: false),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    _exportExcel(report);
                  },
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Export Excel', maxLines: 1, softWrap: false),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9.5,
          color: Color(0xFF486581),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 42,
            color: Colors.black38,
          ),
          SizedBox(height: 12),
          Text(
            'No reports generated yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _darkTextColor,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Generated analytics reports will '
            'appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.black45,
            size: 36,
          ),
          const SizedBox(height: 8),
          const Text('Unable to load report history.'),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _historyFuture = _reportService.getReportHistory();
              });
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
