import 'package:flutter/material.dart';

import '../../services/analyst_service.dart';
import '../../widgets/analyst/analytics_filter_card.dart';

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

  static const Color _comparisonBarColor = Color(0xFF2F5F98);

  String? _selectedDestinationId;
  String? _selectedPurpose;

  String _comparisonMode = 'destination';

  bool _showAllAttentionRequirements = false;

  late Future<Map<String, dynamic>> _analyticsFuture;

  late Future<List<Map<String, String>>> _countriesFuture;

  @override
  void initState() {
    super.initState();

    _analyticsFuture = _analystService.getChecklistCompletionAnalytics();

    _countriesFuture = _analystService.getAnalyticsFilterCountries();
  }

  void _reloadAnalytics() {
    _analyticsFuture = _analystService.getChecklistCompletionAnalytics(
      destinationId: _selectedDestinationId,
      purpose: _selectedPurpose,
    );
  }

  Future<void> _refresh() async {
    final Future<Map<String, dynamic>> analyticsFuture = _analystService
        .getChecklistCompletionAnalytics(
          destinationId: _selectedDestinationId,
          purpose: _selectedPurpose,
        );

    final Future<List<Map<String, String>>> countriesFuture = _analystService
        .getAnalyticsFilterCountries();

    setState(() {
      _analyticsFuture = analyticsFuture;

      _countriesFuture = countriesFuture;
    });

    await analyticsFuture;
    await countriesFuture;
  }

  Widget _buildFilters() {
    return FutureBuilder<List<Map<String, String>>>(
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

        final List<Map<String, String>> countries = snapshot.data ?? [];

        return AnalyticsFilterCard(
          countries: countries,
          selectedDestinationId: _selectedDestinationId,
          selectedPurpose: _selectedPurpose,

          onDestinationChanged: (value) {
            setState(() {
              _selectedDestinationId = value;

              _showAllAttentionRequirements = false;

              _syncComparisonMode();

              _reloadAnalytics();
            });
          },

          onPurposeChanged: (value) {
            setState(() {
              _selectedPurpose = value;

              _showAllAttentionRequirements = false;

              _syncComparisonMode();

              _reloadAnalytics();
            });
          },

          onClear: () {
            setState(() {
              _selectedDestinationId = null;
              _selectedPurpose = null;

              _showAllAttentionRequirements = false;

              _syncComparisonMode();

              _reloadAnalytics();
            });
          },
        );
      },
    );
  }

  String _formatPurpose(String purpose) {
    switch (purpose) {
      case 'tourism':
        return 'Tourism';

      case 'business':
        return 'Business';

      case 'study':
        return 'Study';

      default:
        if (purpose.isEmpty) {
          return 'Unknown';
        }

        return '${purpose[0].toUpperCase()}'
            '${purpose.substring(1)}';
    }
  }

  bool get _hasDestinationFilter => _selectedDestinationId != null;

  bool get _hasPurposeFilter => _selectedPurpose != null;

  bool get _bothFiltersSelected => _hasDestinationFilter && _hasPurposeFilter;

  bool get _showComparisonSelector =>
      !_hasDestinationFilter && !_hasPurposeFilter;

  void _syncComparisonMode() {
    // If a destination is fixed, compare purposes
    // within that selected destination.
    if (_hasDestinationFilter && !_hasPurposeFilter) {
      _comparisonMode = 'purpose';
      return;
    }

    // If a purpose is fixed, compare destinations
    // within that selected purpose.
    if (!_hasDestinationFilter && _hasPurposeFilter) {
      _comparisonMode = 'destination';
      return;
    }

    // If both filters are cleared, return to the
    // default destination comparison.
    if (!_hasDestinationFilter && !_hasPurposeFilter) {
      _comparisonMode = 'destination';
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

              final double overallCompletionRate =
                  data['overallCompletionRate'] as double? ?? 0;

              final int completedItems =
                  data['completedChecklistItems'] as int? ?? 0;

              final int incompleteItems =
                  data['incompleteChecklistItems'] as int? ?? 0;

              final int tripsWithChecklist =
                  data['tripsWithChecklist'] as int? ?? 0;

              final List<Map<String, dynamic>> destinationComparison =
                  List<Map<String, dynamic>>.from(
                    data['destinationComparison'] as List? ?? [],
                  );

              final List<Map<String, dynamic>> purposeComparison =
                  List<Map<String, dynamic>>.from(
                    data['purposeComparison'] as List? ?? [],
                  );

              final List<Map<String, dynamic>> attentionRequirements =
                  List<Map<String, dynamic>>.from(
                    data['requirementsNeedingAttention'] as List? ?? [],
                  );

              final List<Map<String, dynamic>> comparisonData =
                  _comparisonMode == 'destination'
                  ? destinationComparison
                  : purposeComparison;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                children: [
                  _buildHeader(),

                  const SizedBox(height: 18),

                  _buildFilters(),

                  const SizedBox(height: 24),

                  _buildOverallCompletionCard(
                    completionRate: overallCompletionRate,
                    completedItems: completedItems,
                    incompleteItems: incompleteItems,
                    tripCount: tripsWithChecklist,
                  ),

                  const SizedBox(height: 28),

                  if (!_bothFiltersSelected) ...[
                    _buildComparisonSection(data: comparisonData),

                    const SizedBox(height: 28),
                  ],

                  _buildAttentionSection(requirements: attentionRequirements),
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
                  'Understand how well travellers '
                  'complete their preparation guidance.',
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

  // ---------------------------------------------------------------------------
  // OVERALL COMPLETION
  // ---------------------------------------------------------------------------

  Widget _buildOverallCompletionCard({
    required double completionRate,
    required int completedItems,
    required int incompleteItems,
    required int tripCount,
  }) {
    final double progress = (completionRate / 100).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Overall Preparation Completion',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _darkTextColor,
              ),
            ),
          ),

          const SizedBox(height: 4),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              tripCount == 0
                  ? 'No checklist data is available for the selected filters.'
                  : 'Average completion across $tripCount '
                        '${tripCount == 1 ? 'trip' : 'trips'} '
                        'with generated checklists.',
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: Colors.black54,
              ),
            ),
          ),

          const SizedBox(height: 18),

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
                      '${completionRate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: _darkTextColor,
                      ),
                    ),

                    const SizedBox(height: 2),

                    const Text(
                      'Average completion',
                      style: TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildSupportingStat(
                  icon: Icons.check_circle_outline,
                  label: 'Completed',
                  value: completedItems,
                ),
              ),

              Container(width: 1, height: 38, color: _borderColor),

              Expanded(
                child: _buildSupportingStat(
                  icon: Icons.pending_actions_outlined,
                  label: 'Incomplete',
                  value: incompleteItems,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: Colors.black45,
                ),

                SizedBox(width: 7),

                Expanded(
                  child: Text(
                    'Completion indicates how much of the '
                    'generated preparation checklist travellers '
                    'have marked as completed.',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.4,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportingStat({
    required IconData icon,
    required String label,
    required int value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 19, color: _primaryColor),

        const SizedBox(height: 5),

        Text(
          '$value',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _darkTextColor,
          ),
        ),

        const SizedBox(height: 2),

        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // DESTINATION / PURPOSE COMPARISON
  // ---------------------------------------------------------------------------

  Widget _buildComparisonSection({required List<Map<String, dynamic>> data}) {
    String title;
    String description;

    if (_hasDestinationFilter && !_hasPurposeFilter) {
      title = 'Completion by Purpose';

      description =
          'Compare average checklist completion across '
          'travel purposes for the selected destination.';
    } else if (!_hasDestinationFilter && _hasPurposeFilter) {
      title = 'Completion by Destination';

      description =
          'Compare average checklist completion across '
          'destinations for the selected travel purpose.';
    } else {
      title = 'Completion Comparison';

      description =
          'Compare average checklist completion by '
          'destination or travel purpose.';
    }

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
            fontSize: 12.5,
            height: 1.4,
            color: Colors.black54,
          ),
        ),

        // Only show the switch when neither
        // analytical dimension is fixed.
        if (_showComparisonSelector) ...[
          const SizedBox(height: 14),

          _buildComparisonSelector(),
        ],

        const SizedBox(height: 14),

        if (data.isEmpty)
          _buildEmptyComparison()
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              children: [
                for (int index = 0; index < data.length; index++) ...[
                  _buildComparisonRow(data[index]),

                  if (index != data.length - 1) const SizedBox(height: 18),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildComparisonSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0F3),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildComparisonOption(
              value: 'destination',
              label: 'Destination',
              icon: Icons.public_outlined,
            ),
          ),

          Expanded(
            child: _buildComparisonOption(
              value: 'purpose',
              label: 'Purpose',
              icon: Icons.work_outline_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonOption({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final bool selected = _comparisonMode == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _comparisonMode = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? _primaryColor : Colors.black45,
              ),

              const SizedBox(width: 6),

              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? _darkTextColor : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonRow(Map<String, dynamic> item) {
    final String label = _comparisonMode == 'destination'
        ? item['name'] as String? ?? 'Unknown'
        : _formatPurpose(item['purpose'] as String? ?? '');

    final int tripCount = item['tripCount'] as int? ?? 0;

    final double rate = item['completionRate'] as double? ?? 0;

    final double progress = (rate / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _darkTextColor,
                ),
              ),
            ),

            Text(
              '${rate.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _primaryColor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 7),

        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor: const Color(0xFFEAF0F3),
            color: _comparisonBarColor,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          '$tripCount '
          '${tripCount == 1 ? 'trip' : 'trips'} included',
          style: const TextStyle(fontSize: 10, color: Colors.black45),
        ),
      ],
    );
  }

  Widget _buildEmptyComparison() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 34, color: Colors.black38),

          SizedBox(height: 8),

          Text(
            'No completion comparison data is available '
            'for the selected filters.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REQUIREMENTS FOR FURTHER INVESTIGATION
  // ---------------------------------------------------------------------------

  Widget _buildAttentionSection({
    required List<Map<String, dynamic>> requirements,
  }) {
    final List<Map<String, dynamic>> visibleRequirements =
        _showAllAttentionRequirements
        ? requirements
        : requirements.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Requirements for Further Investigation',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _darkTextColor,
          ),
        ),

        const SizedBox(height: 5),

        const Text(
          'Requirements with lower completion highlight '
          'patterns that may warrant further investigation. ',
          style: TextStyle(fontSize: 12.5, height: 1.4, color: Colors.black54),
        ),

        const SizedBox(height: 6),

        const Text(
          'Completion rate alone does not prove that '
          'the guidance is inadequate.',
          style: TextStyle(
            fontSize: 10.5,
            fontStyle: FontStyle.italic,
            color: Colors.black45,
          ),
        ),

        const SizedBox(height: 14),

        if (requirements.isEmpty)
          _buildNoAttentionRequired()
        else ...[
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              children: [
                for (
                  int index = 0;
                  index < visibleRequirements.length;
                  index++
                ) ...[
                  _buildAttentionRequirement(
                    rank: index + 1,
                    requirement: visibleRequirements[index],
                  ),

                  if (index != visibleRequirements.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),

          if (requirements.length > 3) ...[
            const SizedBox(height: 10),

            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showAllAttentionRequirements =
                        !_showAllAttentionRequirements;
                  });
                },
                icon: Icon(
                  _showAllAttentionRequirements
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
                label: Text(
                  _showAllAttentionRequirements
                      ? 'Show less'
                      : 'View all ${requirements.length}',
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildAttentionRequirement({
    required int rank,
    required Map<String, dynamic> requirement,
  }) {
    final String title =
        requirement['title'] as String? ?? 'Unnamed requirement';

    final int generated = requirement['generated'] as int? ?? 0;

    final int completed = requirement['completed'] as int? ?? 0;

    final int incomplete = requirement['incomplete'] as int? ?? 0;

    final double completionRate = requirement['completionRate'] as double? ?? 0;

    final double progress = (completionRate / 100).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F7),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _primaryColor,
              ),
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _darkTextColor,
                  ),
                ),

                const SizedBox(height: 7),

                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          backgroundColor: const Color(0xFFEAF0F3),
                          color: _primaryColor,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Text(
                      '${completionRate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 7),

                Text(
                  '$completed of $generated completed · '
                  '$incomplete incomplete',
                  style: const TextStyle(fontSize: 10.5, color: Colors.black54),
                ),

                const SizedBox(height: 3),

                Text(
                  'Based on $generated generated '
                  '${generated == 1 ? 'instance' : 'instances'}',
                  style: const TextStyle(fontSize: 9.5, color: Colors.black38),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAttentionRequired() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 36,
            color: _primaryColor,
          ),

          SizedBox(height: 8),

          Text(
            'No incomplete requirements were found '
            'for the selected filters.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
