import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key, this.requestConsent = false});

  // Reading the notice elsewhere does not request or change registration consent.
  final bool requestConsent;

  // ---------------------------------------------------------------------------
  // EXTERNAL PRIVACY AND MAPS INFORMATION
  // ---------------------------------------------------------------------------

  // Open provider information separately and show feedback if it is unavailable.
  Future<void> _openLink(BuildContext context, String address) async {
    try {
      final bool opened = await launchUrl(
        Uri.parse(address),
        mode: LaunchMode.externalApplication,
      );
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to open this link. Please try again later.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Notice')),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 36,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Your information.\nYour choice.',
                          style: TextStyle(
                            fontSize: 27,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Please read how TravelGuard MY handles information before creating your account.',
                          style: TextStyle(height: 1.6),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Version 1.0 · Updated 17 October 2026',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _NoticeSection(
                    number: '01',
                    title: 'About TravelGuard MY',
                    paragraphs: [
                      'TravelGuard MY is an academic Final Year Project developed to support travel preparation for Malaysian travellers. It provides personalised requirement checklists, preparation progress, packing tools, reminders, route planning and aggregated reports.',
                    ],
                  ),
                  const _NoticeSection(
                    number: '02',
                    title: 'Information the app handles',
                    paragraphs: [
                      'Account information includes your name, email address, account identifier, role and account timestamps. Firebase Authentication handles your sign-in credentials. When you use Google sign-in, your Google account supplies basic profile information for signing in.',
                      'Trip information includes destination, travel purpose, duration and departure date. The app also stores requirement completion, packing items and quantities, reminder titles and times, and the saved places and travel mode you choose for a route plan.',
                      'The current app does not ask for passport numbers, payment card details or continuous device location. Please do not enter sensitive personal information into names, packing items or reminder text.',
                    ],
                  ),
                  const _NoticeSection(
                    number: '03',
                    title: 'How your information is used',
                    paragraphs: [
                      'Your information is used to create and manage your account, match travel requirements to your trip, save your preparation progress, organise packing, schedule reminders and provide the routes you request.',
                      'Authorised tourism data analysts receive aggregated destination, travel-purpose, completion and requirement reports from the backend. Their analyst access does not include individual traveller trip or checklist records. The backend processes those records to calculate the reports. Account administrators can access profile details for account management.',
                    ],
                  ),
                  const _NoticeSection(
                    number: '04',
                    title: 'Services used by the app',
                    paragraphs: [
                      'Google Firebase provides authentication and cloud database storage. The application backend is hosted on Render. These providers process the information needed to deliver their services and may process it outside Malaysia.',
                      'If you request AI packing suggestions, your destination, travel purpose, duration and departure date are sent through the backend to Google Gemini. Your name, email and password are not included in that packing request.',
                      'Under Gemini unpaid-service terms, Google can use submitted prompts and responses to improve its products, including review by people. Different data-use terms apply when the project uses a paid Gemini service. The linked Gemini terms describe these differences.',
                      'When you use maps, place search or route planning, Google Maps Platform processes the map requests, place searches, selected locations and travel mode needed for that feature. The saved route plan records your selected place identifiers and travel mode; displayed place details and route results are retrieved when needed.',
                      'Service providers may also process technical information such as IP addresses and service logs under their own policies. Use of Google Maps features and content is subject to the Google Maps End User Additional Terms of Service and Google Privacy Policy linked below.',
                    ],
                  ),
                  const _NoticeSection(
                    number: '05',
                    title: 'Reminders and permissions',
                    paragraphs: [
                      'If you enable reminders, Android may ask for permission to display notifications and schedule alarms. The app uses the device timezone to schedule your chosen reminder times.',
                      'Reminder titles and destinations may appear on your lock screen, depending on your Android notification settings. You can change those permissions and lock-screen settings on your device.',
                    ],
                  ),
                  const _NoticeSection(
                    number: '06',
                    title: 'Saved information and deletion',
                    paragraphs: [
                      'Saved account and travel records remain in the project database until they are deleted. You can edit or delete your trips and manage the packing items, reminders and route plans available in the app. Deleting a trip also removes its linked preparation records and saved route plan from the app database.',
                      'Signing out or uninstalling the app does not delete your cloud account or saved records. This version does not provide an in-app account deletion button. The app does not control the separate retention practices of its service providers.',
                    ],
                  ),
                  const _NoticeSection(
                    number: '07',
                    title: 'Your choices',
                    paragraphs: [
                      'You can return to registration without agreeing; the Register button will remain disabled. Name, email and password are needed to create an email account. You choose which trip details to enter and whether to request AI packing suggestions, plan routes or enable reminders.',
                      'Agreement is not permission to collect unrelated information. You can untick the acknowledgement before submitting registration. Reading the notice again does not create an account.',
                    ],
                  ),
                  const _NoticeSection(
                    number: '08',
                    title: 'Using travel guidance',
                    paragraphs: [
                      'Requirement checklists, readiness percentages, AI suggestions and routes are planning aids. A checked requirement records your own progress; it does not verify a document or guarantee entry, eligibility or travel safety. Confirm requirements with the relevant official sources before travelling.',
                    ],
                  ),
                  const _NoticeSection(
                    number: '09',
                    title: 'Changes to this notice',
                    paragraphs: [
                      'This notice describes the current version of the prototype. Changes to how information is handled will be reflected in the notice and its version date. Please review the latest notice when using an updated version of the app.',
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Provider information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ProviderLink(
                    label: 'Google Privacy Policy',
                    onPressed: () => _openLink(
                      context,
                      'https://policies.google.com/privacy',
                    ),
                  ),
                  _ProviderLink(
                    label: 'Google Maps End User Additional Terms',
                    onPressed: () => _openLink(
                      context,
                      'https://maps.google.com/help/terms_maps/',
                    ),
                  ),
                  _ProviderLink(
                    label: 'Firebase privacy and security',
                    onPressed: () => _openLink(
                      context,
                      'https://firebase.google.com/support/privacy',
                    ),
                  ),
                  _ProviderLink(
                    label: 'Gemini API terms',
                    onPressed: () => _openLink(
                      context,
                      'https://ai.google.dev/gemini-api/terms',
                    ),
                  ),
                  _ProviderLink(
                    label: 'Render Privacy Policy',
                    onPressed: () =>
                        _openLink(context, 'https://render.com/privacy'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(requestConsent ? true : null),
                  icon: Icon(
                    requestConsent
                        ? Icons.check_rounded
                        : Icons.arrow_back_rounded,
                  ),
                  label: Text(requestConsent ? 'Agree and continue' : 'Back'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeSection extends StatelessWidget {
  const _NoticeSection({
    required this.number,
    required this.title,
    required this.paragraphs,
  });

  final String number;
  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            for (final paragraph in paragraphs) ...[
              const SizedBox(height: 10),
              Text(paragraph, style: const TextStyle(height: 1.6)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProviderLink extends StatelessWidget {
  const _ProviderLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(child: Text(label)),
            const SizedBox(width: 8),
            const Icon(Icons.open_in_new_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}
