import 'package:flutter/material.dart';

import '../../models/country.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class ManageDestinationsScreen extends StatefulWidget {
  const ManageDestinationsScreen({super.key});

  @override
  State<ManageDestinationsScreen> createState() =>
      _ManageDestinationsScreenState();
}

class _ManageDestinationsScreenState extends State<ManageDestinationsScreen> {
  final AdminService _adminService = AdminService();

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            title: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4DC),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFA86300),
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Destination Required',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This destination cannot be disabled.',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 9),
                Text(
                  'At least one destination must remain enabled '
                  'so travellers can continue creating new trips.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Got It'),
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
        final Color actionColor = newEnabled
            ? AppColors.primary
            : const Color(0xFFA86300);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),

          // ---------------------------------------------------
          // CONFIRMATION HEADER
          // ---------------------------------------------------
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: newEnabled
                      ? AppColors.primaryLight
                      : const Color(0xFFFFF4DC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  newEnabled
                      ? Icons.check_circle_outline_rounded
                      : Icons.block_outlined,
                  color: actionColor,
                  size: 23,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Text(
                  newEnabled ? 'Enable Destination' : 'Disable Destination',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          // ---------------------------------------------------
          // CONFIRMATION DETAILS
          // ---------------------------------------------------
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                newEnabled
                    ? 'Make this destination available for new trips?'
                    : 'Remove this destination from the new trip options?',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DESTINATION',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      country.name,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Divider(height: 1, color: AppColors.border),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Icon(
                          newEnabled
                              ? Icons.check_circle_outline_rounded
                              : Icons.block_outlined,
                          color: actionColor,
                          size: 18,
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: Text(
                            newEnabled
                                ? 'New status: Enabled'
                                : 'New status: Disabled',
                            style: TextStyle(
                              color: actionColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // -------------------------------------------------
              // EXISTING TRIP INFORMATION
              // -------------------------------------------------
              if (!newEnabled) ...[
                const SizedBox(height: 13),

                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),

                    SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        'Existing trips will not be deleted. '
                        'This destination will only become '
                        'unavailable for new trips.',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 11.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),

          // ---------------------------------------------------
          // CONFIRMATION BUTTONS
          // ---------------------------------------------------
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),

            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: actionColor),
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
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(18),
                  children: [
                    const SizedBox(height: 70),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 32,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Loading Destinations',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Retrieving supported destinations...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------------------------------------------
          // DESTINATION MANAGEMENT HEADER
          // ---------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.public_outlined,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Destination Availability',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      'Control which supported destinations '
                      'are available when travellers create '
                      'new trips.',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 19),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 15),

          // ---------------------------------------------------
          // DESTINATION AVAILABILITY INFORMATION
          // ---------------------------------------------------
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppColors.primary,
                size: 19,
              ),

              SizedBox(width: 10),

              Expanded(
                child: Text(
                  'At least one destination must remain '
                  'enabled so travellers can continue '
                  'creating trips.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
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
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 136),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ---------------------------------------------------
          // STATISTIC ICON
          // ---------------------------------------------------
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),

          const SizedBox(height: 11),

          // ---------------------------------------------------
          // STATISTIC VALUE
          // ---------------------------------------------------
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          // ---------------------------------------------------
          // STATISTIC LABEL
          // ---------------------------------------------------
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryCard(Country country) {
    final bool isEnabled = country.enabled;
    final bool isUpdating = _updatingCountryId == country.id;

    final Color actionColor = isEnabled
        ? const Color(0xFFA86300)
        : AppColors.primary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------------------------------------------
          // DESTINATION NAME AND STATUS
          // ---------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      country.name,
                      softWrap: true,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      country.code.isEmpty ? country.id : country.code,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              _buildStatusBadge(isEnabled),
            ],
          ),

          const SizedBox(height: 14),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 12),

          // ---------------------------------------------------
          // LAST UPDATED DATE
          // ---------------------------------------------------
          Row(
            children: [
              const Icon(
                Icons.schedule_outlined,
                color: AppColors.secondaryText,
                size: 17,
              ),

              const SizedBox(width: 7),

              Expanded(
                child: Text(
                  'Last updated: ${_formatDate(country.lastUpdated)}',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ---------------------------------------------------
          // DESTINATION AVAILABILITY ACTION
          // ---------------------------------------------------
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _updatingCountryId != null
                  ? null
                  : () {
                      _changeDestinationStatus(country);
                    },

              style: OutlinedButton.styleFrom(
                foregroundColor: actionColor,
                backgroundColor: isEnabled
                    ? const Color(0xFFFFF9EE)
                    : AppColors.primaryLight,
                side: BorderSide(
                  color: isEnabled ? const Color(0xFFEAD5AF) : AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              icon: isUpdating
                  ? SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: actionColor,
                      ),
                    )
                  : Icon(
                      isEnabled
                          ? Icons.block_outlined
                          : Icons.check_circle_outline_rounded,
                      size: 19,
                    ),

              label: Text(
                isUpdating
                    ? 'Updating Destination...'
                    : isEnabled
                    ? 'Disable Destination'
                    : 'Enable Destination',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool enabled) {
    final Color statusColor = enabled
        ? AppColors.success
        : AppColors.secondaryText;

    final Color backgroundColor = enabled
        ? const Color(0xFFE7F7F1)
        : const Color(0xFFF1F3F5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled
                ? Icons.check_circle_rounded
                : Icons.remove_circle_outline_rounded,
            color: statusColor,
            size: 13,
          ),

          const SizedBox(width: 5),

          Text(
            enabled ? 'ENABLED' : 'DISABLED',
            style: TextStyle(
              color: statusColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.public_off_outlined, color: AppColors.primary, size: 42),
          SizedBox(height: 14),
          Text(
            'No Destinations Found',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'No supported destinations are currently '
            'available in the system.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Unable to Load Destinations',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Destination information could not be retrieved. '
            'Please check your connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
