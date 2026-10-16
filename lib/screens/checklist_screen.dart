import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/checklist_item.dart';
import '../services/trip_service.dart';
import '../theme/app_theme.dart';

class ChecklistScreen extends StatefulWidget {
  final String tripId;

  const ChecklistScreen({super.key, required this.tripId});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final TripService _tripService = TripService();

  static const Color _primaryColor = AppColors.primary;

  static const Color _darkTextColor = AppColors.navy;

  static const Color _backgroundColor = AppColors.background;

  static const Color _borderColor = AppColors.border;

  List<ChecklistItem> _checklistItems = [];

  final Set<String> _updatingItems = {};

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadChecklistItems();
  }

  // Loads the personalised checklist generated for this trip.
  Future<void> _loadChecklistItems({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<ChecklistItem> items = await _tripService.getChecklistItems(
        widget.tripId,
      );

      if (!mounted) return;

      setState(() {
        _checklistItems = items;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('CHECKLIST LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load the travel requirements.';
      });
    }
  }

  // Updates only the completion status of the selected checklist item.
  Future<void> _updateCompletion(ChecklistItem item, bool completed) async {
    if (_updatingItems.contains(item.id)) {
      return;
    }

    setState(() {
      _updatingItems.add(item.id);
    });

    try {
      await _tripService.updateChecklistItemCompletion(
        tripId: widget.tripId,
        itemId: item.id,
        completed: completed,
      );

      await _loadChecklistItems(showLoading: false);
    } catch (e) {
      debugPrint('CHECKLIST UPDATE ERROR: $e');

      if (!mounted) return;

      _showChecklistError(
        title: 'Unable to Update Requirement',
        message:
            'The checklist completion status could not be '
            'saved. Please check your connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingItems.remove(item.id);
        });
      }
    }
  }

  // Opens an official regulatory source in the external browser.
  Future<void> _openOfficialSource(String url) async {
    final Uri? uri = Uri.tryParse(url);

    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      _showSourceError();
      return;
    }

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        _showSourceError();
      }
    } catch (e) {
      debugPrint('OFFICIAL SOURCE ERROR: $e');

      if (mounted) {
        _showSourceError();
      }
    }
  }

  void _showChecklistError({required String title, required String message}) {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 36,
          ),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(message, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('OK'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSourceError() {
    _showChecklistError(
      title: 'Unable to Open Official Source',
      message:
          'The official website could not be opened. '
          'Please check your internet connection '
          'and try again.',
    );
  }

  int get _completedCount {
    return _checklistItems.where((item) => item.completed).length;
  }

  int get _totalCount {
    return _checklistItems.length;
  }

  int get _remainingCount {
    final int remaining = _totalCount - _completedCount;

    return remaining < 0 ? 0 : remaining;
  }

  double get _completionProgress {
    if (_checklistItems.isEmpty) {
      return 0;
    }

    return _completedCount / _checklistItems.length;
  }

  int get _completionPercentage {
    return (_completionProgress * 100).round();
  }

  String _formatText(String value) {
    if (value.isEmpty) {
      return value;
    }

    return value
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}'
                    '${word.substring(1)}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Travel Requirements',
          style: TextStyle(color: _darkTextColor, fontWeight: FontWeight.w700),
        ),
      ),

      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildChecklistState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return RefreshIndicator(
      onRefresh: () => _loadChecklistItems(showLoading: false),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 36),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 9),

                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 22),

                    OutlinedButton.icon(
                      onPressed: () {
                        _loadChecklistItems();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ---------------------------------------------------------------------------
    // ERROR STATE
    // ---------------------------------------------------------------------------

    if (_errorMessage != null) {
      return _buildChecklistState(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to Load Requirements',
        message:
            'We could not retrieve your travel requirements. '
            'Please check your connection and try again.',
      );
    }

    // ---------------------------------------------------------------------------
    // EMPTY STATE
    // ---------------------------------------------------------------------------

    if (_checklistItems.isEmpty) {
      return _buildChecklistState(
        icon: Icons.fact_check_outlined,
        title: 'No Requirements Available',
        message:
            'No checklist requirements are currently available '
            'for this trip. Review your trip details and verify '
            'the latest entry requirements with official sources.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadChecklistItems(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
        children: [
          _buildProgressCard(),

          const SizedBox(height: 18),

          _buildInformationNote(),

          const SizedBox(height: 26),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Requirements',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),
              ),

              Text(
                '$_totalCount total',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ..._checklistItems.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildRequirementCard(item),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final int completed = _completedCount;
    final int total = _totalCount;
    final int remaining = _remainingCount;

    // Preserve the existing checklist progress calculation.
    final double progress = _completionProgress;
    final int percentage = _completionPercentage;

    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -----------------------------------------------------
          // CARD HEADER
          // -----------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: AppColors.primary,
                  size: 25,
                ),
              ),

              const SizedBox(width: 13),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preparation Progress',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    SizedBox(height: 5),

                    Text(
                      'Track your applicable travel requirements '
                      'before departure.',
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

          const SizedBox(height: 22),

          // -----------------------------------------------------
          // COMPLETION SUMMARY
          // -----------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percentage%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 35,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    remaining == 0
                        ? 'All requirements completed'
                        : '$remaining requirement'
                              '${remaining == 1 ? '' : 's'} remaining',
                    style: TextStyle(
                      color: remaining == 0
                          ? AppColors.success
                          : AppColors.secondaryText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // -----------------------------------------------------
          // ANIMATED PROGRESS BAR
          // -----------------------------------------------------
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, animatedProgress, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: animatedProgress,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFE5EEF0),
                  color: AppColors.primary,
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // -----------------------------------------------------
          // COMPLETED AND TOTAL COUNTS
          // -----------------------------------------------------
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.primary,
                size: 17,
              ),

              const SizedBox(width: 7),

              Expanded(
                child: Text(
                  '$completed completed',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              Text(
                '$total total',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInformationNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.verified_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Your Requirements',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  'Your checklist is generated from the travel '
                  'rules applicable to your selected destination, '
                  'travel purpose and duration of stay.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),

                SizedBox(height: 10),

                Text(
                  'Travel policies can change. Always verify '
                  'the latest requirements using the official '
                  'sources before departure.',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementCard(ChecklistItem item) {
    final bool isUpdating = _updatingItems.contains(item.id);
    final bool isCompleted = item.completed;

    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted ? const Color(0xFFB9E2D0) : _borderColor,
          width: isCompleted ? 1.3 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------------------------------------------
            // CHECKBOX, REQUIREMENT TITLE AND BADGES
            // ---------------------------------------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Checkbox(
                    value: isCompleted,
                    onChanged: isUpdating
                        ? null
                        : (bool? value) {
                            if (value == null) return;
                            _updateCompletion(item, value);
                          },
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.checklistLabel,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),

                      const SizedBox(height: 11),

                      // Badges wrap instead of overflowing
                      // on narrow physical phones.
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _buildStatusBadge(item.mandatory),

                          if (item.category.trim().isNotEmpty)
                            _buildCategoryBadge(item.category),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 17),

            const Divider(height: 1, color: AppColors.border),

            const SizedBox(height: 15),

            // ---------------------------------------------------
            // REQUIREMENT DESCRIPTION
            // ---------------------------------------------------
            Text(
              item.description,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
                height: 1.55,
              ),
            ),

            // ---------------------------------------------------
            // OFFICIAL SOURCE INFORMATION
            // ---------------------------------------------------
            if (item.sourceName.trim().isNotEmpty) ...[
              const SizedBox(height: 17),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_outlined,
                        color: AppColors.primary,
                        size: 19,
                      ),
                    ),

                    const SizedBox(width: 11),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OFFICIAL SOURCE',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            item.sourceName,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ---------------------------------------------------
            // OFFICIAL SOURCE BUTTON
            // ---------------------------------------------------
            if (item.officialUrl.trim().isNotEmpty) ...[
              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _openOfficialSource(item.officialUrl);
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Open Official Source'),
                ),
              ),
            ],

            // ---------------------------------------------------
            // UPDATE INDICATOR
            // ---------------------------------------------------
            if (isUpdating) ...[
              const SizedBox(height: 14),

              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool mandatory) {
    final Color backgroundColor = mandatory
        ? const Color(0xFFFFE8E6)
        : const Color(0xFFE9F2FF);

    final Color textColor = mandatory
        ? const Color(0xFFB42318)
        : const Color(0xFF1D5F9A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        mandatory ? 'REQUIRED' : 'INFORMATION',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _formatText(category),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: _primaryColor,
        ),
      ),
    );
  }
}
