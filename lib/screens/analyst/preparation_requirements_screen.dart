import 'package:flutter/material.dart';

import '../../services/analyst_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/analyst/analytics_filter_card.dart';

class PreparationRequirementsScreen extends StatefulWidget {
  const PreparationRequirementsScreen({super.key});

  @override
  State<PreparationRequirementsScreen> createState() =>
      _PreparationRequirementsScreenState();
}

class _PreparationRequirementsScreenState
    extends State<PreparationRequirementsScreen> {
  final AnalystService _analystService = AnalystService();

  String? _selectedDestinationId;
  String? _selectedPurpose;

  bool _showAllRequirements = false;

  // Cached Firestore analytics.
  Map<String, dynamic>? _analyticsData;

  // Track which filters produced the cached data.
  String? _loadedDestinationId;
  String? _loadedPurpose;

  List<Map<String, String>> _countries = [];

  bool _analyticsLoading = true;
  bool _analyticsError = false;

  bool _countriesLoading = true;
  bool _countriesError = false;

  // Prevent outdated requests from overwriting newer results.
  int _analyticsRequestVersion = 0;
  int _countriesRequestVersion = 0;

  @override
  void initState() {
    super.initState();

    _loadAnalytics();
    _loadCountries();
  }

  // ---------------------------------------------------------------------------
  // LOAD REQUIREMENT ANALYTICS
  // ---------------------------------------------------------------------------

  Future<void> _loadAnalytics() async {
    final int requestVersion = ++_analyticsRequestVersion;

    final String? requestedDestination = _selectedDestinationId;
    final String? requestedPurpose = _selectedPurpose;

    try {
      final Map<String, dynamic> data = await _analystService
          .getPreparationRequirementAnalytics(
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
      debugPrint('REQUIREMENT PATTERN ERROR: $error');

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

      // Do not discard already loaded results if refresh fails.
      if (hasCachedData) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to refresh requirement patterns. '
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
      debugPrint('REQUIREMENT FILTER COUNTRIES ERROR: $error');

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
  // RETRY HELPERS
  // ---------------------------------------------------------------------------

  void _retryAnalytics() {
    setState(() {
      _analyticsLoading = true;
      _analyticsError = false;
    });

    _loadAnalytics();
  }

  void _retryCountries() {
    setState(() {
      _countriesLoading = true;
      _countriesError = false;
    });

    _loadCountries();
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

      _showAllRequirements = false;
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

      _showAllRequirements = false;
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

      _showAllRequirements = false;
    });

    _loadAnalytics();
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
        _analyticsData != null &&
        _loadedDestinationId == _selectedDestinationId &&
        _loadedPurpose == _selectedPurpose;

    final Map<String, dynamic>? currentData = hasCurrentData
        ? _analyticsData
        : null;

    final int analysedTrips = _readInt(currentData?['analysedTrips']);

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,

        title: const Text(
          'Requirement Patterns',
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
              _buildHeader(
                analysedTrips: analysedTrips,
                hasData: hasCurrentData,
              ),

              const SizedBox(height: 26),

              _buildSectionTitle(
                'Filter Analytics',
                'Select a destination and travel purpose '
                    'to explore requirement generation patterns.',
              ),

              const SizedBox(height: 13),

              _buildFilters(),

              const SizedBox(height: 27),

              _buildPatternContent(currentData),
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

  Widget _buildHeader({required int analysedTrips, required bool hasData}) {
    String description;

    if (!hasData && _analyticsLoading) {
      description = 'Loading requirement pattern analytics...';
    } else if (!hasData && _analyticsError) {
      description = 'Requirement analytics are temporarily unavailable.';
    } else if (analysedTrips == 0) {
      description =
          'No generated requirements match '
          'the selected traveller segment.';
    } else {
      description =
          'Explore preparation requirements generated '
          'across $analysedTrips '
          '${analysedTrips == 1 ? 'trip' : 'trips'}.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const _RequirementIcon(icon: Icons.insights_outlined, size: 52),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Requirement Insights',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      description,
                      style: const TextStyle(
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
                Icons.fact_check_outlined,
                color: AppColors.primary,
                size: 19,
              ),

              SizedBox(width: 9),

              Expanded(
                child: Text(
                  'Identify frequently generated travel '
                  'requirements across traveller segments.',
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
  // FILTER CARD
  // ---------------------------------------------------------------------------

  Widget _buildFilters() {
    if (_countriesLoading && _countries.isEmpty) {
      return _buildStatusCard(
        icon: Icons.filter_alt_outlined,
        title: 'Loading Destinations',
        message: 'Retrieving available destination filters...',
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
        onRetry: _retryCountries,
      );
    }

    // Preserve the existing reusable analytics filter.
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
  // PATTERN CONTENT
  // ---------------------------------------------------------------------------

  Widget _buildPatternContent(Map<String, dynamic>? data) {
    if (data == null) {
      return _buildStatusCard(
        icon: _analyticsError
            ? Icons.cloud_off_outlined
            : Icons.insights_outlined,
        title: _analyticsError
            ? 'Unable to Load Patterns'
            : 'Loading Requirement Patterns',
        message: _analyticsError
            ? 'Requirement patterns could not be '
                  'retrieved. Please try again.'
            : 'Retrieving generated requirement '
                  'statistics for the selected filters...',
        isLoading: _analyticsLoading && !_analyticsError,
        minimumHeight: 290,
        onRetry: _analyticsError ? _retryAnalytics : null,
      );
    }

    final int analysedTrips = _readInt(data['analysedTrips']);

    final List<Map<String, dynamic>> requirements = _readList(
      data['requirementPatterns'],
    );

    return _buildPatternSection(
      requirements: requirements,
      analysedTrips: analysedTrips,
    );
  }

  // ---------------------------------------------------------------------------
  // REQUIREMENT PATTERNS SECTION
  // ---------------------------------------------------------------------------

  Widget _buildPatternSection({
    required List<Map<String, dynamic>> requirements,
    required int analysedTrips,
  }) {
    // Preserve the order returned by AnalystService.
    final List<Map<String, dynamic>> visibleRequirements = _showAllRequirements
        ? requirements
        : requirements.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildSectionTitle(
          'Commonly Generated Requirements',
          'Shows which preparation requirements occur '
              'most often within the selected traveller segment.',
        ),

        const SizedBox(height: 16),

        if (requirements.isEmpty)
          _buildStatusCard(
            icon: Icons.insights_outlined,
            title: 'No Requirement Patterns',
            message:
                'No requirement patterns are available '
                'for the selected filters.',
            minimumHeight: 190,
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
                  _buildRequirementRow(
                    rank: index + 1,
                    requirement: visibleRequirements[index],
                    analysedTrips: analysedTrips,
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

          if (requirements.length > 5) ...[
            const SizedBox(height: 11),

            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showAllRequirements = !_showAllRequirements;
                  });
                },

                icon: Icon(
                  _showAllRequirements
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),

                label: Text(
                  _showAllRequirements
                      ? 'Show Less'
                      : 'View All ${requirements.length}',
                ),

                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 17),

          _buildExplanationCard(),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // INDIVIDUAL REQUIREMENT ROW
  // ---------------------------------------------------------------------------

  Widget _buildRequirementRow({
    required int rank,
    required Map<String, dynamic> requirement,
    required int analysedTrips,
  }) {
    final String title =
        requirement['title'] as String? ?? 'Unnamed requirement';

    final int tripCount = _readInt(requirement['tripCount']);

    final double percentage = _readDouble(requirement['percentage']);

    final double progress = (percentage / 100).clamp(0.0, 1.0);

    final List<Map<String, dynamic>> destinationBreakdown = _readList(
      requirement['destinationBreakdown'],
    );

    final List<Map<String, dynamic>> purposeBreakdown = _readList(
      requirement['purposeBreakdown'],
    );

    return Padding(
      padding: const EdgeInsets.all(16),

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
                  title,
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
                '${percentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          Text(
            'Generated for $tripCount of $analysedTrips '
            '${analysedTrips == 1 ? 'trip' : 'trips'}',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
              height: 1.4,
            ),
          ),

          // Show destination breakdown when no destination
          // filter has been selected.
          if (_selectedDestinationId == null &&
              destinationBreakdown.isNotEmpty) ...[
            const SizedBox(height: 15),

            _buildBreakdownLabel(
              icon: Icons.public_outlined,
              label: 'Destinations',
            ),

            const SizedBox(height: 8),

            Wrap(
              spacing: 7,
              runSpacing: 7,

              children: destinationBreakdown.map((item) {
                final String name = item['name'] as String? ?? 'Unknown';

                final int count = _readInt(item['tripCount']);

                return _buildContextChip('$name · $count');
              }).toList(),
            ),
          ],

          // Show travel purpose breakdown when no purpose
          // filter has been selected.
          if (_selectedPurpose == null && purposeBreakdown.isNotEmpty) ...[
            const SizedBox(height: 13),

            _buildBreakdownLabel(
              icon: Icons.work_outline_rounded,
              label: 'Travel Purposes',
            ),

            const SizedBox(height: 8),

            Wrap(
              spacing: 7,
              runSpacing: 7,

              children: purposeBreakdown.map((item) {
                final String purpose = item['purpose'] as String? ?? '';

                final int count = _readInt(item['tripCount']);

                return _buildContextChip('${_formatPurpose(purpose)} · $count');
              }).toList(),
            ),
          ],
        ],
      ),
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
  // DESTINATION / PURPOSE CHIP
  // ---------------------------------------------------------------------------

  Widget _buildContextChip(String label) {
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
  // ANALYTICS EXPLANATION
  // ---------------------------------------------------------------------------

  Widget _buildExplanationCard() {
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
                  'Understanding Requirement Patterns',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                SizedBox(height: 7),

                Text(
                  'Requirement patterns describe the types '
                  'of preparation commonly generated for '
                  'different traveller groups.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),

                SizedBox(height: 9),

                Text(
                  'These patterns support analytical comparison '
                  'and do not indicate whether regulation content '
                  'is accurate or requires updating.',
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
          _RequirementIcon(icon: icon, size: 52),

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
// REUSABLE REQUIREMENT ICON
// -----------------------------------------------------------------------------

class _RequirementIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _RequirementIcon({required this.icon, required this.size});

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
