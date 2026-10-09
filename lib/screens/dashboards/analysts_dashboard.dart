import 'package:flutter/material.dart';

import '../../services/analyst_service.dart';
import '../analyst/destination_trends_screen.dart';
import '../analyst/purpose_distribution_screen.dart';
import '../analyst/checklist_completion_screen.dart';
import '../analyst/preparation_requirements_screen.dart';

class AnalystDashboard extends StatefulWidget {
  const AnalystDashboard({super.key});

  @override
  State<AnalystDashboard> createState() => _AnalystDashboardState();
}

class _AnalystDashboardState extends State<AnalystDashboard> {
  final AnalystService _analystService = AnalystService();

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

  late Future<Map<String, dynamic>> _overviewFuture;

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _overviewFuture = _analystService.getOverview();
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  Future<void> _refresh() async {
    final Future<Map<String, dynamic>> future = _analystService.getOverview();

    setState(() {
      _overviewFuture = future;
    });

    await future;
  }

  // ---------------------------------------------------------------------------
  // SCREEN
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Tourism Data Analyst',
          style: TextStyle(color: _darkTextColor, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
            children: [
              _buildWelcomeCard(),

              const SizedBox(height: 26),

              const Text(
                'Analytics Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _darkTextColor,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Aggregated travel activity '
                'across supported destinations.',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),

              const SizedBox(height: 14),

              _buildOverview(),

              const SizedBox(height: 28),

              const Text(
                'Analytics Modules',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _darkTextColor,
                ),
              ),

              const SizedBox(height: 12),

              _buildAnalyticsModuleCard(
                icon: Icons.public_outlined,
                title: 'Destination Trends',
                description:
                    'Compare trip activity across '
                    'the five supported destinations.',
                available: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DestinationTrendsScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              _buildAnalyticsModuleCard(
                icon: Icons.donut_large_outlined,
                title: 'Travel Purpose Distribution',
                description:
                    'Review the distribution of tourism, '
                    'business and study trips.',
                available: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PurposeDistributionScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildAnalyticsModuleCard(
                icon: Icons.task_alt_outlined,
                title: 'Checklist Completion',
                description:
                    'Analyse aggregated traveller '
                    'requirement completion.',
                available: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChecklistCompletionScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              _buildAnalyticsModuleCard(
                icon: Icons.inventory_2_outlined,
                title: 'Preparation Requirements',
                description:
                    'Analyse aggregated preparation '
                    'requirement patterns.',
                available: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const PreparationRequirementsScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              _buildInformationCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WELCOME
  // ---------------------------------------------------------------------------

  Widget _buildWelcomeCard() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.analytics_outlined, color: _primaryColor, size: 32),

          SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TravelGuard MY Analytics',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),

                SizedBox(height: 6),

                Text(
                  'Explore aggregated travel preparation '
                  'patterns without displaying individual '
                  'traveller information.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
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
  // OVERVIEW
  // ---------------------------------------------------------------------------

  Widget _buildOverview() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 230,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
            ),
            child: const Text(
              'Unable to load analytics overview.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        final Map<String, dynamic> data = snapshot.data ?? {};

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildOverviewCard(
                    icon: Icons.flight_takeoff_outlined,
                    value: '${data['totalTrips'] ?? 0}',
                    label: 'Total Trips',
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _buildOverviewCard(
                    icon: Icons.groups_outlined,
                    value: '${data['uniqueTravellers'] ?? 0}',
                    label: 'Travellers',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildOverviewCard(
                    icon: Icons.location_on_outlined,
                    value: '${data['topDestination'] ?? 'No trip data'}',
                    label: 'Top Destination',
                    compactValue: true,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _buildOverviewCard(
                    icon: Icons.public_outlined,
                    value: '${data['supportedDestinations'] ?? 0}',
                    label: 'Destinations',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildOverviewCard({
    required IconData icon,
    required String value,
    required String label,
    bool compactValue = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _primaryColor, size: 23),

          const SizedBox(height: 7),

          Text(
            value,
            maxLines: compactValue ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compactValue ? 15 : 21,
              fontWeight: FontWeight.w800,
              color: _darkTextColor,
              height: 1.15,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ANALYTICS MODULES
  // ---------------------------------------------------------------------------

  Widget _buildAnalyticsModuleCard({
    required IconData icon,
    required String title,
    required String description,
    VoidCallback? onTap,
    bool available = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: available ? onTap : null,
        borderRadius: BorderRadius.circular(17),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _primaryColor, size: 24),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _darkTextColor,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              if (available)
                const Icon(Icons.chevron_right_rounded, color: Colors.black38)
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'NEXT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF627D98),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INFORMATION
  // ---------------------------------------------------------------------------

  Widget _buildInformationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FA),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFD8E6EE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, color: _primaryColor, size: 24),

          SizedBox(width: 13),

          Expanded(
            child: Text(
              'Analytics are generated from aggregated '
              'stored travel records and are read-only. '
              'Individual traveller names and email '
              'addresses are not displayed.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: Color(0xFF334E68),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
