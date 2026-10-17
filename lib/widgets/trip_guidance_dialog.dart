import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/trip_guidance_policy.dart';
import '../theme/app_theme.dart';

// -----------------------------------------------------------------------------
// OFFICIAL GUIDANCE DIALOG
// -----------------------------------------------------------------------------
// Use one dialog for unsupported trip contexts in both Add Trip and Edit Trip.
Future<void> showTripGuidanceDialog(
  BuildContext context,
  TripGuidance guidance,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(
        Icons.info_outline_rounded,
        color: AppColors.primary,
        size: 32,
      ),
      title: Text(guidance.title, textAlign: TextAlign.center),
      content: SingleChildScrollView(child: Text(guidance.message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await _openOfficialGuidance(context, guidance);
          },
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(guidance.buttonLabel),
        ),
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// OFFICIAL REFERENCE LINK
// -----------------------------------------------------------------------------
// Explain failed launches only while the originating screen is still mounted.
Future<void> _openOfficialGuidance(
  BuildContext context,
  TripGuidance guidance,
) async {
  bool opened = false;

  try {
    opened = await launchUrl(
      Uri.parse(guidance.officialUrl),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }

  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(guidance.failureMessage)));
  }
}
