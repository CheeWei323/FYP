import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/country.dart';
import '../../models/travel_rule.dart';
import '../../services/content_manager_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/role_ui_widgets.dart';

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
    // Preserve the distinction between publishing later and editing an active rule.
    final message = !widget.isEditing
        ? 'New regulations are saved inactive and pending review. Review the saved regulation before enabling it for travellers.'
        : widget.existingRule!.active
        ? 'This regulation is active. Saving changes will update the information used for future traveller checklists.'
        : 'Save these changes to the inactive regulation?';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          widget.isEditing ? 'Save regulation changes?' : 'Create regulation?',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RoleBadge(label: widget.country.name),
              const SizedBox(height: 14),
              Text(
                rule.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 14),
              Text(message),
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
            child: Text(widget.isEditing ? 'Save changes' : 'Create rule'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Edit regulation' : 'Add regulation'),
          leading: IconButton(
            tooltip: 'Back to regulations',
            onPressed: _isSaving
                ? null
                : () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RoleIntroCard(
                        eyebrow: widget.isEditing
                            ? 'Edit regulation'
                            : 'New regulation',
                        title: widget.country.name,
                        description:
                            'Define the requirement, when it applies and its official source.',
                        icon: Icons.policy_outlined,
                      ),
                      const SizedBox(height: 18),
                      _section(
                        title: 'Regulation details',
                        description:
                            'Use a clear title and a short checklist label for travellers.',
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCategory,
                            isExpanded: true,
                            itemHeight: null,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: _categories
                                .map(
                                  (category) => DropdownMenuItem<String>(
                                    value: category['value'],
                                    child: Text(category['label']!),
                                  ),
                                )
                                .toList(),
                            onChanged: _isSaving
                                ? null
                                : (value) => setState(() {
                                    _selectedCategory = value;
                                  }),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _titleController,
                            enabled: !_isSaving,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.next,
                            validator: (value) =>
                                _validateRequiredText(value, 'a rule title'),
                            decoration: const InputDecoration(
                              labelText: 'Rule title',
                              prefixIcon: Icon(Icons.title_rounded),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _checklistLabelController,
                            enabled: !_isSaving,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.next,
                            validator: (value) => _validateRequiredText(
                              value,
                              'a checklist label',
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Checklist label',
                              helperText:
                                  'The short requirement shown to travellers.',
                              helperMaxLines: 3,
                              prefixIcon: Icon(Icons.checklist_rounded),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            enabled: !_isSaving,
                            minLines: 3,
                            maxLines: 8,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            validator: (value) =>
                                _validateRequiredText(value, 'a description'),
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _section(
                        title: 'When this applies',
                        description:
                            'Choose the travel purposes and duration covered by this requirement.',
                        children: [
                          const Text(
                            'Travel purposes',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (final purpose in [
                                ('all', 'All purposes'),
                                ('tourism', 'Tourism'),
                                ('business', 'Business'),
                                ('study', 'Study'),
                              ])
                                FilterChip(
                                  label: Text(purpose.$2),
                                  selected: _selectedPurposes.contains(
                                    purpose.$1,
                                  ),
                                  onSelected: _isSaving
                                      ? null
                                      : (_) => _togglePurpose(purpose.$1),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final minimum = _durationField(minimum: true);
                              final maximum = _durationField(minimum: false);
                              // Stack the numeric fields when there is insufficient room for their labels.
                              if (constraints.maxWidth < 390 ||
                                  MediaQuery.textScalerOf(context).scale(14) >
                                      18) {
                                return Column(
                                  children: [
                                    minimum,
                                    const SizedBox(height: 16),
                                    maximum,
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: minimum),
                                  const SizedBox(width: 12),
                                  Expanded(child: maximum),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _priorityController,
                            enabled: !_isSaving,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: _validatePriority,
                            decoration: const InputDecoration(
                              labelText: 'Priority',
                              helperText: 'Lower numbers appear first.',
                              helperMaxLines: 3,
                              prefixIcon: Icon(Icons.low_priority_rounded),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _mandatory,
                            title: const Text('Mandatory requirement'),
                            subtitle: Text(
                              _mandatory
                                  ? 'Include this as a required checklist item.'
                                  : 'Display this as informational guidance.',
                            ),
                            onChanged: _isSaving
                                ? null
                                : (value) => setState(() {
                                    _mandatory = value;
                                  }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _section(
                        title: 'Official reference',
                        description:
                            'Record the authority and source used to validate this regulation.',
                        children: [
                          TextFormField(
                            controller: _sourceNameController,
                            enabled: !_isSaving,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            validator: (value) => _validateRequiredText(
                              value,
                              'the official source name',
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Source name',
                              prefixIcon: Icon(Icons.account_balance_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _officialUrlController,
                            enabled: !_isSaving,
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            enableSuggestions: false,
                            validator: _validateUrl,
                            decoration: const InputDecoration(
                              labelText: 'Official URL',
                              hintText: 'https://...',
                              prefixIcon: Icon(Icons.link_rounded),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      RoleStatusCard(
                        title: widget.isEditing
                            ? 'Current publication status'
                            : 'Review before publishing',
                        message: !widget.isEditing
                            ? 'New regulations start inactive and pending review. Enable the saved regulation after checking its information and official source.'
                            : widget.existingRule!.active
                            ? 'This regulation is active. Saved changes apply to future generated requirements.'
                            : 'This regulation is inactive. Saving edits preserves its current review status.',
                        icon: Icons.fact_check_outlined,
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveRule,
                        icon: _isSaving
                            ? const SizedBox.square(
                                dimension: 19,
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
                              ? 'Save changes'
                              : 'Create rule',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(description),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(height: 1),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _durationField({required bool minimum}) {
    return TextFormField(
      controller: minimum ? _minDurationController : _maxDurationController,
      enabled: !_isSaving,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: minimum ? _validateMinimumDuration : _validateMaximumDuration,
      decoration: InputDecoration(
        labelText: minimum ? 'Minimum days' : 'Maximum days',
        helperText: minimum
            ? 'From 1 to 3650 days.'
            : 'Optional; leave blank for no upper limit.',
        helperMaxLines: 3,
      ),
    );
  }
}
