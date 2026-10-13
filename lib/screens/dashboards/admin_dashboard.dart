import 'package:flutter/material.dart';

import '../../models/admin_activity_log.dart';
import '../../services/admin_service.dart';
import '../admin/admin_activity_history_screen.dart';
import '../admin/admin_profile_screen.dart';
import '../admin/manage_destinations_screen.dart';
import '../admin/manage_users_screen.dart';
import '../../theme/app_theme.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminService _adminService = AdminService();

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

  late Future<Map<String, int>> _overviewFuture;

  late Future<List<AdminActivityLog>> _recentActivityFuture;

  int _selectedIndex = 0;

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _overviewFuture = _adminService.getOverview();

    _recentActivityFuture = _adminService.getRecentActivity(limit: 4);
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  Future<void> _refresh() async {
    final Future<Map<String, int>> overviewFuture = _adminService.getOverview();

    final Future<List<AdminActivityLog>> activityFuture = _adminService
        .getRecentActivity(limit: 4);

    setState(() {
      _overviewFuture = overviewFuture;

      _recentActivityFuture = activityFuture;
    });

    await overviewFuture;
    await activityFuture;
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  Future<void> _openUsers() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManageUsersScreen()),
    );

    if (!mounted) {
      return;
    }

    await _refresh();
  }

  Future<void> _openDestinations() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManageDestinationsScreen()),
    );

    if (!mounted) {
      return;
    }

    await _refresh();
  }

  Future<void> _openActivityHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminActivityHistoryScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _refresh();
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
        title: Text(
          _selectedIndex == 0 ? 'System Administrator' : 'Profile',
          style: const TextStyle(
            color: _darkTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [_buildDashboardContent(), const AdminProfileScreen()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
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

  // ---------------------------------------------------------------------------
  // DASHBOARD CONTENT
  // ---------------------------------------------------------------------------

  Widget _buildDashboardContent() {
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
            'System Management',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _darkTextColor,
            ),
          ),

          const SizedBox(height: 12),

          _buildManagementCard(
            icon: Icons.manage_accounts_outlined,
            title: 'User & Role Management',
            description:
                'Review registered accounts and manage '
                'their authorised system roles.',
            actionText: 'Manage User Accounts',
            onTap: _openUsers,
          ),

          const SizedBox(height: 12),

          _buildManagementCard(
            icon: Icons.public_outlined,
            title: 'Destination Management',
            description:
                'Control which supported destinations are '
                'available when travellers create new trips.',
            actionText: 'Manage Destinations',
            onTap: _openDestinations,
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Administrative Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openActivityHistory,
                child: const Text('View All'),
              ),
            ],
          ),

          const SizedBox(height: 10),

          _buildRecentActivity(),

          const SizedBox(height: 28),

          _buildInformationCard(),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------------------------------------------
          // ADMINISTRATOR HEADER
          // ---------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: AppColors.primary,
                  size: 29,
                ),
              ),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Administrator Workspace',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      'Manage system access, supported '
                      'destinations and administrative '
                      'activity in one place.',
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

          const SizedBox(height: 19),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 15),

          // ---------------------------------------------------
          // ADMINISTRATOR ROLE INFORMATION
          // ---------------------------------------------------
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: AppColors.primary, size: 19),

              SizedBox(width: 10),

              Expanded(
                child: Text(
                  'System administration tools are '
                  'restricted to authorised accounts.',
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
  // SYSTEM OVERVIEW
  // ---------------------------------------------------------------------------

  Widget _buildDashboardStatusCard({
    required IconData icon,
    required String title,
    required String message,
    bool isLoading = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),

          const SizedBox(height: 17),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),

          if (isLoading) ...[
            const SizedBox(height: 20),

            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ] else ...[
            const SizedBox(height: 14),

            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.swipe_down_alt_rounded,
                  size: 17,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6),
                Text(
                  'Pull down to refresh',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return FutureBuilder<Map<String, int>>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildDashboardStatusCard(
            icon: Icons.analytics_outlined,
            title: 'Loading System Overview',
            message:
                'Retrieving the latest account and '
                'destination statistics...',
            isLoading: true,
          );
        }
        if (snapshot.hasError) {
          return _buildDashboardStatusCard(
            icon: Icons.cloud_off_outlined,
            title: 'Unable to Load Overview',
            message:
                'System statistics could not be retrieved. '
                'Please check your connection and try again.',
          );
        }

        final Map<String, int> data = snapshot.data ?? {};

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildOverviewCard(
                    icon: Icons.people_outline_rounded,
                    value: '${data['users'] ?? 0}',
                    label: 'Total Users',
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _buildOverviewCard(
                    icon: Icons.luggage_outlined,
                    value: '${data['travellers'] ?? 0}',
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
                    icon: Icons.policy_outlined,
                    value: '${data['contentManagers'] ?? 0}',
                    label: 'Content Managers',
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _buildOverviewCard(
                    icon: Icons.analytics_outlined,
                    value: '${data['analysts'] ?? 0}',
                    label: 'Data Analysts',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildOverviewCard(
                    icon: Icons.admin_panel_settings_outlined,
                    value: '${data['admins'] ?? 0}',
                    label: 'Administrators',
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _buildOverviewCard(
                    icon: Icons.public_outlined,
                    value:
                        '${data['enabledCountries'] ?? 0}'
                        '/'
                        '${data['countries'] ?? 0}',
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
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 156),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------------------------------------------
          // STATISTIC ICON
          // ---------------------------------------------------
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.primary, size: 23),
          ),

          const SizedBox(height: 15),

          // ---------------------------------------------------
          // STATISTIC VALUE
          // ---------------------------------------------------
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
          ),

          const SizedBox(height: 7),

          // ---------------------------------------------------
          // STATISTIC LABEL
          // ---------------------------------------------------
          Text(
            label,
            softWrap: true,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MANAGEMENT
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
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------------------------------------
                // MANAGEMENT ICON AND TITLE
                // ---------------------------------------------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 49,
                      height: 49,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 25),
                    ),

                    const SizedBox(width: 13),

                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
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

                const SizedBox(height: 15),

                // ---------------------------------------------
                // MANAGEMENT DESCRIPTION
                // ---------------------------------------------
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12.5,
                    height: 1.55,
                  ),
                ),

                const SizedBox(height: 17),

                const Divider(height: 1, color: AppColors.border),

                const SizedBox(height: 13),

                // ---------------------------------------------
                // NAVIGATION ACTION
                // ---------------------------------------------
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        actionText,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.primary,
                      size: 19,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RECENT ADMINISTRATIVE ACTIVITY
  // ---------------------------------------------------------------------------

  Widget _buildRecentActivity() {
    return FutureBuilder<List<AdminActivityLog>>(
      future: _recentActivityFuture,
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
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
            ),
            child: const Text(
              'Unable to load recent activity.',
              textAlign: TextAlign.center,
            ),
          );
        }

        final List<AdminActivityLog> logs = snapshot.data ?? [];

        if (logs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
            ),
            child: const Column(
              children: [
                Icon(Icons.history_rounded, color: Colors.black38),
                SizedBox(height: 7),
                Text(
                  'No administrative activity yet.',
                  style: TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [for (final log in logs) _buildRecentActivityCard(log)],
        );
      },
    );
  }

  Widget _buildRecentActivityCard(AdminActivityLog log) {
    // ---------------------------------------------------------
    // ACTIVITY STATUS COLOURS
    // ---------------------------------------------------------

    final bool isEnabled = log.action == 'destinationEnabled';
    final bool isDisabled = log.action == 'destinationDisabled';

    final Color accentColor = isEnabled
        ? AppColors.success
        : isDisabled
        ? const Color(0xFFA86300)
        : AppColors.primary;

    final Color accentBackground = isEnabled
        ? const Color(0xFFEAF7F1)
        : isDisabled
        ? const Color(0xFFFFF4DC)
        : AppColors.primaryLight;

    final String performedBy = log.performedByName.trim().isNotEmpty
        ? log.performedByName.trim()
        : log.performedByEmail.trim().isNotEmpty
        ? log.performedByEmail.trim()
        : 'Administrator';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------------------------------------------
          // ACTIVITY TYPE AND TARGET
          // ---------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentBackground,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _adminActivityIcon(log.action),
                  color: accentColor,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Activity type badge.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentBackground,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        _adminActivityLabel(log.action),
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // User or destination affected.
                    Text(
                      log.targetName,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ---------------------------------------------------
          // ACTIVITY DESCRIPTION
          // ---------------------------------------------------
          if (log.details.trim().isNotEmpty) ...[
            const SizedBox(height: 15),

            Text(
              log.details,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],

          const SizedBox(height: 16),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 13),

          // ---------------------------------------------------
          // ADMINISTRATOR INFORMATION
          // ---------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.person_outline_rounded,
                color: AppColors.secondaryText,
                size: 17,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  'By $performedBy',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          // ---------------------------------------------------
          // ACTIVITY TIMESTAMP
          // ---------------------------------------------------
          Row(
            children: [
              const Icon(
                Icons.schedule_outlined,
                color: AppColors.secondaryText,
                size: 17,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  _formatAdminActivityTime(log.timestamp),
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _adminActivityLabel(String action) {
    switch (action) {
      case 'roleChanged':
        return 'ROLE CHANGED';

      case 'destinationEnabled':
        return 'DESTINATION ENABLED';

      case 'destinationDisabled':
        return 'DESTINATION DISABLED';

      default:
        return 'ADMINISTRATIVE ACTION';
    }
  }

  IconData _adminActivityIcon(String action) {
    switch (action) {
      case 'roleChanged':
        return Icons.manage_accounts_outlined;

      case 'destinationEnabled':
        return Icons.check_circle_outline_rounded;

      case 'destinationDisabled':
        return Icons.block_outlined;

      default:
        return Icons.history_rounded;
    }
  }

  String _formatAdminActivityTime(DateTime? timestamp) {
    if (timestamp == null) {
      return 'Time pending';
    }

    // Convert the stored timestamp to the device's local time.
    final DateTime local = timestamp.toLocal();

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

    final int hour = local.hour % 12 == 0 ? 12 : local.hour % 12;

    final String minute = local.minute.toString().padLeft(2, '0');

    final String period = local.hour >= 12 ? 'PM' : 'AM';

    return '${local.day} '
        '${months[local.month - 1]} '
        '${local.year} • '
        '$hour:$minute $period';
  }

  // ---------------------------------------------------------------------------
  // INFORMATION
  // ---------------------------------------------------------------------------

  Widget _buildInformationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E6EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.security_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Administration & Security',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    SizedBox(height: 7),

                    Text(
                      'Administrator access is used to manage '
                      'authorised system roles, destination '
                      'availability and administrative activity.',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12.5,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          const Divider(height: 1, color: Color(0xFFD8E6EE)),

          const SizedBox(height: 13),

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
                  'Administrator accounts remain protected '
                  'from client-side role modification.',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
