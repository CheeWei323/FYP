import 'package:flutter/material.dart';

import '../../services/analyst_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/analyst/analytics_filter_card.dart';

class ChecklistCompletionScreen extends StatefulWidget {
  const ChecklistCompletionScreen({super.key});

  @override
  State<ChecklistCompletionScreen> createState() =>
      _ChecklistCompletionScreenState();
}

class _ChecklistCompletionScreenState extends State<ChecklistCompletionScreen> {
  final AnalystService _analystService = AnalystService();

  String? _selectedDestinationId;
  String? _selectedPurpose;

  String _comparisonMode = 'destination';

  bool _showAllAttentionRequirements = false;

  // Cached Firestore analytics.
  Map<String, dynamic>? _analyticsData;

  String? _loadedDestinationId;
  String? _loadedPurpose;

  List<Map<String, String>> _countries = [];

  bool _analyticsLoading = true;
  bool _analyticsError = false;

  bool _countriesLoading = true;
  bool _countriesError = false;

  // Prevent outdated requests from replacing newer results.
  int _analyticsRequestVersion = 0;
  int _countriesRequestVersion = 0;

  @override
  void initState() {
    super.initState();

    _loadAnalytics();
    _loadCountries();
  }

  // ---------------------------------------------------------------------------
  // LOAD CHECKLIST ANALYTICS
  // ---------------------------------------------------------------------------

  Future<void> _loadAnalytics() async {
    final int requestVersion = ++_analyticsRequestVersion;

    final String? requestedDestination = _selectedDestinationId;
    final String? requestedPurpose = _selectedPurpose;

    try {
      final Map<String, dynamic> data = await _analystService
          .getChecklistCompletionAnalytics(
            destinationId: requestedDestination,
            purpose: requestedPurpose,
          );

      if (!mounted || requestVersion != _analyticsRequestVersion) {
        return;
      }

      setState(() {
        _analyticsData = data;

        _loadedDestinationId = requestedDestination;
        _loadedPurpose = requestedPurpose;

        _analyticsLoading = false;
        _analyticsError = false;
      });
    } catch (error) {
      debugPrint('CHECKLIST ANALYTICS ERROR: $error');

      if (!mounted || requestVersion != _analyticsRequestVersion) {
        return;
      }

      final bool hasCachedData =
          _analyticsData != null &&
          _loadedDestinationId == requestedDestination &&
          _loadedPurpose == requestedPurpose;

      setState(() {
        _analyticsLoading = false;
        _analyticsError = true;
      });

      // Preserve existing analytics if a refresh fails.
      if (hasCachedData) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to refresh checklist analytics. '
              'Showing the previously loaded data.',
            ),
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // LOAD FILTER DESTINATIONS
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
      debugPrint('CHECKLIST FILTER COUNTRIES ERROR: $error');

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
    await Future.wait<void>([_loadAnalytics(), _loadCountries()]);
  }

  // ---------------------------------------------------------------------------
  // FILTER HANDLING
  // ---------------------------------------------------------------------------

  void _changeDestination(String? destinationId) {
    if (_selectedDestinationId == destinationId) {
      return;
    }

    setState(() {
      _selectedDestinationId = destinationId;

      _analyticsLoading = true;
      _analyticsError = false;

      _showAllAttentionRequirements = false;

      _syncComparisonMode();
    });

    _loadAnalytics();
  }

  void _changePurpose(String? purpose) {
    if (_selectedPurpose == purpose) {
      return;
    }

    setState(() {
      _selectedPurpose = purpose;

      _analyticsLoading = true;
      _analyticsError = false;

      _showAllAttentionRequirements = false;

      _syncComparisonMode();
    });

    _loadAnalytics();
  }

  void _clearFilters() {
    if (_selectedDestinationId == null && _selectedPurpose == null) {
      return;
    }

    setState(() {
      _selectedDestinationId = null;
      _selectedPurpose = null;

      _analyticsLoading = true;
      _analyticsError = false;

      _showAllAttentionRequirements = false;

      _syncComparisonMode();
    });

    _loadAnalytics();
  }

