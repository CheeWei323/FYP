import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/role_ui_widgets.dart';
import '../login_screen.dart';
import '../privacy_notice_screen.dart';

class ContentManagerProfileScreen extends StatefulWidget {
  const ContentManagerProfileScreen({super.key});

  @override
  State<ContentManagerProfileScreen> createState() =>
      _ContentManagerProfileScreenState();
}

class _ContentManagerProfileScreenState
    extends State<ContentManagerProfileScreen> {
  // ---------------------------------------------------------------------------
  // PROFILE DATA AND RECOVERY
  // ---------------------------------------------------------------------------

  final _userService = UserService();
  final _authService = AuthService();
  Map<String, dynamic>? _profile;
  bool _loading = false;
  bool _failed = false;
  bool _isLoggingOut = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // Keep existing account details if a later refresh fails.
  Future<void> _loadProfile() async {
    if (_isLoggingOut) return;
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('No authenticated Content Manager.');
      final profile = await _userService.getUserProfile(user.uid);
      if (profile == null) {
        throw StateError('Content Manager profile not found.');
      }
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _profile = profile;
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

  // ---------------------------------------------------------------------------
  // CONFIRMED LOGOUT
  // ---------------------------------------------------------------------------

  Future<void> _confirmLogout() async {
    if (_isLoggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const SingleChildScrollView(
          child: Text(
            'You will need to sign in again to access your Content Manager account.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _isLoggingOut) return;
    setState(() {
      _isLoggingOut = true;
    });

    try {
      // Clear the authenticated navigation stack after the existing sign-out call.
      await _authService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to log out. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = (_profile?['fullName'] as String?)?.trim();
    final displayName = name != null && name.isNotEmpty
        ? name
        : user?.displayName ?? 'Content Manager';
    final email =
        (_profile?['email'] as String?)?.trim() ??
        user?.email ??
        'Not available';

    return RolePageBody(
      storageId: 'content-manager-profile',
      onRefresh: _loadProfile,
      children: [
        RoleIntroCard(
          eyebrow: 'Content Manager',
          title: displayName,
          description: 'Your account and system access.',
          icon: Icons.policy_outlined,
        ),
        const SizedBox(height: 18),
        if (_loading)
          const RoleStatusCard(
            title: 'Loading your profile',
            message: 'Retrieving your account details.',
            loading: true,
          ),
        if (_failed)
          RoleStatusCard(
            title: 'Unable to refresh your profile',
            message: _profile == null
                ? 'Check your connection and try again.'
                : 'Showing the last loaded profile.',
            icon: Icons.cloud_off_outlined,
            onRetry: _loading || _isLoggingOut ? null : _loadProfile,
          ),
        if (_profile != null) ...[
          const RoleSectionTitle(title: 'Account details'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EMAIL ADDRESS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(email, style: const TextStyle(color: AppColors.navy)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1),
                  ),
                  const RoleBadge(label: 'Content Manager'),
                  const SizedBox(height: 12),
                  const Text(
                    'Maintain travel regulations, official sources and regulatory activity.',
                  ),
                ],
              ),
            ),
          ),
        ],
        const RoleSectionTitle(title: 'Application'),
        RoleActionTile(
          title: 'Privacy Notice',
          description: 'Review how TravelGuard MY handles information.',
          icon: Icons.privacy_tip_outlined,
          onTap: _isLoggingOut
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PrivacyNoticeScreen(),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isLoggingOut ? null : _confirmLogout,
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
          icon: _isLoggingOut
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_rounded),
          label: Text(_isLoggingOut ? 'Logging out...' : 'Log out'),
        ),
      ],
    );
  }
}
