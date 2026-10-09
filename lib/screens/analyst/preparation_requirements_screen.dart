import 'package:flutter/material.dart';

import '../../services/analyst_service.dart';

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
  static const Color _barColor = Color(0xFF2F5F98);

  late Future<Map<String, dynamic>> _analyticsFuture;

  @override
  void initState() {
    super.initState();

    _analyticsFuture = _analystService.getPreparationRequirementAnalytics();
  }

  Future<void> _refresh() async {
    final Future<Map<String, dynamic>> future = _analystService
        .getPreparationRequirementAnalytics();

    setState(() {
      _analyticsFuture = future;
    });

    await future;
  }

  String _formatCategoryLabel(String value) {
    final String cleaned = value
        .trim()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');

    if (cleaned.isEmpty) {
      return 'Uncategorised';
    }

    return cleaned
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) {
            return '';
          }

          return '${word[0].toUpperCase()}'
              '${word.substring(1).toLowerCase()}';
        })
        .join(' ');
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
          'Preparation Requirements',
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
                  'PREPARATION ANALYTICS ERROR: '
                  '${snapshot.error}',
                );

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: const [
                    SizedBox(height: 130),
                    Center(
                      child: Text(
                        'Unable to load preparation requirement analytics.',
                      ),
                    ),
                  ],
                );
              }

              final Map<String, dynamic> data = snapshot.data ?? {};

              final int totalRequirements =
                  data['totalRequirements'] as int? ?? 0;

              final int categoryCount = data['categoryCount'] as int? ?? 0;

              final List<Map<String, dynamic>> categories =
                  List<Map<String, dynamic>>.from(
                    data['categories'] as List? ?? [],
                  );

              final List<Map<String, dynamic>> topRequirements =
                  List<Map<String, dynamic>>.from(
                    data['topRequirements'] as List? ?? [],
                  );

              final int maximumCategoryCount = categories.isEmpty
                  ? 0
                  : categories
                        .map((item) => item['count'] as int? ?? 0)
                        .fold<int>(
                          0,
                          (currentMax, itemCount) =>
                              itemCount > currentMax ? itemCount : currentMax,
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
                          value: '$totalRequirements',
                          label: 'Requirements',
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: _buildSummaryCard(
                          icon: Icons.category_outlined,
                          value: '$categoryCount',
                          label: 'Categories',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    'Requirement Category Distribution',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _darkTextColor,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Distribution of generated preparation '
                    'requirements across checklist categories.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),

                  const SizedBox(height: 16),

                  if (categories.isEmpty)
                    _buildEmptyState()
                  else ...[
                    _buildCategoryChart(
                      categories: categories,
                      maximumCount: maximumCategoryCount,
                    ),

                    const SizedBox(height: 18),

                    _buildTopCategoryCard(categories.first),
                  ],

                  const SizedBox(height: 28),

                  const Text(
                    'Frequently Generated Requirements',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _darkTextColor,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Most frequently generated checklist '
                    'requirements across stored trips.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),

                  const SizedBox(height: 16),

                  if (topRequirements.isEmpty)
                    _buildEmptyRequirements()
                  else
                    _buildTopRequirements(topRequirements),
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
          Icon(Icons.inventory_2_outlined, color: _primaryColor, size: 32),

          SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preparation Requirements',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'Aggregated analysis of generated travel '
                  'preparation requirements.',
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

  Widget _buildCategoryChart({
    required List<Map<String, dynamic>> categories,
    required int maximumCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          for (int index = 0; index < categories.length; index++) ...[
            _buildCategoryBar(
              category: categories[index],
              maximumCount: maximumCount,
            ),
            if (index != categories.length - 1) const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryBar({
    required Map<String, dynamic> category,
    required int maximumCount,
  }) {
    final String categoryName = category['category'] as String? ?? '';

    final int itemCount = category['count'] as int? ?? 0;

    final double percentage = category['percentage'] as double? ?? 0;

    final double barFactor = maximumCount == 0 ? 0 : itemCount / maximumCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 94,
              child: Text(
                _formatCategoryLabel(categoryName),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _darkTextColor,
                ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF0F3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),

                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 22,
                        width: constraints.maxWidth * barFactor,
                        decoration: BoxDecoration(
                          color: _barColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(width: 9),

            SizedBox(
              width: 28,
              child: Text(
                '$itemCount',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _primaryColor,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 5),

        Padding(
          padding: const EdgeInsets.only(left: 104),
          child: Text(
            '${percentage.toStringAsFixed(1)}% of generated requirements',
            style: const TextStyle(fontSize: 9.5, color: Colors.black45),
          ),
        ),
      ],
    );
  }

  Widget _buildTopCategoryCard(Map<String, dynamic> category) {
    final String categoryName =
        category['category'] as String? ?? 'Uncategorised';

    final int itemCount = category['count'] as int? ?? 0;

    final double percentage = category['percentage'] as double? ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E6EE)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F7),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.insights_outlined, color: _primaryColor),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Most Common Category',
                  style: TextStyle(fontSize: 10.5, color: Colors.black54),
                ),

                const SizedBox(height: 3),

                Text(
                  _formatCategoryLabel(categoryName),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  '$itemCount requirements · '
                  '${percentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF486581),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRequirements(List<Map<String, dynamic>> requirements) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          for (int index = 0; index < requirements.length; index++) ...[
            _buildRequirementRow(
              index: index,
              requirement: requirements[index],
            ),
            if (index != requirements.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildRequirementRow({
    required int index,
    required Map<String, dynamic> requirement,
  }) {
    final String title = requirement['title'] as String? ?? '';

    final int itemCount = requirement['count'] as int? ?? 0;

    final double percentage = requirement['percentage'] as double? ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${index + 1}',
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

                const SizedBox(height: 4),

                Text(
                  '$itemCount occurrences · '
                  '${percentage.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 10.5, color: Colors.black54),
                ),
              ],
            ),
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
          Icon(Icons.category_outlined, size: 38, color: Colors.black38),
          SizedBox(height: 8),
          Text('No requirement category data available.'),
        ],
      ),
    );
  }

  Widget _buildEmptyRequirements() {
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
          Icon(Icons.fact_check_outlined, size: 38, color: Colors.black38),
          SizedBox(height: 8),
          Text('No generated requirements available.'),
        ],
      ),
    );
  }
}
