import 'package:flutter/material.dart';

import '../../models/admin_activity_log.dart';
import '../../services/admin_service.dart';

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

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

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
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: Text('Unable to load administrative activity.'),
                    ),
                  ],
                );
              }

              final List<AdminActivityLog> visibleLogs = _visibleLogs;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                children: [
                  const Text(
                    'Administrative Activity',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _darkTextColor,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Review successful role and '
                    'destination management actions.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),

                  const SizedBox(height: 18),

                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchText = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search activity',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchText.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();

                                setState(() {
                                  _searchText = '';
                                });
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _borderColor),
                      ),
                    ),
                  ),

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

  Widget _filterChip({required String label, required String value}) {
    final bool selected = _filter == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _filter = value;
          });
        },
      ),
    );
  }

  Widget _buildActivityCard(AdminActivityLog log) {
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
              size: 22,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _actionLabel(log.action),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _primaryColor,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  log.targetName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _darkTextColor,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  log.details,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF486581),
                  ),
                ),

                const SizedBox(height: 9),

                Text(
                  'By ${log.performedByName.isEmpty ? log.performedByEmail : log.performedByName}',
                  style: const TextStyle(fontSize: 10.5, color: Colors.black54),
                ),

                const SizedBox(height: 2),

                Text(
                  _formatTimestamp(log.timestamp),
                  style: const TextStyle(fontSize: 10.5, color: Colors.black45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.history_rounded, size: 38, color: Colors.black38),
          SizedBox(height: 9),
          Text(
            'No matching activity',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _darkTextColor,
            ),
          ),
        ],
      ),
    );
  }
}
