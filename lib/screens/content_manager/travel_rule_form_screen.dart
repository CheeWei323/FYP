import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/country.dart';
import '../../models/travel_rule.dart';
import '../../services/content_manager_service.dart';
import '../../theme/app_theme.dart';

class TravelRuleFormScreen extends StatefulWidget {
  final Country country;
  final TravelRule? existingRule;

  const TravelRuleFormScreen({
    super.key,
    required this.country,
    this.existingRule,
  });

  bool get isEditing => existingRule != null;

  @override
  State<TravelRuleFormScreen> createState() => _TravelRuleFormScreenState();
}

class _TravelRuleFormScreenState extends State<TravelRuleFormScreen> {
  final ContentManagerService _contentManagerService = ContentManagerService();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _checklistLabelController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _minDurationController = TextEditingController();
  final TextEditingController _maxDurationController = TextEditingController();
  final TextEditingController _priorityController = TextEditingController();
  final TextEditingController _sourceNameController = TextEditingController();
  final TextEditingController _officialUrlController = TextEditingController();

  final List<Map<String, String>> _categories = const [
    {'value': 'passport', 'label': 'Passport'},
    {'value': 'visa', 'label': 'Visa'},
    {'value': 'entry', 'label': 'Entry Requirement'},
    {'value': 'document', 'label': 'Document'},
    {'value': 'health', 'label': 'Health'},
  ];

  String? _selectedCategory;

  final Set<String> _selectedPurposes = {};

  bool _mandatory = true;
  bool _isSaving = false;

  // ---------------------------------------------------------------------------
  // INITIALISATION
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    final TravelRule? rule = widget.existingRule;

    if (rule == null) {
      _minDurationController.text = '1';
      _priorityController.text = '1';
      return;
    }

    _titleController.text = rule.title;
    _checklistLabelController.text = rule.checklistLabel;
    _descriptionController.text = rule.description;
    _minDurationController.text = rule.minDurationDays.toString();

    if (rule.maxDurationDays != null) {
      _maxDurationController.text = rule.maxDurationDays.toString();
    }

    _priorityController.text = rule.priority.toString();
    _sourceNameController.text = rule.sourceName;
    _officialUrlController.text = rule.officialUrl;

    _selectedCategory = rule.category;
    _selectedPurposes.addAll(rule.purposes);
    _mandatory = rule.mandatory;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _checklistLabelController.dispose();
    _descriptionController.dispose();
    _minDurationController.dispose();
    _maxDurationController.dispose();
    _priorityController.dispose();
    _sourceNameController.dispose();
    _officialUrlController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // PURPOSE SELECTION
  // ---------------------------------------------------------------------------

