import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/country.dart';
import '../../models/travel_rule.dart';
import '../../services/content_manager_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/role_ui_widgets.dart';
import 'travel_rule_form_screen.dart';

class ManageTravelRulesScreen extends StatefulWidget {
  const ManageTravelRulesScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ManageTravelRulesScreen> createState() =>
      _ManageTravelRulesScreenState();
}

class _ManageTravelRulesScreenState extends State<ManageTravelRulesScreen> {
  // ---------------------------------------------------------------------------
  // DESTINATION AND REGULATION STATE
  // ---------------------------------------------------------------------------

  final _service = ContentManagerService();
  final _searchController = TextEditingController();
  List<Country>? _countries;
  Country? _selectedCountry;
  List<TravelRule>? _rules;
  String _search = '';
  String _statusFilter = 'all';
  String? _savingRuleId;
  bool _loadingCountries = false;
  bool _loadingRules = false;
  bool _countriesFailed = false;
  bool _rulesFailed = false;
  int _countryRequest = 0;
  int _ruleRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Preserve the selected destination when reloading the supported country list.
  Future<void> _loadCountries() async {
    final request = ++_countryRequest;
    setState(() {
      _loadingCountries = true;
    });
    try {
      final countries = await _service.getAllCountries();
      if (!mounted || request != _countryRequest) return;
      Country? selected;
      for (final country in countries) {
        if (country.id == _selectedCountry?.id) selected = country;
      }
      selected ??= countries.isEmpty ? null : countries.first;
      final changedCountry = selected?.id != _selectedCountry?.id;
      setState(() {
        _countries = countries;
        _selectedCountry = selected;
        _countriesFailed = false;
        if (changedCountry || selected == null) {
          _ruleRequest++;
          _rules = null;
          _rulesFailed = false;
          _loadingRules = false;
        }
      });
      if (selected != null) await _loadRules(selected.id);
    } catch (_) {
      if (!mounted || request != _countryRequest) return;
      setState(() {
        _countriesFailed = true;
      });
    } finally {
      if (mounted && request == _countryRequest) {
        setState(() {
          _loadingCountries = false;
        });
      }
    }
  }

