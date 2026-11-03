import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AnalyticsFilterCard extends StatelessWidget {
  final List<Map<String, String>> countries;
  final String? selectedDestinationId;
  final String? selectedPurpose;
  final ValueChanged<String?> onDestinationChanged;
  final ValueChanged<String?> onPurposeChanged;
  final VoidCallback onClear;
  final bool showDestination;
  final bool showPurpose;
  final bool enabled;

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
    this.enabled = true,
  });

  // ---------------------------------------------------------------------------
  // FILTER VALUES
  // ---------------------------------------------------------------------------

  static const _allValue = '__all__';
  static const _purposes = {
    'tourism': 'Tourism',
    'business': 'Business',
    'study': 'Study',
  };

  // Preserve null as the service's unfiltered value.
  bool get _hasActiveFilters =>
      (showDestination && selectedDestinationId != null) ||
      (showPurpose && selectedPurpose != null);

  @override
  Widget build(BuildContext context) {
    final destinationValue =
        countries.any((country) => country['id'] == selectedDestinationId)
        ? selectedDestinationId!
        : _allValue;
    final purposeValue = _purposes.containsKey(selectedPurpose)
        ? selectedPurpose!
        : _allValue;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Analytics filters',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          if (showDestination) ...[
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              key: ValueKey('destination-$destinationValue'),
              initialValue: destinationValue,
              isExpanded: true,
              itemHeight: null,
              decoration: const InputDecoration(labelText: 'Destination'),
              items: [
                const DropdownMenuItem(
                  value: _allValue,
                  child: Text('All destinations'),
                ),
                for (final country in countries)
                  DropdownMenuItem(
                    value: country['id'],
                    child: Text(country['name'] ?? country['id'] ?? 'Unknown'),
                  ),
              ],
              onChanged: enabled
                  ? (value) =>
                        onDestinationChanged(value == _allValue ? null : value)
                  : null,
            ),
          ],
          if (showPurpose) ...[
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              key: ValueKey('purpose-$purposeValue'),
              initialValue: purposeValue,
              isExpanded: true,
              itemHeight: null,
              decoration: const InputDecoration(labelText: 'Travel purpose'),
              items: [
                const DropdownMenuItem(
                  value: _allValue,
                  child: Text('All purposes'),
                ),
                for (final entry in _purposes.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: enabled
                  ? (value) =>
                        onPurposeChanged(value == _allValue ? null : value)
                  : null,
            ),
          ],
          if (_hasActiveFilters) ...[
            const SizedBox(height: 14),
            const Text(
              'Only trips matching these filters are included.',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: enabled ? onClear : null,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Clear filters'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
