import 'package:flutter/material.dart';

import '../../models/rule_activity_log.dart';
import '../../services/content_manager_service.dart';
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
  final ContentManagerService _contentManagerService = ContentManagerService();

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

  int _selectedIndex = 0;

  late Future<Map<String, int>> _overviewFuture;

  late Future<List<RuleActivityLog>> _recentActivityFuture;

  @override
  void initState() {
    super.initState();

    _overviewFuture = _contentManagerService.getOverview();

    _recentActivityFuture = _contentManagerService.getRecentActivity(limit: 4);
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  Future<void> _refresh() async {
    final Future<Map<String, int>> overviewFuture = _contentManagerService
        .getOverview();

    final Future<List<RuleActivityLog>> activityFuture = _contentManagerService
        .getRecentActivity(limit: 4);

    setState(() {
      _overviewFuture = overviewFuture;

      _recentActivityFuture = activityFuture;
    });

    await Future.wait([overviewFuture, activityFuture]);
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  Future<void> _openTravelRegulations() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManageTravelRulesScreen()),
    );

    if (!mounted) {
      return;
    }

    await _refresh();
  }

  Future<void> _openActivityHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ActivityHistoryScreen()),
    );

    if (!mounted) {
      return;
    }

    await _refresh();
  }

  // ---------------------------------------------------------------------------
  // DATE FORMATTING
  // ---------------------------------------------------------------------------

  String _formatActivityDate(DateTime? date) {
    if (date == null) {
      return 'Just now';
    }

    final DateTime localDate = date.toLocal();

    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final int hour = localDate.hour;

    final int displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;

    final String period = hour >= 12 ? 'PM' : 'AM';

    final String minute = localDate.minute.toString().padLeft(2, '0');

    return '${localDate.day} '
        '${months[localDate.month - 1]} '
        '${localDate.year}, '
        '$displayHour:$minute $period';
  }

  // ---------------------------------------------------------------------------
  // SCREEN
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool dashboardSelected = _selectedIndex == 0;

    return Scaffold(
      backgroundColor: _backgroundColor,

      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          dashboardSelected ? 'Content Manager' : 'Profile',
          style: const TextStyle(
            color: _darkTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildDashboardPage(),

            const ContentManagerProfileScreen(),
          ],
        ),
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDFF3F5),
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: _primaryColor),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: _primaryColor),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DASHBOARD PAGE
  // ---------------------------------------------------------------------------

  Widget _buildDashboardPage() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
        children: [
          _buildWelcomeCard(),

          const SizedBox(height: 26),

          const Text(
            'System Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _darkTextColor,
            ),
          ),

          const SizedBox(height: 12),

          _buildOverview(),

          const SizedBox(height: 28),

          const Text(
            'Review Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _darkTextColor,
            ),
          ),

          const SizedBox(height: 12),

          _buildReviewStatus(),

          const SizedBox(height: 28),

          const Text(
            'Content Management',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _darkTextColor,
            ),
          ),

          const SizedBox(height: 12),

          _buildManagementCard(
            icon: Icons.policy_outlined,
            title: 'Manage Travel Regulations',
            description:
                'Review, add, edit, enable and disable '
                'destination regulatory requirements '
                'and official authority references.',
            actionText: 'Manage Regulations',
            onTap: _openTravelRegulations,
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),
              ),

              TextButton(
                onPressed: _openActivityHistory,
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _primaryColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          _buildRecentActivity(),

          const SizedBox(height: 28),

          const Text(
            'Publishing & Traceability',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _darkTextColor,
            ),
          ),

          const SizedBox(height: 12),

          _buildTraceabilityCard(),
        ],
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: _primaryColor,
              size: 28,
            ),
          ),

          const SizedBox(width: 15),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TravelGuard MY',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),

                SizedBox(height: 6),

                Text(
                  'Maintain validated travel preparation '
                  'information, review regulatory content '
                  'and manage official references.',
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
  // SYSTEM OVERVIEW
  // ---------------------------------------------------------------------------

  Widget _buildOverview() {
    return FutureBuilder<Map<String, int>>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 120,
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
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
            ),
            child: const Text(
              'Unable to load system overview.',
              textAlign: TextAlign.center,
            ),
          );
        }

        final Map<String, int> overview = snapshot.data ?? {};

        final int countries = overview['enabledCountries'] ?? 0;

        final int rules = overview['rules'] ?? 0;

        final int active = overview['activeRules'] ?? 0;

        return Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                icon: Icons.public_outlined,
                value: '$countries',
                label: 'Destinations',
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _buildOverviewCard(
                icon: Icons.list_alt_outlined,
                value: '$rules',
                label: 'Travel Rules',
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _buildOverviewCard(
                icon: Icons.check_circle_outline_rounded,
                value: '$active',
                label: 'Active Rules',
              ),
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
              fontSize: 20,
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

  // ---------------------------------------------------------------------------
  // REVIEW STATUS
  // ---------------------------------------------------------------------------

  Widget _buildReviewStatus() {
    return FutureBuilder<Map<String, int>>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final Map<String, int> overview = snapshot.data ?? {};

        final int pending = overview['pendingReviewRules'] ?? 0;

        final int disabled = overview['disabledRules'] ?? 0;

        return Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                icon: Icons.schedule_outlined,
                value: '$pending',
                label: 'Pending Review',
                description: 'Awaiting approval',
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _buildStatusCard(
                icon: Icons.pause_circle_outline_rounded,
                value: '$disabled',
                label: 'Disabled',
                description: 'Not used by DSS',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String value,
    required String label,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6F7),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: _primaryColor, size: 20),
              ),

              const Spacer(),

              Text(
                value,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: _darkTextColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _darkTextColor,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            description,
            style: const TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONTENT MANAGEMENT
  // ---------------------------------------------------------------------------

  Widget _buildManagementCard({
    required IconData icon,
    required String title,
    required String description,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6F7),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: _primaryColor, size: 25),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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

                    const SizedBox(height: 9),

                    Text(
                      actionText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RECENT ACTIVITY
  // ---------------------------------------------------------------------------

  Widget _buildRecentActivity() {
    return FutureBuilder<List<RuleActivityLog>>(
      future: _recentActivityFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 110,
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
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
            ),
            child: const Text(
              'Unable to load recent activity.',
              textAlign: TextAlign.center,
            ),
          );
        }

        final List<RuleActivityLog> logs = snapshot.data ?? [];

        if (logs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
            ),
            child: const Column(
              children: [
                Icon(Icons.history_rounded, color: Colors.black38, size: 32),

                SizedBox(height: 8),

                Text(
                  'No regulatory activity recorded yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            children: [
              for (int index = 0; index < logs.length; index++) ...[
                _buildActivityItem(logs[index]),

                if (index != logs.length - 1)
                  const Divider(height: 1, indent: 62),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityItem(RuleActivityLog log) {
    IconData icon;
    String actionLabel;

    switch (log.action) {
      case 'created':
        icon = Icons.add_circle_outline_rounded;
        actionLabel = 'Created rule';
        break;

      case 'updated':
        icon = Icons.edit_outlined;
        actionLabel = 'Updated rule';
        break;

      case 'enabled':
        icon = Icons.check_circle_outline_rounded;
        actionLabel = 'Enabled rule';
        break;

      case 'disabled':
        icon = Icons.pause_circle_outline_rounded;
        actionLabel = 'Disabled rule';
        break;

      default:
        icon = Icons.history_rounded;
        actionLabel = 'Rule activity';
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F7),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: _primaryColor, size: 20),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _darkTextColor,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  log.ruleTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF486581),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  '${log.performedByName} • '
                  '${_formatActivityDate(log.timestamp)}',
                  style: const TextStyle(fontSize: 10.5, color: Colors.black45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TRACEABILITY
  // ---------------------------------------------------------------------------

  Widget _buildTraceabilityCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E6EE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: _primaryColor, size: 25),

          SizedBox(width: 13),

          Expanded(
            child: Text(
              'New regulations remain pending review until enabled. '
              'Create, update, enable and disable actions are recorded '
              'with the responsible Content Manager and timestamp.',
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
