import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/country.dart';
import '../../models/travel_rule.dart';
import '../../services/content_manager_service.dart';
import '../../theme/app_theme.dart';
import 'travel_rule_form_screen.dart';

class ManageTravelRulesScreen extends StatefulWidget {
  const ManageTravelRulesScreen({super.key});

  @override
  State<ManageTravelRulesScreen> createState() =>
      _ManageTravelRulesScreenState();
}

class _ManageTravelRulesScreenState extends State<ManageTravelRulesScreen> {
  final ContentManagerService _contentManagerService = ContentManagerService();

  final TextEditingController _searchController = TextEditingController();

  List<Country> _countries = [];
  List<TravelRule> _rules = [];

  Country? _selectedCountry;

  bool _isLoadingCountries = true;
  bool _isLoadingRules = false;

  String? _updatingRuleId;
  String? _countryError;
  String? _ruleError;

  String _searchText = '';

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

  // ---------------------------------------------------------------------------
  // DATA LOADING
  // ---------------------------------------------------------------------------

  Future<void> _loadCountries() async {
    setState(() {
      _isLoadingCountries = true;
      _countryError = null;
    });

    try {
      final List<Country> countries = await _contentManagerService
          .getAllCountries();

      if (!mounted) return;

      setState(() {
        _countries = countries;
        _isLoadingCountries = false;
        _selectedCountry = countries.isNotEmpty ? countries.first : null;
      });

      if (_selectedCountry != null) {
        await _loadRules(_selectedCountry!.id);
      }
    } catch (error) {
      debugPrint('CONTENT MANAGER COUNTRY ERROR: $error');

      if (!mounted) return;

      setState(() {
        _isLoadingCountries = false;
        _countryError = 'Unable to load destination countries.';
      });
    }
  }

  Future<void> _loadRules(String countryId) async {
    setState(() {
      _isLoadingRules = true;
      _ruleError = null;
    });

    try {
      final List<TravelRule> rules = await _contentManagerService
          .getRulesForCountry(countryId);

      if (!mounted) return;

      // Ignore a response if the user has since selected another country.
      if (_selectedCountry?.id != countryId) return;

      setState(() {
        _rules = rules;
        _isLoadingRules = false;
      });
    } catch (error) {
      debugPrint('CONTENT MANAGER RULE ERROR: $error');

      if (!mounted || _selectedCountry?.id != countryId) return;

      setState(() {
        _isLoadingRules = false;
        _ruleError = 'Unable to load travel regulations.';
      });
    }
  }

  Future<void> _refresh() async {
    if (_selectedCountry == null) {
      await _loadCountries();
      return;
    }

    await _loadRules(_selectedCountry!.id);
  }

  // ---------------------------------------------------------------------------
  // RULE COUNTS AND SEARCH
  // ---------------------------------------------------------------------------

  List<TravelRule> get _visibleRules {
    final String search = _searchText.trim().toLowerCase();

    if (search.isEmpty) return _rules;

    return _rules.where((rule) {
      return rule.title.toLowerCase().contains(search) ||
          rule.checklistLabel.toLowerCase().contains(search) ||
          rule.category.toLowerCase().contains(search) ||
          rule.sourceName.toLowerCase().contains(search) ||
          rule.purposes.any(
            (purpose) => purpose.toLowerCase().contains(search),
          );
    }).toList();
  }

  int get _approvedRuleCount {
    return _rules.where((rule) => rule.reviewStatus == 'approved').length;
  }

  int get _pendingReviewRuleCount {
    return _rules.where((rule) => rule.reviewStatus == 'pendingReview').length;
  }

  int get _disabledRuleCount {
    return _rules.where((rule) => rule.reviewStatus == 'disabled').length;
  }

  // ---------------------------------------------------------------------------
  // FORMATTING
  // ---------------------------------------------------------------------------

  String _formatText(String value) {
    if (value.isEmpty) return value;

    final String spaced = value
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        );

    return spaced
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String _purposeLabel(String purpose) {
    if (purpose == 'all') return 'All purposes';
    return _formatText(purpose);
  }

