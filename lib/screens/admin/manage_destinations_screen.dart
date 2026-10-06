import 'package:flutter/material.dart';

import '../../models/country.dart';
import '../../services/admin_service.dart';

class ManageDestinationsScreen extends StatefulWidget {
  const ManageDestinationsScreen({super.key});

  @override
  State<ManageDestinationsScreen> createState() =>
      _ManageDestinationsScreenState();
}

class _ManageDestinationsScreenState extends State<ManageDestinationsScreen> {
  final AdminService _adminService = AdminService();

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

  late Future<List<Country>> _countriesFuture;

  List<Country> _countries = [];

  String? _updatingCountryId;

  @override
  void initState() {
    super.initState();

    _countriesFuture = _loadCountries();
  }

  // ---------------------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------------------

  Future<List<Country>> _loadCountries() async {
    final List<Country> countries = await _adminService.getAllCountries();

    _countries = countries;

    return countries;
  }

  Future<void> _refresh() async {
    final Future<List<Country>> future = _loadCountries();

    setState(() {
      _countriesFuture = future;
    });

    await future;
  }

  int get _enabledCount {
    return _countries.where((country) => country.enabled).length;
  }

  int get _disabledCount {
    return _countries.where((country) => !country.enabled).length;
  }

  // ---------------------------------------------------------------------------
  // DESTINATION STATUS
  // ---------------------------------------------------------------------------

  Future<void> _changeDestinationStatus(Country country) async {
    if (_updatingCountryId != null) {
      return;
    }

    final bool newEnabled = !country.enabled;

    // Prevent the final enabled destination from
    // being disabled.
    if (!newEnabled && _enabledCount <= 1) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFC47F00),
              size: 34,
            ),
            title: const Text(
              'Destination Required',
              textAlign: TextAlign.center,
            ),
            content: const Text(
              'At least one destination must remain '
              'enabled so travellers can continue '
              'creating trips.',
              textAlign: TextAlign.center,
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: Icon(
            newEnabled
                ? Icons.check_circle_outline_rounded
                : Icons.block_outlined,
            color: newEnabled ? _primaryColor : const Color(0xFFB54708),
            size: 34,
          ),
          title: Text(
            newEnabled ? 'Enable Destination' : 'Disable Destination',
            textAlign: TextAlign.center,
          ),
          content: Text(
            newEnabled
                ? 'Enable ${country.name} for new traveller trips?'
                : 'Disable ${country.name} for new traveller trips?\n\n'
                      'Existing trips will not be deleted.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(newEnabled ? 'Enable' : 'Disable'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _updatingCountryId = country.id;
    });

    try {
      await _adminService.setCountryEnabled(
        country: country,
        enabled: newEnabled,
      );

      if (!mounted) {
        return;
      }

      final Future<List<Country>> future = _loadCountries();

      setState(() {
        _countriesFuture = future;
      });

      await future;

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              newEnabled
                  ? '${country.name} is now available for new trips.'
                  : '${country.name} is no longer available for new trips.',
            ),
          ),
        );
    } catch (error) {
      debugPrint('ADMIN DESTINATION UPDATE ERROR: $error');

      if (!mounted) {
        return;
      }

      final String message = error is StateError
          ? 'At least one destination must remain enabled.'
          : 'Unable to update the destination status.';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _updatingCountryId = null;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // DISPLAY HELPERS
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Not recorded';
    }

    final DateTime local = date.toLocal();

    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${local.day} '
        '${months[local.month - 1]} '
        '${local.year}';
  }

  // ---------------------------------------------------------------------------
  // SCREEN
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: _darkTextColor,
        title: const Text(
          'Destination Management',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Country>>(
            future: _countriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [const SizedBox(height: 120), _buildErrorState()],
                );
              }

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                children: [
                  _buildIntroCard(),

                  const SizedBox(height: 22),

                  _buildSummary(),

                  const SizedBox(height: 26),

                  const Text(
                    'Supported Destinations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _darkTextColor,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Disabled destinations remain in the '
                    'system but are unavailable when travellers '
                    'create new trips.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (_countries.isEmpty)
                    _buildEmptyState()
                  else
                    for (final Country country in _countries)
                      _buildCountryCard(country),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE7F7F8), Color(0xFFF1F8FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBE8EB)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.public_outlined, color: _primaryColor, size: 31),

          SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Destination Availability',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),

                SizedBox(height: 6),

                Text(
                  'Control which supported destinations '
                  'are available when travellers create '
                  'new trips.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.check_circle_outline_rounded,
            value: '$_enabledCount',
            label: 'Enabled',
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _buildSummaryCard(
            icon: Icons.block_outlined,
            value: '$_disabledCount',
            label: 'Disabled',
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _buildSummaryCard(
            icon: Icons.public_outlined,
            value: '${_countries.length}',
            label: 'Total',
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: _primaryColor, size: 21),

          const SizedBox(height: 6),

          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _darkTextColor,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryCard(Country country) {
    final bool updating = _updatingCountryId == country.id;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6F7),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: _primaryColor,
                  size: 24,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      country.name,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: _darkTextColor,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      country.code.isEmpty ? country.id : country.code,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              _buildStatusBadge(country.enabled),
            ],
          ),

          const SizedBox(height: 13),

          const Divider(height: 1),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Last updated: '
                  '${_formatDate(country.lastUpdated)}',
                  style: const TextStyle(fontSize: 10.5, color: Colors.black45),
                ),
              ),

              const SizedBox(width: 10),

              SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: _updatingCountryId != null
                      ? null
                      : () {
                          _changeDestinationStatus(country);
                        },
                  icon: updating
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          country.enabled
                              ? Icons.block_outlined
                              : Icons.check_circle_outline_rounded,
                          size: 17,
                        ),
                  label: Text(country.enabled ? 'Disable' : 'Enable'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFE7F7F1) : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        enabled ? 'ENABLED' : 'DISABLED',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: enabled ? const Color(0xFF147D64) : const Color(0xFF667085),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.public_off_outlined, size: 40, color: Colors.black38),

          SizedBox(height: 10),

          Text(
            'No destinations found',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _darkTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 38,
            color: Colors.black45,
          ),

          const SizedBox(height: 10),

          const Text(
            'Unable to load destinations.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _darkTextColor,
            ),
          ),

          const SizedBox(height: 12),

          OutlinedButton(onPressed: _refresh, child: const Text('Try Again')),
        ],
      ),
    );
  }
}
