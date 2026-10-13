import 'package:flutter/material.dart';

import '../../models/system_user.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

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

  late Future<List<SystemUser>> _usersFuture;

  List<SystemUser> _allUsers = [];

  String _searchText = '';

  String? _updatingUserId;

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

  String _roleDescription(String role) {
    switch (role) {
      case 'traveller':
        return 'Travel planning, requirements and packing.';

      case 'contentManager':
        return 'Manage and review travel regulations.';

      case 'analyst':
        return 'View tourism analytics and reports.';

      default:
        return '';
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'traveller':
        return Icons.luggage_outlined;

      case 'contentManager':
        return Icons.policy_outlined;

      case 'analyst':
        return Icons.analytics_outlined;

      default:
        return Icons.person_outline_rounded;
    }
  }

  Future<void> _changeUserRole(SystemUser user) async {
    if (_updatingUserId != null || user.role == 'admin') {
      return;
    }

    String selectedRole = user.role;

    final String? newRole = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change User Role'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName.isEmpty ? user.email : user.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _darkTextColor,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Select the authorised role for this account.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF486581)),
                    ),

                    const SizedBox(height: 10),

                    RadioGroup<String>(
                      groupValue: selectedRole,
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          selectedRole = value;
                        });
                      },
                      child: Column(
                        children: [
                          _buildRoleOption(
                            role: 'traveller',
                            selectedRole: selectedRole,
                          ),

                          _buildRoleOption(
                            role: 'contentManager',
                            selectedRole: selectedRole,
                          ),

                          _buildRoleOption(
                            role: 'analyst',
                            selectedRole: selectedRole,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F6FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: _primaryColor,
                          ),

                          SizedBox(width: 9),

                          Expanded(
                            child: Text(
                              'Changing a role changes the system '
                              'features and permissions available to '
                              'this account.',
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.4,
                                color: Color(0xFF486581),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedRole == user.role
                      ? null
                      : () {
                          Navigator.pop(dialogContext, selectedRole);
                        },
                  child: const Text('Update Role'),
                ),
              ],
            );
          },
        );
      },
    );

    if (newRole == null || newRole == user.role || !mounted) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final String accountName = user.fullName.trim().isNotEmpty
            ? user.fullName.trim()
            : user.email.trim().isNotEmpty
            ? user.email.trim()
            : 'Unnamed User';

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
          contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),

          // ---------------------------------------------------
          // CONFIRMATION HEADER
          // ---------------------------------------------------
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.manage_accounts_outlined,
                  color: AppColors.primary,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Text(
                  'Confirm Role Change',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          // ---------------------------------------------------
          // CONFIRMATION DETAILS
          // ---------------------------------------------------
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Review the changes before updating this account.',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                accountName,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),

              if (user.email.trim().isNotEmpty &&
                  accountName != user.email.trim()) ...[
                const SizedBox(height: 3),
                Text(
                  user.email,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11.5,
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // -------------------------------------------------
              // OLD AND NEW ROLES
              // -------------------------------------------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CURRENT ROLE',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      _formatRole(user.role),
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 11),

                    const Divider(height: 1, color: AppColors.border),

                    const SizedBox(height: 11),

                    const Text(
                      'NEW ROLE',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      _formatRole(newRole),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                    size: 17,
                  ),

                  SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      'This change affects the features and '
                      'permissions available to this account.',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ---------------------------------------------------
          // CONFIRMATION ACTIONS
          // ---------------------------------------------------
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _updatingUserId = user.id;
    });

    try {
      await _adminService.updateUserRole(user: user, newRole: newRole);

      if (!mounted) {
        return;
      }

      final Future<List<SystemUser>> future = _loadUsers();

      setState(() {
        _usersFuture = future;
      });

      await future;

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Role updated to '
              '${_formatRole(newRole)}.',
            ),
          ),
        );
    } catch (error) {
      debugPrint('ADMIN ROLE UPDATE ERROR: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Unable to update the user role.')),
        );
    } finally {
      if (mounted) {
        setState(() {
          _updatingUserId = null;
        });
      }
    }
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
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(18),
                  children: [
                    const SizedBox(height: 70),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 32,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 3,
                          ),

                          SizedBox(height: 20),

                          Text(
                            'Loading User Accounts',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          SizedBox(height: 7),

                          Text(
                            'Retrieving registered accounts...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
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

                  const SizedBox(height: 18),

                  // ---------------------------------------------------
                  // USER ACCOUNT OVERVIEW
                  // ---------------------------------------------------
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildUserSummaryCard(
                          icon: Icons.people_outline_rounded,
                          count: _allUsers.length,
                          label: 'Total Users',
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: _buildUserSummaryCard(
                          icon: Icons.admin_panel_settings_outlined,
                          count: _allUsers
                              .where((user) => user.role == 'admin')
                              .length,
                          label: 'Protected Admins',
                        ),
                      ),
                    ],
                  ),

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
          // USER MANAGEMENT HEADER
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
                  Icons.manage_accounts_outlined,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Management',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      'Review registered accounts and '
                      'manage their authorised system roles.',
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
          // ROLE MANAGEMENT INFORMATION
          // ---------------------------------------------------
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: AppColors.primary, size: 19),

              SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Administrator roles cannot be changed '
                  'through this management screen.',
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

  Widget _buildUserSummaryCard({
    required IconData icon,
    required int count,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),

          const SizedBox(height: 14),

          Text(
            '$count',
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            label,
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

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onChanged: (value) {
        setState(() {
          _searchText = value;
        });
      },
      style: const TextStyle(color: AppColors.navy, fontSize: 13.5),
      decoration: InputDecoration(
        hintText: 'Search name, email or role',
        hintStyle: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 13,
        ),

        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.primary,
          size: 22,
        ),

        suffixIcon: _searchText.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.secondaryText,
                  size: 20,
                ),
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    _searchText = '';
                  });
                },
              ),

        filled: true,
        fillColor: Colors.white,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildUserCard(SystemUser user) {
    final bool isAdmin = user.role == 'admin';
    final bool isUpdating = _updatingUserId == user.id;

    final String displayName = user.fullName.trim().isNotEmpty
        ? user.fullName.trim()
        : 'Unnamed User';

    final String displayEmail = user.email.trim().isNotEmpty
        ? user.email.trim()
        : 'No email recorded';

    final String avatarInitial = user.fullName.trim().isNotEmpty
        ? user.fullName.trim()[0].toUpperCase()
        : user.email.trim().isNotEmpty
        ? user.email.trim()[0].toUpperCase()
        : 'U';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          // ACCOUNT AVATAR AND INFORMATION
          // ---------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Text(
                  avatarInitial,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      softWrap: true,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      displayEmail,
                      softWrap: true,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 15),

          // ---------------------------------------------------
          // ROLE AND REGISTRATION INFORMATION
          // ---------------------------------------------------
          const Text(
            'ACCOUNT INFORMATION',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),

          const SizedBox(height: 11),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildRoleBadge(user.role),

              _buildInfoChip('Joined ${_formatDate(user.createdAt)}'),
            ],
          ),

          const SizedBox(height: 17),

          // ---------------------------------------------------
          // ROLE MANAGEMENT / PROTECTED ADMIN
          // ---------------------------------------------------
          if (!isAdmin)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _updatingUserId != null
                    ? null
                    : () {
                        _changeUserRole(user);
                      },
                icon: isUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.manage_accounts_outlined, size: 19),
                label: Text(isUpdating ? 'Updating Role...' : 'Manage Role'),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.primary,
                    size: 19,
                  ),

                  SizedBox(width: 9),

                  Expanded(
                    child: Text(
                      'Administrator role is protected '
                      'and cannot be changed here.',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
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
    final bool isSearchEmpty = title == 'No matching users';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Icon(
              isSearchEmpty
                  ? Icons.search_off_rounded
                  : Icons.people_outline_rounded,
              color: AppColors.primary,
              size: 31,
            ),
          ),

          const SizedBox(height: 16),

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

          if (isSearchEmpty) ...[
            const SizedBox(height: 17),

            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();

                setState(() {
                  _searchText = '';
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Clear Search'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.primary,
              size: 30,
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Unable to Load User Accounts',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'User accounts could not be retrieved. '
            'Please check your connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 18),

          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleOption({
    required String role,
    required String selectedRole,
  }) {
    final bool isSelected = selectedRole == role;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryLight : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: RadioListTile<String>(
        value: role,
        selected: isSelected,
        activeColor: AppColors.primary,
        dense: true,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              _roleIcon(role),
              color: isSelected ? AppColors.primary : AppColors.secondaryText,
              size: 21,
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatRole(role),
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.navy,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    _roleDescription(role),
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