  // ---------------------------------------------------------------------------
  // COMPARISON MODE
  // ---------------------------------------------------------------------------

  bool get _hasDestinationFilter => _selectedDestinationId != null;

  bool get _hasPurposeFilter => _selectedPurpose != null;

  bool get _bothFiltersSelected => _hasDestinationFilter && _hasPurposeFilter;

  bool get _showComparisonSelector =>
      !_hasDestinationFilter && !_hasPurposeFilter;

  void _syncComparisonMode() {
    // A fixed destination means comparing travel purposes.
    if (_hasDestinationFilter && !_hasPurposeFilter) {
      _comparisonMode = 'purpose';
      return;
    }

    // A fixed purpose means comparing destinations.
    if (!_hasDestinationFilter && _hasPurposeFilter) {
      _comparisonMode = 'destination';
      return;
    }

    // Default to comparing destinations.
    if (!_hasDestinationFilter && !_hasPurposeFilter) {
      _comparisonMode = 'destination';
    }
  }

  // ---------------------------------------------------------------------------
  // DATA HELPERS
  // ---------------------------------------------------------------------------

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

  List<Map<String, dynamic>> _readList(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
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

  // ---------------------------------------------------------------------------
  // CARD DECORATION
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
        _analyticsData != null &&
        _loadedDestinationId == _selectedDestinationId &&
        _loadedPurpose == _selectedPurpose;

    final Map<String, dynamic>? currentData = hasCurrentData
        ? _analyticsData
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,

        title: const Text(
          'Checklist Completion',
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

              const SizedBox(height: 26),

              _buildSectionTitle(
                'Filter Analytics',
                'Select a destination and travel purpose '
                    'to explore checklist completion.',
              ),

              const SizedBox(height: 13),

              _buildFilters(),

              const SizedBox(height: 27),

              _buildAnalyticsContent(currentData),
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
              _ChecklistIcon(icon: Icons.task_alt_outlined, size: 52),

              SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Checklist Insights',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    SizedBox(height: 7),

                    Text(
                      'Understand how travellers complete '
                      'their generated travel preparation '
                      'requirements.',
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
                Icons.analytics_outlined,
                color: AppColors.primary,
                size: 19,
              ),

              SizedBox(width: 9),

              Expanded(
                child: Text(
                  'Compare completion rates across '
                  'destinations, travel purposes and '
                  'individual requirements.',
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
  // ANALYTICS FILTERS
  // ---------------------------------------------------------------------------

  Widget _buildFilters() {
    if (_countriesLoading && _countries.isEmpty) {
      return _buildStatusCard(
        icon: Icons.filter_alt_outlined,
        title: 'Loading Filters',
        message: 'Retrieving supported destination filters...',
        isLoading: true,
        minimumHeight: 160,
      );
    }

    if (_countriesError && _countries.isEmpty) {
      return _buildStatusCard(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to Load Filters',
        message: 'Destination filters could not be retrieved.',
        minimumHeight: 160,
        onRetry: _loadCountries,
      );
    }

    // Keep the existing reusable destination/purpose filter.
    return AnalyticsFilterCard(
      countries: _countries,
      selectedDestinationId: _selectedDestinationId,
      selectedPurpose: _selectedPurpose,
      onDestinationChanged: _changeDestination,
      onPurposeChanged: _changePurpose,
      onClear: _clearFilters,
    );
  }

  // ---------------------------------------------------------------------------
  // ANALYTICS CONTENT
  // ---------------------------------------------------------------------------

  Widget _buildAnalyticsContent(Map<String, dynamic>? data) {
    if (data == null) {
      return _buildStatusCard(
        icon: _analyticsError
            ? Icons.cloud_off_outlined
            : Icons.analytics_outlined,
        title: _analyticsError
            ? 'Unable to Load Analytics'
            : 'Loading Checklist Analytics',
        message: _analyticsError
            ? 'Checklist completion statistics could not '
                  'be retrieved. Please try again.'
            : 'Retrieving checklist completion statistics '
                  'for the selected filters...',
        isLoading: _analyticsLoading && !_analyticsError,
        minimumHeight: 300,
        onRetry: _analyticsError ? _loadAnalytics : null,
      );
    }

    final double overallCompletionRate = _readDouble(
      data['overallCompletionRate'],
    );

    final int completedItems = _readInt(data['completedChecklistItems']);

    final int incompleteItems = _readInt(data['incompleteChecklistItems']);

    final int tripsWithChecklist = _readInt(data['tripsWithChecklist']);

    final List<Map<String, dynamic>> destinationComparison = _readList(
      data['destinationComparison'],
    );

    final List<Map<String, dynamic>> purposeComparison = _readList(
      data['purposeComparison'],
    );

    final List<Map<String, dynamic>> attentionRequirements = _readList(
      data['requirementsNeedingAttention'],
    );

    final List<Map<String, dynamic>> comparisonData =
        _comparisonMode == 'destination'
        ? destinationComparison
        : purposeComparison;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildOverallCompletionCard(
          completionRate: overallCompletionRate,
          completedItems: completedItems,
          incompleteItems: incompleteItems,
          tripCount: tripsWithChecklist,
        ),

        const SizedBox(height: 28),

        // Comparison is hidden when both dimensions
        // are already fixed by the selected filters.
        if (!_bothFiltersSelected) ...[
          _buildComparisonSection(data: comparisonData),

          const SizedBox(height: 28),
        ],

        _buildAttentionSection(requirements: attentionRequirements),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // OVERALL COMPLETION CARD
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

      padding: const EdgeInsets.fromLTRB(19, 20, 19, 18),

      decoration: _cardDecoration(),

      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Overall Preparation Completion',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              Icon(
                Icons.donut_large_outlined,
                color: AppColors.primary,
                size: 23,
              ),
            ],
          ),

          const SizedBox(height: 6),

          Align(
            alignment: Alignment.centerLeft,

            child: Text(
              tripCount == 0
                  ? 'No checklist data is available '
                        'for the selected filters.'
                  : 'Average completion across $tripCount '
                        '${tripCount == 1 ? 'trip' : 'trips'} '
                        'with generated checklists.',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: 174,
            height: 174,

            child: Stack(
              alignment: Alignment.center,

              children: [
                SizedBox(
                  width: 154,
                  height: 154,

                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 18,
                    backgroundColor: AppColors.primaryLight,
                    color: AppColors.primary,
                    strokeCap: StrokeCap.butt,
                  ),
                ),

                Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Text(
                      '${completionRate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 3),

                    const Text(
                      'Average completion',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 7),

            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),

            child: Row(
              children: [
                Expanded(
                  child: _buildSupportingStat(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Completed',
                    value: completedItems,
                  ),
                ),

                Container(width: 1, height: 46, color: AppColors.border),

                Expanded(
                  child: _buildSupportingStat(
                    icon: Icons.pending_actions_outlined,
                    label: 'Incomplete',
                    value: incompleteItems,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),

            decoration: BoxDecoration(
              color: const Color(0xFFF1F6FA),
              borderRadius: BorderRadius.circular(13),
            ),

            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),

                SizedBox(width: 9),

                Expanded(
                  child: Text(
                    'Completion indicates how much of '
                    'the generated preparation checklist '
                    'travellers have marked as completed.',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                      height: 1.45,
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

  // ---------------------------------------------------------------------------
  // SUPPORTING STATISTIC
  // ---------------------------------------------------------------------------

  Widget _buildSupportingStat({
    required IconData icon,
    required String label,
    required int value,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 21),

        const SizedBox(height: 6),

        Text(
          '$value',
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          label,
          style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // COMPLETION COMPARISON
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
        _buildSectionTitle(title, description),

        if (_showComparisonSelector) ...[
          const SizedBox(height: 15),

          _buildComparisonSelector(),
        ],

        const SizedBox(height: 15),

        if (data.isEmpty)
          _buildStatusCard(
            icon: Icons.bar_chart_rounded,
            title: 'No Comparison Data',
            message:
                'No completion comparison data is available '
                'for the selected filters.',
            minimumHeight: 175,
          )
        else
          _buildComparisonChart(data),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // COMPARISON SELECTOR
  // ---------------------------------------------------------------------------

  Widget _buildComparisonSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),

      decoration: BoxDecoration(
        color: const Color(0xFFEAF0F3),
        borderRadius: BorderRadius.circular(14),
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
        borderRadius: BorderRadius.circular(11),

        onTap: () {
          if (_comparisonMode == value) {
            return;
          }

          setState(() {
            _comparisonMode = value;
          });
        },

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),

          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),

          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),

            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x10000000),
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
                color: selected ? AppColors.primary : AppColors.secondaryText,
              ),

              const SizedBox(width: 7),

              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.navy : AppColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COMPARISON CHART
  // ---------------------------------------------------------------------------

  Widget _buildComparisonChart(List<Map<String, dynamic>> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),

      child: Column(
        children: [
          for (int index = 0; index < data.length; index++) ...[
            _buildComparisonRow(data[index]),

            if (index != data.length - 1) const SizedBox(height: 21),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COMPARISON ROW
  // ---------------------------------------------------------------------------

  Widget _buildComparisonRow(Map<String, dynamic> item) {
    final String label = _comparisonMode == 'destination'
        ? item['name'] as String? ?? 'Unknown'
        : _formatPurpose(item['purpose'] as String? ?? '');

    final int tripCount = _readInt(item['tripCount']);

    final double rate = _readDouble(item['completionRate']);

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
                  color: AppColors.navy,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(width: 10),

            Text(
              '${rate.toStringAsFixed(1)}%',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
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
            backgroundColor: AppColors.primaryLight,
            color: AppColors.primary,
          ),
        ),

        const SizedBox(height: 7),

        Text(
          '$tripCount '
          '${tripCount == 1 ? 'trip' : 'trips'} included',
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 10.5,
          ),
        ),
      ],
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
        _buildSectionTitle(
          'Requirements for Further Investigation',
          'Requirements with lower completion highlight '
              'patterns that may warrant further investigation.',
        ),

        const SizedBox(height: 10),

        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: AppColors.secondaryText,
            ),

            SizedBox(width: 7),

            Expanded(
              child: Text(
                'Completion rate alone does not prove '
                'that the guidance is inadequate.',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 11,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        if (requirements.isEmpty)
          _buildStatusCard(
            icon: Icons.check_circle_outline_rounded,
            title: 'No Requirements Identified',
            message:
                'No requirements needing further investigation '
                'were returned for the selected filters.',
            minimumHeight: 175,
          )
        else ...[
          Container(
            width: double.infinity,
            decoration: _cardDecoration(),

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
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppColors.border,
                    ),
                ],
              ],
            ),
          ),

          if (requirements.length > 3) ...[
            const SizedBox(height: 11),

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
                      ? 'Show Less'
                      : 'View All ${requirements.length}',
                ),

                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // REQUIREMENT ITEM
  // ---------------------------------------------------------------------------

  Widget _buildAttentionRequirement({
    required int rank,
    required Map<String, dynamic> requirement,
  }) {
    final String title =
        requirement['title'] as String? ?? 'Unnamed requirement';

    final int generated = _readInt(requirement['generated']);

    final int completed = _readInt(requirement['completed']);

    final int incomplete = _readInt(requirement['incomplete']);

    final double completionRate = _readDouble(requirement['completionRate']);

    final double progress = (completionRate / 100).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.all(16),

      child: Row(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 9),

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
                      '${completionRate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 9),

                Text(
                  '$completed of $generated completed · '
                  '$incomplete incomplete',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Based on $generated generated '
                  '${generated == 1 ? 'instance' : 'instances'}',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 10,
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
          _ChecklistIcon(icon: icon, size: 52),

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
// REUSABLE CHECKLIST ICON
// -----------------------------------------------------------------------------

class _ChecklistIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _ChecklistIcon({required this.icon, required this.size});

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
