import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.initialEmail = '',
    this.sendResetEmail,
  });

  final String initialEmail;

  // Tests supply a sender so no real account or email service is contacted.
  final Future<void> Function(String email)? sendResetEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail.trim(),
  );
  late final _authService = AuthService();

  Timer? _resendTimer;
  bool _isSending = false;
  bool _requestAccepted = false;
  int _resendSeconds = 0;
  String? _errorMessage;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) timer.cancel();
    });
  }

  void _showAcceptedRequest() {
    setState(() {
      _requestAccepted = true;
      _errorMessage = null;
    });
    _startCooldown();
  }

  Future<void> _sendResetEmail() async {
    if (_isSending || _resendSeconds > 0) return;
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    FocusScope.of(context).unfocus();
    setState(() {
      _isSending = true;
      _requestAccepted = false;
      _errorMessage = null;
    });

    try {
      final sender = widget.sendResetEmail;
      if (sender != null) {
        await sender(email);
      } else {
        await _authService.sendPasswordResetEmail(email: email);
      }
      if (!mounted) return;
      _showAcceptedRequest();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      if (error.code == 'user-not-found') {
        // Keep confirmation identical whether an account exists or not.
        _showAcceptedRequest();
      } else {
        setState(() {
          _errorMessage = switch (error.code) {
            'invalid-email' => 'Please enter a valid email address.',
            'network-request-failed' =>
              'Check your internet connection and try again.',
            'too-many-requests' =>
              'Too many requests. Please wait before trying again.',
            _ => 'Unable to request a reset email. Please try again later.',
          };
        });
        if (error.code == 'too-many-requests') _startCooldown();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Unable to request a reset email. Please try again later.';
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonLabel = _isSending
        ? 'Sending...'
        : _resendSeconds > 0
        ? 'Resend in ${_resendSeconds}s'
        : _requestAccepted
        ? 'Resend reset email'
        : 'Send reset email';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('TravelGuard MY'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primaryLight,
                      child: Icon(
                        Icons.lock_reset_rounded,
                        color: AppColors.primary,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Forgot password?',
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
                    'Enter the email address used for email and password sign-in.',
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
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              enabled: !_isSending,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isEmpty) {
                                  return 'Please enter your email.';
                                }
                                if (!_emailPattern.hasMatch(email)) {
                                  return 'Please enter a valid email address.';
                                }
                                return null;
                              },
                              onChanged: (_) {
                                if (_requestAccepted || _errorMessage != null) {
                                  setState(() {
                                    _requestAccepted = false;
                                    _errorMessage = null;
                                  });
                                }
                              },
                              onFieldSubmitted: (_) => _sendResetEmail(),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _isSending || _resendSeconds > 0
                                  ? null
                                  : _sendResetEmail,
                              child: Text(buttonLabel),
                            ),
                            if (_isSending)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Semantics(
                                  liveRegion: true,
                                  label: 'Requesting a password reset email.',
                                  child: const LinearProgressIndicator(
                                    minHeight: 3,
                                  ),
                                ),
                              ),
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_requestAccepted)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Check your inbox',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'If this email is registered, a password reset '
                                'link will be sent. Check the inbox and spam '
                                'folder. Follow the link to choose a new '
                                'password, then return to sign in.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'For Google sign-in, use Continue with Google on the login screen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
