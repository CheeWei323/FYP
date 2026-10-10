import 'package:flutter/material.dart';

import '../../services/analyst_service.dart';
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

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

  String? _selectedDestinationId;
  String? _selectedPurpose;

  bool _showAllRequirements = false;

  late Future<Map<String, dynamic>> _analyticsFuture;

  late Future<List<Map<String, String>>> _countriesFuture;

  @override
  void initState() {
    super.initState();

    _analyticsFuture = _analystService.getPreparationRequirementAnalytics();

    _countriesFuture = _analystService.getAnalyticsFilterCountries();
  }

  void _reloadAnalytics() {
    _analyticsFuture = _analystService.getPreparationRequirementAnalytics(
      destinationId: _selectedDestinationId,
      purpose: _selectedPurpose,
    );
  }

  Future<void> _refresh() async {
    final Future<Map<String, dynamic>> analyticsFuture = _analystService
        .getPreparationRequirementAnalytics(
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
  // FILTERS
  // ---------------------------------------------------------------------------

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

              _showAllRequirements = false;

              _reloadAnalytics();
            });
          },
          onPurposeChanged: (value) {
            setState(() {
              _selectedPurpose = value;

              _showAllRequirements = false;

              _reloadAnalytics();
            });
          },
          onClear: () {
            setState(() {
              _selectedDestinationId = null;

              _selectedPurpose = null;

              _showAllRequirements = false;

              _reloadAnalytics();
            });
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

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
          'Requirement Patterns',
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
                  'REQUIREMENT PATTERN ERROR: '
                  '${snapshot.error}',
                );

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: const [
                    SizedBox(height: 130),
                    Center(
                      child: Text(
                        'Unable to load requirement patterns.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                );
              }

              final Map<String, dynamic> data = snapshot.data ?? {};

              final int analysedTrips = data['analysedTrips'] as int? ?? 0;

              final List<Map<String, dynamic>> requirements =
                  List<Map<String, dynamic>>.from(
                    data['requirementPatterns'] as List? ?? [],
                  );

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                children: [
                  _buildHeader(analysedTrips),

                  const SizedBox(height: 18),

                  _buildFilters(),

                  const SizedBox(height: 26),

                  _buildPatternSection(
                    requirements: requirements,
                    analysedTrips: analysedTrips,
                  ),
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

  Widget _buildHeader(int analysedTrips) {
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
          const Icon(Icons.insights_outlined, color: _primaryColor, size: 32),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Requirement Patterns',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  analysedTrips == 0
                      ? 'No generated requirements match '
                            'the selected traveller segment.'
                      : 'Explore preparation requirements '
                            'generated across $analysedTrips '
                            '${analysedTrips == 1 ? 'trip' : 'trips'}.',
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

  // ---------------------------------------------------------------------------
  // REQUIREMENT PATTERNS
  // ---------------------------------------------------------------------------

  Widget _buildPatternSection({
    required List<Map<String, dynamic>> requirements,
    required int analysedTrips,
  }) {
    final List<Map<String, dynamic>> visibleRequirements = _showAllRequirements
        ? requirements
        : requirements.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Commonly Generated Requirements',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _darkTextColor,
          ),
        ),

        const SizedBox(height: 5),

        const Text(
          'Shows which preparation requirements occur '
          'most often within the selected traveller segment.',
          style: TextStyle(fontSize: 12.5, height: 1.4, color: Colors.black54),
        ),

        const SizedBox(height: 16),

        if (requirements.isEmpty)
          _buildEmptyState()
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
                  _buildRequirementRow(
                    rank: index + 1,
                    requirement: visibleRequirements[index],
                    analysedTrips: analysedTrips,
                  ),

                  if (index != visibleRequirements.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),

          if (requirements.length > 5) ...[
            const SizedBox(height: 10),

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
                      ? 'Show less'
                      : 'View all ${requirements.length}',
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          _buildExplanationCard(),
        ],
      ],
    );
  }

  Widget _buildRequirementRow({
    required int rank,
    required Map<String, dynamic> requirement,
    required int analysedTrips,
  }) {
    final String title =
        requirement['title'] as String? ?? 'Unnamed requirement';

    final int tripCount = requirement['tripCount'] as int? ?? 0;

    final double percentage = requirement['percentage'] as double? ?? 0;

    final double progress = (percentage / 100).clamp(0.0, 1.0);

    final List<Map<String, dynamic>> destinationBreakdown =
        List<Map<String, dynamic>>.from(
          requirement['destinationBreakdown'] as List? ?? [],
        );

    final List<Map<String, dynamic>> purposeBreakdown =
        List<Map<String, dynamic>>.from(
          requirement['purposeBreakdown'] as List? ?? [],
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
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _darkTextColor,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

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
                '${percentage.toStringAsFixed(1)}%',
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
            'Generated for $tripCount of $analysedTrips '
            '${analysedTrips == 1 ? 'trip' : 'trips'}',
            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
          ),

          // If no destination filter is selected,
          // show which destinations generated this requirement.
          if (_selectedDestinationId == null &&
              destinationBreakdown.isNotEmpty) ...[
            const SizedBox(height: 12),

            const Text(
              'Destinations',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Colors.black45,
              ),
            ),

            const SizedBox(height: 6),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: destinationBreakdown.map((item) {
                final String name = item['name'] as String? ?? 'Unknown';

                final int count = item['tripCount'] as int? ?? 0;

                return _buildContextChip('$name · $count');
              }).toList(),
            ),
          ],

          // If no purpose filter is selected,
          // show which traveller purposes generated it.
          if (_selectedPurpose == null && purposeBreakdown.isNotEmpty) ...[
            const SizedBox(height: 10),

            const Text(
              'Travel purposes',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Colors.black45,
              ),
            ),

            const SizedBox(height: 6),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: purposeBreakdown.map((item) {
                final String purpose = item['purpose'] as String? ?? '';

                final int count = item['tripCount'] as int? ?? 0;

                return _buildContextChip('${_formatPurpose(purpose)} · $count');
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContextChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E7EC)),
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

  // ---------------------------------------------------------------------------
  // EXPLANATION
  // ---------------------------------------------------------------------------

  Widget _buildExplanationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E6EE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _primaryColor, size: 19),

          SizedBox(width: 9),

          Expanded(
            child: Text(
              'Requirement patterns describe the types of '
              'preparation commonly generated for different '
              'traveller groups. They support comparison of '
              'travel preparation patterns and do not indicate '
              'whether regulation content is accurate or requires updating.',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.45,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------------------------

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
          Icon(Icons.insights_outlined, size: 38, color: Colors.black38),

          SizedBox(height: 8),

          Text(
            'No requirement patterns are available '
            'for the selected filters.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
