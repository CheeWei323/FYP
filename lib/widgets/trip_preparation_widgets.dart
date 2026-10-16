import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// -----------------------------------------------------------------------------
// TRAVEL READINESS
// -----------------------------------------------------------------------------
class TripReadinessCard extends StatelessWidget {
  final Future<Map<String, int>> progressFuture;
  final VoidCallback onRetry;
  final VoidCallback? onOpenRequirements;

  const TripReadinessCard({
    super.key,
    required this.progressFuture,
    required this.onRetry,
    this.onOpenRequirements,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: progressFuture,
      builder: (context, snapshot) {
        final Widget content;

        // Keep requirements accessible while the score loads or needs a retry.
        if (snapshot.connectionState != ConnectionState.done) {
          content = const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Travel Readiness Score',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 14),
              LinearProgressIndicator(),
              SizedBox(height: 10),
              Text('Loading your readiness score...'),
            ],
          );
        } else if (snapshot.hasError) {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unable to load readiness',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text('You can still open your requirements below.'),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          );
        } else {
          content = _buildScore(context, snapshot.data ?? const {});
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              content,
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onOpenRequirements,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text(
                  'View Requirements',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SCORE CALCULATION
  // ---------------------------------------------------------------------------
  // Preserve completed / total and round only the displayed percentage.
  Widget _buildScore(BuildContext context, Map<String, int> progress) {
    final completed = progress['completed'] ?? 0;
    final total = progress['total'] ?? 0;
    final value = total == 0
        ? 0.0
        : (completed / total).clamp(0.0, 1.0).toDouble();
    final percentage = (value * 100).round();
    final remaining = total > completed ? total - completed : 0;
    final status = total == 0
        ? 'No requirements available'
        : remaining == 0
        ? 'All requirements completed'
        : '$remaining ${remaining == 1 ? 'requirement' : 'requirements'} remaining';

    // Respect the device's motion and accessibility settings.
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Travel Readiness Score',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          total == 0 ? 'Not available' : '$percentage%',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: total == 0 ? 24 : 34,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          status,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          total == 0
              ? 'A score appears when applicable requirements are available.'
              : '$completed of $total applicable requirements completed.',
        ),
        if (total > 0) ...[
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, child) => LinearProgressIndicator(
              value: animatedValue,
              minHeight: 8,
              borderRadius: BorderRadius.circular(12),
              color: AppColors.primary,
              backgroundColor: AppColors.primaryLight,
              semanticsLabel: 'Travel requirements completed',
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Tracks checklist completion, not visa approval or entry permission.',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// TRIP ACTION
// -----------------------------------------------------------------------------
class TripActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String actionText;
  final VoidCallback? onTap;

  const TripActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.actionText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 25,
                  color: enabled ? AppColors.primary : AppColors.secondaryText,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        actionText,
                        style: TextStyle(
                          color: enabled
                              ? AppColors.primary
                              : AppColors.secondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  enabled
                      ? Icons.chevron_right_rounded
                      : Icons.lock_outline_rounded,
                  size: 20,
                  color: AppColors.secondaryText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
