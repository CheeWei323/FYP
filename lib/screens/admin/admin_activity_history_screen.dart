import 'package:flutter/material.dart';

import '../../models/admin_activity_log.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class AdminActivityHistoryScreen extends StatefulWidget {
  const AdminActivityHistoryScreen({super.key});

  @override
  State<AdminActivityHistoryScreen> createState() =>
      _AdminActivityHistoryScreenState();
}

class _AdminActivityHistoryScreenState
    extends State<AdminActivityHistoryScreen> {
  final AdminService _adminService = AdminService();

  final TextEditingController _searchController = TextEditingController();

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  late Future<List<AdminActivityLog>> _historyFuture;

  List<AdminActivityLog> _logs = [];

  String _searchText = '';
  String _filter = 'all';

  @override
  void initState() {
    super.initState();

    _historyFuture = _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<AdminActivityLog>> _loadHistory() async {
    final List<AdminActivityLog> logs = await _adminService
        .getActivityHistory();

    _logs = logs;

    return logs;
  }

  Future<void> _refresh() async {
    final Future<List<AdminActivityLog>> future = _loadHistory();

    setState(() {
      _historyFuture = future;
    });

    await future;
  }

  List<AdminActivityLog> get _visibleLogs {
    final String search = _searchText.trim().toLowerCase();

    return _logs.where((log) {
      final bool matchesFilter = switch (_filter) {
        'roleChanged' => log.action == 'roleChanged',
        'destinationEnabled' => log.action == 'destinationEnabled',
        'destinationDisabled' => log.action == 'destinationDisabled',
        _ => true,
      };

      if (!matchesFilter) {
        return false;
      }

      if (search.isEmpty) {
        return true;
      }

      return log.targetName.toLowerCase().contains(search) ||
          log.details.toLowerCase().contains(search) ||
          log.performedByName.toLowerCase().contains(search) ||
          log.performedByEmail.toLowerCase().contains(search) ||
          _actionLabel(log.action).toLowerCase().contains(search);
    }).toList();
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'roleChanged':
        return 'Role Changed';

      case 'destinationEnabled':
        return 'Destination Enabled';

      case 'destinationDisabled':
        return 'Destination Disabled';

      default:
        return 'Administrative Action';
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'roleChanged':
        return Icons.manage_accounts_outlined;

      case 'destinationEnabled':
        return Icons.check_circle_outline_rounded;

      case 'destinationDisabled':
        return Icons.block_outlined;

      default:
        return Icons.history_rounded;
    }
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) {
      return 'Time pending';
    }

    final DateTime local = timestamp.toLocal();

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

    final int hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;

    final String minute = local.minute.toString().padLeft(2, '0');

    final String period = local.hour >= 12 ? 'PM' : 'AM';

    return '${local.day} '
        '${months[local.month - 1]} '
        '${local.year}, '
        '$hour:$minute $period';
  }

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
          'Activity History',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<AdminActivityLog>>(
            future: _historyFuture,
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
                            'Loading Activity History',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          SizedBox(height: 8),

                          Text(
                            'Retrieving administrative activity records...',
                            textAlign: TextAlign.center,
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
                );
              }

              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(18),
                  children: [const SizedBox(height: 70), _buildErrorState()],
                );
              }

              final List<AdminActivityLog> visibleLogs = _visibleLogs;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                children: [
                  _buildIntroCard(),

                  const SizedBox(height: 18),

                  _buildSearchField(),

                  const SizedBox(height: 14),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip(label: 'All', value: 'all'),
                        _filterChip(
                          label: 'Role Changes',
                          value: 'roleChanged',
                        ),
                        _filterChip(
                          label: 'Enabled',
                          value: 'destinationEnabled',
                        ),
                        _filterChip(
                          label: 'Disabled',
                          value: 'destinationDisabled',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'History',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _darkTextColor,
                          ),
                        ),
                      ),
                      Text(
                        '${visibleLogs.length} shown',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (visibleLogs.isEmpty)
                    _buildEmptyState()
                  else
                    for (final log in visibleLogs) _buildActivityCard(log),
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
      padding: const EdgeInsets.all(18),
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
          // ACTIVITY HISTORY HEADER
          // ---------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),

              const SizedBox(width: 13),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Administrative Activity',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),

                    SizedBox(height: 7),

                    Text(
                      'Review successful role and '
                      'destination management actions.',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 12),

          // ---------------------------------------------------
          // TOTAL RECORDED ACTIVITY
          // ---------------------------------------------------
          Row(
            children: [
              const Icon(
                Icons.fact_check_outlined,
                color: AppColors.primary,
                size: 18,
              ),

              const SizedBox(width: 8),

              Text(
                '${_logs.length} recorded '
                '${_logs.length == 1 ? 'action' : 'actions'}',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onChanged: (value) {
        setState(() {
          _searchText = value;
        });
      },
      style: const TextStyle(color: AppColors.navy, fontSize: 13.5),
      decoration: InputDecoration(
        hintText: 'Search activity, user or destination',
        hintStyle: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 12.5,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.primary,
          size: 22,
        ),
        suffixIcon: _searchText.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.secondaryText,
                  size: 20,
                ),
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    _searchText = '';
                  });
                },
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _filterChip({required String label, required String value}) {
    final bool isSelected = _filter == value;

    // ---------------------------------------------------
    // FILTER ICON
    // ---------------------------------------------------

    final IconData filterIcon = switch (value) {
      'roleChanged' => Icons.manage_accounts_outlined,
      'destinationEnabled' => Icons.check_circle_outline_rounded,
      'destinationDisabled' => Icons.block_outlined,
      _ => Icons.list_alt_rounded,
    };

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: isSelected,
        showCheckmark: false,

        // -------------------------------------------------
        // FILTER LABEL
        // -------------------------------------------------
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filterIcon,
              size: 16,
              color: isSelected ? AppColors.primary : AppColors.secondaryText,
            ),

            const SizedBox(width: 7),

            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.secondaryText,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),

        // -------------------------------------------------
        // FILTER APPEARANCE
        // -------------------------------------------------
        backgroundColor: Colors.white,
        selectedColor: AppColors.primaryLight,

        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 1.4 : 1,
        ),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),

        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),

        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),

        // -------------------------------------------------
        // EXISTING FILTER LOGIC
        // -------------------------------------------------
        onSelected: (_) {
          setState(() {
            _filter = value;
          });
        },
      ),
    );
  }

  Widget _buildActivityCard(AdminActivityLog log) {
    // ---------------------------------------------------------
    // ACTIVITY TYPE COLOURS
    // ---------------------------------------------------------

    final Color accentColor = switch (log.action) {
      'destinationEnabled' => AppColors.success,
      'destinationDisabled' => const Color(0xFFA86300),
      _ => AppColors.primary,
    };

    final Color accentBackground = switch (log.action) {
      'destinationEnabled' => const Color(0xFFEAF7F1),
      'destinationDisabled' => const Color(0xFFFFF4DC),
      _ => AppColors.primaryLight,
    };

    final String administrator = log.performedByName.trim().isNotEmpty
        ? log.performedByName.trim()
        : log.performedByEmail.trim().isNotEmpty
        ? log.performedByEmail.trim()
        : 'Administrator';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 11),
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
          // ACTIVITY ICON, ACTION TYPE AND TARGET
          // ---------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: accentBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _actionIcon(log.action),
                  color: accentColor,
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Activity type label.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accentBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _actionLabel(log.action).toUpperCase(),
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Affected user or destination.
                    Text(
                      log.targetName.trim().isNotEmpty
                          ? log.targetName
                          : 'Unknown Target',
                      softWrap: true,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ---------------------------------------------------
          // ACTIVITY DESCRIPTION
          // ---------------------------------------------------
          if (log.details.trim().isNotEmpty) ...[
            const SizedBox(height: 12),

            Text(
              log.details,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],

          const SizedBox(height: 14),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 12),

          // ---------------------------------------------------
          // ADMINISTRATOR INFORMATION
          // ---------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.person_outline_rounded,
                color: AppColors.secondaryText,
                size: 17,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  'By $administrator',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ---------------------------------------------------
          // ACTIVITY TIMESTAMP
          // ---------------------------------------------------
          Row(
            children: [
              const Icon(
                Icons.schedule_outlined,
                color: AppColors.secondaryText,
                size: 17,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  _formatTimestamp(log.timestamp),
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
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
            'Unable to Load Activity History',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Administrative activity could not be retrieved. '
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

  Widget _buildEmptyState() {
    final bool noRecords = _logs.isEmpty;

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
          // ---------------------------------------------------
          // EMPTY STATE ICON
          // ---------------------------------------------------
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Icon(
              noRecords ? Icons.history_rounded : Icons.search_off_rounded,
              color: AppColors.primary,
              size: 31,
            ),
          ),

          const SizedBox(height: 16),

          // ---------------------------------------------------
          // EMPTY STATE TITLE
          // ---------------------------------------------------
          Text(
            noRecords ? 'No Activity Recorded' : 'No Matching Activity',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          // ---------------------------------------------------
          // EMPTY STATE DESCRIPTION
          // ---------------------------------------------------
          Text(
            noRecords
                ? 'Administrative actions will appear here '
                      'once activity records are available.'
                : 'No activity matches the selected search '
                      'or filter. Try adjusting your criteria.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),

          // ---------------------------------------------------
          // CLEAR SEARCH AND FILTERS
          // ---------------------------------------------------
          if (!noRecords &&
              (_searchText.trim().isNotEmpty || _filter != 'all')) ...[
            const SizedBox(height: 18),

            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();

                setState(() {
                  _searchText = '';
                  _filter = 'all';
                });
              },
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }
}