  void _togglePurpose(String purpose) {
    setState(() {
      if (purpose == 'all') {
        if (_selectedPurposes.contains('all')) {
          _selectedPurposes.clear();
        } else {
          _selectedPurposes
            ..clear()
            ..add('all');
        }
        return;
      }

      _selectedPurposes.remove('all');

      if (_selectedPurposes.contains(purpose)) {
        _selectedPurposes.remove(purpose);
      } else {
        _selectedPurposes.add(purpose);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // VALIDATION
  // ---------------------------------------------------------------------------

  String? _validateRequiredText(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName.';
    }
    return null;
  }

  String? _validateMinimumDuration(String? value) {
    final int? duration = int.tryParse(value?.trim() ?? '');

    if (duration == null || duration < 1) {
      return 'Enter a valid minimum duration.';
    }

    if (duration > 3650) {
      return 'Maximum supported duration is 3650 days.';
    }

    return null;
  }

  String? _validateMaximumDuration(String? value) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) return null;

    final int? maximum = int.tryParse(text);

    if (maximum == null || maximum < 1) {
      return 'Enter a valid maximum duration.';
    }

    final int? minimum = int.tryParse(_minDurationController.text.trim());

    if (minimum != null && maximum < minimum) {
      return 'Maximum duration cannot be less than minimum.';
    }

    if (maximum > 3650) {
      return 'Maximum supported duration is 3650 days.';
    }

    return null;
  }

  String? _validatePriority(String? value) {
    final int? priority = int.tryParse(value?.trim() ?? '');

    if (priority == null || priority < 0) {
      return 'Enter a valid priority.';
    }

    return null;
  }

  String? _validateUrl(String? value) {
    final String url = value?.trim() ?? '';

    if (url.isEmpty) {
      return 'Please enter the official source URL.';
    }

    final Uri? uri = Uri.tryParse(url);

    if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.host.isEmpty) {
      return 'Please enter a valid official URL.';
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // CHANGE DETECTION
  // ---------------------------------------------------------------------------

  bool _hasChanges() {
    final TravelRule? existing = widget.existingRule;

    if (existing == null) return true;

    final int? minimumDuration = int.tryParse(
      _minDurationController.text.trim(),
    );

    final String maximumText = _maxDurationController.text.trim();

    final int? maximumDuration = maximumText.isEmpty
        ? null
        : int.tryParse(maximumText);

    final int? priority = int.tryParse(_priorityController.text.trim());

    final Set<String> existingPurposes = existing.purposes.toSet();

    final bool purposesChanged =
        existingPurposes.length != _selectedPurposes.length ||
        !existingPurposes.containsAll(_selectedPurposes);

    return _selectedCategory != existing.category ||
        _titleController.text.trim() != existing.title ||
        _checklistLabelController.text.trim() != existing.checklistLabel ||
        _descriptionController.text.trim() != existing.description ||
        purposesChanged ||
        minimumDuration != existing.minDurationDays ||
        maximumDuration != existing.maxDurationDays ||
        _mandatory != existing.mandatory ||
        priority != existing.priority ||
        _sourceNameController.text.trim() != existing.sourceName ||
        _officialUrlController.text.trim() != existing.officialUrl;
  }

  // ---------------------------------------------------------------------------
  // SAVE RULE
  // ---------------------------------------------------------------------------

  Future<void> _saveRule() async {
    if (_isSaving) return;

    FocusScope.of(context).unfocus();

    final bool formValid = _formKey.currentState?.validate() ?? false;

    if (!formValid) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please select a rule category.')),
        );
      return;
    }

    if (_selectedPurposes.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please select at least one travel purpose.'),
          ),
        );
      return;
    }

    // Avoid unnecessary Firestore writes and activity logs.
    if (widget.isEditing && !_hasChanges()) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('No changes were made.')));
      return;
    }

    final int minimumDuration = int.parse(_minDurationController.text.trim());

    final String maximumText = _maxDurationController.text.trim();

    final int? maximumDuration = maximumText.isEmpty
        ? null
        : int.parse(maximumText);

    final int priority = int.parse(_priorityController.text.trim());

    final TravelRule rule = TravelRule(
      id: widget.existingRule?.id ?? '',
      countryId: widget.country.id,
      category: _selectedCategory!,
      title: _titleController.text.trim(),
      checklistLabel: _checklistLabelController.text.trim(),
      description: _descriptionController.text.trim(),
      purposes: _selectedPurposes.toList(),
      minDurationDays: minimumDuration,
      maxDurationDays: maximumDuration,
      mandatory: _mandatory,
      officialUrl: _officialUrlController.text.trim(),
      sourceName: _sourceNameController.text.trim(),
      active: widget.existingRule?.active ?? false,
      reviewStatus: widget.existingRule?.reviewStatus ?? 'pendingReview',
      priority: priority,
      lastValidatedAt: DateTime.now(),
    );

    final bool confirmed = await _showSaveConfirmation(rule);

    if (!confirmed || !mounted) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.isEditing) {
        await _contentManagerService.updateTravelRule(rule);
      } else {
        await _contentManagerService.createTravelRule(rule);
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      debugPrint('SAVE TRAVEL RULE ERROR: $error');

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Unable to update the travel rule.'
                : 'Unable to create the travel rule.',
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // SAVE CONFIRMATION
  // ---------------------------------------------------------------------------

  Future<bool> _showSaveConfirmation(TravelRule rule) async {
    String message;

    if (widget.isEditing) {
      if (widget.existingRule!.active) {
        message =
            'This rule is currently active. '
            'Saving changes will immediately update '
            'the regulatory information used for '
            'future traveller checklists.';
      } else {
        message = 'Save changes to this inactive travel rule?';
      }
    } else {
      message =
          'New rules are created as inactive and pending '
          'review. Review the saved rule before enabling '
          'it for travellers.';
    }

    final bool? result = await showDialog<bool>(
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
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.isEditing
                      ? Icons.edit_note_rounded
                      : Icons.add_circle_outline_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.isEditing
                      ? 'Update Travel Rule'
                      : 'Create Travel Rule',
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
                const Text(
                  'Review this regulation before saving.',
                  style: TextStyle(
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
                        'DESTINATION',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.country.name,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),
                      const Text(
                        'TRAVEL RULE',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        rule.title,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
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
                        message,
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
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(widget.isEditing ? 'Update Rule' : 'Create Rule'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ---------------------------------------------------------------------------
  // SHARED UI HELPERS
  // ---------------------------------------------------------------------------

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
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

  InputDecoration _decoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      labelStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
      hintStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    String? description,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 15),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 15),
          child,
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
        title: Text(
          widget.isEditing ? 'Edit Travel Rule' : 'Add Travel Rule',
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDestinationCard(),

                const SizedBox(height: 18),

                _buildRuleInformationSection(),

                const SizedBox(height: 18),

                _buildApplicabilitySection(),

                const SizedBox(height: 18),

                _buildOfficialReferenceSection(),

                const SizedBox(height: 18),

                _buildStatusNote(),

                const SizedBox(height: 22),

                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DESTINATION HEADER
  // ---------------------------------------------------------------------------

  Widget _buildDestinationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
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
              Icons.location_on_outlined,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEditing ? 'Edit Regulation' : 'New Regulation',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.country.name,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create and maintain official '
                  'travel preparation requirements.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    height: 1.4,
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
  // RULE INFORMATION
  // ---------------------------------------------------------------------------

  Widget _buildRuleInformationSection() {
    return _buildSectionCard(
      title: 'Rule Information',
      icon: Icons.fact_check_outlined,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            isExpanded: true,
            decoration: _decoration(
              label: 'Category',
              prefixIcon: const Icon(
                Icons.category_outlined,
                color: AppColors.primary,
              ),
            ),
            items: _categories.map((category) {
              return DropdownMenuItem<String>(
                value: category['value'],
                child: Text(category['label']!),
              );
            }).toList(),
            onChanged: _isSaving
                ? null
                : (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
          ),

          const SizedBox(height: 13),

          TextFormField(
            controller: _titleController,
            enabled: !_isSaving,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) => _validateRequiredText(value, 'a rule title'),
            decoration: _decoration(
              label: 'Rule Title',
              hint: 'Example: Valid Passport for Japan Travel',
              prefixIcon: const Icon(
                Icons.title_outlined,
                color: AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 13),

          TextFormField(
            controller: _checklistLabelController,
            enabled: !_isSaving,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) =>
                _validateRequiredText(value, 'a checklist label'),
            decoration: _decoration(
              label: 'Checklist Label',
              hint: 'Short traveller-facing requirement',
              prefixIcon: const Icon(
                Icons.check_box_outlined,
                color: AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 13),

          TextFormField(
            controller: _descriptionController,
            enabled: !_isSaving,
            minLines: 4,
            maxLines: 7,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) => _validateRequiredText(value, 'a description'),
            decoration: _decoration(
              label: 'Description',
              hint: 'Explain the requirement and relevant conditions',
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // APPLICABILITY
  // ---------------------------------------------------------------------------

  Widget _buildApplicabilitySection() {
    return _buildSectionCard(
      title: 'Applicability',
      icon: Icons.tune_rounded,
      description: 'Define when this requirement applies to travellers.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRAVEL PURPOSES',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 10),

          _buildPurposeSelector(),

          const SizedBox(height: 18),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _minDurationController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validateMinimumDuration,
                  decoration: _decoration(label: 'Minimum Days', hint: '1'),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: TextFormField(
                  controller: _maxDurationController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validateMaximumDuration,
                  decoration: _decoration(
                    label: 'Maximum Days',
                    hint: 'Optional',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          TextFormField(
            controller: _priorityController,
            enabled: !_isSaving,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: _validatePriority,
            decoration: _decoration(
              label: 'Priority',
              hint: 'Lower numbers appear first',
              prefixIcon: const Icon(
                Icons.low_priority_rounded,
                color: AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 15),

          _buildMandatorySwitch(),
        ],
      ),
    );
  }

  Widget _buildPurposeSelector() {
    const List<Map<String, String>> purposes = [
      {'value': 'all', 'label': 'All Purposes'},
      {'value': 'tourism', 'label': 'Tourism'},
      {'value': 'business', 'label': 'Business'},
      {'value': 'study', 'label': 'Study'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: purposes.map((purpose) {
        final String value = purpose['value']!;
        final bool selected = _selectedPurposes.contains(value);

        return FilterChip(
          selected: selected,
          showCheckmark: true,
          label: Text(
            purpose['label']!,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.secondaryText,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          onSelected: _isSaving ? null : (_) => _togglePurpose(value),
          selectedColor: AppColors.primaryLight,
          backgroundColor: Colors.white,
          checkmarkColor: AppColors.primary,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        );
      }).toList(),
    );
  }

  Widget _buildMandatorySwitch() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _mandatory,
        activeThumbColor: AppColors.primary,
        title: const Text(
          'Required Requirement',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          _mandatory
              ? 'Travellers must complete this requirement.'
              : 'Displayed as informational guidance.',
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 11.5,
            height: 1.4,
          ),
        ),
        onChanged: _isSaving
            ? null
            : (value) {
                setState(() {
                  _mandatory = value;
                });
              },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // OFFICIAL REFERENCE
  // ---------------------------------------------------------------------------

  Widget _buildOfficialReferenceSection() {
    return _buildSectionCard(
      title: 'Official Reference',
      icon: Icons.verified_outlined,
      description:
          'Record the official authority responsible '
          'for this travel requirement.',
      child: Column(
        children: [
          TextFormField(
            controller: _sourceNameController,
            enabled: !_isSaving,
            textCapitalization: TextCapitalization.words,
            validator: (value) =>
                _validateRequiredText(value, 'the official source name'),
            decoration: _decoration(
              label: 'Source Name',
              hint: 'Example: Ministry of Foreign Affairs',
              prefixIcon: const Icon(
                Icons.account_balance_outlined,
                color: AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 13),

          TextFormField(
            controller: _officialUrlController,
            enabled: !_isSaving,
            keyboardType: TextInputType.url,
            autocorrect: false,
            validator: _validateUrl,
            decoration: _decoration(
              label: 'Official URL',
              hint: 'https://...',
              prefixIcon: const Icon(
                Icons.link_rounded,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RULE STATUS INFORMATION
  // ---------------------------------------------------------------------------

  Widget _buildStatusNote() {
    final TravelRule? existing = widget.existingRule;

    String text;

    if (existing == null) {
      text =
          'New rules are created as inactive. '
          'Review the saved rule before enabling it '
          'for travellers.';
    } else if (existing.active) {
      text =
          'This rule is currently active. '
          'Saved changes will affect future generated '
          'travel requirements.';
    } else {
      text =
          'This rule is currently inactive. '
          'You can enable it from the Travel Regulations '
          'screen after reviewing the changes.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E6EE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SAVE BUTTON
  // ---------------------------------------------------------------------------

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _saveRule,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _isSaving
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(widget.isEditing ? Icons.save_outlined : Icons.add_rounded),
        label: Text(
          _isSaving
              ? 'Saving...'
              : widget.isEditing
              ? 'Save Changes'
              : 'Create Rule',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
