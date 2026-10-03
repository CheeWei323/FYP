import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/checklist_item.dart';
import '../services/trip_service.dart';

class ChecklistScreen extends StatefulWidget {
  final String tripId;

  const ChecklistScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<ChecklistScreen> createState() =>
      _ChecklistScreenState();
}

class _ChecklistScreenState
    extends State<ChecklistScreen> {
  final TripService _tripService = TripService();

  static const Color _primaryColor =
  Color(0xFF087F8C);

  static const Color _darkTextColor =
  Color(0xFF102A43);

  static const Color _backgroundColor =
  Color(0xFFF7F9FB);

  static const Color _borderColor =
  Color(0xFFE1E7EC);

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
  Future<void> _loadChecklistItems({
    bool showLoading = true,
  }) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<ChecklistItem> items =
      await _tripService.getChecklistItems(
        widget.tripId,
      );

      if (!mounted) return;

      setState(() {
        _checklistItems = items;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint(
        'CHECKLIST LOAD ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
        'Unable to load the travel requirements.';
      });
    }
  }

  // Updates only the completion status of the selected checklist item.
  Future<void> _updateCompletion(
      ChecklistItem item,
      bool completed,
      ) async {
    if (_updatingItems.contains(item.id)) {
      return;
    }

    setState(() {
      _updatingItems.add(item.id);
    });

    try {
      await _tripService
          .updateChecklistItemCompletion(
        tripId: widget.tripId,
        itemId: item.id,
        completed: completed,
      );

      await _loadChecklistItems(
        showLoading: false,
      );
    } catch (e) {
      debugPrint(
        'CHECKLIST UPDATE ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update the requirement.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingItems.remove(
            item.id,
          );
        });
      }
    }
  }

  // Opens an official regulatory source in the external browser.
  Future<void> _openOfficialSource(
      String url,
      ) async {
    final Uri? uri = Uri.tryParse(url);

    if (uri == null ||
        (uri.scheme != 'https' &&
            uri.scheme != 'http')) {
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
      debugPrint(
        'OFFICIAL SOURCE ERROR: $e',
      );

      if (mounted) {
        _showSourceError();
      }
    }
  }

  void _showSourceError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Unable to open the official source.',
        ),
      ),
    );
  }

  int get _completedCount {
    return _checklistItems
        .where(
          (item) => item.completed,
    )
        .length;
  }

  int get _totalCount {
    return _checklistItems.length;
  }

  int get _remainingCount {
    final int remaining =
        _totalCount - _completedCount;

    return remaining < 0
        ? 0
        : remaining;
  }

  double get _completionProgress {
    if (_checklistItems.isEmpty) {
      return 0;
    }

    return _completedCount /
        _checklistItems.length;
  }

  int get _completionPercentage {
    return (_completionProgress * 100)
        .round();
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
          style: TextStyle(
            color: _darkTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return RefreshIndicator(
        onRefresh: () =>
            _loadChecklistItems(
              showLoading: false,
            ),
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          const EdgeInsets.symmetric(
            horizontal: 24,
          ),
          children: [
            const SizedBox(height: 140),

            const Icon(
              Icons.cloud_off_outlined,
              size: 58,
              color: Colors.black38,
            ),

            const SizedBox(height: 18),

            const Text(
              'Unable to load requirements',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                FontWeight.w700,
                color: _darkTextColor,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Pull down to try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black45,
              ),
            ),
          ],
        ),
      );
    }

    if (_checklistItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: () =>
            _loadChecklistItems(
              showLoading: false,
            ),
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          const EdgeInsets.symmetric(
            horizontal: 24,
          ),
          children: const [
            SizedBox(height: 130),

            Icon(
              Icons.fact_check_outlined,
              size: 60,
              color: _primaryColor,
            ),

            SizedBox(height: 18),

            Text(
              'No travel requirements',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                FontWeight.w700,
                color: _darkTextColor,
              ),
            ),

            SizedBox(height: 8),

            Text(
              'No requirements were generated '
                  'for this trip.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          _loadChecklistItems(
            showLoading: false,
          ),
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          18,
          16,
          36,
        ),
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
                    fontWeight:
                    FontWeight.w800,
                    color:
                    _darkTextColor,
                  ),
                ),
              ),

              Text(
                '$_totalCount total',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ..._checklistItems.map(
                (item) {
              return Padding(
                padding:
                const EdgeInsets.only(
                  bottom: 14,
                ),
                child:
                _buildRequirementCard(
                  item,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color:
          const Color(0xFFCBE8EB),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: _primaryColor,
                  size: 25,
                ),
              ),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preparation Progress',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                        FontWeight.w800,
                        color:
                        _darkTextColor,
                      ),
                    ),

                    SizedBox(height: 3),

                    Text(
                      'Complete the applicable '
                          'requirements before departure.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color:
                        Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '$_completionPercentage%',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight:
                  FontWeight.w800,
                  color: _primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          ClipRRect(
            borderRadius:
            BorderRadius.circular(20),
            child:
            LinearProgressIndicator(
              value:
              _completionProgress,
              minHeight: 9,
              backgroundColor:
              const Color(
                0xFFDDEBED,
              ),
              valueColor:
              const AlwaysStoppedAnimation<
                  Color>(
                _primaryColor,
              ),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Text(
                  '$_completedCount of '
                      '$_totalCount completed',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.black54,
                  ),
                ),
              ),

              if (_remainingCount > 0)
                Text(
                  '$_remainingCount remaining',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w600,
                    color:
                    Color(0xFF9B5713),
                  ),
                )
              else
                const Text(
                  'All completed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w700,
                    color:
                    Color(0xFF177245),
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD8E6EE),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_outlined,
            size: 21,
            color: Color(0xFF0A5B83),
          ),

          SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Official Information',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334E68),
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'Requirements are generated from validated '
                      'travel rules and official references.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Color(0xFF334E68),
                  ),
                ),

                SizedBox(height: 6),

                Text(
                  'Travel requirements may change. Always verify '
                      'the latest information with the official source '
                      'before departure.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334E68),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementCard(
      ChecklistItem item,
      ) {
    final bool isUpdating =
    _updatingItems.contains(
      item.id,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: item.completed
              ? const Color(
            0xFFB9E2D0,
          )
              : _borderColor,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding:
        const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 30,
                  height: 30,
                  child: Checkbox(
                    value: item.completed,
                    onChanged: isUpdating
                        ? null
                        : (bool? value) {
                      if (value ==
                          null) {
                        return;
                      }

                      _updateCompletion(
                        item,
                        value,
                      );
                    },
                    activeColor:
                    _primaryColor,
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Text(
                    item.checklistLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                      FontWeight.w700,
                      color:
                      _darkTextColor,
                      decoration:
                      item.completed
                          ? TextDecoration
                          .none
                          : null,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                _buildStatusBadge(
                  item.mandatory,
                ),
              ],
            ),

            const SizedBox(height: 14),

            Padding(
              padding:
              const EdgeInsets.only(
                left: 41,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  _buildCategoryBadge(
                    item.category,
                  ),

                  const SizedBox(height: 12),

                  Text(
                    item.description,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color:
                      Color(0xFF486581),
                    ),
                  ),

                  if (item.sourceName
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 14,
                    ),

                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        const Icon(
                          Icons
                              .account_balance_outlined,
                          size: 17,
                          color:
                          Colors.black45,
                        ),

                        const SizedBox(
                          width: 7,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              const Text(
                                'Official Source',
                                style:
                                TextStyle(
                                  fontSize:
                                  11,
                                  color:
                                  Colors
                                      .black45,
                                ),
                              ),

                              const SizedBox(
                                height: 2,
                              ),

                              Text(
                                item.sourceName,
                                style:
                                const TextStyle(
                                  fontSize:
                                  12.5,
                                  fontWeight:
                                  FontWeight
                                      .w600,
                                  color:
                                  _darkTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (item.officialUrl
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 15,
                    ),

                    SizedBox(
                      width:
                      double.infinity,
                      height: 43,
                      child:
                      OutlinedButton.icon(
                        style:
                        OutlinedButton
                            .styleFrom(
                          foregroundColor:
                          _primaryColor,
                          side:
                          const BorderSide(
                            color: Color(
                              0xFF9BD2D7,
                            ),
                          ),
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),
                          ),
                        ),
                        onPressed: () {
                          _openOfficialSource(
                            item.officialUrl,
                          );
                        },
                        icon: const Icon(
                          Icons
                              .open_in_new_rounded,
                          size: 17,
                        ),
                        label: const Text(
                          'Open Official Source',
                          style: TextStyle(
                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (isUpdating) ...[
                    const SizedBox(
                      height: 13,
                    ),

                    const ClipRRect(
                      borderRadius:
                      BorderRadius.all(
                        Radius.circular(
                          20,
                        ),
                      ),
                      child:
                      LinearProgressIndicator(
                        minHeight: 3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
      bool mandatory,
      ) {
    final Color backgroundColor =
    mandatory
        ? const Color(
      0xFFFFE8E6,
    )
        : const Color(
      0xFFE9F2FF,
    );

    final Color textColor =
    mandatory
        ? const Color(
      0xFFB42318,
    )
        : const Color(
      0xFF1D5F9A,
    );

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Text(
        mandatory
            ? 'REQUIRED'
            : 'INFORMATION',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight:
          FontWeight.w800,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(
      String category,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
        const Color(0xFFE8F6F7),
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Text(
        _formatText(category),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight:
          FontWeight.w600,
          color: _primaryColor,
        ),
      ),
    );
  }
}