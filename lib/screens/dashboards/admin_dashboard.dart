import 'package:flutter/material.dart';

import '../../services/admin_service.dart';
import '../admin/manage_users_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminService _adminService = AdminService();

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

  late Future<Map<String, int>> _overviewFuture;

  @override
  void initState() {
    super.initState();

    _overviewFuture = _adminService.getOverview();
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  Future<void> _refresh() async {
    final Future<Map<String, int>> future = _adminService.getOverview();

    setState(() {
      _overviewFuture = future;
    });

    await future;
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
          'System Administrator',
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
                actionText: 'View User Accounts',
                onTap: _openUsers,
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
          Icon(
            Icons.admin_panel_settings_outlined,
            color: _primaryColor,
            size: 32,
          ),

          SizedBox(width: 14),

          Expanded(
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
                  'Monitor system access, manage authorised '
                  'accounts and maintain destination availability.',
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
            height: 260,
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
            style: const TextStyle(fontSize: 11, color: Colors.black54),
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
  // INFORMATION
  // ---------------------------------------------------------------------------

  Widget _buildInformationCard() {
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
          Icon(Icons.security_outlined, color: _primaryColor, size: 25),

          SizedBox(width: 13),

          Expanded(
            child: Text(
              'Administrator access is used to manage authorised '
              'system roles and system-level configuration '
              'Administrator accounts remain protected from '
              'client-side role modification.',
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
