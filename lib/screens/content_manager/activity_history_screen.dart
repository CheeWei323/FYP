import 'package:flutter/material.dart';

import '../../models/rule_activity_log.dart';
import '../../services/content_manager_service.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  final ContentManagerService _contentManagerService = ContentManagerService();

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

  final TextEditingController _searchController = TextEditingController();

  late Future<List<RuleActivityLog>> _activityFuture;

  List<RuleActivityLog> _allLogs = [];

  String _selectedFilter = 'all';

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _activityFuture = _loadActivity();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------------------

  Future<List<RuleActivityLog>> _loadActivity() async {
    final List<RuleActivityLog> logs = await _contentManagerService
        .getActivityHistory();

    _allLogs = logs;

    return logs;
  }

  Future<void> _refresh() async {
    final Future<List<RuleActivityLog>> newFuture = _loadActivity();

    setState(() {
      _activityFuture = newFuture;
    });

    await newFuture;
  }

  // ---------------------------------------------------------------------------
  // FILTERING
  // ---------------------------------------------------------------------------

  List<RuleActivityLog> _applyFilters(List<RuleActivityLog> logs) {
    return logs.where((log) {
      final bool matchesAction =
          _selectedFilter == 'all' || log.action == _selectedFilter;

      if (!matchesAction) {
        return false;
      }

      final String search = _searchQuery.trim().toLowerCase();

      if (search.isEmpty) {
        return true;
      }

      return log.ruleTitle.toLowerCase().contains(search) ||
          log.performedByName.toLowerCase().contains(search) ||
          log.performedByEmail.toLowerCase().contains(search) ||
          log.countryId.toLowerCase().contains(search) ||
          log.action.toLowerCase().contains(search);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // FORMATTING
  // ---------------------------------------------------------------------------

  String _formatActivityDate(DateTime? date) {
    if (date == null) {
      return 'Timestamp unavailable';
    }

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

    final int displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;

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
                  : '${word[0].toUpperCase()}'
                        '${word.substring(1)}',
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
          'Activity History',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<RuleActivityLog>>(
            future: _activityFuture,
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

              final List<RuleActivityLog> logs = _applyFilters(_allLogs);

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                children: [
                  _buildSummaryCard(),

                  const SizedBox(height: 18),

                  _buildSearchField(),

                  const SizedBox(height: 14),

                  _buildFilters(),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Regulatory Activity',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _darkTextColor,
                          ),
                        ),
                      ),

                      Text(
                        '${logs.length} '
                        '${logs.length == 1 ? 'record' : 'records'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (_allLogs.isEmpty)
                    _buildEmptyState()
                  else if (logs.isEmpty)
                    _buildNoResultsState()
                  else
                    ...logs.map(_buildActivityCard),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUMMARY
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: _primaryColor,
              size: 24,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Regulation Traceability',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _darkTextColor,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '${_allLogs.length} '
                  '${_allLogs.length == 1 ? 'activity record' : 'activity records'} '
                  'stored for regulatory management.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
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

  // ---------------------------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------------------------

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search rule, country or manager',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primaryColor, width: 1.4),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTERS
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
              label: Text(filter['label']!),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedFilter = value;
                });
              },
              showCheckmark: false,
              selectedColor: const Color(0xFFDFF3F5),
              backgroundColor: Colors.white,
              side: BorderSide(color: selected ? _primaryColor : _borderColor),
              labelStyle: TextStyle(
                color: selected ? _primaryColor : const Color(0xFF486581),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _actionIcon(log.action),
              color: _primaryColor,
              size: 21,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_actionLabel(log.action)} rule',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _darkTextColor,
                        ),
                      ),
                    ),

                    _buildActionBadge(log.action),
                  ],
                ),

                const SizedBox(height: 6),

                Text(
                  log.ruleTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334E68),
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    const Icon(
                      Icons.public_outlined,
                      size: 14,
                      color: Colors.black45,
                    ),

                    const SizedBox(width: 5),

                    Expanded(
                      child: Text(
                        _formatCountry(log.countryId),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: Colors.black45,
                    ),

                    const SizedBox(width: 5),

                    Expanded(
                      child: Text(
                        log.performedByName,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),

                if (log.performedByEmail.isNotEmpty) ...[
                  const SizedBox(height: 3),

                  Padding(
                    padding: const EdgeInsets.only(left: 19),
                    child: Text(
                      log.performedByEmail,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Colors.black45,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 7),

                Row(
                  children: [
                    const Icon(
                      Icons.schedule_outlined,
                      size: 14,
                      color: Colors.black45,
                    ),

                    const SizedBox(width: 5),

                    Text(
                      _formatActivityDate(log.timestamp),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBadge(String action) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _actionLabel(action),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _primaryColor,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STATES
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.history_rounded, size: 38, color: Colors.black38),

          SizedBox(height: 10),

          Text(
            'No activity recorded yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _darkTextColor,
            ),
          ),

          SizedBox(height: 5),

          Text(
            'Regulatory management activity will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, size: 36, color: Colors.black38),

          SizedBox(height: 9),

          Text(
            'No matching activity',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _darkTextColor,
            ),
          ),

          SizedBox(height: 4),

          Text(
            'Try another search term or activity filter.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
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
            'Unable to load activity history.',
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
