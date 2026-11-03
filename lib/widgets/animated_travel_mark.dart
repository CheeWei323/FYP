import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A decorative, one-time arrival animation. No assets or packages required.
class AnimatedTravelMark extends StatelessWidget {
  const AnimatedTravelMark({super.key, this.size = 160});

  final double size;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations || media.accessibleNavigation;

    Widget artwork(double progress) {
      return SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              margin: EdgeInsets.all(size * .04),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: .15),
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.all(size * .15),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryLight, AppColors.accent],
                ),
              ),
            ),
            Positioned(
              top: size * .08,
              right: size * .16,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: size * .14,
                color: AppColors.primary,
              ),
            ),
            Positioned(
              bottom: size * .12,
              left: size * .12,
              child: Container(
                width: size * .1,
                height: size * .1,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Opacity(
              opacity: progress,
              child: Transform.translate(
                offset: Offset(
                  -size * .2 * (1 - progress),
                  size * .15 * (1 - progress),
                ),
                child: Transform.rotate(
                  angle: -.12 * (1 - progress),
                  child: Icon(
                    Icons.flight_takeoff_rounded,
                    size: size * .4,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ExcludeSemantics(
      child: reduceMotion
          ? artwork(1)
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => artwork(progress),
            ),
    );
  }
}
