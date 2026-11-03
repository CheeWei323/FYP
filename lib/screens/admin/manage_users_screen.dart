import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/system_user.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/role_ui_widgets.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  // ---------------------------------------------------------------------------
  // ACCOUNT LIST STATE
  // ---------------------------------------------------------------------------

  final _service = AdminService();
  final _searchController = TextEditingController();
  List<SystemUser>? _users;
  String _search = '';
  String _roleFilter = 'all';
  String? _savingUserId;
  bool _loading = false;
  bool _failed = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Keep the last list after a failed refresh and ignore superseded responses.
  Future<void> _loadUsers() async {
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
    });
    try {
      final users = await _service.getUsers();
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _users = users;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _failed = true;
      });
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // Avoid refreshing the list while a role update is still being saved.
  Future<void> _refresh() async {
    if (_savingUserId != null) return;
    await _loadUsers();
  }

  // ---------------------------------------------------------------------------
  // ROLE LABELS AND LOCAL FILTERS
  // ---------------------------------------------------------------------------

  String _roleLabel(String role) => switch (role) {
    'traveller' => 'Traveller',
    'contentManager' => 'Content Manager',
    'analyst' => 'Tourism Data Analyst',
    'admin' => 'System Administrator',
    _ => role.isEmpty ? 'Unknown role' : role,
  };

  String _roleDescription(String role) => switch (role) {
    'traveller' => 'Prepare trips, check requirements and plan routes.',
    'contentManager' => 'Maintain travel regulations and source information.',
    'analyst' => 'Review tourism analytics and create reports.',
    _ => '',
  };

  List<SystemUser> get _visibleUsers {
    final query = _search.trim().toLowerCase();
    return (_users ?? []).where((user) {
      final matchesRole = _roleFilter == 'all' || user.role == _roleFilter;
      final matchesSearch =
          query.isEmpty ||
          '${user.fullName} ${user.email} ${user.role} ${_roleLabel(user.role)}'
              .toLowerCase()
              .contains(query);
      return matchesRole && matchesSearch;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // ROLE UPDATE AND CONFIRMATION
  // ---------------------------------------------------------------------------

  Future<void> _changeRole(SystemUser user) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (_savingUserId != null ||
        _failed ||
        _loading ||
        user.role == 'admin' ||
        user.id == currentUid) {
      return;
    }
    String selection = user.role;

    // Offer only the three roles already allowed by AdminService and Firestore.
    final newRole = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('Change user role'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isEmpty ? user.email : user.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text('Choose the access this account should have.'),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  groupValue: selection,
                  onChanged: (value) {
                    if (value == null) return;
                    updateDialog(() {
                      selection = value;
                    });
                  },
                  child: Column(
                    children: [
                      for (final role in [
                        'traveller',
                        'contentManager',
                        'analyst',
                      ])
                        RadioListTile<String>(
                          value: role,
                          contentPadding: EdgeInsets.zero,
                          title: Text(_roleLabel(role)),
                          subtitle: Text(_roleDescription(role)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selection == user.role
                  ? null
                  : () => Navigator.pop(dialogContext, selection),
              child: const Text('Review change'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || newRole == null || newRole == user.role) return;

    // Keep a separate confirmation before changing another account's access.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm role change'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.email,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Text('Current role: ${_roleLabel(user.role)}'),
              const SizedBox(height: 8),
              Text('New role: ${_roleLabel(newRole)}'),
              const SizedBox(height: 16),
              const Text(
                'This changes the features and permissions available to this account.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _savingUserId = user.id;
    });

    try {
      // The existing service verifies permissions and writes its activity log.
      await _service.updateUserRole(user: user, newRole: newRole);
      if (!mounted) return;
      _showMessage('Role updated to ${_roleLabel(newRole)}.');
      await _loadUsers();
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to update this role. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _savingUserId = null;
        });
      }
    }
  }

  // Replace earlier feedback so messages do not queue behind each other.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleUsers;
    final body = RolePageBody(
      storageId: 'admin-users',
      onRefresh: _refresh,
      children: [
        const RoleIntroCard(
          eyebrow: 'Account management',
          title: 'The right access for every role.',
          description:
              'Find an account, review its role and confirm any access changes.',
          icon: Icons.manage_accounts_outlined,
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() {
            _search = value;
          }),
          decoration: InputDecoration(
            labelText: 'Search accounts',
            hintText: 'Name, email or role',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _search = '';
                      });
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final filter in [
              ('all', 'All'),
              ('traveller', 'Travellers'),
              ('contentManager', 'Content Managers'),
              ('analyst', 'Analysts'),
              ('admin', 'Administrators'),
            ])
              ChoiceChip(
                label: Text(filter.$2),
                selected: _roleFilter == filter.$1,
                onSelected: (_) => setState(() {
                  _roleFilter = filter.$1;
                }),
              ),
          ],
        ),
        RoleSectionTitle(
          title: _users == null
              ? 'Accounts'
              : 'Accounts · ${visible.length} of ${_users!.length}',
        ),
        if (_loading)
          const RoleStatusCard(
            title: 'Loading accounts',
            message: 'Retrieving the latest account roles.',
            loading: true,
          ),
        if (_failed)
          RoleStatusCard(
            title: 'Unable to refresh accounts',
            message: _users == null
                ? 'Check your connection and try again.'
                : 'Showing the last loaded accounts. Refresh before changing a role.',
            icon: Icons.cloud_off_outlined,
            onRetry: _loading ? null : _refresh,
          ),
        if (_users != null && visible.isEmpty && !_loading)
          RoleStatusCard(
            title: _users!.isEmpty ? 'No accounts yet' : 'No matching accounts',
            message: _users!.isEmpty
                ? 'Registered accounts will appear here.'
                : 'Try another name, email or role filter.',
            icon: Icons.person_search_outlined,
          ),
        for (final user in visible) _accountCard(user),
      ],
    );
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: const Text('Users')),
            body: SafeArea(child: body),
          );
  }

  Widget _accountCard(SystemUser user) {
    final protected =
        user.role == 'admin' ||
        user.id == FirebaseAuth.instance.currentUser?.uid;
    final saving = _savingUserId == user.id;
    return Card(
      key: ValueKey('account-${user.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              user.fullName.isEmpty ? 'Unnamed account' : user.fullName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(user.email),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: RoleBadge(label: _roleLabel(user.role)),
            ),
            const SizedBox(height: 12),
            Text(
              'Joined ${formatRoleDate(user.createdAt)}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              'Updated ${formatRoleDate(user.updatedAt)}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            if (protected)
              const Text(
                'Administrator access is managed separately.',
                style: TextStyle(fontSize: 12),
              )
            else
              OutlinedButton.icon(
                onPressed: _savingUserId != null || _loading || _failed
                    ? null
                    : () => _changeRole(user),
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.manage_accounts_outlined),
                label: Text(saving ? 'Updating role...' : 'Change role'),
              ),
          ],
        ),
      ),
    );
  }
}
