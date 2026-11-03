import 'package:flutter/material.dart';

import '../../models/admin_activity_log.dart';
import '../../services/admin_service.dart';
import '../../widgets/role_ui_widgets.dart';
import '../admin/admin_activity_history_screen.dart';
import '../admin/admin_profile_screen.dart';
import '../admin/manage_destinations_screen.dart';
import '../admin/manage_users_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // ---------------------------------------------------------------------------
  // DASHBOARD DATA AND TAB STATE
  // ---------------------------------------------------------------------------

  final _service = AdminService();
  final Set<int> _visitedTabs = {0};
  Map<String, int>? _overview;
  List<AdminActivityLog>? _activity;
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

  // Load each section independently so one failed request does not hide the other.
  Future<void> _loadDashboard() async {
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
    });
    Map<String, int>? overview;
    List<AdminActivityLog>? activity;
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

    // Catch each section's failure before awaiting both requests together.
    await Future.wait<void>([loadOverview(), loadActivity()]);
    if (!mounted || version != _requestVersion) return;
    setState(() {
      if (overview != null) _overview = overview;
      if (activity != null) _activity = activity;
      _overviewFailed = overviewFailed;
      _activityFailed = activityFailed;
      _loading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // ROLE NAVIGATION
  // ---------------------------------------------------------------------------

  // Create tabs on their first visit and preserve their state when switching.
  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      _visitedTabs.add(index);
      if (index == 2) _activityVersion++;
    });
    if (index == 0) _loadDashboard();
  }

  // Destination management remains a focused page reached from the dashboard.
  Future<void> _openDestinations() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ManageDestinationsScreen()));
    if (!mounted) return;
    await _loadDashboard();
  }

  String _activityLabel(String action) => switch (action) {
    'roleChanged' => 'Role changed',
    'destinationEnabled' => 'Destination enabled',
    'destinationDisabled' => 'Destination disabled',
    _ => 'Administrative action',
  };

  @override
  Widget build(BuildContext context) {
    const titles = ['Administrator', 'Users', 'Activity', 'Profile'];
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
              const ManageUsersScreen(embedded: true)
            else
              const SizedBox.shrink(),
            if (_visitedTabs.contains(2))
              AdminActivityHistoryScreen(
                embedded: true,
                reloadVersion: _activityVersion,
              )
            else
              const SizedBox.shrink(),
            if (_visitedTabs.contains(3))
              const AdminProfileScreen()
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
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Users',
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
      storageId: 'admin-dashboard',
      onRefresh: _loadDashboard,
      children: [
        const RoleIntroCard(
          eyebrow: 'System Administrator',
          title: 'Keep every journey running smoothly.',
          description:
              'Manage account access, destination availability and the changes made across your system.',
          icon: Icons.admin_panel_settings_outlined,
        ),
        const RoleSectionTitle(title: 'System overview'),
        if (_loading)
          const RoleStatusCard(
            title: 'Refreshing system overview',
            message: 'Retrieving the latest account and destination records.',
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
                label: 'Total accounts',
                value: '${overview['users'] ?? 0}',
                icon: Icons.people_outline_rounded,
              ),
              RoleMetric(
                label: 'Travellers',
                value: '${overview['travellers'] ?? 0}',
                icon: Icons.luggage_outlined,
              ),
              RoleMetric(
                label: 'Content Managers',
                value: '${overview['contentManagers'] ?? 0}',
                icon: Icons.policy_outlined,
              ),
              RoleMetric(
                label: 'Tourism Data Analysts',
                value: '${overview['analysts'] ?? 0}',
                icon: Icons.analytics_outlined,
              ),
              RoleMetric(
                label: 'Administrators',
                value: '${overview['admins'] ?? 0}',
                icon: Icons.admin_panel_settings_outlined,
              ),
              RoleMetric(
                label: 'Destinations enabled',
                value:
                    '${overview['enabledCountries'] ?? 0} / ${overview['countries'] ?? 0}',
                icon: Icons.public_outlined,
              ),
            ],
          ),
        const RoleSectionTitle(title: 'Manage your system'),
        RoleActionTile(
          title: 'User accounts',
          description: 'Find accounts and manage their authorised roles.',
          icon: Icons.manage_accounts_outlined,
          onTap: () => _selectTab(1),
        ),
        RoleActionTile(
          title: 'Destinations',
          description:
              'Choose which supported destinations are available for new trips.',
          icon: Icons.public_outlined,
          onTap: _openDestinations,
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
            title: 'No administrative activity yet',
            message: 'Role and destination changes will appear here.',
            icon: Icons.history_rounded,
          ),
        for (final log in _activity ?? <AdminActivityLog>[])
          RoleActivityTile(
            title: _activityLabel(log.action),
            target: log.targetName.isEmpty ? log.targetId : log.targetName,
            details: log.details,
            actor: log.performedByName.isNotEmpty
                ? log.performedByName
                : log.performedByEmail.isNotEmpty
                ? log.performedByEmail
                : 'Administrator',
            timestamp: log.timestamp,
          ),
      ],
    );
  }
}