  // Ignore responses for an older request, including when selecting A, B, then A.
  Future<void> _loadRules(String countryId) async {
    final request = ++_ruleRequest;
    setState(() {
      _loadingRules = true;
    });
    try {
      final rules = await _service.getRulesForCountry(countryId);
      if (!mounted ||
          request != _ruleRequest ||
          _selectedCountry?.id != countryId) {
        return;
      }
      setState(() {
        _rules = rules;
        _rulesFailed = false;
      });
    } catch (_) {
      if (!mounted ||
          request != _ruleRequest ||
          _selectedCountry?.id != countryId) {
        return;
      }
      setState(() {
        _rulesFailed = true;
      });
    } finally {
      if (mounted &&
          request == _ruleRequest &&
          _selectedCountry?.id == countryId) {
        setState(() {
          _loadingRules = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    if (_savingRuleId != null) return;
    await _loadCountries();
  }

  // Clear old destination results immediately, while keeping the local filters.
  void _selectCountry(String? id) {
    if (id == null ||
        id == _selectedCountry?.id ||
        _savingRuleId != null ||
        _loadingCountries) {
      return;
    }
    final country = _countries!.firstWhere((country) => country.id == id);
    setState(() {
      _selectedCountry = country;
      _rules = null;
      _rulesFailed = false;
    });
    _loadRules(id);
  }

  // ---------------------------------------------------------------------------
  // DISPLAY LABELS AND LOCAL FILTERS
  // ---------------------------------------------------------------------------

  String _label(String value) => value
      .replaceAll('_', ' ')
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');

  String _reviewLabel(String status) => switch (status) {
    'approved' => 'Approved',
    'pendingReview' => 'Pending review',
    'disabled' => 'Disabled',
    _ => _label(status),
  };

  String _durationLabel(TravelRule rule) => rule.maxDurationDays == null
      ? '${rule.minDurationDays}+ days'
      : rule.minDurationDays == rule.maxDurationDays
      ? '${rule.minDurationDays} days'
      : '${rule.minDurationDays}–${rule.maxDurationDays} days';

  List<TravelRule> get _visibleRules {
    final query = _search.trim().toLowerCase();
    return (_rules ?? []).where((rule) {
      final matchesStatus =
          _statusFilter == 'all' || rule.reviewStatus == _statusFilter;
      final matchesSearch =
          query.isEmpty ||
          '${rule.title} ${rule.checklistLabel} ${rule.category} ${rule.sourceName} ${rule.purposes.join(' ')}'
              .toLowerCase()
              .contains(query);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  bool get _busy => _loadingCountries || _loadingRules || _savingRuleId != null;
  bool get _canEdit =>
      !_busy && !_countriesFailed && !_rulesFailed && _selectedCountry != null;

  // ---------------------------------------------------------------------------
  // OFFICIAL SOURCES AND ADD / EDIT NAVIGATION
  // ---------------------------------------------------------------------------

  Future<void> _openSource(TravelRule rule) async {
    final uri = Uri.tryParse(rule.officialUrl);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      _showMessage('This regulation does not contain a valid official source.');
      return;
    }
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      if (!mounted) return;
    }
    if (mounted) _showMessage('Unable to open the official source.');
  }

  Future<void> _openForm({TravelRule? rule}) async {
    final country = _selectedCountry;
    if (!_canEdit || country == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            TravelRuleFormScreen(country: country, existingRule: rule),
      ),
    );
    if (!mounted || changed != true) return;
    await _loadRules(country.id);
  }

  // ---------------------------------------------------------------------------
  // CONFIRMED PUBLICATION CHANGES
  // ---------------------------------------------------------------------------

  Future<void> _changeStatus(TravelRule rule) async {
    if (!_canEdit) return;
    final enable = !rule.active;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(enable ? 'Enable regulation?' : 'Disable regulation?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rule.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                enable
                    ? 'Confirm that the regulation and official source have been reviewed. Enabling approves it for future traveller requirements.'
                    : 'This regulation will remain saved but will be excluded from future generated requirements.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(enable ? 'Enable rule' : 'Disable rule'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || !_canEdit) return;
    setState(() {
      _savingRuleId = rule.id;
    });
    try {
      // The existing service applies the publication status and its activity log.
      await _service.setTravelRuleActive(rule: rule, active: enable);
      if (!mounted) return;
      _showMessage(
        enable ? 'Regulation enabled and approved.' : 'Regulation disabled.',
      );
      await _loadRules(rule.countryId);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to update this regulation. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _savingRuleId = null;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleRules;
    final countries = _countries;
    final body = RolePageBody(
      storageId: 'content-manager-regulations',
      onRefresh: _refresh,
      children: [
        const RoleIntroCard(
          eyebrow: 'Travel regulations',
          title: 'Clear guidance starts with reliable information.',
          description:
              'Select a destination to maintain requirements, review their sources and manage publication.',
          icon: Icons.policy_outlined,
        ),
        const SizedBox(height: 18),
        if (_loadingCountries)
          const RoleStatusCard(
            title: 'Loading destinations',
            message: 'Retrieving supported destinations.',
            loading: true,
          ),
        if (_countriesFailed)
          RoleStatusCard(
            title: 'Unable to refresh destinations',
            message: countries == null
                ? 'Check your connection and try again.'
                : 'Showing the last loaded destinations. Refresh before editing regulations.',
            icon: Icons.cloud_off_outlined,
            onRetry: _busy ? null : _refresh,
          ),
        if (countries != null && countries.isEmpty && !_loadingCountries)
          const RoleStatusCard(
            title: 'No destinations available',
            message: 'Supported destinations will appear here when configured.',
            icon: Icons.public_outlined,
          ),
        if (countries != null && countries.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            key: ValueKey('regulation-country-${_selectedCountry?.id}'),
            initialValue: _selectedCountry?.id,
            isExpanded: true,
            itemHeight: null,
            decoration: const InputDecoration(
              labelText: 'Destination',
              prefixIcon: Icon(Icons.public_outlined),
            ),
            items: countries
                .map(
                  (country) => DropdownMenuItem<String>(
                    value: country.id,
                    child: Text(
                      country.enabled
                          ? country.name
                          : '${country.name} · Disabled for new trips',
                    ),
                  ),
                )
                .toList(),
            onChanged: _savingRuleId != null || _loadingCountries
                ? null
                : _selectCountry,
          ),
          if (_selectedCountry?.enabled == false) ...[
            const SizedBox(height: 10),
            const Text(
              'You can maintain regulations for this destination while it is disabled for new trips.',
              style: TextStyle(fontSize: 12),
            ),
          ],
          RoleSectionTitle(
            title: 'Regulations',
            action: FilledButton.icon(
              onPressed: _canEdit ? () => _openForm() : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add rule'),
            ),
          ),
          if (_rules != null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                RoleBadge(label: '${_rules!.length} total'),
                RoleBadge(
                  label:
                      '${_rules!.where((rule) => rule.reviewStatus == 'approved').length} approved',
                ),
                RoleBadge(
                  label:
                      '${_rules!.where((rule) => rule.reviewStatus == 'pendingReview').length} pending review',
                ),
                RoleBadge(
                  label:
                      '${_rules!.where((rule) => rule.reviewStatus == 'disabled').length} disabled',
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() {
              _search = value;
            }),
            decoration: InputDecoration(
              labelText: 'Search regulations',
              hintText: 'Title, category, source or purpose',
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
              for (final status in [
                ('all', 'All'),
                ('approved', 'Approved'),
                ('pendingReview', 'Pending review'),
                ('disabled', 'Disabled'),
              ])
                ChoiceChip(
                  label: Text(status.$2),
                  selected: _statusFilter == status.$1,
                  onSelected: (_) => setState(() {
                    _statusFilter = status.$1;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingRules)
            const RoleStatusCard(
              title: 'Loading regulations',
              message: 'Retrieving requirements for the selected destination.',
              loading: true,
            ),
          if (_rulesFailed)
            RoleStatusCard(
              title: 'Unable to refresh regulations',
              message: _rules == null
                  ? 'Check your connection and try again.'
                  : 'Showing the last loaded regulations. Refresh before making changes.',
              icon: Icons.cloud_off_outlined,
              onRetry: _busy ? null : () => _loadRules(_selectedCountry!.id),
            ),
          if (_rules != null && visible.isEmpty && !_loadingRules) ...[
            RoleStatusCard(
              title: _rules!.isEmpty
                  ? 'No regulations for this destination'
                  : 'No matching regulations',
              message: _rules!.isEmpty
                  ? 'Add a regulation with its official source to begin.'
                  : 'Try another search or review-status filter.',
              icon: Icons.policy_outlined,
            ),
            if (_rules!.isNotEmpty)
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _search = '';
                    _statusFilter = 'all';
                  });
                },
                child: const Text('Clear filters'),
              ),
          ],
          for (final rule in visible) _ruleCard(rule),
        ],
      ],
    );
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: const Text('Regulations')),
            body: SafeArea(child: body),
          );
  }

  Widget _ruleCard(TravelRule rule) {
    final saving = _savingRuleId == rule.id;
    return Card(
      key: ValueKey('regulation-${rule.id}'),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              rule.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                RoleBadge(label: _reviewLabel(rule.reviewStatus)),
                RoleBadge(
                  label: rule.active ? 'Active' : 'Inactive',
                  color: rule.active
                      ? AppColors.success
                      : AppColors.secondaryText,
                ),
                RoleBadge(
                  label: rule.mandatory ? 'Mandatory' : 'Informational',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Checklist: ${rule.checklistLabel}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(rule.description),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                RoleBadge(label: _label(rule.category)),
                RoleBadge(label: _durationLabel(rule)),
                for (final purpose in rule.purposes)
                  RoleBadge(
                    label: purpose == 'all' ? 'All purposes' : _label(purpose),
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1),
            ),
            Text(
              'Source: ${rule.sourceName}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              'Last validated: ${formatRoleDate(rule.lastValidatedAt)}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              'Priority: ${rule.priority}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _canEdit ? () => _openForm(rule: rule) : null,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openSource(rule),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Official source'),
                ),
                OutlinedButton.icon(
                  onPressed: _canEdit ? () => _changeStatus(rule) : null,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          rule.active
                              ? Icons.pause_circle_outline_rounded
                              : Icons.check_circle_outline_rounded,
                        ),
                  label: Text(
                    saving
                        ? 'Updating...'
                        : rule.active
                        ? 'Disable'
                        : 'Enable',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
