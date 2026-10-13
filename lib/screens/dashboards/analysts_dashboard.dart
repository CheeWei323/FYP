
import 'package:flutter/material.dart';

import '../../services/analyst_service.dart';
import '../../theme/app_theme.dart';
import '../analyst/destination_trends_screen.dart';
import '../analyst/purpose_distribution_screen.dart';
import '../analyst/checklist_completion_screen.dart';
import '../analyst/preparation_requirements_screen.dart';
import '../analyst/analyst_reports_screen.dart';
import '../analyst/analyst_profile_screen.dart';

class AnalystDashboard extends StatefulWidget {
  const AnalystDashboard({super.key});

  @override
  State<AnalystDashboard> createState() => _AnalystDashboardState();
}

class _AnalystDashboardState extends State<AnalystDashboard> {
  final AnalystService _analystService = AnalystService();

  int _selectedIndex = 0;

  // Cache Firestore analytics to prevent unnecessary
  // loading-state changes during scrolling.
  Map<String, dynamic>? _overviewData;

  bool _overviewError = false;

  // Prevent older Firestore requests from replacing newer data.
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  // ---------------------------------------------------------------------------
  // LOAD ANALYTICS OVERVIEW
  // ---------------------------------------------------------------------------

  Future<void> _loadOverview() async {
    final int requestVersion = ++_requestVersion;

    try {
      final Map<String, dynamic> overview =
      await _analystService.getOverview();

      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _overviewData = overview;
        _overviewError = false;
      });
    } catch (error) {
      debugPrint('ANALYST OVERVIEW ERROR: $error');

      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _overviewError = true;
      });

      // Preserve previously loaded statistics if refresh fails.
      if (_overviewData != null && _selectedIndex == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to refresh analytics. '
                  'Showing the last loaded data.',
            ),
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  Future<void> _refresh() async {
    await _loadOverview();
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  Future<void> _openAnalyticsScreen(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => screen,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED CARD DECORATION
  // ---------------------------------------------------------------------------

  BoxDecoration _cardDecoration({
    Color color = Colors.white,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: AppColors.border,
      ),
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
    const List<String> titles = [
      'Tourism Data Analyst',
      'Reports',
      'Profile',
    ];

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.navy,

        title: Text(
          titles[_selectedIndex],
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboardTab(),
          const AnalystReportsScreen(),
          const AnalystProfileScreen(),
        ],
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primaryLight,

        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.dashboard_outlined,
            ),
            selectedIcon: Icon(
              Icons.dashboard_rounded,
              color: AppColors.primary,
            ),
            label: 'Dashboard',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.description_outlined,
            ),
            selectedIcon: Icon(
              Icons.description_rounded,
              color: AppColors.primary,
            ),
            label: 'Reports',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.person_outline_rounded,
            ),
            selectedIcon: Icon(
              Icons.person_rounded,
              color: AppColors.primary,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DASHBOARD TAB
  // ---------------------------------------------------------------------------

  Widget _buildDashboardTab() {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,

        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),

          padding: const EdgeInsets.fromLTRB(
            18,
            18,
            18,
            36,
          ),

          children: [
            _buildWelcomeCard(),

            const SizedBox(height: 26),

            _buildSectionTitle(
              'Analytics Overview',
            ),

            const SizedBox(height: 5),

            const Text(
              'Aggregated travel activity across '
                  'supported destinations.',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 14),

            _buildOverview(),

            const SizedBox(height: 27),

            _buildSectionTitle(
              'Analytics Modules',
            ),

            const SizedBox(height: 5),

            const Text(
              'Explore travel trends and preparation insights.',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12.5,
              ),
            ),

            const SizedBox(height: 14),

            _buildAnalyticsModuleCard(
              icon: Icons.public_outlined,
              title: 'Destination Trends',
              description:
              'Analyse popular destinations and '
                  'monthly departure activity.',
              onTap: () {
                _openAnalyticsScreen(
                  const DestinationTrendsScreen(),
                );
              },
            ),

            const SizedBox(height: 11),

            _buildAnalyticsModuleCard(
              icon: Icons.donut_large_outlined,
              title: 'Travel Purpose Distribution',
              description:
              'Compare tourism, business and '
                  'study travel patterns.',
              onTap: () {
                _openAnalyticsScreen(
                  const PurposeDistributionScreen(),
                );
              },
            ),

            const SizedBox(height: 11),

            _buildAnalyticsModuleCard(
              icon: Icons.task_alt_outlined,
              title: 'Checklist Completion',
              description:
              'Analyse aggregated checklist completion '
                  'and lower-completion requirements.',
              onTap: () {
                _openAnalyticsScreen(
                  const ChecklistCompletionScreen(),
                );
              },
            ),

            const SizedBox(height: 11),

            _buildAnalyticsModuleCard(
              icon: Icons.insights_outlined,
              title: 'Requirement Patterns',
              description:
              'Explore commonly generated requirements '
                  'by traveller segment.',
              onTap: () {
                _openAnalyticsScreen(
                  const PreparationRequirementsScreen(),
                );
              },
            ),

            const SizedBox(height: 27),

            _buildSectionTitle(
              'Data Privacy',
            ),

            const SizedBox(height: 12),

            _buildInformationCard(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION TITLE
  // ---------------------------------------------------------------------------

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.navy,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WELCOME CARD
  // ---------------------------------------------------------------------------

  Widget _buildWelcomeCard() {
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
              _AnalystDashboardIcon(
                icon: Icons.analytics_outlined,
                size: 52,
              ),

              SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Analytics Workspace',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    SizedBox(height: 7),

                    Text(
                      'Explore travel preparation trends, '
                          'compare traveller patterns and '
                          'review aggregated insights.',
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

          const Divider(
            height: 1,
            color: AppColors.border,
          ),

          const SizedBox(height: 13),

          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Icon(
                Icons.shield_outlined,
                color: AppColors.primary,
                size: 18,
              ),

              SizedBox(width: 9),

              Expanded(
                child: Text(
                  'Analytics are read-only and focus on '
                      'aggregated travel preparation data.',
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
  // ANALYTICS OVERVIEW
  // ---------------------------------------------------------------------------

  Widget _buildOverview() {
    // Show a retry option when the initial Firestore request fails.
    if (_overviewData == null && _overviewError) {
      return _buildOverviewErrorCard();
    }

    final Map<String, dynamic>? data = _overviewData;

    // Display placeholders while the first request loads.
    // The statistics grid keeps the same dimensions before
    // and after data arrives.
    final String totalTrips =
    data == null ? '—' : '${data['totalTrips'] ?? 0}';

    final String uniqueTravellers =
    data == null ? '—' : '${data['uniqueTravellers'] ?? 0}';

    final String topDestination = data == null
        ? '—'
        : '${data['topDestination'] ?? 'No trip data'}';

    final String supportedDestinations = data == null
        ? '—'
        : '${data['supportedDestinations'] ?? 0}';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                icon: Icons.flight_takeoff_outlined,
                value: totalTrips,
                label: 'Total Trips',
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: _buildOverviewCard(
                icon: Icons.groups_outlined,
                value: uniqueTravellers,
                label: 'Travellers',
              ),
            ),
          ],
        ),

        const SizedBox(height: 11),

        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                icon: Icons.location_on_outlined,
                value: topDestination,
                label: 'Top Destination',
                compactValue: true,
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: _buildOverviewCard(
                icon: Icons.public_outlined,
                value: supportedDestinations,
                label: 'Destinations',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // OVERVIEW STATISTIC CARD
  // ---------------------------------------------------------------------------

  Widget _buildOverviewCard({
    required IconData icon,
    required String value,
    required String label,
    bool compactValue = false,
  }) {
    return Container(
      width: double.infinity,
      height: 144,

      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 13,
      ),

      decoration: _cardDecoration(),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Container(
            width: 39,
            height: 39,

            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),

            child: Icon(
              icon,
              color: AppColors.primary,
              size: 21,
            ),
          ),

          const SizedBox(height: 11),

          Text(
            value,
            maxLines: compactValue ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,

            style: TextStyle(
              color: AppColors.navy,
              fontSize: compactValue ? 15 : 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,

            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // OVERVIEW ERROR
  // ---------------------------------------------------------------------------

  Widget _buildOverviewErrorCard() {
    return Container(
      width: double.infinity,
      height: 299,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          const _AnalystDashboardIcon(
            icon: Icons.cloud_off_outlined,
            size: 55,
          ),

          const SizedBox(height: 14),

          const Text(
            'Unable to Load Analytics',
            textAlign: TextAlign.center,

            style: TextStyle(
              color: AppColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'The analytics overview could not be '
                'retrieved. Check your connection and try again.',
            textAlign: TextAlign.center,

            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 18),

          OutlinedButton.icon(
            onPressed: () {
              _loadOverview();
            },
            icon: const Icon(
              Icons.refresh_rounded,
              size: 18,
            ),
            label: const Text('Try Again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ANALYTICS MODULE CARD
  // ---------------------------------------------------------------------------

  Widget _buildAnalyticsModuleCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,

      child: Ink(
        decoration: _cardDecoration(),

        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),

          child: Padding(
            padding: const EdgeInsets.all(17),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,

              children: [
                _AnalystDashboardIcon(
                  icon: icon,
                  size: 49,
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        description,
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 11.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.secondaryText,
                  size: 23,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DATA PRIVACY INFORMATION
  // ---------------------------------------------------------------------------

  Widget _buildInformationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD8E6EE),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Icon(
                Icons.privacy_tip_outlined,
                color: AppColors.primary,
                size: 25,
              ),

              SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Aggregated Analytics',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    SizedBox(height: 7),

                    Text(
                      'Analytics are generated from aggregated '
                          'stored travel records and are read-only.',
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

          const SizedBox(height: 14),

          const Divider(
            height: 1,
            color: Color(0xFFD8E6EE),
          ),

          const SizedBox(height: 12),

          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Icon(
                Icons.verified_user_outlined,
                color: AppColors.primary,
                size: 18,
              ),

              SizedBox(width: 9),

              Expanded(
                child: Text(
                  'Individual traveller names and email '
                      'addresses are not displayed.',
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
}

// -----------------------------------------------------------------------------
// REUSABLE ANALYST DASHBOARD ICON
// -----------------------------------------------------------------------------

class _AnalystDashboardIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _AnalystDashboardIcon({
    required this.icon,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,

      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(13),
      ),

      child: Icon(
        icon,
        color: AppColors.primary,
        size: size * 0.51,
      ),
    );
  }
}
