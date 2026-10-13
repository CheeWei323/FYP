import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../login_screen.dart';

class ContentManagerProfileScreen extends StatefulWidget {
  const ContentManagerProfileScreen({super.key});

  @override
  State<ContentManagerProfileScreen> createState() =>
      _ContentManagerProfileScreenState();
}

class _ContentManagerProfileScreenState
    extends State<ContentManagerProfileScreen> {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  late Future<Map<String, dynamic>?> _profileFuture;

  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  // ---------------------------------------------------------------------------
  // PROFILE DATA
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> _loadProfile() async {
    final User? user = _firebaseAuth.currentUser;

    if (user == null) {
      return null;
    }

    return _userService.getUserProfile(user.uid);
  }

  Future<void> _refresh() async {
    final Future<Map<String, dynamic>?> future = _loadProfile();

    setState(() {
      _profileFuture = future;
    });

    await future;
  }

  // ---------------------------------------------------------------------------
  // ROLE FORMATTING
  // ---------------------------------------------------------------------------

  String _formatRole(String role) {
    switch (role) {
      case 'contentManager':
        return 'Content Manager';

      case 'traveller':
        return 'Traveller';

      case 'administrator':
        return 'Administrator';

      case 'tourismDataAnalyst':
        return 'Tourism Data Analyst';

      default:
        return role;
    }
  }

  // ---------------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------------

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),

          // -------------------------------------------------
          // CONFIRMATION HEADER
          // -------------------------------------------------
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.danger,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Text(
                  'Log Out',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          // -------------------------------------------------
          // CONFIRMATION MESSAGE
          // -------------------------------------------------
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to log out of '
                'your Content Manager account?',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),

              SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),

                  SizedBox(width: 9),

                  Expanded(
                    child: Text(
                      'You will need to sign in again '
                      'to access the Content Manager workspace.',
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

          // -------------------------------------------------
          // ACTION BUTTONS
          // -------------------------------------------------
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
              icon: const Icon(Icons.logout_rounded, size: 17),
              label: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (error) {
      debugPrint('CONTENT MANAGER LOGOUT ERROR: $error');

      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Unable to log out. Please try again.')),
        );
    }
  }

  // ---------------------------------------------------------------------------
  // SHARED CARD DECORATION
  // ---------------------------------------------------------------------------

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
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
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN SCREEN
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          // -------------------------------------------------
          // LOADING
          // -------------------------------------------------

          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildFeedbackPage(
              icon: Icons.person_outline_rounded,
              title: 'Loading Content Manager Profile',
              message: 'Retrieving your account information...',
              isLoading: true,
            );
          }

          // -------------------------------------------------
          // ERROR
          // -------------------------------------------------

          if (snapshot.hasError) {
            return _buildFeedbackPage(
              icon: Icons.cloud_off_outlined,
              title: 'Unable to Load Profile',
              message:
                  'Account information could not be retrieved. '
                  'Please check your connection and try again.',
              onRetry: _refresh,
            );
          }

          final Map<String, dynamic>? profile = snapshot.data;

          if (profile == null) {
            return _buildFeedbackPage(
              icon: Icons.person_off_outlined,
              title: 'Profile Not Available',
              message:
                  'No Content Manager profile was found '
                  'for the current account.',
              onRetry: _refresh,
            );
          }

          // -------------------------------------------------
          // ACCOUNT INFORMATION
          // -------------------------------------------------

          final String rawName = (profile['fullName'] as String? ?? '').trim();

          final String rawEmail = (profile['email'] as String? ?? '').trim();

          final String fullName = rawName.isEmpty ? 'Content Manager' : rawName;

          final String email = rawEmail.isEmpty ? 'Not recorded' : rawEmail;

          final String role = _formatRole(
            profile['role'] as String? ?? 'contentManager',
          );

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
            children: [
              _buildProfileHeader(fullName: fullName, email: email, role: role),

              const SizedBox(height: 26),

              _buildSectionTitle('Account Information'),

              const SizedBox(height: 12),

              _buildInformationCard(
                icon: Icons.person_outline_rounded,
                label: 'Full Name',
                value: fullName,
              ),

              const SizedBox(height: 10),

              _buildInformationCard(
                icon: Icons.email_outlined,
                label: 'Email Address',
                value: email,
              ),

              const SizedBox(height: 10),

              _buildInformationCard(
                icon: Icons.badge_outlined,
                label: 'Account Role',
                value: role,
              ),

              const SizedBox(height: 26),

              _buildSectionTitle('Account Access'),

              const SizedBox(height: 12),

              _buildAccessCard(),

              const SizedBox(height: 26),

              _buildLogoutButton(),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION TITLE
  // ---------------------------------------------------------------------------

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.navy,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PROFILE HEADER
  // ---------------------------------------------------------------------------

  Widget _buildProfileHeader({
    required String fullName,
    required String email,
    required String role,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.manage_accounts_outlined,
                  color: AppColors.primary,
                  size: 31,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      softWrap: true,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      email,
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

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.primary,
                  size: 17,
                ),

                const SizedBox(width: 7),

                Text(
                  role.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
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
  // ACCOUNT INFORMATION CARD
  // ---------------------------------------------------------------------------

  Widget _buildInformationCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.primary, size: 23),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  value,
                  softWrap: true,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
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
  // ACCOUNT ACCESS
  // ---------------------------------------------------------------------------

  Widget _buildAccessCard() {
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
              _AccessIcon(),

              SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Content Management Access',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    SizedBox(height: 7),

                    Text(
                      'This account is authorised to '
                      'maintain travel regulation information, '
                      'review publication status and access '
                      'regulatory activity history.',
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

          const SizedBox(height: 15),

          const Divider(height: 1, color: Color(0xFFD8E6EE)),

          const SizedBox(height: 13),

          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.history_rounded, color: AppColors.primary, size: 19),

              SizedBox(width: 9),

              Expanded(
                child: Text(
                  'Travel rule changes are recorded '
                  'in regulatory activity history '
                  'for traceability.',
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

  // ---------------------------------------------------------------------------
  // LOGOUT BUTTON
  // ---------------------------------------------------------------------------

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _isLoggingOut ? null : _logout,
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
        label: Text(
          _isLoggingOut ? 'Logging Out...' : 'Log Out',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: Color(0xFFF0B7B2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LOADING / ERROR STATES
  // ---------------------------------------------------------------------------

  Widget _buildFeedbackPage({
    required IconData icon,
    required String title,
    required String message,
    bool isLoading = false,
    VoidCallback? onRetry,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(18),
      children: [
        const SizedBox(height: 70),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: AppColors.primary, size: 29),
              ),

              const SizedBox(height: 15),

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
                const SizedBox(height: 18),

                const CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              ],

              if (onRetry != null) ...[
                const SizedBox(height: 16),

                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// REUSABLE ACCESS ICON
// -----------------------------------------------------------------------------

class _AccessIcon extends StatelessWidget {
  const _AccessIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.verified_user_outlined,
        color: AppColors.primary,
        size: 24,
      ),
    );
  }
}
