import 'package:flutter/material.dart';

import '../../models/country.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/role_ui_widgets.dart';

class ManageDestinationsScreen extends StatefulWidget {
  const ManageDestinationsScreen({super.key});

  @override
  State<ManageDestinationsScreen> createState() =>
      _ManageDestinationsScreenState();
}

class _ManageDestinationsScreenState extends State<ManageDestinationsScreen> {
  // ---------------------------------------------------------------------------
  // DESTINATION STATE AND REFRESH
  // ---------------------------------------------------------------------------

  final _service = AdminService();
  List<Country>? _countries;
  String? _savingCountryId;
  bool _loading = false;
  bool _failed = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  // Retain the last known list if connectivity fails during a refresh.
  Future<void> _loadCountries() async {
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
    });
    try {
      final countries = await _service.getAllCountries();
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _countries = countries;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _failed = true;
      });
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // Do not start an overlapping refresh while a status change is being saved.
  Future<void> _refresh() async {
    if (_savingCountryId != null) return;
    await _loadCountries();
  }

  int get _enabledCount =>
      (_countries ?? []).where((country) => country.enabled).length;

  // ---------------------------------------------------------------------------
  // CONFIRM AND SAVE DESTINATION AVAILABILITY
  // ---------------------------------------------------------------------------

  Future<void> _changeStatus(Country country) async {
    if (_savingCountryId != null || _loading || _failed) return;
    final enabled = !country.enabled;

    // Preserve the existing requirement to keep at least one destination enabled.
    if (!enabled && _enabledCount <= 1) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Destination required'),
          content: const SingleChildScrollView(
            child: Text(
              'At least one destination must remain enabled so travellers can create new trips.',
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${enabled ? 'Enable' : 'Disable'} ${country.name}?'),
        content: SingleChildScrollView(
          child: Text(
            enabled
                ? 'Travellers will be able to select this destination when creating new trips.'
                : 'This destination will be unavailable for new trips. Existing trips will remain saved.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(enabled ? 'Enable' : 'Disable'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _savingCountryId = country.id;
    });

    try {
      // AdminService rechecks availability and commits the existing activity log.
      await _service.setCountryEnabled(country: country, enabled: enabled);
      if (!mounted) return;
      _showMessage(
        '${country.name} ${enabled ? 'enabled' : 'disabled'} for new trips.',
      );
      await _loadCountries();
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error is StateError
            ? 'At least one destination must remain enabled.'
            : 'Unable to update this destination. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingCountryId = null;
        });
      }
    }
  }

  // Display one current message instead of accumulating earlier notifications.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Destinations')),
      body: SafeArea(
        child: RolePageBody(
          storageId: 'admin-destinations',
          onRefresh: _refresh,
          children: [
            const RoleIntroCard(
              eyebrow: 'Destination management',
              title: 'Choose where new journeys begin.',
              description:
                  'Control which supported destinations are available for new trips. Existing trips stay saved.',
              icon: Icons.public_outlined,
            ),
            const RoleSectionTitle(title: 'Destination availability'),
            if (_countries != null)
              RoleMetricGrid(
                metrics: [
                  RoleMetric(
                    label: 'Enabled',
                    value: '$_enabledCount',
                    icon: Icons.check_circle_outline_rounded,
                  ),
                  RoleMetric(
                    label: 'Disabled',
                    value: '${_countries!.length - _enabledCount}',
                    icon: Icons.block_outlined,
                  ),
                ],
              ),
            const SizedBox(height: 16),
            if (_loading)
              const RoleStatusCard(
                title: 'Loading destinations',
                message: 'Retrieving current destination availability.',
                loading: true,
              ),
            if (_failed)
              RoleStatusCard(
                title: 'Unable to refresh destinations',
                message: _countries == null
                    ? 'Check your connection and try again.'
                    : 'Showing the last loaded destinations. Refresh before changing availability.',
                icon: Icons.cloud_off_outlined,
                onRetry: _loading ? null : _refresh,
              ),
            if (_countries != null && _countries!.isEmpty && !_loading)
              const RoleStatusCard(
                title: 'No destinations yet',
                message:
                    'Supported destinations will appear here when configured.',
                icon: Icons.public_outlined,
              ),
            for (final country in _countries ?? <Country>[])
              _countryCard(country),
          ],
        ),
      ),
    );
  }

  Widget _countryCard(Country country) {
    final saving = country.id == _savingCountryId;
    return Card(
      key: ValueKey('destination-${country.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              country.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: RoleBadge(
                label: country.enabled
                    ? 'Enabled for new trips'
                    : 'Disabled for new trips',
                color: country.enabled
                    ? AppColors.success
                    : AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 12),
            Text(country.code, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            Text(
              'Updated ${formatRoleDate(country.lastUpdated)}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _savingCountryId != null || _loading || _failed
                  ? null
                  : () => _changeStatus(country),
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      country.enabled
                          ? Icons.pause_circle_outline_rounded
                          : Icons.check_circle_outline_rounded,
                    ),
              label: Text(
                saving
                    ? 'Updating destination...'
                    : country.enabled
                    ? 'Disable destination'
                    : 'Enable destination',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
