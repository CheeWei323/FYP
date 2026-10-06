import 'package:flutter/material.dart';

import '../../models/system_user.dart';
import '../../services/admin_service.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final AdminService _adminService = AdminService();

  final TextEditingController _searchController = TextEditingController();

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

  late Future<List<SystemUser>> _usersFuture;

  List<SystemUser> _allUsers = [];

  String _searchText = '';

  @override
  void initState() {
    super.initState();

    _usersFuture = _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------------------

  Future<List<SystemUser>> _loadUsers() async {
    final List<SystemUser> users = await _adminService.getUsers();

    _allUsers = users;

    return users;
  }

  Future<void> _refresh() async {
    final Future<List<SystemUser>> future = _loadUsers();

    setState(() {
      _usersFuture = future;
    });

    await future;
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  List<SystemUser> get _visibleUsers {
    final String search = _searchText.trim().toLowerCase();

    if (search.isEmpty) {
      return _allUsers;
    }

    return _allUsers.where((user) {
      return user.fullName.toLowerCase().contains(search) ||
          user.email.toLowerCase().contains(search) ||
          user.role.toLowerCase().contains(search) ||
          _formatRole(user.role).toLowerCase().contains(search);
    }).toList();
  }

  String _formatRole(String role) {
    switch (role) {
      case 'traveller':
        return 'Traveller';

      case 'contentManager':
        return 'Content Manager';

      case 'analyst':
        return 'Tourism Data Analyst';

      case 'admin':
        return 'System Administrator';

      default:
        return role.isEmpty ? 'Unknown Role' : role;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Not recorded';
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

    return '${localDate.day} '
        '${months[localDate.month - 1]} '
        '${localDate.year}';
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: _darkTextColor,
        title: const Text(
          'User Accounts',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<SystemUser>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [const SizedBox(height: 120), _buildErrorState()],
                );
              }

              final List<SystemUser> visibleUsers = _visibleUsers;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                children: [
                  _buildIntroCard(),

                  const SizedBox(height: 22),

                  _buildSearchField(),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Registered Users',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _darkTextColor,
                          ),
                        ),
                      ),
                      Text(
                        '${visibleUsers.length} shown',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (_allUsers.isEmpty)
                    _buildEmptyState(
                      title: 'No user accounts',
                      message: 'No registered user profiles are available.',
                    )
                  else if (visibleUsers.isEmpty)
                    _buildEmptyState(
                      title: 'No matching users',
                      message: 'Try a different name, email or role.',
                    )
                  else
                    for (final SystemUser user in visibleUsers)
                      _buildUserCard(user),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
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
          Icon(Icons.manage_accounts_outlined, color: _primaryColor, size: 30),

          SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Management',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),

                SizedBox(height: 6),

                Text(
                  'Review registered system accounts and '
                  'their authorised roles.',
                  style: TextStyle(
                    fontSize: 13,
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

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchText = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search name, email or role',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchText.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    _searchText = '';
                  });
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primaryColor, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildUserCard(SystemUser user) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F7),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: _primaryColor,
              size: 23,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isEmpty ? 'Unnamed User' : user.fullName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _darkTextColor,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  user.email.isEmpty ? 'No email recorded' : user.email,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                ),

                const SizedBox(height: 9),

                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _buildRoleBadge(user.role),
                    _buildInfoChip('Joined ${_formatDate(user.createdAt)}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F6F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _formatRole(role),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: _primaryColor,
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10.5, color: Color(0xFF486581)),
      ),
    );
  }

  Widget _buildEmptyState({required String title, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.people_outline_rounded,
            size: 40,
            color: Colors.black38,
          ),

          const SizedBox(height: 10),

          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: _darkTextColor,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 38,
            color: Colors.black45,
          ),

          const SizedBox(height: 10),

          const Text(
            'Unable to load user accounts.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _darkTextColor,
            ),
          ),

          const SizedBox(height: 12),

          OutlinedButton(onPressed: _refresh, child: const Text('Try Again')),
        ],
      ),
    );
  }
}
