import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// -----------------------------------------------------------------------------
// TRAVELLER INTRODUCTION
// -----------------------------------------------------------------------------
class TravellerIntroCard extends StatelessWidget {
  const TravellerIntroCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 27, color: AppColors.primary),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(message),
            ],
          ),
        ),
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// EMPTY AND ERROR FEEDBACK
// -----------------------------------------------------------------------------
class TravellerStatusCard extends StatelessWidget {
  const TravellerStatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, color: AppColors.primary, size: 34),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (actionText != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              child: Text(actionText!, textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// RESPONSIVE TRAVEL PURPOSE CHOICES
// -----------------------------------------------------------------------------
class TripPurposeSelector extends StatelessWidget {
  const TripPurposeSelector({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<({String value, String label, IconData icon})> options;
  final String? value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Switch to full-width choices when three columns would crowd the text.
      final stacked =
          constraints.maxWidth < 320 ||
          MediaQuery.textScalerOf(context).scale(14) > 18;
      final reduceMotion =
          MediaQuery.disableAnimationsOf(context) ||
          MediaQuery.accessibleNavigationOf(context);

      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final option in options)
            SizedBox(
              width: stacked
                  ? constraints.maxWidth
                  : (constraints.maxWidth - (options.length - 1) * 10) /
                        options.length,
              child: Semantics(
                button: true,
                selected: value == option.value,
                enabled: onChanged != null,
                child: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: value == option.value
                        ? AppColors.primaryLight
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: value == option.value
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: onChanged == null
                          ? null
                          : () => onChanged!(option.value),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: stacked
                            ? Row(
                                children: [
                                  Icon(
                                    option.icon,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      option.label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    value == option.value
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  Icon(
                                    option.icon,
                                    color: AppColors.primary,
                                    size: 26,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    option.label,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
