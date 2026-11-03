import 'package:flutter/material.dart';

import '../../models/rule_activity_log.dart';
import '../../services/content_manager_service.dart';
import '../../widgets/role_ui_widgets.dart';
import '../content_manager/activity_history_screen.dart';
import '../content_manager/content_manager_profile_screen.dart';
import '../content_manager/manage_travel_rules_screen.dart';

class ContentManagerDashboard extends StatefulWidget {
  const ContentManagerDashboard({super.key});

  @override
  State<ContentManagerDashboard> createState() =>
      _ContentManagerDashboardState();
}

class _ContentManagerDashboardState extends State<ContentManagerDashboard> {
  // ---------------------------------------------------------------------------
  // DASHBOARD DATA AND TAB STATE
  // ---------------------------------------------------------------------------

  final _service = ContentManagerService();
  final Set<int> _visitedTabs = {0};
  Map<String, int>? _overview;
  List<RuleActivityLog>? _activity;
  int _selectedIndex = 0;
  int _activityVersion = 0;
  int _requestVersion = 0;
  bool _loading = false;
  bool _overviewFailed = false;
  bool _activityFailed = false;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  // Refresh each section independently and retain its last successful result.
  Future<void> _loadDashboard() async {
    final request = ++_requestVersion;
    setState(() {
      _loading = true;
    });
    Map<String, int>? overview;
    List<RuleActivityLog>? activity;
    bool overviewFailed = false;
    bool activityFailed = false;

    Future<void> loadOverview() async {
      try {
        overview = await _service.getOverview();
      } catch (_) {
        overviewFailed = true;
      }
    }

    Future<void> loadActivity() async {
      try {
        activity = await _service.getRecentActivity(limit: 4);
      } catch (_) {
        activityFailed = true;
      }
    }

    // Observe both requests before updating the displayed dashboard state.
    await Future.wait<void>([loadOverview(), loadActivity()]);
    if (!mounted || request != _requestVersion) return;
    setState(() {
      if (overview != null) _overview = overview;
      if (activity != null) _activity = activity;
      _overviewFailed = overviewFailed;
      _activityFailed = activityFailed;
      _loading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // ROLE NAVIGATION AND ACTIVITY LABELS
  // ---------------------------------------------------------------------------

  // Load tabs on demand and retain their search, destination and filter state.
  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      _visitedTabs.add(index);
      if (index == 2) _activityVersion++;
    });
    if (index == 0) _loadDashboard();
  }

  String _actionLabel(String action) => switch (action) {
    'created' => 'Rule created',
    'updated' => 'Rule updated',
    'enabled' => 'Rule enabled',
    'disabled' => 'Rule disabled',
    _ => 'Regulatory activity',
  };

  String _countryLabel(String id) => id
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');

  @override
  Widget build(BuildContext context) {
    const titles = ['Content Manager', 'Regulations', 'Activity', 'Profile'];
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          titles[_selectedIndex],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              tooltip: 'Refresh dashboard',
              onPressed: _loading ? null : _loadDashboard,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _dashboardContent(),
            if (_visitedTabs.contains(1))
              const ManageTravelRulesScreen(embedded: true)
            else
              const SizedBox.shrink(),
            if (_visitedTabs.contains(2))
              ActivityHistoryScreen(
                embedded: true,
                reloadVersion: _activityVersion,
              )
            else
              const SizedBox.shrink(),
            if (_visitedTabs.contains(3))
              const ContentManagerProfileScreen()
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
            icon: Icon(Icons.policy_outlined),
            selectedIcon: Icon(Icons.policy_rounded),
            label: 'Regulations',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Activity',
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

  Widget _dashboardContent() {
    final overview = _overview;
    return RolePageBody(
      storageId: 'content-manager-dashboard',
      onRefresh: _loadDashboard,
      children: [
        const RoleIntroCard(
          eyebrow: 'Content Manager',
          title: 'Keep travel guidance current.',
          description:
              'Maintain clear requirements, reliable official sources and a traceable record of regulation changes.',
          icon: Icons.policy_outlined,
        ),
        const RoleSectionTitle(title: 'Content overview'),
        if (_loading)
          const RoleStatusCard(
            title: 'Refreshing content overview',
            message:
                'Retrieving the latest regulation and destination records.',
            loading: true,
          ),
        if (_overviewFailed)
          RoleStatusCard(
            title: 'Unable to refresh overview',
            message: overview == null
                ? 'Check your connection and try again.'
                : 'Showing the last loaded statistics.',
            icon: Icons.cloud_off_outlined,
            onRetry: _loading ? null : _loadDashboard,
          ),
        if (overview != null)
          RoleMetricGrid(
            metrics: [
              RoleMetric(
                label: 'Total regulations',
                value: '${overview['rules'] ?? 0}',
                icon: Icons.policy_outlined,
              ),
              RoleMetric(
                label: 'Active regulations',
                value: '${overview['activeRules'] ?? 0}',
                icon: Icons.check_circle_outline_rounded,
              ),
              RoleMetric(
                label: 'Pending review',
                value: '${overview['pendingReviewRules'] ?? 0}',
                icon: Icons.fact_check_outlined,
              ),
              RoleMetric(
                label: 'Disabled regulations',
                value: '${overview['disabledRules'] ?? 0}',
                icon: Icons.pause_circle_outline_rounded,
              ),
            ],
          ),
        const RoleSectionTitle(title: 'Manage travel guidance'),
        RoleActionTile(
          title: 'Travel regulations',
          description:
              'Add or edit requirements, review official sources and manage publication.',
          icon: Icons.edit_note_rounded,
          onTap: () => _selectTab(1),
        ),
        RoleSectionTitle(
          title: 'Recent activity',
          action: TextButton(
            onPressed: () => _selectTab(2),
            child: const Text('View all activity'),
          ),
        ),
        if (_activityFailed)
          RoleStatusCard(
            title: 'Unable to refresh activity',
            message: _activity == null
                ? 'Check your connection and try again.'
                : 'Showing the last loaded activity.',
            icon: Icons.cloud_off_outlined,
            onRetry: _loading ? null : _loadDashboard,
          ),
        if (_activity != null && _activity!.isEmpty)
          const RoleStatusCard(
            title: 'No regulatory activity yet',
            message:
                'Created, edited, enabled and disabled regulations will appear here.',
            icon: Icons.history_rounded,
          ),
        for (final log in _activity ?? <RuleActivityLog>[])
          RoleActivityTile(
            title: _actionLabel(log.action),
            target: log.ruleTitle.isEmpty
                ? 'Untitled regulation'
                : log.ruleTitle,
            details: 'Destination: ${_countryLabel(log.countryId)}',
            actor: log.performedByName.isNotEmpty
                ? log.performedByName
                : log.performedByEmail.isNotEmpty
                ? log.performedByEmail
                : 'Content Manager',
            timestamp: log.timestamp,
          ),
      ],
    );
  }
}
