import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/country.dart';
import '../../models/travel_rule.dart';
import '../../services/content_manager_service.dart';

class ManageTravelRulesScreen
    extends StatefulWidget {
  const ManageTravelRulesScreen({
    super.key,
  });

  @override
  State<ManageTravelRulesScreen>
  createState() =>
      _ManageTravelRulesScreenState();
}

class _ManageTravelRulesScreenState
    extends State<ManageTravelRulesScreen> {
  final ContentManagerService
  _contentManagerService =
  ContentManagerService();

  static const Color _primaryColor =
  Color(0xFF087F8C);

  static const Color _darkTextColor =
  Color(0xFF102A43);

  static const Color _backgroundColor =
  Color(0xFFF7F9FB);

  static const Color _borderColor =
  Color(0xFFE1E7EC);

  List<Country> _countries = [];
  List<TravelRule> _rules = [];

  Country? _selectedCountry;

  bool _isLoadingCountries = true;
  bool _isLoadingRules = false;

  String? _countryError;
  String? _ruleError;

  final TextEditingController
  _searchController =
  TextEditingController();

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
  // DATA
  // ---------------------------------------------------------------------------

  Future<void> _loadCountries() async {
    setState(() {
      _isLoadingCountries = true;
      _countryError = null;
    });

    try {
      final List<Country> countries =
      await _contentManagerService
          .getAllCountries();

      if (!mounted) return;

      setState(() {
        _countries = countries;
        _isLoadingCountries = false;

        if (countries.isNotEmpty) {
          _selectedCountry =
              countries.first;
        }
      });

      if (_selectedCountry != null) {
        await _loadRules(
          _selectedCountry!.id,
        );
      }
    } catch (e) {
      debugPrint(
        'CONTENT MANAGER COUNTRY ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoadingCountries = false;
        _countryError =
        'Unable to load destination countries.';
      });
    }
  }

  Future<void> _loadRules(
      String countryId,
      ) async {
    setState(() {
      _isLoadingRules = true;
      _ruleError = null;
    });

    try {
      final List<TravelRule> rules =
      await _contentManagerService
          .getRulesForCountry(
        countryId,
      );

      if (!mounted) return;

      setState(() {
        _rules = rules;
        _isLoadingRules = false;
      });
    } catch (e) {
      debugPrint(
        'CONTENT MANAGER RULE ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoadingRules = false;
        _ruleError =
        'Unable to load travel regulations.';
      });
    }
  }

  Future<void> _refresh() async {
    if (_selectedCountry == null) {
      await _loadCountries();
      return;
    }

    await _loadRules(
      _selectedCountry!.id,
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  List<TravelRule> get _visibleRules {
    final String search =
    _searchText.trim().toLowerCase();

    if (search.isEmpty) {
      return _rules;
    }

    return _rules.where(
          (rule) {
        return rule.title
            .toLowerCase()
            .contains(search) ||
            rule.checklistLabel
                .toLowerCase()
                .contains(search) ||
            rule.category
                .toLowerCase()
                .contains(search) ||
            rule.sourceName
                .toLowerCase()
                .contains(search) ||
            rule.purposes.any(
                  (purpose) =>
                  purpose
                      .toLowerCase()
                      .contains(search),
            );
      },
    ).toList();
  }

  int get _activeRuleCount {
    return _rules
        .where(
          (rule) => rule.active,
    )
        .length;
  }

  int get _inactiveRuleCount {
    return _rules.length -
        _activeRuleCount;
  }

  String _formatText(
      String value,
      ) {
    if (value.isEmpty) {
      return value;
    }

    final String spaced = value
        .replaceAll('_', ' ')
        .replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
          (match) =>
      '${match.group(1)} '
          '${match.group(2)}',
    );

    return spaced
        .split(' ')
        .where(
          (word) => word.isNotEmpty,
    )
        .map(
          (word) =>
      '${word[0].toUpperCase()}'
          '${word.substring(1)}',
    )
        .join(' ');
  }

  String _purposeLabel(
      String purpose,
      ) {
    if (purpose == 'all') {
      return 'All purposes';
    }

    return _formatText(
      purpose,
    );
  }

  String _durationLabel(
      TravelRule rule,
      ) {
    if (rule.maxDurationDays == null) {
      return '${rule.minDurationDays}+ days';
    }

    if (rule.minDurationDays ==
        rule.maxDurationDays) {
      return '${rule.minDurationDays} days';
    }

    return '${rule.minDurationDays}–'
        '${rule.maxDurationDays} days';
  }

  String _formatDate(
      DateTime? date,
      ) {
    if (date == null) {
      return 'Not recorded';
    }

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

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  Future<void> _openOfficialSource(
      TravelRule rule,
      ) async {
    final Uri? uri =
    Uri.tryParse(
      rule.officialUrl,
    );

    if (uri == null ||
        !(uri.scheme == 'http' ||
            uri.scheme == 'https')) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'This rule does not contain a valid official source.',
          ),
        ),
      );

      return;
    }

    try {
      final bool opened =
      await launchUrl(
        uri,
        mode:
        LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open the official source.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint(
        'OFFICIAL SOURCE ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open the official source.',
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      _backgroundColor,
      appBar: AppBar(
        backgroundColor:
        Colors.white,
        surfaceTintColor:
        Colors.white,
        elevation: 0,
        title: const Text(
          'Travel Regulations',
          style: TextStyle(
            color:
            _darkTextColor,
            fontWeight:
            FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingCountries) {
      return const Center(
        child:
        CircularProgressIndicator(),
      );
    }

    if (_countryError != null) {
      return _buildCountryError();
    }

    if (_countries.isEmpty) {
      return const Center(
        child: Text(
          'No destinations are available.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding:
        const EdgeInsets.fromLTRB(
          18,
          18,
          18,
          36,
        ),
        children: [
          _buildIntroCard(),

          const SizedBox(
            height: 24,
          ),

          const Text(
            'Destination',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
              FontWeight.w800,
              color:
              _darkTextColor,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          _buildCountrySelector(),

          const SizedBox(
            height: 20,
          ),

          if (!_isLoadingRules &&
              _ruleError == null)
            _buildRuleSummary(),

          const SizedBox(
            height: 22,
          ),

          _buildSearchField(),

          const SizedBox(
            height: 22,
          ),

          _buildRuleSection(),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient:
        const LinearGradient(
          colors: [
            Color(0xFFE7F7F8),
            Color(0xFFF1F8FB),
          ],
          begin:
          Alignment.topLeft,
          end:
          Alignment.bottomRight,
        ),
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color:
          const Color(
            0xFFCBE8EB,
          ),
        ),
      ),
      child: const Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons
                .policy_outlined,
            color:
            _primaryColor,
            size: 30,
          ),

          SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  'Manage Travel Regulations',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                    FontWeight.w800,
                    color:
                    _darkTextColor,
                  ),
                ),

                SizedBox(height: 6),

                Text(
                  'Review the regulatory rules used to generate '
                      'personalised traveller requirements.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color:
                    Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountrySelector() {
    return DropdownButtonFormField<
        Country>(
      initialValue:
      _selectedCountry,
      isExpanded: true,
      decoration:
      InputDecoration(
        prefixIcon:
        const Icon(
          Icons
              .location_on_outlined,
        ),
        filled: true,
        fillColor:
        Colors.white,
        contentPadding:
        const EdgeInsets
            .symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            14,
          ),
          borderSide:
          const BorderSide(
            color:
            _borderColor,
          ),
        ),
        enabledBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            14,
          ),
          borderSide:
          const BorderSide(
            color:
            _borderColor,
          ),
        ),
      ),
      items: _countries.map(
            (country) {
          return DropdownMenuItem<
              Country>(
            value: country,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    country.name,
                    overflow:
                    TextOverflow
                        .ellipsis,
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Text(
                  country.code,
                  style:
                  const TextStyle(
                    fontSize: 12,
                    color:
                    Colors.black45,
                  ),
                ),

                if (!country.enabled) ...[
                  const SizedBox(
                    width: 8,
                  ),
                  const Text(
                    'Disabled',
                    style:
                    TextStyle(
                      fontSize: 11,
                      color:
                      Color(
                        0xFF9B5713,
                      ),
                      fontWeight:
                      FontWeight
                          .w600,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ).toList(),
      onChanged: (country) {
        if (country == null) {
          return;
        }

        setState(() {
          _selectedCountry =
              country;

          _searchText = '';
          _searchController.clear();
        });

        _loadRules(
          country.id,
        );
      },
    );
  }

  Widget _buildRuleSummary() {
    return Row(
      children: [
        Expanded(
          child:
          _buildSummaryItem(
            label:
            'Total Rules',
            value:
            '${_rules.length}',
            icon:
            Icons.list_alt_outlined,
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        Expanded(
          child:
          _buildSummaryItem(
            label: 'Active',
            value:
            '$_activeRuleCount',
            icon: Icons
                .check_circle_outline_rounded,
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        Expanded(
          child:
          _buildSummaryItem(
            label: 'Inactive',
            value:
            '$_inactiveRuleCount',
            icon:
            Icons.pause_circle_outline_rounded,
          ),
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
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(15),
        border: Border.all(
          color: _borderColor,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color:
            _primaryColor,
            size: 21,
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            value,
            style:
            const TextStyle(
              fontSize: 18,
              fontWeight:
              FontWeight.w800,
              color:
              _darkTextColor,
            ),
          ),

          const SizedBox(
            height: 2,
          ),

          Text(
            label,
            textAlign:
            TextAlign.center,
            style:
            const TextStyle(
              fontSize: 10.5,
              color:
              Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller:
      _searchController,
      onChanged: (value) {
        setState(() {
          _searchText =
              value;
        });
      },
      decoration:
      InputDecoration(
        hintText:
        'Search rules',
        prefixIcon:
        const Icon(
          Icons.search_rounded,
        ),
        suffixIcon:
        _searchText.isEmpty
            ? null
            : IconButton(
          onPressed: () {
            _searchController
                .clear();

            setState(() {
              _searchText =
              '';
            });
          },
          icon:
          const Icon(
            Icons
                .close_rounded,
          ),
        ),
        filled: true,
        fillColor:
        Colors.white,
        border:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            14,
          ),
          borderSide:
          const BorderSide(
            color:
            _borderColor,
          ),
        ),
        enabledBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            14,
          ),
          borderSide:
          const BorderSide(
            color:
            _borderColor,
          ),
        ),
      ),
    );
  }

  Widget _buildRuleSection() {
    if (_isLoadingRules) {
      return const Padding(
        padding:
        EdgeInsets.symmetric(
          vertical: 60,
        ),
        child: Center(
          child:
          CircularProgressIndicator(),
        ),
      );
    }

    if (_ruleError != null) {
      return Container(
        width: double.infinity,
        padding:
        const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(
            16,
          ),
          border: Border.all(
            color:
            _borderColor,
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons
                  .error_outline_rounded,
              color:
              Color(
                0xFFC62828,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            Text(
              _ruleError!,
              textAlign:
              TextAlign.center,
            ),

            const SizedBox(
              height: 8,
            ),

            TextButton(
              onPressed:
              _selectedCountry ==
                  null
                  ? null
                  : () =>
                  _loadRules(
                    _selectedCountry!
                        .id,
                  ),
              child:
              const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final List<TravelRule>
    visibleRules =
        _visibleRules;

    if (_rules.isEmpty) {
      return _buildEmptyState(
        title:
        'No travel rules',
        message:
        'No regulatory rules are stored for this destination.',
      );
    }

    if (visibleRules.isEmpty) {
      return _buildEmptyState(
        title:
        'No matching rules',
        message:
        'Try a different search term.',
      );
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Regulatory Rules',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.w800,
                  color:
                  _darkTextColor,
                ),
              ),
            ),

            Text(
              '${visibleRules.length} shown',
              style:
              const TextStyle(
                fontSize: 12,
                color:
                Colors.black54,
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 12,
        ),

        for (final TravelRule rule
        in visibleRules)
          _buildRuleCard(rule),
      ],
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color:
          _borderColor,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons
                .policy_outlined,
            size: 42,
            color:
            Colors.black38,
          ),

          const SizedBox(
            height: 12,
          ),

          Text(
            title,
            style:
            const TextStyle(
              fontSize: 17,
              fontWeight:
              FontWeight.w700,
              color:
              _darkTextColor,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            message,
            textAlign:
            TextAlign.center,
            style:
            const TextStyle(
              color:
              Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(
      TravelRule rule,
      ) {
    return Container(
      width: double.infinity,
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),
      padding:
      const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: _borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFFE8F6F7,
                  ),
                  borderRadius:
                  BorderRadius
                      .circular(
                    12,
                  ),
                ),
                child: const Icon(
                  Icons
                      .fact_check_outlined,
                  color:
                  _primaryColor,
                  size: 22,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      rule.title,
                      style:
                      const TextStyle(
                        fontSize: 15.5,
                        fontWeight:
                        FontWeight
                            .w800,
                        color:
                        _darkTextColor,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      rule.checklistLabel,
                      style:
                      const TextStyle(
                        fontSize: 12.5,
                        color:
                        Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              _buildStatusBadge(
                active:
                rule.active,
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _buildInfoChip(
                _formatText(
                  rule.category,
                ),
              ),

              _buildInfoChip(
                _durationLabel(
                  rule,
                ),
              ),

              _buildMandatoryChip(
                rule.mandatory,
              ),

              _buildInfoChip(
                'Priority ${rule.priority}',
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          Wrap(
            spacing: 7,
            runSpacing: 7,
            children:
            rule.purposes
                .map(
                  (purpose) =>
                  _buildPurposeChip(
                    _purposeLabel(
                      purpose,
                    ),
                  ),
            )
                .toList(),
          ),

          const SizedBox(
            height: 14,
          ),

          Text(
            rule.description,
            style:
            const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color:
              Color(
                0xFF486581,
              ),
            ),
          ),

          const SizedBox(
            height: 15,
          ),

          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.all(
              13,
            ),
            decoration:
            BoxDecoration(
              color:
              const Color(
                0xFFF7F9FB,
              ),
              borderRadius:
              BorderRadius
                  .circular(
                12,
              ),
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                const Text(
                  'Official Reference',
                  style:
                  TextStyle(
                    fontSize: 11,
                    fontWeight:
                    FontWeight
                        .w700,
                    color:
                    Colors.black54,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  rule.sourceName
                      .trim()
                      .isEmpty
                      ? 'No source name recorded'
                      : rule.sourceName,
                  style:
                  const TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                    FontWeight
                        .w600,
                    color:
                    _darkTextColor,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Last validated: '
                            '${_formatDate(rule.lastValidatedAt)}',
                        style:
                        const TextStyle(
                          fontSize:
                          11.5,
                          color:
                          Colors.black54,
                        ),
                      ),
                    ),

                    TextButton.icon(
                      onPressed:
                      rule.officialUrl
                          .trim()
                          .isEmpty
                          ? null
                          : () =>
                          _openOfficialSource(
                            rule,
                          ),
                      icon:
                      const Icon(
                        Icons
                            .open_in_new_rounded,
                        size: 16,
                      ),
                      label:
                      const Text(
                        'Open Source',
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

  Widget _buildStatusBadge({
    required bool active,
  }) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: active
            ? const Color(
          0xFFEAF7F1,
        )
            : const Color(
          0xFFF1F3F5,
        ),
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Text(
        active
            ? 'ACTIVE'
            : 'INACTIVE',
        style: TextStyle(
          fontSize: 10,
          fontWeight:
          FontWeight.w800,
          color: active
              ? const Color(
            0xFF177245,
          )
              : const Color(
            0xFF627D98,
          ),
        ),
      ),
    );
  }

  Widget _buildMandatoryChip(
      bool mandatory,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: mandatory
            ? const Color(
          0xFFFFE8E6,
        )
            : const Color(
          0xFFE9F2FF,
        ),
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Text(
        mandatory
            ? 'REQUIRED'
            : 'INFORMATION',
        style: TextStyle(
          fontSize: 10,
          fontWeight:
          FontWeight.w700,
          color: mandatory
              ? const Color(
            0xFFB42318,
          )
              : const Color(
            0xFF1D5F9A,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(
      String text,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
        const Color(
          0xFFF0F4F6,
        ),
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style:
        const TextStyle(
          fontSize: 10.5,
          fontWeight:
          FontWeight.w600,
          color:
          Color(
            0xFF486581,
          ),
        ),
      ),
    );
  }

  Widget _buildPurposeChip(
      String text,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
        const Color(
          0xFFE8F6F7,
        ),
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style:
        const TextStyle(
          fontSize: 10.5,
          fontWeight:
          FontWeight.w600,
          color:
          _primaryColor,
        ),
      ),
    );
  }

  Widget _buildCountryError() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .error_outline_rounded,
              color:
              Color(
                0xFFC62828,
              ),
              size: 44,
            ),

            const SizedBox(
              height: 14,
            ),

            Text(
              _countryError!,
              textAlign:
              TextAlign.center,
            ),

            const SizedBox(
              height: 12,
            ),

            FilledButton(
              onPressed:
              _loadCountries,
              child:
              const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}