import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'login_screen.dart';

class TravellerSettingsScreen extends StatefulWidget {
  const TravellerSettingsScreen({
    super.key,
  });

  @override
  State<TravellerSettingsScreen> createState() =>
      _TravellerSettingsScreenState();
}

class _TravellerSettingsScreenState
    extends State<TravellerSettingsScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  bool _isLoggingOut = false;

  Future<Map<String, dynamic>?> _loadProfile() async {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    return _userService.getUserProfile(user.uid);
  }

  Future<void> _confirmLogout() async {
    final bool? confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text(
            'Are you sure you want to log out of '
                'TravelGuard MY?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                const Color(0xFFC62828),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted ||
        _isLoggingOut) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) =>
          const LoginScreen(),
        ),
            (route) => false,
      );
    } catch (e) {
      debugPrint('LOGOUT ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to log out. Please try again.',
          ),
        ),
      );
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE4E8EC),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? firebaseUser =
        FirebaseAuth.instance.currentUser;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadProfile(),
      builder: (context, snapshot) {
        final Map<String, dynamic>? profile =
            snapshot.data;

        final String fullName =
            (profile?['fullName'] as String?)?.trim() ??
                firebaseUser?.displayName?.trim() ??
                'Traveller';

        final String email =
            (profile?['email'] as String?)?.trim() ??
                firebaseUser?.email ??
                'Not available';

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            110,
          ),
          children: [
            _buildSectionTitle('ACCOUNT'),

            _buildSettingsCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor:
                    const Color(0xFFE8F6F7),
                    child: Text(
                      fullName.isNotEmpty
                          ? fullName[0].toUpperCase()
                          : 'T',
                      style: const TextStyle(
                        color: Color(0xFF087F8C),
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Traveller',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF087F8C),
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            _buildSectionTitle('APPLICATION'),

            _buildSettingsCard(
              child: const Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.info_outline_rounded,
                    ),
                    title: Text(
                      'About TravelGuard MY',
                    ),
                    subtitle: Text(
                      'AI-Based Travel Preparation '
                          'Decision Support System',
                    ),
                  ),
                  Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.apps_rounded,
                    ),
                    title: Text('Version'),
                    trailing: Text(
                      '1.0.0',
                      style: TextStyle(
                        color: Colors.black54,
                      ),
                    ),
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
                  foregroundColor:
                  const Color(0xFFC62828),
                  side: const BorderSide(
                    color: Color(0xFFC62828),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isLoggingOut
                    ? null
                    : _confirmLogout,
                icon: _isLoggingOut
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.logout_rounded,
                ),
                label: Text(
                  _isLoggingOut
                      ? 'Logging Out...'
                      : 'Log Out',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}