import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'login_screen.dart';
import '../theme/app_theme.dart';

class TravellerSettingsScreen extends StatefulWidget {
  const TravellerSettingsScreen({super.key});

  @override
  State<TravellerSettingsScreen> createState() =>
      _TravellerSettingsScreenState();
}

class _TravellerSettingsScreenState extends State<TravellerSettingsScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  bool _isLoggingOut = false;

  late final Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<Map<String, dynamic>?> _loadProfile() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    return _userService.getUserProfile(user.uid);
  }

  Future<void> _confirmLogout() async {
    if (_isLoggingOut) return;

    // ---------------------------------------------------------
    // LOGOUT CONFIRMATION
    // ---------------------------------------------------------

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFFECEB),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: AppColors.danger,
              size: 28,
            ),
          ),

          title: const Text('Log Out?', textAlign: TextAlign.center),

          content: const Text(
            'Are you sure you want to log out of '
            'TravelGuard MY?\n\n'
            'You will need to sign in again to access '
            'your trips and travel preparation information.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
              height: 1.55,
            ),
          ),

          actionsAlignment: MainAxisAlignment.center,

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),

            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    // ---------------------------------------------------------
    // CANCELLED LOGOUT
    // ---------------------------------------------------------

    if (confirmed != true || !mounted || _isLoggingOut) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    // ---------------------------------------------------------
    // FIREBASE SIGN OUT
    // ---------------------------------------------------------

    try {
      await _authService.signOut();

      if (!mounted) return;

      // Clear navigation history after successful sign out.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('LOGOUT ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      // -------------------------------------------------------
      // LOGOUT ERROR DIALOG
      // -------------------------------------------------------

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFFECEB),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 29,
              ),
            ),

            title: const Text('Unable to Log Out', textAlign: TextAlign.center),

            content: const Text(
              'Your account could not be signed out. '
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
                height: 1.5,
              ),
            ),

            actionsAlignment: MainAxisAlignment.center,

            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('OK'),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildProfileCard({required String fullName, required String email}) {
    final String initial = fullName.trim().isNotEmpty
        ? fullName.trim()[0].toUpperCase()
        : 'T';

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
          // -----------------------------------------------------
          // PROFILE AVATAR AND NAME
          // -----------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 31,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SIGNED IN AS',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      fullName,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 9),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            color: AppColors.primary,
                            size: 15,
                          ),

                          SizedBox(width: 5),

                          Text(
                            'Traveller',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 17),

          // -----------------------------------------------------
          // ACCOUNT EMAIL
          // -----------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EMAIL ADDRESS',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      email,
                      softWrap: true,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 3, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: child,
    );
  }

  Widget _buildApplicationInfoRow({
    required IconData icon,
    required String title,
    required String subtitle,
    String? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -----------------------------------------------
        // INFORMATION ICON
        // -----------------------------------------------
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),

        const SizedBox(width: 13),

        // -----------------------------------------------
        // TITLE AND DESCRIPTION
        // -----------------------------------------------
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        // -----------------------------------------------
        // OPTIONAL VERSION BADGE
        // -----------------------------------------------
        if (trailing != null) ...[
          const SizedBox(width: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              trailing,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? firebaseUser = FirebaseAuth.instance.currentUser;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final Map<String, dynamic>? profile = snapshot.data;

        final String fullName =
            (profile?['fullName'] as String?)?.trim() ??
            firebaseUser?.displayName?.trim() ??
            'Traveller';

        final String email =
            (profile?['email'] as String?)?.trim() ??
            firebaseUser?.email ??
            'Not available';

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          children: [
            _buildSectionTitle('ACCOUNT'),

            _buildProfileCard(fullName: fullName, email: email),

            const SizedBox(height: 28),

            _buildSectionTitle('APPLICATION'),

            _buildSettingsCard(
              child: Column(
                children: [
                  _buildApplicationInfoRow(
                    icon: Icons.info_outline_rounded,
                    title: 'About TravelGuard MY',
                    subtitle:
                        'AI-Based Travel Preparation '
                        'Decision Support System '
                        'for Malaysian Travellers.',
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 17),
                    child: Divider(height: 1, color: AppColors.border),
                  ),

                  _buildApplicationInfoRow(
                    icon: Icons.apps_rounded,
                    title: 'App Version',
                    subtitle: 'Current application version',
                    trailing: '1.0.0',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            _buildSectionTitle('ACCOUNT ACTIONS'),

            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC62828),
                  side: const BorderSide(color: Color(0xFFC62828)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isLoggingOut ? null : _confirmLogout,
                icon: _isLoggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.danger,
                        ),
                      )
                    : const Icon(Icons.logout_rounded),
                label: Text(_isLoggingOut ? 'Logging Out...' : 'Log Out'),
              ),
            ),
          ],
        );
      },
    );
  }
}
