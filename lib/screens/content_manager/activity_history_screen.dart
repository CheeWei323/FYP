import 'package:flutter/material.dart';

import '../../models/rule_activity_log.dart';
import '../../services/content_manager_service.dart';
import '../../theme/app_theme.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  final ContentManagerService _contentManagerService = ContentManagerService();

  final TextEditingController _searchController = TextEditingController();

  late Future<List<RuleActivityLog>> _activityFuture;

  String _selectedFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _activityFuture = _contentManagerService.getActivityHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // DATA AND REFRESH
  // ---------------------------------------------------------------------------

  Future<void> _refresh() async {
    final Future<List<RuleActivityLog>> newFuture = _contentManagerService
        .getActivityHistory();

    setState(() {
      _activityFuture = newFuture;
    });

    await newFuture;
  }

  // ---------------------------------------------------------------------------
  // SEARCH AND FILTERING
  // ---------------------------------------------------------------------------

  List<RuleActivityLog> _applyFilters(List<RuleActivityLog> logs) {
    final String search = _searchQuery.trim().toLowerCase();

    return logs.where((log) {
      final bool matchesAction =
          _selectedFilter == 'all' || log.action == _selectedFilter;

      if (!matchesAction) return false;

      if (search.isEmpty) return true;

      return log.ruleTitle.toLowerCase().contains(search) ||
          log.performedByName.toLowerCase().contains(search) ||
          log.performedByEmail.toLowerCase().contains(search) ||
          log.countryId.toLowerCase().contains(search) ||
          log.action.toLowerCase().contains(search);
    }).toList();
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
      _selectedFilter = 'all';
    });
  }

  // ---------------------------------------------------------------------------
  // FORMATTING
  // ---------------------------------------------------------------------------

  String _formatActivityDate(DateTime? date) {
    if (date == null) return 'Timestamp unavailable';

    final DateTime localDate = date.toLocal();

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

    final int hour = localDate.hour;
    final int displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

    final String minute = localDate.minute.toString().padLeft(2, '0');

    final String period = hour >= 12 ? 'PM' : 'AM';

    return '${localDate.day} '
        '${months[localDate.month - 1]} '
        '${localDate.year}, '
        '$displayHour:$minute $period';
  }

  String _formatCountry(String countryId) {
    switch (countryId) {
      case 'japan':
        return 'Japan';
      case 'united_states':
        return 'United States';
      case 'australia':
        return 'Australia';
      case 'united_kingdom':
        return 'United Kingdom';
      case 'south_korea':
        return 'South Korea';
      default:
        return countryId
            .split('_')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
            )
            .join(' ');
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'created':
        return 'Created';
      case 'updated':
        return 'Updated';
      case 'enabled':
        return 'Enabled';
      case 'disabled':
        return 'Disabled';
      default:
        return 'Activity';
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'created':
        return Icons.add_circle_outline_rounded;
      case 'updated':
        return Icons.edit_outlined;
      case 'enabled':
        return Icons.check_circle_outline_rounded;
      case 'disabled':
        return Icons.pause_circle_outline_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'enabled':
        return AppColors.success;
      case 'disabled':
        return const Color(0xFFA86300);
      case 'updated':
        return const Color(0xFF315FAD);
      default:
        return AppColors.primary;
    }
  }

  Color _actionBackground(String action) {
    switch (action) {
      case 'enabled':
        return const Color(0xFFEAF7F1);
      case 'disabled':
        return const Color(0xFFFFF4DC);
      case 'updated':
        return const Color(0xFFEAF1FF);
      default:
        return AppColors.primaryLight;
    }
  }

  // ---------------------------------------------------------------------------
  // SHARED UI HELPERS
  // ---------------------------------------------------------------------------

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
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
    );
  }

  Widget _buildStateCard({
    required IconData icon,
    required String title,
    required String message,
    bool isLoading = false,
    VoidCallback? onRetry,
    VoidCallback? onClear,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 15),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          if (isLoading) ...[
            const SizedBox(height: 18),
            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
            ),
          ],
          if (onClear != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN SCREEN
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.navy,
        title: const Text(
          'Activity History',
          style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: FutureBuilder<List<RuleActivityLog>>(
            future: _activityFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(18),
                  children: [
                    const SizedBox(height: 70),
                    _buildStateCard(
                      icon: Icons.history_rounded,
                      title: 'Loading Activity History',
                      message: 'Retrieving regulatory activity records...',
                      isLoading: true,
                    ),
                  ],
                );
              }

              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(18),
                  children: [
                    const SizedBox(height: 70),
                    _buildStateCard(
                      icon: Icons.cloud_off_outlined,
                      title: 'Unable to Load Activity',
                      message:
                          'Activity records could not be retrieved. '
                          'Please try again.',
                      onRetry: _refresh,
                    ),
                  ],
                );
              }

              final List<RuleActivityLog> allLogs =
                  snapshot.data ?? <RuleActivityLog>[];

              final List<RuleActivityLog> visibleLogs = _applyFilters(allLogs);

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                children: [
                  _buildSummaryCard(allLogs.length),

                  const SizedBox(height: 20),

                  _buildSearchField(),

                  const SizedBox(height: 13),

                  _buildFilters(),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Regulatory Activity',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${visibleLogs.length} '
                        '${visibleLogs.length == 1 ? 'record' : 'records'}',
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (allLogs.isEmpty)
                    _buildStateCard(
                      icon: Icons.history_rounded,
                      title: 'No Activity Recorded',
                      message:
                          'Regulatory activity will appear here '
                          'after travel rules are created, updated, '
                          'enabled or disabled.',
                    )
                  else if (visibleLogs.isEmpty)
                    _buildStateCard(
                      icon: Icons.search_off_rounded,
                      title: 'No Matching Activity',
                      message:
                          'Try another search term or select '
                          'a different activity filter.',
                      onClear: _clearFilters,
                    )
                  else
                    for (final RuleActivityLog log in visibleLogs)
                      _buildActivityCard(log),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUMMARY CARD
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCard(int totalRecords) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 49,
                height: 49,
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
                      'Regulation Traceability',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Review regulatory changes made '
                      'by Content Managers.',
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

          const SizedBox(height: 16),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(
                Icons.fact_check_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '$totalRecords '
                  '${totalRecords == 1 ? 'activity record' : 'activity records'} '
                  'retrieved',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH FIELD
  // ---------------------------------------------------------------------------

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      style: const TextStyle(color: AppColors.navy, fontSize: 13.5),
      decoration: InputDecoration(
        hintText: 'Search rule, country or manager',
        hintStyle: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 13,
        ),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.secondaryText,
                  size: 20,
                ),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIVITY FILTERS
  // ---------------------------------------------------------------------------

  Widget _buildFilters() {
    const List<Map<String, String>> filters = [
      {'value': 'all', 'label': 'All'},
      {'value': 'created', 'label': 'Created'},
      {'value': 'updated', 'label': 'Updated'},
      {'value': 'enabled', 'label': 'Enabled'},
      {'value': 'disabled', 'label': 'Disabled'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final String value = filter['value']!;
          final bool selected = _selectedFilter == value;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                filter['label']!,
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.secondaryText,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) {
                setState(() {
                  _selectedFilter = value;
                });
              },
              selectedColor: AppColors.primaryLight,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIVITY CARD
  // ---------------------------------------------------------------------------

  Widget _buildActivityCard(RuleActivityLog log) {
    final Color accentColor = _actionColor(log.action);
    final Color accentBackground = _actionBackground(log.action);

    final String ruleTitle = log.ruleTitle.trim().isNotEmpty
        ? log.ruleTitle
        : 'Untitled Regulation';

    final String managerName = log.performedByName.trim().isNotEmpty
        ? log.performedByName
        : 'Content Manager';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentBackground,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _actionIcon(log.action),
                  color: accentColor,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildActionBadge(log.action),

                    const SizedBox(height: 9),

                    Text(
                      ruleTitle,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 12),

          _buildDetailRow(
            icon: Icons.public_outlined,
            value: _formatCountry(log.countryId),
          ),

          const SizedBox(height: 9),

          _buildDetailRow(
            icon: Icons.person_outline_rounded,
            value: managerName,
          ),

          if (log.performedByEmail.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.only(left: 25),
              child: Text(
                log.performedByEmail,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ],

          const SizedBox(height: 9),

          _buildDetailRow(
            icon: Icons.schedule_outlined,
            value: _formatActivityDate(log.timestamp),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBadge(String action) {
    final Color color = _actionColor(action);
    final Color background = _actionBackground(action);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        _actionLabel(action).toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildDetailRow({required IconData icon, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.secondaryText, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
