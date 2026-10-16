import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_travel_mark.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  // ---------------------------------------------------------------------------
  // VERIFICATION STATE AND RESEND COOLDOWN
  // ---------------------------------------------------------------------------

  final _authService = AuthService();
  bool _isChecking = false;
  bool _isResending = false;
  bool _isLeaving = false;
  int _resendSeconds = 60;
  Timer? _resendTimer;

  // Keep verification, resending and sign-out from overlapping.
  bool get _isBusy => _isChecking || _isResending || _isLeaving;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  // Start the existing 60-second wait after entry or a successful resend.
  void _startResendTimer() {
    if (!mounted) return;
    _resendTimer?.cancel();
    setState(() {
      _resendSeconds = 60;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendSeconds--;
      });
      if (_resendSeconds <= 0) timer.cancel();
    });
  }

  // Stop cooldown updates when this screen leaves the navigation stack.
  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // VERIFY THE SIGNED-IN EMAIL
  // ---------------------------------------------------------------------------

  // Reload Firebase before checking verification; the email link opens externally.
  Future<void> _checkVerification() async {
    if (_isBusy) return;
    setState(() {
      _isChecking = true;
    });
    try {
      final user = await _authService.reloadUser();
      if (!mounted) return;
      if (user == null) {
        _showMessage(
          'Your session has ended. Return to Login and sign in again.',
        );
        return;
      }
      if (!user.emailVerified) {
        _showMessage(
          'Your email has not been verified yet. Open the email link, then try again.',
        );
        return;
      }

      // Keep the existing requirement to log in again after verification.
      await _authService.signOut();
      if (!mounted) return;
      _showMessage('Email verified successfully. Please log in.');
      _returnToLogin();
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to check verification status. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // RESEND VERIFICATION EMAIL
  // ---------------------------------------------------------------------------

  // Only report success after Firebase sends an email for an unverified session.
  Future<void> _resendVerification() async {
    if (_isBusy || _resendSeconds > 0) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage(
        'Your session has ended. Return to Login and sign in again.',
      );
      return;
    }
    if (user.emailVerified) {
      _showMessage(
        'Your email is already verified. Select "I\'ve Verified" to continue.',
      );
      return;
    }
    setState(() {
      _isResending = true;
    });
    try {
      await _authService.resendVerificationEmail();
      if (!mounted) return;
      _startResendTimer();
      _showMessage(
        'Verification email sent. Check your inbox and spam folder.',
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'too-many-requests' =>
          'Too many requests. Please wait before requesting another email.',
        'network-request-failed' =>
          'Check your internet connection and try again.',
        _ => 'Unable to resend the verification email. Please try again later.',
      };
      _showMessage(message);
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Unable to resend the verification email. Please try again later.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // RETURN TO LOGIN AND ACTION FEEDBACK
  // ---------------------------------------------------------------------------

  // Sign out before leaving, and keep the screen usable if sign-out fails.
  Future<void> _backToLogin() async {
    if (_isBusy) return;
    setState(() {
      _isLeaving = true;
    });
    try {
      await _authService.signOut();
      if (!mounted) return;
      _returnToLogin();
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to return to Login. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLeaving = false;
        });
      }
    }
  }

  // Reuse the underlying login screen, with a fallback for a root verification page.
  void _returnToLogin() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
    }
  }

  // Replace older feedback so repeated checks show one clear message.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_isBusy) _backToLogin();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          leading: IconButton(
            tooltip: 'Back to Login',
            onPressed: _isBusy ? null : _backToLogin,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('TravelGuard MY'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AnimatedTravelMark(size: 92)),
                    const SizedBox(height: 14),
                    const Text(
                      'Check your inbox',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Verify your email to continue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.mark_email_unread_outlined,
                            size: 32,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            email ?? 'Your sign-in session has ended.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _VerificationStep(
                            number: '1',
                            title: 'Open the email',
                            description:
                                'Look for the verification message in your inbox or spam folder.',
                          ),
                          const SizedBox(height: 16),
                          const _VerificationStep(
                            number: '2',
                            title: 'Select the verification link',
                            description:
                                'Follow the link to confirm your email address.',
                          ),
                          const SizedBox(height: 16),
                          const _VerificationStep(
                            number: '3',
                            title: 'Return here to confirm',
                            description:
                                'Select "I\'ve Verified" below, then log in again.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isBusy ? null : _checkVerification,
                      icon: _isChecking
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_outlined),
                      label: Text(
                        _isChecking ? 'Checking...' : "I've Verified",
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isBusy || _resendSeconds > 0
                          ? null
                          : _resendVerification,
                      icon: _isResending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.forward_to_inbox_outlined),
                      label: Text(
                        _isResending
                            ? 'Sending...'
                            : _resendSeconds > 0
                            ? 'Resend email in ${_resendSeconds}s'
                            : 'Resend email',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _isBusy ? null : _backToLogin,
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: Text(
                        _isLeaving ? 'Returning to Login...' : 'Back to Login',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerificationStep extends StatelessWidget {
  const _VerificationStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
