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
        return 'Access travel planning, requirements and packing features.';

      case 'contentManager':
        return 'Maintain and review regulatory travel information.';

      case 'analyst':
        return 'Access tourism data analytics and reporting features.';

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
        return AlertDialog(
          icon: const Icon(
            Icons.manage_accounts_outlined,
            color: _primaryColor,
            size: 32,
          ),
          title: const Text('Confirm Role Change', textAlign: TextAlign.center),
          content: Text(
            'Change ${user.fullName.isEmpty ? 'this account' : user.fullName} '
            'from ${_formatRole(user.role)} to '
            '${_formatRole(newRole)}?',
            textAlign: TextAlign.center,
          ),
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
                  'manage their authorised roles.',
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
                if (user.role != 'admin') ...[
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: _updatingUserId != null
                          ? null
                          : () => _changeUserRole(user),
                      icon: _updatingUserId == user.id
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.manage_accounts_outlined,
                              size: 18,
                            ),
                      label: const Text('Manage Role'),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),

                  const Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 15,
                        color: Colors.black38,
                      ),

                      SizedBox(width: 5),

                      Text(
                        'Administrator role is protected',
                        style: TextStyle(fontSize: 10.5, color: Colors.black45),
                      ),
                    ],
                  ),
                ],
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

  Widget _buildRoleOption({
    required String role,
    required String selectedRole,
  }) {
    final bool selected = selectedRole == role;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE8F6F7) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? _primaryColor : _borderColor),
      ),
      child: RadioListTile<String>(
        value: role,
        activeColor: _primaryColor,
        title: Row(
          children: [
            Icon(
              _roleIcon(role),
              size: 19,
              color: selected ? _primaryColor : const Color(0xFF486581),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Text(
                _formatRole(role),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? _primaryColor : _darkTextColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            _roleDescription(role),
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.3,
              color: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}
