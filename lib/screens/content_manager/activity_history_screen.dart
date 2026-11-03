import 'package:flutter/material.dart';

import '../../models/rule_activity_log.dart';
import '../../services/content_manager_service.dart';
import '../../widgets/role_ui_widgets.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({
    super.key,
    this.embedded = false,
    this.reloadVersion = 0,
  });

  final bool embedded;
  final int reloadVersion;

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  // ---------------------------------------------------------------------------
  // ACTIVITY HISTORY STATE
  // ---------------------------------------------------------------------------

  final _service = ContentManagerService();
  final _searchController = TextEditingController();
  List<RuleActivityLog>? _logs;
  String _search = '';
  String _filter = 'all';
  bool _loading = false;
  bool _failed = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // Refresh when returning to this tab, while preserving its search and filter.
  @override
  void didUpdateWidget(covariant ActivityHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadVersion != widget.reloadVersion) _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Handle refresh errors locally instead of exposing uncaught future errors.
  Future<void> _loadHistory() async {
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
    });
    try {
      final logs = await _service.getActivityHistory();
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _logs = logs;
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

  // ---------------------------------------------------------------------------
  // ACTIVITY LABELS AND LOCAL FILTERS
  // ---------------------------------------------------------------------------

  String _actionLabel(String action) => switch (action) {
    'created' => 'Rule created',
    'updated' => 'Rule updated',
    'enabled' => 'Rule enabled',
    'disabled' => 'Rule disabled',
    _ => 'Regulatory activity',
  };

  List<RuleActivityLog> get _visibleLogs {
    final query = _search.trim().toLowerCase();
    return (_logs ?? []).where((log) {
      final matchesAction = _filter == 'all' || log.action == _filter;
      final matchesSearch =
          query.isEmpty ||
          '${log.ruleTitle} ${log.countryId} ${log.performedByName} ${log.performedByEmail} ${_actionLabel(log.action)}'
              .toLowerCase()
              .contains(query);
      return matchesAction && matchesSearch;
    }).toList();
  }

  // Convert stored country identifiers into readable destination names.
  String _countryLabel(String id) => id
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final visible = _visibleLogs;
    final body = RolePageBody(
      storageId: 'content-manager-activity',
      onRefresh: _loadHistory,
      children: [
        const RoleIntroCard(
          eyebrow: 'Regulatory activity',
          title: 'Keep every regulation traceable.',
          description:
              'Review regulation updates, publication changes and the manager responsible.',
          icon: Icons.history_rounded,
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() {
            _search = value;
          }),
          decoration: InputDecoration(
            labelText: 'Search activity',
            hintText: 'Regulation, destination or manager',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _search = '';
                      });
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final option in [
              ('all', 'All'),
              ('created', 'Created'),
              ('updated', 'Updated'),
              ('enabled', 'Enabled'),
              ('disabled', 'Disabled'),
            ])
              ChoiceChip(
                label: Text(option.$2),
                selected: _filter == option.$1,
                onSelected: (_) => setState(() {
                  _filter = option.$1;
                }),
              ),
          ],
        ),
        RoleSectionTitle(
          title: _logs == null
              ? 'History'
              : 'History · ${visible.length} shown',
        ),
        if (_loading)
          const RoleStatusCard(
            title: 'Loading activity',
            message: 'Retrieving regulatory changes.',
            loading: true,
          ),
        if (_failed)
          RoleStatusCard(
            title: 'Unable to refresh activity',
            message: _logs == null
                ? 'Check your connection and try again.'
                : 'Showing the last loaded history.',
            icon: Icons.cloud_off_outlined,
            onRetry: _loading ? null : _loadHistory,
          ),
        if (_logs != null && visible.isEmpty && !_loading)
          RoleStatusCard(
            title: _logs!.isEmpty
                ? 'No regulatory activity yet'
                : 'No matching activity',
            message: _logs!.isEmpty
                ? 'Created, edited, enabled and disabled regulations will appear here.'
                : 'Try another search or activity filter.',
            icon: Icons.history_rounded,
          ),
        for (final log in visible)
          RoleActivityTile(
            key: ValueKey(log.id),
            title: _actionLabel(log.action),
            target: log.ruleTitle.isEmpty
                ? 'Untitled regulation'
                : log.ruleTitle,
            details: 'Destination: ${_countryLabel(log.countryId)}',
            actor: log.performedByName.isNotEmpty
                ? log.performedByName
                : log.performedByEmail.isNotEmpty
                ? log.performedByEmail
                : 'Content Manager',
            timestamp: log.timestamp,
          ),
      ],
    );
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: const Text('Activity')),
            body: SafeArea(child: body),
          );
  }
}
