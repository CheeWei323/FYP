import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'destination_photo.dart';

// -----------------------------------------------------------------------------
// TRIP OVERVIEW CARD
// -----------------------------------------------------------------------------
// Displays the selected trip using labels prepared by Trip Details.
class TripOverviewCard extends StatelessWidget {
  final String countryId;
  final String destination;
  final String purpose;
  final int durationDays;
  final String departureDateLabel;
  final String departureStatus;
  final bool isPastTrip;

  const TripOverviewCard({
    super.key,
    required this.countryId,
    required this.destination,
    required this.purpose,
    required this.durationDays,
    required this.departureDateLabel,
    required this.departureStatus,
    required this.isPastTrip,
  });

  // ---------------------------------------------------------------------------
  // CARD LAYOUT
  // ---------------------------------------------------------------------------
  // Combines destination imagery with the trip's purpose, duration and departure.
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDestination(),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wrap metadata onto additional lines when text is enlarged.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip(Icons.explore_outlined, purpose),
                    _buildChip(
                      Icons.schedule_outlined,
                      '$durationDays ${durationDays == 1 ? 'day' : 'days'}',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 18),
                _buildDeparture(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DESTINATION IMAGE AND STATUS
  // ---------------------------------------------------------------------------
  // Let the text determine height so long names and larger fonts stay visible.
  Widget _buildDestination() {
    return Stack(
      children: [
        Positioned.fill(child: DestinationPhoto(countryId: countryId)),
        // Darken the entire photo to keep the heading readable over bright areas.
        const Positioned.fill(child: ColoredBox(color: Color(0x33000000))),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 210),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChip(
                  isPastTrip
                      ? Icons.history_rounded
                      : Icons.flight_takeoff_rounded,
                  isPastTrip ? 'Past trip' : 'Upcoming trip',
                  backgroundColor: const Color(0xF2FFFFFF),
                  foregroundColor: AppColors.navy,
                ),
                const SizedBox(height: 42),
                const Text(
                  'YOUR DESTINATION',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 7),
                Semantics(
                  header: true,
                  child: Text(
                    destination,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(color: Color(0x88000000), blurRadius: 9),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // WRAPPING INFORMATION CHIP
  // ---------------------------------------------------------------------------
  // Keep the icon beside its label while allowing longer labels to wrap.
  Widget _buildChip(
    IconData icon,
    String label, {
    Color backgroundColor = AppColors.primaryLight,
    Color foregroundColor = AppColors.primary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: foregroundColor),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DEPARTURE INFORMATION
  // ---------------------------------------------------------------------------
  // Show the saved departure date and distinguish upcoming trips from history.
  Widget _buildDeparture() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Departure date',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    departureDateLabel,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 16,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isPastTrip ? AppColors.primaryLight : AppColors.accent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            departureStatus,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
