import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../login_screen.dart';

class AnalystProfileScreen extends StatefulWidget {
  const AnalystProfileScreen({super.key});

  @override
  State<AnalystProfileScreen> createState() => _AnalystProfileScreenState();
}

class _AnalystProfileScreenState extends State<AnalystProfileScreen> {
  final UserService _userService = UserService();

  final AuthService _authService = AuthService();

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _borderColor = Color(0xFFE1E7EC);

  late Future<Map<String, dynamic>> _profileFuture;

  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();

    _profileFuture = _loadProfile();
  }

  // ---------------------------------------------------------------------------
  // PROFILE
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _loadProfile() async {
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

    return profile;
  }

  Future<void> _refresh() async {
    final Future<Map<String, dynamic>> future = _loadProfile();

    setState(() {
      _profileFuture = future;
    });

    await future;
  }

  // ---------------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------------

  Future<void> _confirmLogout() async {
    if (_isLoggingOut) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.logout_rounded,
            color: _primaryColor,
            size: 32,
          ),
          title: const Text('Log Out', textAlign: TextAlign.center),
          content: const Text(
            'Are you sure you want to log out '
            'of the Tourism Data Analyst account?',
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
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

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
  // SCREEN
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [const SizedBox(height: 130), _buildErrorState()],
            );
          }

          final Map<String, dynamic> profile = snapshot.data ?? {};

          final String fullName = (profile['fullName'] as String? ?? '').trim();

          final String email = (profile['email'] as String? ?? '').trim();

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
                value: fullName.isEmpty ? 'Not recorded' : fullName,
              ),

              const SizedBox(height: 10),

              _buildInformationCard(
                icon: Icons.email_outlined,
                label: 'Email Address',
                value: email.isEmpty ? 'Not recorded' : email,
              ),

              const SizedBox(height: 10),

              _buildInformationCard(
                icon: Icons.analytics_outlined,
                label: 'System Role',
                value: 'Tourism Data Analyst',
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

              const SizedBox(height: 28),

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
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.analytics_outlined,
              size: 36,
              color: _primaryColor,
            ),
          ),

          const SizedBox(height: 13),

          Text(
            fullName.isEmpty ? 'Tourism Data Analyst' : fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _darkTextColor,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            email,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: Colors.black54),
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFDDF3F4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'TOURISM DATA ANALYST',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
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
      width: double.infinity,
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
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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

  // ---------------------------------------------------------------------------
  // ACCOUNT ACCESS
  // ---------------------------------------------------------------------------

  Widget _buildAccessCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FA),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFD8E6EE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: _primaryColor, size: 25),

          SizedBox(width: 13),

          Expanded(
            child: Text(
              'This account has read-only access to aggregated '
              'travel analytics, including destination trends, '
              'travel purpose patterns, checklist completion '
              'and preparation requirement patterns.',
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
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
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
                  color: Colors.red,
                ),
              )
            : const Icon(Icons.logout_rounded),
        label: Text(
          _isLoggingOut ? 'Logging Out...' : 'Log Out',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ERROR
  // ---------------------------------------------------------------------------

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
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
            'Unable to load Tourism Data Analyst profile.',
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
