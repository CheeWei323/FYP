import 'package:flutter/material.dart';

import '../../models/rule_activity_log.dart';
import '../../services/content_manager_service.dart';
import '../../theme/app_theme.dart';
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

  int _selectedIndex = 0;

  // Cached Firestore data.
  Map<String, int>? _overview;
  List<RuleActivityLog>? _recentActivity;

  bool _hasLoadedOnce = false;
  bool _overviewFailed = false;
  bool _activityFailed = false;

  // Prevents older requests from replacing newer dashboard data.
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  // ---------------------------------------------------------------------------
  // DASHBOARD DATA
  // ---------------------------------------------------------------------------

  Future<void> _loadDashboard() async {
    final int requestVersion = ++_requestVersion;

    Map<String, int>? updatedOverview;
    List<RuleActivityLog>? updatedActivity;

    Object? overviewError;
    Object? activityError;

    // Fetch overview statistics.
    Future<void> fetchOverview() async {
      try {
        updatedOverview = await _contentManagerService.getOverview();
      } catch (error) {
        overviewError = error;
        debugPrint('CONTENT MANAGER OVERVIEW ERROR: $error');
      }
    }

    // Fetch recent regulatory activity.
    Future<void> fetchActivity() async {
      try {
        updatedActivity = await _contentManagerService.getRecentActivity(
          limit: 4,
        );
      } catch (error) {
        activityError = error;
        debugPrint('CONTENT MANAGER ACTIVITY ERROR: $error');
      }
    }

    // Run both Firestore requests concurrently.
    await Future.wait<void>([fetchOverview(), fetchActivity()]);

    if (!mounted || requestVersion != _requestVersion) {
      return;
    }

    // Update cached data only after both requests finish.
    // This keeps dashboard dimensions stable during refresh.
    setState(() {
      if (updatedOverview != null) {
        _overview = updatedOverview;
      }

      if (updatedActivity != null) {
        _recentActivity = updatedActivity;
      }

      _overviewFailed = overviewError != null;
      _activityFailed = activityError != null;

      _hasLoadedOnce = true;
    });
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  Future<void> _refresh() async {
    await _loadDashboard();
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  Future<void> _openTravelRegulations() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManageTravelRulesScreen()),
    );

    if (!mounted) return;

    await _refresh();
  }

  Future<void> _openActivityHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ActivityHistoryScreen()),
    );

    if (!mounted) return;

    await _refresh();
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
  // ACTIVITY FORMATTING
  // ---------------------------------------------------------------------------

  String _formatActivityDate(DateTime? date) {
    if (date == null) {
      return 'Just now';
    }

    final DateTime local = date.toLocal();

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
        '${local.year}, '
        '$hour:$minute $period';
  }

  String _activityLabel(String action) {
    switch (action) {
      case 'created':
        return 'RULE CREATED';

      case 'updated':
        return 'RULE UPDATED';

      case 'enabled':
        return 'RULE ENABLED';

      case 'disabled':
        return 'RULE DISABLED';

      default:
        return 'RULE ACTIVITY';
    }
  }

  IconData _activityIcon(String action) {
    switch (action) {
      case 'created':
        return Icons.add_circle_outline_rounded;

      case 'updated':
        return Icons.edit_outlined;

      case 'enabled':
        return Icons.check_circle_outline_rounded;

      case 'disabled':
        return Icons.pause_circle_outline_rounded;

      default:
        return Icons.history_rounded;
    }
  }

  Color _activityColor(String action) {
    switch (action) {
      case 'enabled':
        return AppColors.success;

      case 'disabled':
        return const Color(0xFFA86300);

      default:
        return AppColors.primary;
    }
  }

  Color _activityBackground(String action) {
    switch (action) {
      case 'enabled':
        return const Color(0xFFEAF7F1);

      case 'disabled':
        return const Color(0xFFFFF4DC);

      default:
        return AppColors.primaryLight;
    }
  }

  // ---------------------------------------------------------------------------
  // MAIN SCREEN
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool dashboardSelected = _selectedIndex == 0;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.navy,

        title: Text(
          dashboardSelected ? 'Content Manager' : 'Profile',
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w800,
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
        indicatorColor: AppColors.primaryLight,

        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(
              Icons.dashboard_rounded,
              color: AppColors.primary,
            ),
            label: 'Dashboard',
          ),

          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
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
      color: AppColors.primary,
      onRefresh: _refresh,

      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),

        padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),

        children: [
          _buildWelcomeCard(),

          const SizedBox(height: 26),

          _buildSectionTitle('System Overview'),

          const SizedBox(height: 12),

          _buildOverview(),

          const SizedBox(height: 26),

          _buildSectionTitle('Review Status'),

          const SizedBox(height: 12),

          _buildReviewStatus(),

          const SizedBox(height: 26),

          _buildSectionTitle('Content Management'),

          const SizedBox(height: 12),

          _buildManagementCard(
            icon: Icons.policy_outlined,
            title: 'Manage Travel Regulations',
            description:
                'Review, add, edit, enable and disable '
                'travel requirements and official references.',
            actionText: 'Manage Regulations',
            onTap: _openTravelRegulations,
          ),

          const SizedBox(height: 26),

          _buildSectionTitle(
            'Recent Activity',
            onViewAll: _openActivityHistory,
          ),

          const SizedBox(height: 10),

          _buildRecentActivity(),

          const SizedBox(height: 26),

          _buildSectionTitle('Publishing & Traceability'),

          const SizedBox(height: 12),

          _buildTraceabilityCard(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION TITLE
  // ---------------------------------------------------------------------------

  Widget _buildSectionTitle(String title, {VoidCallback? onViewAll}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: const Text(
              'View All',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
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
              _DashboardIcon(icon: Icons.fact_check_outlined, size: 52),

              SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Content Workspace',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    SizedBox(height: 7),

                    Text(
                      'Maintain travel regulations, review '
                      'requirements and manage official '
                      'authority references.',
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

          const Divider(height: 1, color: AppColors.border),

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
                  'Regulatory changes are recorded for '
                  'accountability and review.',
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
  // LOADING / ERROR / EMPTY STATE
  // ---------------------------------------------------------------------------

  Widget _buildStatusMessage({
    required IconData icon,
    required String title,
    required String message,
    bool isLoading = false,
    VoidCallback? onRetry,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: _cardDecoration(),

      child: Column(
        children: [
          _DashboardIcon(icon: icon, size: 56),

          const SizedBox(height: 14),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 15,
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
            const SizedBox(height: 18),

            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ],

          if (onRetry != null) ...[
            const SizedBox(height: 14),

            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SYSTEM OVERVIEW
  // ---------------------------------------------------------------------------

  Widget _buildOverview() {
    final Map<String, int>? overview = _overview;

    // Initial loading state.
    if (overview == null && !_hasLoadedOnce) {
      return _buildStatusMessage(
        icon: Icons.analytics_outlined,
        title: 'Loading Overview',
        message: 'Retrieving regulation statistics...',
        isLoading: true,
      );
    }

    // Initial error state.
    if (overview == null && _overviewFailed) {
      return _buildStatusMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to Load Overview',
        message: 'System statistics could not be retrieved.',
        onRetry: _refresh,
      );
    }

    if (overview == null) {
      return const SizedBox.shrink();
    }

    // Real Firestore statistics stored in state.
    final int destinations = overview['enabledCountries'] ?? 0;

    final int rules = overview['rules'] ?? 0;

    final int active = overview['activeRules'] ?? 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Expanded(
          child: _buildOverviewCard(
            icon: Icons.public_outlined,
            value: '$destinations',
            label: 'Destinations',
          ),
        ),

        const SizedBox(width: 9),

        Expanded(
          child: _buildOverviewCard(
            icon: Icons.list_alt_outlined,
            value: '$rules',
            label: 'Travel Rules',
          ),
        ),

        const SizedBox(width: 9),

        Expanded(
          child: _buildOverviewCard(
            icon: Icons.check_circle_outline_rounded,
            value: '$active',
            label: 'Active Rules',
          ),
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
  }) {
    return Container(
      width: double.infinity,
      height: 145,

      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),

      decoration: _cardDecoration(),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Container(
            width: 38,
            height: 38,

            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(11),
            ),

            child: Icon(icon, color: AppColors.primary, size: 21),
          ),

          const SizedBox(height: 10),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,

            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 24,
              fontWeight: FontWeight.w800,
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
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REVIEW STATUS
  // ---------------------------------------------------------------------------

  Widget _buildReviewStatus() {
    final Map<String, int>? overview = _overview;

    if (overview == null && !_hasLoadedOnce) {
      return _buildStatusMessage(
        icon: Icons.fact_check_outlined,
        title: 'Loading Review Status',
        message: 'Checking regulatory review information...',
        isLoading: true,
      );
    }

    if (overview == null && _overviewFailed) {
      return _buildStatusMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to Load Review Status',
        message: 'Review information could not be retrieved.',
        onRetry: _refresh,
      );
    }

    if (overview == null) {
      return const SizedBox.shrink();
    }

    final int pending = overview['pendingReviewRules'] ?? 0;

    final int disabled = overview['disabledRules'] ?? 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Expanded(
          child: _buildReviewCard(
            icon: Icons.schedule_outlined,
            value: '$pending',
            label: 'Pending Review',
            description: 'Awaiting approval',
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _buildReviewCard(
            icon: Icons.pause_circle_outline_rounded,
            value: '$disabled',
            label: 'Disabled',
            description: 'Not used by DSS',
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // REVIEW CARD
  // ---------------------------------------------------------------------------

  Widget _buildReviewCard({
    required IconData icon,
    required String value,
    required String label,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      height: 145,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              _DashboardIcon(icon: icon, size: 38),

              const Spacer(),

              Text(
                value,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,

            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONTENT MANAGEMENT CARD
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

      child: Ink(
        decoration: _cardDecoration(),

        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),

          child: Padding(
            padding: const EdgeInsets.all(18),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    _DashboardIcon(icon: icon, size: 49),

                    const SizedBox(width: 13),

                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.secondaryText,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 15),

                const Divider(height: 1, color: AppColors.border),

                const SizedBox(height: 12),

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
  // RECENT ACTIVITY
  // ---------------------------------------------------------------------------

  Widget _buildRecentActivity() {
    final List<RuleActivityLog>? logs = _recentActivity;

    if (logs == null && !_hasLoadedOnce) {
      return _buildStatusMessage(
        icon: Icons.history_rounded,
        title: 'Loading Recent Activity',
        message: 'Retrieving the latest regulatory actions...',
        isLoading: true,
      );
    }

    if (logs == null && _activityFailed) {
      return _buildStatusMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to Load Activity',
        message: 'Recent activity could not be retrieved.',
        onRetry: _refresh,
      );
    }

    if (logs == null || logs.isEmpty) {
      return _buildStatusMessage(
        icon: Icons.history_rounded,
        title: 'No Recent Activity',
        message:
            'Regulatory changes will appear here '
            'when activity is recorded.',
      );
    }

    return Column(
      children: [
        for (final RuleActivityLog log in logs) _buildActivityItem(log),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIVITY ITEM
  // ---------------------------------------------------------------------------

  Widget _buildActivityItem(RuleActivityLog log) {
    final Color accentColor = _activityColor(log.action);

    final Color accentBackground = _activityBackground(log.action);

    final String performedBy = log.performedByName.trim().isNotEmpty
        ? log.performedByName.trim()
        : 'Content Manager';

    final String ruleTitle = log.ruleTitle.trim().isNotEmpty
        ? log.ruleTitle
        : 'Untitled Regulation';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                width: 43,
                height: 43,

                decoration: BoxDecoration(
                  color: accentBackground,
                  borderRadius: BorderRadius.circular(12),
                ),

                child: Icon(
                  _activityIcon(log.action),
                  color: accentColor,
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),

                      decoration: BoxDecoration(
                        color: accentBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),

                      child: Text(
                        _activityLabel(log.action),
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      ruleTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 12),

          Row(
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
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

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
                  _formatActivityDate(log.timestamp),
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11.5,
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
  // PUBLISHING & TRACEABILITY
  // ---------------------------------------------------------------------------

  Widget _buildTraceabilityCard() {
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
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Icon(
                Icons.verified_user_outlined,
                color: AppColors.primary,
                size: 25,
              ),

              SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Regulatory Traceability',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    SizedBox(height: 7),

                    Text(
                      'New regulations remain pending '
                      'review until enabled.',
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

          const Divider(height: 1, color: Color(0xFFD8E6EE)),

          const SizedBox(height: 12),

          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Icon(Icons.history_rounded, color: AppColors.primary, size: 18),

              SizedBox(width: 9),

              Expanded(
                child: Text(
                  'Create, update, enable and disable actions '
                  'are recorded with the responsible Content '
                  'Manager and timestamp.',
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
// REUSABLE DASHBOARD ICON
// -----------------------------------------------------------------------------

class _DashboardIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _DashboardIcon({required this.icon, required this.size});

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
