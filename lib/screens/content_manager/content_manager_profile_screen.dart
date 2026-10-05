import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/user_service.dart';
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

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _borderColor = Color(0xFFE1E7EC);

  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();

    _profileFuture = _loadProfile();
  }

  // ---------------------------------------------------------------------------
  // PROFILE
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
  // LOGOUT
  // ---------------------------------------------------------------------------

  Future<void> _logout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text(
            'Are you sure you want to log out of your Content Manager account?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _authService.signOut();

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Unable to log out. Please try again.')),
        );
    }
  }

  // ---------------------------------------------------------------------------
  // ROLE FORMAT
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
  // SCREEN
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 220),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }

          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [const SizedBox(height: 120), _buildErrorCard()],
            );
          }

          final Map<String, dynamic>? profile = snapshot.data;

          if (profile == null) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [const SizedBox(height: 120), _buildErrorCard()],
            );
          }

          final String fullName =
              profile['fullName'] as String? ?? 'Content Manager';

          final String email = profile['email'] as String? ?? '';

          final String role = _formatRole(
            profile['role'] as String? ?? 'contentManager',
          );

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
            children: [
              _buildProfileHeader(fullName: fullName, email: email),

              const SizedBox(height: 24),

              const Text(
                'Account Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _darkTextColor,
                ),
              ),

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
                value: email.isEmpty ? 'Not available' : email,
              ),

              const SizedBox(height: 10),

              _buildInformationCard(
                icon: Icons.badge_outlined,
                label: 'Account Role',
                value: role,
              ),

              const SizedBox(height: 26),

              const Text(
                'Account Access',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _darkTextColor,
                ),
              ),

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
  // PROFILE HEADER
  // ---------------------------------------------------------------------------

  Widget _buildProfileHeader({
    required String fullName,
    required String email,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE7F7F8), Color(0xFFF1F8FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBE8EB)),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFD8E6EE)),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 40,
              color: _primaryColor,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _darkTextColor,
            ),
          ),

          const SizedBox(height: 5),

          if (email.isNotEmpty)
            Text(
              email,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Content Manager',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INFORMATION
  // ---------------------------------------------------------------------------

  Widget _buildInformationCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _primaryColor, size: 21),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _darkTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessCard() {
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
          Icon(Icons.verified_user_outlined, color: _primaryColor, size: 25),

          SizedBox(width: 13),

          Expanded(
            child: Text(
              'This account is authorised to maintain travel '
              'regulation information, review publication status '
              'and access regulatory activity history.',
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

  // ---------------------------------------------------------------------------
  // LOGOUT BUTTON
  // ---------------------------------------------------------------------------

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout_rounded),
        label: const Text(
          'Log Out',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFB42318),
          side: const BorderSide(color: Color(0xFFF0B7B2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ERROR
  // ---------------------------------------------------------------------------

  Widget _buildErrorCard() {
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
            'Unable to load account information.',
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
