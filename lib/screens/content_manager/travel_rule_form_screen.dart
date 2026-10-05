import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/country.dart';
import '../../models/travel_rule.dart';
import '../../services/content_manager_service.dart';

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

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

  static const Color _borderColor = Color(0xFFE1E7EC);

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

    if (text.isEmpty) {
      return null;
    }

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
  // SAVE
  // ---------------------------------------------------------------------------

  Future<void> _saveRule() async {
    if (_isSaving) return;

    FocusScope.of(context).unfocus();

    final bool formValid = _formKey.currentState?.validate() ?? false;

    if (!formValid) {
      return;
    }

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

    // Do not create an unnecessary update or activity log
    // when the Content Manager has not changed any rule information.
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

    if (!confirmed || !mounted) {
      return;
    }

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
    } catch (e) {
      debugPrint('SAVE TRAVEL RULE ERROR: $e');

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
  // CHANGE DETECTION
  // ---------------------------------------------------------------------------

  // Checks whether any editable rule information has changed.
  // This prevents unnecessary Firestore writes and activity logs.
  bool _hasChanges() {
    final TravelRule? existing = widget.existingRule;

    // A new rule always contains changes.
    if (existing == null) {
      return true;
    }

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

  Future<bool> _showSaveConfirmation(TravelRule rule) async {
    String message;

    if (widget.isEditing) {
      if (widget.existingRule!.active) {
        message =
            'This rule is currently active.\n\n'
            'Saving these changes will immediately update '
            'the regulatory information used for future '
            'traveller checklists.\n\n'
            'Continue with the update?';
      } else {
        message = 'Save the changes to this inactive travel rule?';
      }
    } else {
      message =
          'Create this travel rule for '
          '${widget.country.name}?\n\n'
          'New rules are created as inactive. '
          'You can review the rule and enable it afterwards.';
    }

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: Icon(
            widget.isEditing
                ? Icons.edit_note_rounded
                : Icons.add_circle_outline_rounded,
            color: _primaryColor,
            size: 32,
          ),
          title: Text(
            widget.isEditing ? 'Update Travel Rule?' : 'Create Travel Rule?',
            textAlign: TextAlign.center,
          ),
          content: Text(message),
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
  // UI HELPERS
  // ---------------------------------------------------------------------------

  InputDecoration _decoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primaryColor, width: 1.6),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: _darkTextColor,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.isEditing ? 'Edit Travel Rule' : 'Add Travel Rule',
          style: const TextStyle(
            color: _darkTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDestinationCard(),

                const SizedBox(height: 26),

                _buildSectionTitle('Rule Information'),

                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: _decoration(
                    label: 'Category',
                    prefixIcon: const Icon(Icons.category_outlined),
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

                const SizedBox(height: 16),

                TextFormField(
                  controller: _titleController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) =>
                      _validateRequiredText(value, 'a rule title'),
                  decoration: _decoration(
                    label: 'Rule Title',
                    hint: 'Example: Valid Passport for Japan Travel',
                    prefixIcon: const Icon(Icons.title_outlined),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _checklistLabelController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) =>
                      _validateRequiredText(value, 'a checklist label'),
                  decoration: _decoration(
                    label: 'Checklist Label',
                    hint: 'Short traveller-facing requirement',
                    prefixIcon: const Icon(Icons.check_box_outlined),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _descriptionController,
                  enabled: !_isSaving,
                  minLines: 4,
                  maxLines: 7,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) =>
                      _validateRequiredText(value, 'a description'),
                  decoration: _decoration(
                    label: 'Description',
                    hint: 'Explain the requirement and relevant conditions',
                  ),
                ),

                const SizedBox(height: 28),

                _buildSectionTitle('Applicability'),

                const SizedBox(height: 6),

                const Text(
                  'Select the travel purposes that this rule applies to.',
                  style: TextStyle(fontSize: 12.5, color: Colors.black54),
                ),

                const SizedBox(height: 12),

                _buildPurposeSelector(),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minDurationController,
                        enabled: !_isSaving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: _validateMinimumDuration,
                        decoration: _decoration(label: 'Minimum Days'),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: TextFormField(
                        controller: _maxDurationController,
                        enabled: !_isSaving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: _validateMaximumDuration,
                        decoration: _decoration(
                          label: 'Maximum Days',
                          hint: 'Optional',
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                TextFormField(
                  controller: _priorityController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validatePriority,
                  decoration: _decoration(
                    label: 'Priority',
                    hint: 'Lower numbers appear first',
                    prefixIcon: const Icon(Icons.low_priority_rounded),
                  ),
                ),

                const SizedBox(height: 18),

                _buildMandatorySwitch(),

                const SizedBox(height: 28),

                _buildSectionTitle('Official Reference'),

                const SizedBox(height: 14),

                TextFormField(
                  controller: _sourceNameController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      _validateRequiredText(value, 'the official source name'),
                  decoration: _decoration(
                    label: 'Source Name',
                    hint: 'Example: Ministry of Foreign Affairs of Japan',
                    prefixIcon: const Icon(Icons.account_balance_outlined),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _officialUrlController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  validator: _validateUrl,
                  decoration: _decoration(
                    label: 'Official URL',
                    hint: 'https://...',
                    prefixIcon: const Icon(Icons.link_rounded),
                  ),
                ),

                const SizedBox(height: 26),

                _buildStatusNote(),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveRule,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryColor,
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
                        : Icon(
                            widget.isEditing
                                ? Icons.save_outlined
                                : Icons.add_rounded,
                          ),
                    label: Text(
                      _isSaving
                          ? 'Saving...'
                          : widget.isEditing
                          ? 'Save Changes'
                          : 'Create Rule',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDestinationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F7F8),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFCBE8EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: _primaryColor),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Destination',
                  style: TextStyle(fontSize: 11.5, color: Colors.black54),
                ),

                const SizedBox(height: 2),

                Text(
                  widget.country.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _darkTextColor,
                  ),
                ),
              ],
            ),
          ),
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
      spacing: 9,
      runSpacing: 9,
      children: purposes.map((purpose) {
        final String value = purpose['value']!;

        final bool selected = _selectedPurposes.contains(value);

        return FilterChip(
          selected: selected,
          label: Text(purpose['label']!),
          onSelected: _isSaving ? null : (_) => _togglePurpose(value),
          selectedColor: const Color(0xFFDDF4F5),
          checkmarkColor: _primaryColor,
          side: BorderSide(color: selected ? _primaryColor : _borderColor),
        );
      }).toList(),
    );
  }

  Widget _buildMandatorySwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _mandatory,
        activeThumbColor: _primaryColor,
        title: const Text(
          'Required Requirement',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _darkTextColor,
          ),
        ),
        subtitle: Text(
          _mandatory
              ? 'Travellers must complete this requirement.'
              : 'This rule is displayed as informational guidance.',
          style: const TextStyle(fontSize: 12),
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

  Widget _buildStatusNote() {
    final TravelRule? existing = widget.existingRule;

    String text;

    if (existing == null) {
      text =
          'New rules are created as inactive. '
          'Review the saved rule before enabling it for travellers.';
    } else if (existing.active) {
      text =
          'This rule is currently active. '
          'Saved changes will affect future generated travel requirements.';
    } else {
      text =
          'This rule is currently inactive. '
          'You can enable it from the Travel Regulations screen after reviewing the changes.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E6EE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF0A5B83),
            size: 21,
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Color(0xFF334E68),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
