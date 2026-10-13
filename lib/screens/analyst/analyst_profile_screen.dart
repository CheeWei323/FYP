import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../login_screen.dart';

class AnalystProfileScreen extends StatefulWidget {
  const AnalystProfileScreen({super.key});

  @override
  State<AnalystProfileScreen> createState() => _AnalystProfileScreenState();
}

class _AnalystProfileScreenState extends State<AnalystProfileScreen> {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  // Cached Firestore profile.
  Map<String, dynamic>? _profileData;

  bool _profileLoading = true;
  bool _profileError = false;
  bool _isLoggingOut = false;

  // Prevent outdated requests from replacing newer profile data.
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ---------------------------------------------------------------------------
  // LOAD PROFILE
  // ---------------------------------------------------------------------------

  Future<void> _loadProfile() async {
    final int requestVersion = ++_requestVersion;

    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('No authenticated tourism data analyst.');
      }

      final Map<String, dynamic>? profile = await _userService.getUserProfile(
        user.uid,
      );

      if (profile == null) {
        throw Exception('Tourism Data Analyst profile was not found.');
      }

      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _profileData = profile;
        _profileLoading = false;
        _profileError = false;
      });
    } catch (error) {
      debugPrint('ANALYST PROFILE ERROR: $error');

      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      final bool hadCachedData = _profileData != null;

      setState(() {
        _profileLoading = false;
        _profileError = true;
      });

      // Keep the previously loaded profile visible if
      // a refresh fails.
      if (hadCachedData) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to refresh profile. '
                'Showing previously loaded information.',
              ),
            ),
          );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  Future<void> _refresh() async {
    await _loadProfile();
  }

  // ---------------------------------------------------------------------------
  // RETRY
  // ---------------------------------------------------------------------------

  void _retryProfile() {
    setState(() {
      _profileLoading = true;
      _profileError = false;
    });

    _loadProfile();
  }

  // ---------------------------------------------------------------------------
  // LOGOUT CONFIRMATION
  // ---------------------------------------------------------------------------

  Future<void> _confirmLogout() async {
    if (_isLoggingOut) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,

      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          icon: const Icon(
            Icons.logout_rounded,
            color: AppColors.danger,
            size: 32,
          ),

          title: const Text(
            'Log Out',
            textAlign: TextAlign.center,

            style: TextStyle(
              color: AppColors.navy,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),

          content: const Text(
            'Are you sure you want to log out '
            'of the Tourism Data Analyst account?',
            textAlign: TextAlign.center,

            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
              height: 1.5,
            ),
          ),

          actionsAlignment: MainAxisAlignment.center,

          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },

              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondaryText,

                side: const BorderSide(color: AppColors.border),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),

              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },

              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),

              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _logout();
  }

  // ---------------------------------------------------------------------------
  // SIGN OUT
  // ---------------------------------------------------------------------------

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      // Preserve the existing authentication service.
      await _authService.signOut();

      if (!mounted) {
        return;
      }

      // Prevent returning to authenticated pages
      // using the Android back button.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (error) {
      debugPrint('ANALYST LOGOUT ERROR: $error');

      if (!mounted) {
        return;
      }

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
  // MAIN SCREEN
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? profile = _profileData;

    final String fullName = (profile?['fullName'] as String? ?? '').trim();

    final String email = (profile?['email'] as String? ?? '').trim();

    // This screen is displayed inside AnalystDashboard,
    // which already provides the AppBar and bottom navigation.
    return ColoredBox(
      color: AppColors.background,

      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,

          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),

            padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),

            children: [
              if (profile == null)
                _buildProfileStatus()
              else ...[
                _buildProfileHeader(fullName: fullName, email: email),

                const SizedBox(height: 26),

                _buildSectionTitle('Account Information'),

                const SizedBox(height: 13),

                _buildInformationCard(
                  icon: Icons.person_outline_rounded,
                  label: 'Full Name',
                  value: fullName.isEmpty ? 'Not recorded' : fullName,
                ),

                const SizedBox(height: 11),

                _buildInformationCard(
                  icon: Icons.email_outlined,
                  label: 'Email Address',
                  value: email.isEmpty ? 'Not recorded' : email,
                ),

                const SizedBox(height: 11),

                _buildInformationCard(
                  icon: Icons.analytics_outlined,
                  label: 'System Role',
                  value: 'Tourism Data Analyst',
                ),

                const SizedBox(height: 27),

                _buildSectionTitle('Account Access'),

                const SizedBox(height: 13),

                _buildAccessCard(),
              ],

              const SizedBox(height: 28),

              _buildLogoutButton(),
            ],
          ),
        ),
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
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 23, 20, 22),

      decoration: _cardDecoration(),

      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,

            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,

              border: Border.all(color: AppColors.border),
            ),

            child: const Icon(
              Icons.analytics_outlined,
              color: AppColors.primary,
              size: 37,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            fullName.isEmpty ? 'Tourism Data Analyst' : fullName,

            textAlign: TextAlign.center,

            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            email.isEmpty ? 'Email not recorded' : email,

            textAlign: TextAlign.center,

            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),

            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),

            child: const Row(
              mainAxisSize: MainAxisSize.min,

              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: AppColors.primary,
                ),

                SizedBox(width: 6),

                Text(
                  'TOURISM DATA ANALYST',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 13),

          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Icon(Icons.shield_outlined, color: AppColors.primary, size: 18),

              SizedBox(width: 9),

              Expanded(
                child: Text(
                  'Analyst access is limited to aggregated '
                  'travel preparation information.',
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
          _AnalystProfileIcon(icon: icon, size: 45),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13.5,
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
  // ACCOUNT ACCESS INFORMATION
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
                      'Analytics Access',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    SizedBox(height: 7),

                    Text(
                      'This account has read-only access '
                      'to aggregated travel analytics.',
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

          const SizedBox(height: 13),

          _buildAccessItem(Icons.public_outlined, 'Destination Trends'),

          const SizedBox(height: 11),

          _buildAccessItem(
            Icons.donut_large_outlined,
            'Travel Purpose Distribution',
          ),

          const SizedBox(height: 11),

          _buildAccessItem(Icons.task_alt_outlined, 'Checklist Completion'),

          const SizedBox(height: 11),

          _buildAccessItem(Icons.insights_outlined, 'Requirement Patterns'),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACCESS ITEM
  // ---------------------------------------------------------------------------

  Widget _buildAccessItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
        onPressed: _isLoggingOut ? null : _confirmLogout,

        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,

          side: const BorderSide(color: AppColors.danger),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),

        icon: _isLoggingOut
            ? const SizedBox(
                width: 18,
                height: 18,

                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.danger,
                ),
              )
            : const Icon(Icons.logout_rounded, size: 20),

        label: Text(
          _isLoggingOut ? 'Logging Out...' : 'Log Out',

          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LOADING / ERROR STATE
  // ---------------------------------------------------------------------------

  Widget _buildProfileStatus() {
    final bool isLoading = _profileLoading && !_profileError;

    return Container(
      width: double.infinity,

      constraints: const BoxConstraints(minHeight: 285),

      padding: const EdgeInsets.all(23),
      decoration: _cardDecoration(),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          _AnalystProfileIcon(
            icon: _profileError
                ? Icons.cloud_off_outlined
                : Icons.person_outline_rounded,
            size: 57,
          ),

          const SizedBox(height: 15),

          Text(
            _profileError ? 'Unable to Load Profile' : 'Loading Profile',

            textAlign: TextAlign.center,

            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _profileError
                ? 'Tourism Data Analyst profile information '
                      'could not be retrieved.'
                : 'Retrieving your account information...',

            textAlign: TextAlign.center,

            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              height: 1.5,
            ),
          ),

          if (isLoading) ...[
            const SizedBox(height: 19),

            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ],

          if (_profileError) ...[
            const SizedBox(height: 17),

            OutlinedButton.icon(
              onPressed: _retryProfile,

              icon: const Icon(Icons.refresh_rounded, size: 18),

              label: const Text('Try Again'),

              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// REUSABLE PROFILE ICON
// -----------------------------------------------------------------------------

class _AnalystProfileIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _AnalystProfileIcon({required this.icon, required this.size});

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
