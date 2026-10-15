import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// -----------------------------------------------------------------------------
// TRAVEL READINESS CARD
// -----------------------------------------------------------------------------
// Displays saved checklist progress without changing how requirements are counted.
class TripReadinessCard extends StatelessWidget {
  final Future<Map<String, int>> progressFuture;
  final VoidCallback onRetry;

  const TripReadinessCard({
    super.key,
    required this.progressFuture,
    required this.onRetry,
  });

  // ---------------------------------------------------------------------------
  // LOADING, ERROR AND LOADED STATES
  // ---------------------------------------------------------------------------
  // Keep an unavailable score separate from a genuine zero-percent score.
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: progressFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ReadinessSurface(
            child: Column(
              children: [
                SizedBox(height: 10),
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Loading your readiness score...',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return _ReadinessSurface(
            child: Column(
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  color: AppColors.primary,
                  size: 30,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Unable to load readiness',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Check your connection and try again. '
                  'Your preparation tools remain available below.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return _buildScore(context, snapshot.data ?? const {});
      },
    );
  }

  // ---------------------------------------------------------------------------
  // READINESS CALCULATION AND PRESENTATION
  // ---------------------------------------------------------------------------
  // Preserve completed / total, rounding only the displayed percentage.
  Widget _buildScore(BuildContext context, Map<String, int> progress) {
    final int completed = progress['completed'] ?? 0;
    final int total = progress['total'] ?? 0;

    final double value = total == 0
        ? 0
        : (completed / total).clamp(0.0, 1.0).toDouble();

    final int percentage = (value * 100).round();
    final int remaining = total > completed ? total - completed : 0;

    final bool reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);

    final String status = total == 0
        ? 'No requirements available'
        : remaining == 0
        ? 'All requirements completed'
        : '$remaining ${remaining == 1 ? 'requirement' : 'requirements'} remaining';

    return _ReadinessSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Keep the heading flexible beside the decorative icon.
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.speed_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Travel Readiness Score',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            total == 0 ? 'Not available' : '$percentage%',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: total == 0 ? 24 : 36,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            status,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            total == 0
                ? 'A score will appear when applicable requirements '
                      'are available for this trip.'
                : '$completed of $total applicable requirements completed.',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
              height: 1.5,
            ),
          ),

          if (total > 0) ...[
            const SizedBox(height: 18),

            // Animate the bar while leaving its text stable and readable.
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, animatedValue, child) {
                return LinearProgressIndicator(
                  value: animatedValue,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.primary,
                  backgroundColor: AppColors.primaryLight,
                  semanticsLabel: 'Travel requirements completed',
                );
              },
            ),

            const SizedBox(height: 12),

            const Text(
              'Check or uncheck items in Travel Requirements '
              'to update this score.',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Explain what the score measures beside the result itself.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Text(
              'This score tracks checklist completion. '
              'It does not confirm visa approval, entry permission '
              'or travel eligibility.',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// READINESS CARD SURFACE
// -----------------------------------------------------------------------------
// Apply the same border and spacing to every readiness state.
class _ReadinessSurface extends StatelessWidget {
  final Widget child;

  const _ReadinessSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

// -----------------------------------------------------------------------------
// PREPARATION ACTION CARD
// -----------------------------------------------------------------------------
// Provide one full-card action for requirements, packing or a personal reminder.
class TripActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String actionText;
  final VoidCallback? onTap;
  final Color iconBackground;

  const TripActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.actionText,
    required this.onTap,
    this.iconBackground = AppColors.primaryLight,
  });

  // ---------------------------------------------------------------------------
  // ACTION LAYOUT AND TAP HANDLING
  // ---------------------------------------------------------------------------
  // Stack descriptive text so larger fonts can use the full card width.
  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: AppColors.navy, size: 24),
                    ),

                    const Spacer(),

                    Icon(
                      enabled
                          ? Icons.arrow_forward_rounded
                          : Icons.lock_outline_rounded,
                      color: AppColors.secondaryText,
                      size: 21,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  actionText,
                  style: TextStyle(
                    color: enabled
                        ? AppColors.primary
                        : AppColors.secondaryText,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
