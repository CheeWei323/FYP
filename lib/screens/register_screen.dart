import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_travel_mark.dart';
import 'privacy_notice_screen.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ---------------------------------------------------------------------------
  // REGISTRATION STATE
  // ---------------------------------------------------------------------------

  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _privacyAcknowledged = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Release the form's controllers when this screen closes.
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // PRIVACY ACKNOWLEDGEMENT
  // ---------------------------------------------------------------------------

  // Only an explicit agreement on the privacy page can tick the checkbox.
  Future<void> _openPrivacyNotice() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();

    final bool? agreed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            PrivacyNoticeScreen(requestConsent: !_privacyAcknowledged),
      ),
    );

    if (!mounted || agreed != true) return;
    setState(() {
      _privacyAcknowledged = true;
    });
  }

  // Unticking immediately removes agreement; ticking opens the full notice.
  void _changePrivacyAcknowledgement(bool? checked) {
    if (_isLoading || checked == null) return;
    if (!checked) {
      setState(() {
        _privacyAcknowledged = false;
      });
      return;
    }
    _openPrivacyNotice();
  }

  // ---------------------------------------------------------------------------
  // CREATE TRAVELLER ACCOUNT
  // ---------------------------------------------------------------------------

  Future<void> _register() async {
    // Check agreement here too, so keyboard submission cannot bypass the button.
    if (_isLoading) return;
    if (!_privacyAcknowledged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please read and agree to the Privacy Notice first.'),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
    });

    try {
      // Firebase creates the account and sends the existing verification email.
      final UserCredential credential = await _authService.registerWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      final User? user = credential.user;
      if (user == null) {
        throw StateError('Unable to create user account.');
      }

      // Public registration continues to create Traveller profiles only.
      await _userService.createTravellerProfile(
        uid: user.uid,
        fullName: _nameController.text,
        email: _emailController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
      );
    } on FirebaseAuthException catch (error) {
      // Explain common account errors without changing the existing login flow.
      final String message = switch (error.code) {
        'email-already-in-use' =>
          'This email is already registered. Please sign in to continue email verification.',
        'invalid-email' => 'Please enter a valid email address.',
        'weak-password' => 'The password is too weak.',
        'network-request-failed' =>
          'Check your internet connection and try again.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        _ => 'Unable to register. Please try again.',
      };
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to finish registration. Please try again.'),
        ),
      );
    } finally {
      // Unlock the form after either a successful or failed registration attempt.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('TravelGuard MY'),
          leading: IconButton(
            tooltip: 'Back to login',
            onPressed: _isLoading
                ? null
                : () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AnimatedTravelMark(size: 100)),
                        const SizedBox(height: 16),
                        const Text(
                          'Create your account.',
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
                          'A little preparation. A more confident journey.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 28),
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
                              const Text(
                                'TRAVELLER ACCOUNT',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _nameController,
                                enabled: !_isLoading,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                decoration: const InputDecoration(
                                  labelText: 'Full name',
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your full name.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _emailController,
                                enabled: !_isLoading,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email.';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _passwordController,
                                enabled: !_isLoading,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  helperText: 'Use at least 6 characters.',
                                  helperMaxLines: 3,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: _isLoading
                                        ? null
                                        : () => setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          }),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a password.';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must contain at least 6 characters.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _confirmPasswordController,
                                enabled: !_isLoading,
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                autocorrect: false,
                                enableSuggestions: false,
                                onFieldSubmitted: (_) => _register(),
                                decoration: InputDecoration(
                                  labelText: 'Confirm password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _obscureConfirmPassword
                                        ? 'Show confirmation password'
                                        : 'Hide confirmation password',
                                    onPressed: _isLoading
                                        ? null
                                        : () => setState(() {
                                            _obscureConfirmPassword =
                                                !_obscureConfirmPassword;
                                          }),
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password.';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.privacy_tip_outlined,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Know how your data is used',
                                      style: TextStyle(
                                        color: AppColors.navy,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _openPrivacyNotice,
                                  child: Text(
                                    _privacyAcknowledged
                                        ? 'Read Privacy Notice again'
                                        : 'Read Privacy Notice',
                                  ),
                                ),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                activeColor: AppColors.primary,
                                value: _privacyAcknowledged,
                                onChanged: _isLoading
                                    ? null
                                    : _changePrivacyAcknowledgement,
                                title: const Text(
                                  'I understand and agree to the data use described in the Privacy Notice.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _privacyAcknowledged && !_isLoading
                              ? _register
                              : null,
                          style: FilledButton.styleFrom(
                            disabledBackgroundColor: const Color(0xFFE0DCE2),
                            disabledForegroundColor: const Color(0xFF68626C),
                          ),
                          icon: _isLoading
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.secondaryText,
                                  ),
                                )
                              : const Icon(Icons.person_add_alt_1_rounded),
                          label: Text(
                            _isLoading ? 'Creating account...' : 'Register',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _privacyAcknowledged
                              ? 'We will send a verification link to your email.'
                              : 'Read and agree to the Privacy Notice to enable registration.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Already have an account?'),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.of(context).maybePop(),
                              child: const Text('Log in'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
