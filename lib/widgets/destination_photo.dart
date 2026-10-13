import 'package:flutter/material.dart';

class DestinationPhoto extends StatelessWidget {
  final String countryId;
  final double height;
  final Widget? child;
  final BorderRadius borderRadius;

  const DestinationPhoto({
    super.key,
    required this.countryId,
    this.height = 160,
    this.child,
    this.borderRadius = BorderRadius.zero,
  });

  // Maps Firestore destination IDs to local image assets.
  String? get _imagePath {
    final String id = countryId.trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );

    switch (id) {
      case 'japan':
        return 'assets/images/destinations/japan.jpg';

      case 'united_states':
      case 'usa':
      case 'us':
        return 'assets/images/destinations/united_states.jpg';

      case 'australia':
        return 'assets/images/destinations/australia.jpg';

      case 'united_kingdom':
      case 'uk':
        return 'assets/images/destinations/united_kingdom.jpg';

      case 'south_korea':
        return 'assets/images/destinations/south_korea.jpg';

      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? imagePath = _imagePath;

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Landmark photo with a fallback if missing.
            if (imagePath != null)
              Image.asset(
                imagePath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (context, error, stackTrace) {
                  return const _DestinationFallback();
                },
              )
            else
              const _DestinationFallback(),

            // Dark gradient improves white text readability.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x10000000),
                    Color(0x35000000),
                    Color(0xC9000000),
                  ],
                ),
              ),
            ),

            // Optional content displayed above the photo.
            if (child != null) Positioned.fill(child: child!),
          ],
        ),
      ),
    );
  }
}

// Fallback shown when no landmark photo is available.
class _DestinationFallback extends StatelessWidget {
  const _DestinationFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF087F8C), Color(0xFF075267)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.travel_explore_rounded,
          size: 90,
          color: Color(0x40FFFFFF),
        ),
      ),
    );
  }
}
