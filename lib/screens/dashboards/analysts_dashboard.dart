import 'package:flutter/material.dart';

import '../../services/analyst_service.dart';
import '../../widgets/role_ui_widgets.dart';
import '../analyst/analyst_profile_screen.dart';
import '../analyst/analyst_reports_screen.dart';
import '../analyst/checklist_completion_screen.dart';
import '../analyst/destination_trends_screen.dart';
import '../analyst/preparation_requirements_screen.dart';
import '../analyst/purpose_distribution_screen.dart';

class AnalystDashboard extends StatefulWidget {
  const AnalystDashboard({super.key});

  @override
  State<AnalystDashboard> createState() => _AnalystDashboardState();
}

class _AnalystDashboardState extends State<AnalystDashboard> {
  // ---------------------------------------------------------------------------
  // OVERVIEW DATA AND TAB STATE
  // ---------------------------------------------------------------------------

  final _analystService = AnalystService();
  final _visitedTabs = <int>{0};
  Map<String, dynamic>? _overview;
  bool _failed = false;
  int _requestVersion = 0;
  int _selectedIndex = 0;
  int _reportsVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  // Keep the previous overview visible if a later refresh fails.
  Future<void> _loadOverview() async {
    final version = ++_requestVersion;
    try {
      final overview = await _analystService.getOverview();
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _overview = overview;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _failed = true;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION AND REFRESH
  // ---------------------------------------------------------------------------

  // Mount tabs on first use, then preserve their filters and scroll positions.
  void _selectTab(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
      _visitedTabs.add(index);
      if (index == 1) _reportsVersion++;
    });
    if (index == 0) _loadOverview();
  }

  // Analytics return to the same overview and navigation tab.
  Future<void> _openAnalytics(Widget screen) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) _loadOverview();
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Tourism Data Analyst', 'Reports', 'Profile'];
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(titles[_selectedIndex]),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildDashboard(),
            if (_visitedTabs.contains(1))
              AnalystReportsScreen(reloadVersion: _reportsVersion)
            else
              const SizedBox.shrink(),
            if (_visitedTabs.contains(2))
              const AnalystProfileScreen()
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description_rounded),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final overview = _overview;
    final total = (overview?['totalTrips'] as num?)?.toInt() ?? 0;
    return RolePageBody(
      storageId: 'analyst-dashboard',
      onRefresh: _loadOverview,
      children: [
        const RoleIntroCard(
          eyebrow: 'ANALYST WORKSPACE',
          title: 'Turn travel data into insight',
          description:
              'Explore traveller patterns, preparation progress and saved reports.',
          icon: Icons.insights_rounded,
        ),
        const SizedBox(height: 24),
        const RoleSectionTitle(title: 'Travel overview'),
        const SizedBox(height: 12),
        if (overview == null)
          RoleStatusCard(
            title: _failed ? 'Unable to load overview' : 'Loading analytics',
            message: _failed
                ? 'Try again to retrieve the travel overview.'
                : 'Retrieving stored trip data...',
            icon: Icons.analytics_outlined,
            loading: !_failed,
            onRetry: _failed ? _loadOverview : null,
          )
        else ...[
          if (_failed) ...[
            RoleStatusCard(
              title: 'Showing last loaded data',
              message: 'The overview could not be refreshed.',
              onRetry: _loadOverview,
            ),
            const SizedBox(height: 12),
          ],
          RoleMetricGrid(
            metrics: [
              RoleMetric(
                label: 'Stored trips',
                value: '$total',
                icon: Icons.luggage_outlined,
              ),
              RoleMetric(
                label: 'Unique travellers',
                value: '${overview['uniqueTravellers'] ?? 0}',
                icon: Icons.people_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          RoleActionTile(
            title: total == 0
                ? 'No trips recorded yet'
                : '${overview['topDestination'] ?? 'Unknown'}',
            description: total == 0
                ? 'Analytics will appear as travellers create trips.'
                : 'Leading destination · ${overview['topDestinationTrips'] ?? 0} trips. Open destination trends for the full breakdown.',
            icon: Icons.public_rounded,
            onTap: total == 0
                ? null
                : () => _openAnalytics(const DestinationTrendsScreen()),
          ),
        ],
        const SizedBox(height: 24),
        const RoleSectionTitle(title: 'Explore analytics'),
        const SizedBox(height: 12),
        RoleActionTile(
          title: 'Destination trends',
          description: 'Compare destinations and monthly departures.',
          icon: Icons.public_outlined,
          onTap: () => _openAnalytics(const DestinationTrendsScreen()),
        ),
        const SizedBox(height: 12),
        RoleActionTile(
          title: 'Travel purpose distribution',
          description: 'Understand tourism, business and study travel.',
          icon: Icons.donut_large_rounded,
          onTap: () => _openAnalytics(const PurposeDistributionScreen()),
        ),
        const SizedBox(height: 12),
        RoleActionTile(
          title: 'Checklist completion',
          description:
              'Compare preparation progress and outstanding requirements.',
          icon: Icons.task_alt_rounded,
          onTap: () => _openAnalytics(const ChecklistCompletionScreen()),
        ),
        const SizedBox(height: 12),
        RoleActionTile(
          title: 'Preparation requirements',
          description:
              'Explore frequently generated requirements by traveller segment.',
          icon: Icons.fact_check_outlined,
          onTap: () => _openAnalytics(const PreparationRequirementsScreen()),
        ),
        const SizedBox(height: 24),
        const RoleSectionTitle(title: 'Reports'),
        const SizedBox(height: 12),
        RoleActionTile(
          title: 'Generate or view reports',
          description: 'Create an Excel report or reopen a saved snapshot.',
          icon: Icons.description_outlined,
          onTap: () => _selectTab(1),
        ),
      ],
    );
  }
}
