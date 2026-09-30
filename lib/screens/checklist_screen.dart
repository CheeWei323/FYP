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
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final TripService _tripService = TripService();

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
  Future<void> _loadChecklistItems() async {
    try {
      final List<ChecklistItem> items =
      await _tripService.getChecklistItems(widget.tripId);

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
        _errorMessage = 'Unable to load the travel checklist.';
      });
    }
  }

  // Updates only the completion status of the selected checklist item.
  Future<void> _updateCompletion(
      ChecklistItem item,
      bool completed,
      ) async {
    if (_updatingItems.contains(item.id)) return;

    setState(() {
      _updatingItems.add(item.id);
    });

    try {
      await _tripService.updateChecklistItemCompletion(
        tripId: widget.tripId,
        itemId: item.id,
        completed: completed,
      );

      await _loadChecklistItems();
    } catch (e) {
      debugPrint('CHECKLIST UPDATE ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update the checklist item.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingItems.remove(item.id);
        });
      }
    }
  }

  // Opens the official regulatory source in the device browser.
  Future<void> _openOfficialSource(String url) async {
    final Uri? uri = Uri.tryParse(url);

    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
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

  void _showSourceError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to open the official source.'),
      ),
    );
  }

  int get _completedCount {
    return _checklistItems.where((item) => item.completed).length;
  }

  double get _completionProgress {
    if (_checklistItems.isEmpty) {
      return 0;
    }

    return _completedCount / _checklistItems.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Checklist'),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_checklistItems.isEmpty) {
      return const Center(
        child: Text(
          'No checklist items were generated.',
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Preparation Progress',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: _completionProgress,
              ),
              const SizedBox(height: 8),
              Text(
                '$_completedCount of '
                    '${_checklistItems.length} completed',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            itemCount: _checklistItems.length,
            itemBuilder: (context, index) {
              final ChecklistItem item = _checklistItems[index];

              final bool isUpdating =
              _updatingItems.contains(item.id);

              return Card(
                margin: const EdgeInsets.only(
                  bottom: 12,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CheckboxListTile(
                    value: item.completed,
                    onChanged: isUpdating
                        ? null
                        : (bool? value) {
                      if (value == null) return;

                      _updateCompletion(
                        item,
                        value,
                      );
                    },
                    title: Text(
                      item.checklistLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(
                        top: 8,
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(item.description),
                          const SizedBox(height: 8),
                          Text(
                            'Category: ${item.category}',
                          ),
                          Text(
                            item.mandatory
                                ? 'Status: Required'
                                : 'Status: Information',
                          ),
                          if (item.sourceName.isNotEmpty)
                            Text(
                              'Source: ${item.sourceName}',
                            ),

                          // Opens the authoritative source for verification.
                          if (item.officialUrl.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () {
                                _openOfficialSource(
                                  item.officialUrl,
                                );
                              },
                              icon: const Icon(
                                Icons.open_in_new,
                                size: 18,
                              ),
                              label: const Text(
                                'Open Official Source',
                              ),
                            ),
                          ],

                          if (isUpdating) ...[
                            const SizedBox(height: 8),
                            const LinearProgressIndicator(),
                          ],
                        ],
                      ),
                    ),
                    controlAffinity:
                    ListTileControlAffinity.leading,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}