import 'package:flutter/material.dart';

class AnalyticsFilterCard extends StatelessWidget {
  final List<Map<String, String>> countries;
  final String? selectedDestinationId;
  final String? selectedPurpose;
  final ValueChanged<String?> onDestinationChanged;
  final ValueChanged<String?> onPurposeChanged;
  final VoidCallback onClear;
  final bool showDestination;
  final bool showPurpose;

  const AnalyticsFilterCard({
    super.key,
    required this.countries,
    required this.selectedDestinationId,
    required this.selectedPurpose,
    required this.onDestinationChanged,
    required this.onPurposeChanged,
    required this.onClear,
    this.showDestination = true,
    this.showPurpose = true,
  });

  static const String _allValue = '__all__';

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _borderColor = Color(0xFFE1E7EC);

  bool get _hasActiveFilters {
    final bool destinationActive =
        showDestination && selectedDestinationId != null;

    final bool purposeActive = showPurpose && selectedPurpose != null;

    return destinationActive || purposeActive;
  }

  @override
  Widget build(BuildContext context) {
    final Set<String> countryIds = countries
        .map((country) => country['id'] ?? '')
        .toSet();

    final String destinationValue =
        selectedDestinationId != null &&
            countryIds.contains(selectedDestinationId)
        ? selectedDestinationId!
        : _allValue;

    final String purposeValue =
        selectedPurpose == 'tourism' ||
            selectedPurpose == 'business' ||
            selectedPurpose == 'study'
        ? selectedPurpose!
        : _allValue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: _primaryColor, size: 21),

              const SizedBox(width: 8),

              const Expanded(
                child: Text(
                  'Analytics Filters',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),
              ),

              if (_hasActiveFilters)
                TextButton(onPressed: onClear, child: const Text('Clear')),
            ],
          ),

          if (showDestination) ...[
            const SizedBox(height: 14),

            const Text(
              'Destination',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 6),

            _buildDropdownContainer(
              child: DropdownButton<String>(
                value: destinationValue,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: [
                  const DropdownMenuItem<String>(
                    value: _allValue,
                    child: Text('All Destinations'),
                  ),
                  ...countries.map((country) {
                    return DropdownMenuItem<String>(
                      value: country['id'],
                      child: Text(country['name'] ?? country['id'] ?? ''),
                    );
                  }),
                ],
                onChanged: (value) {
                  onDestinationChanged(value == _allValue ? null : value);
                },
              ),
            ),
          ],

          if (showPurpose) ...[
            const SizedBox(height: 14),

            const Text(
              'Travel Purpose',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 6),

            _buildDropdownContainer(
              child: DropdownButton<String>(
                value: purposeValue,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: const [
                  DropdownMenuItem<String>(
                    value: _allValue,
                    child: Text('All Purposes'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'tourism',
                    child: Text('Tourism'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'business',
                    child: Text('Business'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'study',
                    child: Text('Study'),
                  ),
                ],
                onChanged: (value) {
                  onPurposeChanged(value == _allValue ? null : value);
                },
              ),
            ),
          ],

          if (_hasActiveFilters) ...[
            const SizedBox(height: 12),

            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: Colors.black45,
                ),

                SizedBox(width: 6),

                Expanded(
                  child: Text(
                    'Analytics are recalculated using '
                    'only trips matching the selected filters.',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.35,
                      color: Colors.black45,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: child,
    );
  }
}