  String _durationLabel(TravelRule rule) {
    if (rule.maxDurationDays == null) {
      return '${rule.minDurationDays}+ days';
    }

    if (rule.minDurationDays == rule.maxDurationDays) {
      return '${rule.minDurationDays} days';
    }

    return '${rule.minDurationDays}–${rule.maxDurationDays} days';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not recorded';

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
  // OFFICIAL SOURCE
  // ---------------------------------------------------------------------------

  Future<void> _openOfficialSource(TravelRule rule) async {
    final Uri? uri = Uri.tryParse(rule.officialUrl);

    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This rule does not contain a valid official source.'),
        ),
      );
      return;
    }

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the official source.')),
        );
      }
    } catch (error) {
      debugPrint('OFFICIAL SOURCE ERROR: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the official source.')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // ADD / EDIT RULE
  // ---------------------------------------------------------------------------

  Future<void> _openRuleForm({TravelRule? rule}) async {
    final Country? country = _selectedCountry;

    if (country == null) return;

    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TravelRuleFormScreen(country: country, existingRule: rule),
      ),
    );

    if (changed != true || !mounted) return;

    await _loadRules(country.id);
  }

  // ---------------------------------------------------------------------------
  // ENABLE / DISABLE RULE
  // ---------------------------------------------------------------------------

  Future<void> _changeRuleStatus(TravelRule rule) async {
    if (_updatingRuleId != null) return;

    final bool enable = !rule.active;

    final Color actionColor = enable
        ? AppColors.primary
        : const Color(0xFFA86300);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: enable
                      ? AppColors.primaryLight
                      : const Color(0xFFFFF4DC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  enable
                      ? Icons.check_circle_outline_rounded
                      : Icons.pause_circle_outline_rounded,
                  color: actionColor,
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  enable ? 'Enable Travel Rule' : 'Disable Travel Rule',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enable
                      ? 'Make this regulation available '
                            'to the rule-based DSS?'
                      : 'Stop using this regulation for '
                            'new traveller requirements?',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12.5,
                    height: 1.5,
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
                        'TRAVEL REGULATION',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        rule.title,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            enable
                                ? Icons.check_circle_outline_rounded
                                : Icons.pause_circle_outline_rounded,
                            color: actionColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              enable
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
                const SizedBox(height: 13),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        enable
                            ? 'Make sure the regulatory information '
                                  'and official source have been reviewed '
                                  'before enabling this rule.'
                            : 'The rule will remain stored in Firestore '
                                  'and can be enabled again later.',
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 11.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
              child: Text(enable ? 'Enable Rule' : 'Disable Rule'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _updatingRuleId = rule.id;
    });

    try {
      await _contentManagerService.setTravelRuleActive(
        rule: rule,
        active: enable,
      );

      if (!mounted) return;

      final Country? country = _selectedCountry;
      if (country != null) {
        await _loadRules(country.id);
      }
    } catch (error) {
      debugPrint('UPDATE RULE STATUS ERROR: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enable
                ? 'Unable to enable the travel rule.'
                : 'Unable to disable the travel rule.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingRuleId = null;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // COMMON UI
  // ---------------------------------------------------------------------------

  BoxDecoration _cardDecoration({Color color = Colors.white}) {
    return BoxDecoration(
      color: color,
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

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStateCard({
    required IconData icon,
    required String title,
    required String message,
    bool isLoading = false,
    VoidCallback? onRetry,
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
            child: Icon(icon, color: AppColors.primary, size: 29),
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
          const SizedBox(height: 7),
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SCREEN
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
          'Travel Regulations',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: _selectedCountry == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _updatingRuleId != null ? null : () => _openRuleForm(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Rule',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoadingCountries) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          const SizedBox(height: 65),
          _buildStateCard(
            icon: Icons.public_outlined,
            title: 'Loading Destinations',
            message: 'Retrieving supported destinations...',
            isLoading: true,
          ),
        ],
      );
    }

    if (_countryError != null) {
      return _buildCountryError();
    }

    if (_countries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          const SizedBox(height: 65),
          _buildStateCard(
            icon: Icons.public_off_outlined,
            title: 'No Destinations Available',
            message:
                'There are no supported destinations '
                'available for regulation management.',
            onRetry: _loadCountries,
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 105),
        children: [
          _buildIntroCard(),

          const SizedBox(height: 24),

          _buildSectionTitle('Destination'),
          const SizedBox(height: 12),
          _buildCountrySelector(),

          const SizedBox(height: 22),

          if (!_isLoadingRules && _ruleError == null) ...[
            _buildRuleSummary(),
            const SizedBox(height: 22),
          ],

          _buildSearchField(),

          const SizedBox(height: 22),

          _buildRuleSection(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INTRODUCTION
  // ---------------------------------------------------------------------------

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RegulationIcon(icon: Icons.policy_outlined, size: 50),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage Travel Regulations',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Review and maintain the official '
                      'requirements used to generate '
                      'personalised traveller checklists.',
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
          const SizedBox(height: 15),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Review regulatory information and official '
                  'references before enabling rules for the DSS.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.45,
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
  // DESTINATION SELECTOR
  // ---------------------------------------------------------------------------

  Widget _buildCountrySelector() {
    return DropdownButtonFormField<Country>(
      key: ValueKey(_selectedCountry?.id),
      initialValue: _selectedCountry,
      isExpanded: true,
      decoration: InputDecoration(
        prefixIcon: const Icon(
          Icons.location_on_outlined,
          color: AppColors.primary,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
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
      items: _countries.map((country) {
        return DropdownMenuItem<Country>(
          value: country,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  country.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                country.code,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 11,
                ),
              ),
              if (!country.enabled) ...[
                const SizedBox(width: 7),
                const Text(
                  'Disabled',
                  style: TextStyle(
                    color: Color(0xFFA86300),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
      onChanged: (country) {
        if (country == null) return;

        setState(() {
          _selectedCountry = country;
          _rules = [];
          _searchText = '';
          _searchController.clear();
        });

        _loadRules(country.id);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // REGULATION SUMMARY
  // ---------------------------------------------------------------------------

  Widget _buildRuleSummary() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                label: 'Total Rules',
                value: '${_rules.length}',
                icon: Icons.list_alt_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryItem(
                label: 'Approved',
                value: '$_approvedRuleCount',
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                label: 'Pending Review',
                value: '$_pendingReviewRuleCount',
                icon: Icons.schedule_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryItem(
                label: 'Disabled',
                value: '$_disabledRuleCount',
                icon: Icons.pause_circle_outline_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 130),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
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
      textInputAction: TextInputAction.search,
      onChanged: (value) {
        setState(() {
          _searchText = value;
        });
      },
      style: const TextStyle(color: AppColors.navy, fontSize: 13.5),
      decoration: InputDecoration(
        hintText: 'Search regulations',
        hintStyle: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 13,
        ),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
        suffixIcon: _searchText.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchText = '';
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

  // ---------------------------------------------------------------------------
  // RULE LIST
  // ---------------------------------------------------------------------------

  Widget _buildRuleSection() {
    if (_isLoadingRules) {
      return _buildStateCard(
        icon: Icons.fact_check_outlined,
        title: 'Loading Travel Regulations',
        message: 'Retrieving rules for the selected destination...',
        isLoading: true,
      );
    }

    if (_ruleError != null) {
      return _buildStateCard(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to Load Regulations',
        message: _ruleError!,
        onRetry: _selectedCountry == null
            ? null
            : () => _loadRules(_selectedCountry!.id),
      );
    }

    final List<TravelRule> visibleRules = _visibleRules;

    if (_rules.isEmpty) {
      return _buildEmptyState(
        title: 'No Travel Rules',
        message: 'No regulatory rules are stored for this destination.',
        icon: Icons.policy_outlined,
      );
    }

    if (visibleRules.isEmpty) {
      return _buildEmptyState(
        title: 'No Matching Rules',
        message: 'Try another title, purpose or category.',
        icon: Icons.search_off_rounded,
        onClear: () {
          _searchController.clear();
          setState(() {
            _searchText = '';
          });
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Regulatory Rules',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${visibleRules.length} shown',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final TravelRule rule in visibleRules) _buildRuleCard(rule),
      ],
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String message,
    required IconData icon,
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
            child: Icon(icon, color: AppColors.primary, size: 29),
          ),
          const SizedBox(height: 14),
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
          if (onClear != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Clear Search'),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RULE CARD
  // ---------------------------------------------------------------------------

  Widget _buildRuleCard(TravelRule rule) {
    final bool isUpdating = _updatingRuleId == rule.id;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -------------------------------------------------
          // RULE TITLE AND CHECKLIST LABEL
          // -------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _RegulationIcon(icon: Icons.fact_check_outlined, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    if (rule.checklistLabel.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        rule.checklistLabel,
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          // -------------------------------------------------
          // REVIEW STATUS AND REQUIREMENT TYPE
          // -------------------------------------------------
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _buildStatusBadge(reviewStatus: rule.reviewStatus),
              _buildMandatoryChip(rule.mandatory),
            ],
          ),

          const SizedBox(height: 12),

          // -------------------------------------------------
          // RULE METADATA
          // -------------------------------------------------
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _buildInfoChip(_formatText(rule.category)),
              _buildInfoChip(_durationLabel(rule)),
              _buildInfoChip('Priority ${rule.priority}'),
            ],
          ),

          if (rule.purposes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final String purpose in rule.purposes)
                  _buildPurposeChip(_purposeLabel(purpose)),
              ],
            ),
          ],

          // -------------------------------------------------
          // DESCRIPTION
          // -------------------------------------------------
          if (rule.description.trim().isNotEmpty) ...[
            const SizedBox(height: 15),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 13),
            Text(
              rule.description,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],

          const SizedBox(height: 15),

          // -------------------------------------------------
          // OFFICIAL REFERENCE
          // -------------------------------------------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      color: AppColors.primary,
                      size: 17,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'OFFICIAL REFERENCE',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  rule.sourceName.trim().isEmpty
                      ? 'No source name recorded'
                      : rule.sourceName,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Last validated: '
                        '${_formatDate(rule.lastValidatedAt)}',
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: rule.officialUrl.trim().isEmpty
                          ? null
                          : () => _openOfficialSource(rule),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text(
                        'Open Source',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // -------------------------------------------------
          // EDIT / ENABLE / DISABLE ACTIONS
          // -------------------------------------------------
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _updatingRuleId != null
                      ? null
                      : () => _openRuleForm(rule: rule),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _updatingRuleId != null
                      ? null
                      : () => _changeRuleStatus(rule),
                  icon: isUpdating
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          rule.active
                              ? Icons.pause_circle_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                  label: Text(
                    isUpdating
                        ? 'Updating'
                        : rule.active
                        ? 'Disable'
                        : 'Enable',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: rule.active
                        ? const Color(0xFFA86300)
                        : AppColors.primary,
                    backgroundColor: rule.active
                        ? const Color(0xFFFFF9EE)
                        : AppColors.primaryLight,
                    side: BorderSide(
                      color: rule.active
                          ? const Color(0xFFEAD5AF)
                          : AppColors.border,
                    ),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
  // REVIEW STATUS BADGE
  // ---------------------------------------------------------------------------

  Widget _buildStatusBadge({required String reviewStatus}) {
    late final String label;
    late final Color color;
    late final Color background;
    late final IconData icon;

    switch (reviewStatus) {
      case 'pendingReview':
        label = 'PENDING REVIEW';
        color = const Color(0xFFA86300);
        background = const Color(0xFFFFF4DC);
        icon = Icons.schedule_outlined;
        break;

      case 'disabled':
        label = 'DISABLED';
        color = AppColors.secondaryText;
        background = const Color(0xFFF1F3F5);
        icon = Icons.pause_circle_outline_rounded;
        break;

      case 'approved':
      default:
        label = 'APPROVED';
        color = AppColors.success;
        background = const Color(0xFFEAF7F1);
        icon = Icons.check_circle_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INFORMATION CHIPS
  // ---------------------------------------------------------------------------

  Widget _buildMandatoryChip(bool mandatory) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: mandatory ? const Color(0xFFFFE8E6) : const Color(0xFFE9F2FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        mandatory ? 'REQUIRED' : 'INFORMATION',
        style: TextStyle(
          color: mandatory ? const Color(0xFFB42318) : const Color(0xFF1D5F9A),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPurposeChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COUNTRY ERROR
  // ---------------------------------------------------------------------------

  Widget _buildCountryError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(18),
      children: [
        const SizedBox(height: 65),
        _buildStateCard(
          icon: Icons.cloud_off_outlined,
          title: 'Unable to Load Destinations',
          message:
              _countryError ??
              'Destination information could not be retrieved.',
          onRetry: _loadCountries,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// REUSABLE REGULATION ICON
// -----------------------------------------------------------------------------

class _RegulationIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _RegulationIcon({required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: AppColors.primary, size: size * 0.5),
    );
  }
}
