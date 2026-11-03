import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/packing_item.dart';
import '../models/trip.dart';
import '../services/packing_ai_service.dart';
import '../services/packing_service.dart';
import '../theme/app_theme.dart';
import '../widgets/traveller_ui_widgets.dart';

class PackingScreen extends StatefulWidget {
  final Trip trip;

  const PackingScreen({super.key, required this.trip});

  @override
  State<PackingScreen> createState() => _PackingScreenState();
}

class _PackingScreenState extends State<PackingScreen> {
  final PackingService _packingService = PackingService();

  final PackingAiService _packingAiService = PackingAiService();

  List<PackingItem> _packingItems = [];

  final Set<String> _updatingItems = {};

  bool _isLoading = true;
  bool _isGeneratingAi = false;

  String? _errorMessage;

  static const Color _primaryColor = AppColors.primary;

  static const List<String> _categories = [
    'clothing',
    'toiletries',
    'electronics',
    'healthComfort',
    'activityEssentials',
    'generalEssentials',
    'other',
  ];

  static const Map<String, int> _categoryOrder = {
    'clothing': 1,
    'toiletries': 2,
    'electronics': 3,
    'healthComfort': 4,
    'activityEssentials': 5,
    'generalEssentials': 6,
    'other': 7,
  };

  @override
  void initState() {
    super.initState();

    _loadPackingItems();
  }

  // ---------------------------------------------------------------------------
  // DATA LOADING
  // ---------------------------------------------------------------------------

  Future<void> _loadPackingItems({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<PackingItem> items = await _packingService.getPackingItems(
        widget.trip.id,
      );

      if (!mounted) return;

      setState(() {
        _packingItems = items;

        _sortPackingItems();

        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('PACKING LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load the packing list.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // DISPLAY HELPERS
  // ---------------------------------------------------------------------------

  String _categoryLabel(String category) {
    switch (category) {
      case 'clothing':
        return 'Clothing';

      case 'toiletries':
        return 'Toiletries';

      case 'electronics':
        return 'Electronics';

      case 'healthComfort':
        return 'Health & Comfort';

      case 'activityEssentials':
        return 'Activity Essentials';

      case 'generalEssentials':
        return 'General Essentials';

      default:
        return 'Other';
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'clothing':
        return Icons.checkroom_outlined;

      case 'toiletries':
        return Icons.wash_outlined;

      case 'electronics':
        return Icons.devices_outlined;

      case 'healthComfort':
        return Icons.health_and_safety_outlined;

      case 'activityEssentials':
        return Icons.hiking_outlined;

      case 'generalEssentials':
        return Icons.inventory_2_outlined;

      default:
        return Icons.category_outlined;
    }
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

  String _formatDate(DateTime date) {
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

  String _normalizeItemName(String name) {
    return name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  PackingItem? _findDuplicatePackingItem(String name, {String? excludeItemId}) {
    final String normalizedName = _normalizeItemName(name);

    for (final PackingItem item in _packingItems) {
      if (excludeItemId != null && item.id == excludeItemId) {
        continue;
      }

      if (_normalizeItemName(item.name) == normalizedName) {
        return item;
      }
    }

    return null;
  }

  void _sortPackingItems() {
    _packingItems.sort((a, b) {
      final int categoryA = _categoryOrder[a.category] ?? 99;

      final int categoryB = _categoryOrder[b.category] ?? 99;

      final int categoryComparison = categoryA.compareTo(categoryB);

      if (categoryComparison != 0) {
        return categoryComparison;
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  int get _packedCount {
    return _packingItems.where((item) => item.packed).length;
  }

  int get _remainingCount {
    final int remaining = _packingItems.length - _packedCount;

    return remaining < 0 ? 0 : remaining;
  }

  double get _packingProgress {
    if (_packingItems.isEmpty) {
      return 0;
    }

    return _packedCount / _packingItems.length;
  }

  int get _packingPercentage {
    return (_packingProgress * 100).round();
  }

  bool get _hasAiGeneratedItems {
    return _packingItems.any((item) => item.source == 'ai');
  }

  // ---------------------------------------------------------------------------
  // DUPLICATE HANDLING
  // ---------------------------------------------------------------------------

  Future<bool> _showDuplicatePackingItemDialog(PackingItem existingItem) async {
    final bool? editExisting = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.content_copy_outlined,
            color: _primaryColor,
            size: 30,
          ),
          title: const Text('Item Already Exists', textAlign: TextAlign.center),
          content: Text(
            '"${existingItem.name}" is already in '
            'your packing list.\n\n'
            'You can edit the existing item if '
            'you want to change its quantity '
            'or category.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Existing'),
            ),
          ],
        );
      },
    );

    return editExisting ?? false;
  }

  // ---------------------------------------------------------------------------
  // CONTEXTUAL PACKING GENERATION
  // ---------------------------------------------------------------------------

  Future<void> _showPackingFeedback({
    required String title,
    required String message,
    required IconData icon,
    Color iconColor = AppColors.primary,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(icon, color: iconColor, size: 38),
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

  Future<void> _generateAiPackingList() async {
    if (_isGeneratingAi || _hasAiGeneratedItems) {
      return;
    }

    setState(() {
      _isGeneratingAi = true;
    });

    try {
      final List<Map<String, dynamic>> generatedItems = await _packingAiService
          .generatePackingItems(
            destination: widget.trip.destinationCountryId,
            purpose: widget.trip.purpose,
            durationDays: widget.trip.durationDays,
            departureDate: widget.trip.departureDate,
          );

      if (!mounted) return;

      // Prevent generated items from duplicating existing manual items.
      final Set<String> existingNames = _packingItems
          .map((item) => _normalizeItemName(item.name))
          .toSet();

      final Set<String> generatedNames = {};

      final List<PackingItem> packingItems = [];

      for (final Map<String, dynamic> item in generatedItems) {
        final String name = item['name'].toString().trim();

        final String normalizedName = _normalizeItemName(name);

        if (name.isEmpty) {
          continue;
        }

        // Skip an item already in the traveller's list.
        if (existingNames.contains(normalizedName)) {
          continue;
        }

        // Skip duplicate names returned by the generation service.
        if (generatedNames.contains(normalizedName)) {
          continue;
        }

        generatedNames.add(normalizedName);

        packingItems.add(
          PackingItem(
            id: '',
            name: name,
            category: item['category'].toString(),
            quantity: item['quantity'] as int,
            packed: false,
            source: 'ai',
          ),
        );
      }

      if (packingItems.isEmpty) {
        if (!mounted) return;

        await _showPackingFeedback(
          title: 'No New Suggestions',
          message:
              'The generated suggestions are already included '
              'in your packing list. No duplicate items were added.',
          icon: Icons.info_outline_rounded,
        );

        return;
      }

      await _packingService.addGeneratedPackingItems(
        tripId: widget.trip.id,
        items: packingItems,
      );

      if (!mounted) return;

      await _loadPackingItems(showLoading: false);

      if (!mounted) return;

      await _showPackingFeedback(
        title: 'Suggestions Added',
        message:
            '${packingItems.length} contextual packing '
            'suggestions were added successfully.\n\n'
            'Review the items and quantities in your packing list.',
        icon: Icons.check_circle_outline_rounded,
        iconColor: AppColors.success,
      );
    } catch (e) {
      debugPrint('AI PACKING GENERATION ERROR: $e');

      if (!mounted) return;

      // Keep sign-in failures distinct from network and Gemini errors.
      final String? authenticationMessage = e is PackingAuthenticationException
          ? e.message
          : null;

      final String errorText = e.toString().toLowerCase();

      final bool isTemporaryGeminiError =
          errorText.contains('503') ||
          errorText.contains('temporarily busy') ||
          errorText.contains('high demand') ||
          errorText.contains('unavailable');

      await _showPackingFeedback(
        title: 'Unable to Generate Suggestions',
        message:
            authenticationMessage ??
            (isTemporaryGeminiError
                ? 'The packing recommendation service is '
                      'temporarily busy. Please wait a moment '
                      'and try again.'
                : 'Packing suggestions could not be generated. '
                      'Please check your internet connection '
                      'and try again.'),
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.danger,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingAi = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // PACKED STATUS
  // ---------------------------------------------------------------------------

  Future<void> _updatePackedStatus(PackingItem item, bool packed) async {
    if (_updatingItems.contains(item.id)) {
      return;
    }

    final int itemIndex = _packingItems.indexWhere(
      (value) => value.id == item.id,
    );

    if (itemIndex == -1) {
      return;
    }

    final bool previousValue = item.packed;

    setState(() {
      _updatingItems.add(item.id);

      _packingItems[itemIndex] = item.copyWith(packed: packed);
    });

    try {
      await _packingService.updatePackedStatus(
        tripId: widget.trip.id,
        itemId: item.id,
        packed: packed,
      );
    } catch (e) {
      debugPrint('PACKING STATUS ERROR: $e');

      if (!mounted) return;

      final int currentIndex = _packingItems.indexWhere(
        (value) => value.id == item.id,
      );

      if (currentIndex != -1) {
        setState(() {
          _packingItems[currentIndex] = _packingItems[currentIndex].copyWith(
            packed: previousValue,
          );
        });
      }
      await _showPackingFeedback(
        title: 'Unable to Update Item',
        message:
            'The packing status could not be saved. '
            'Your previous selection has been restored. '
            'Please try again.',
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.danger,
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingItems.remove(item.id);
        });
      }
    }
  }

  Widget _buildPackingItemFormFields({
    required String initialName,
    required String initialQuantity,
    required String selectedCategory,
    required bool isSaving,
    required ValueChanged<String> onNameChanged,
    required ValueChanged<String> onCategoryChanged,
    required ValueChanged<String> onQuantityChanged,
    String? errorText,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -----------------------------------------------------
        // ITEM NAME
        // -----------------------------------------------------
        const Text(
          'Item Name',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 9),

        TextFormField(
          initialValue: initialName,
          enabled: !isSaving,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'e.g. Phone charger',
            prefixIcon: Icon(Icons.inventory_2_outlined),
            counterText: '',
          ),
          onChanged: onNameChanged,
        ),

        const SizedBox(height: 19),

        // -----------------------------------------------------
        // CATEGORY
        // -----------------------------------------------------
        const Text(
          'Category',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 9),

        DropdownButtonFormField<String>(
          itemHeight: null,
          initialValue: selectedCategory,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: _categories.map((category) {
            return DropdownMenuItem<String>(
              value: category,
              child: Text(
                _categoryLabel(category),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: isSaving
              ? null
              : (value) {
                  if (value != null) {
                    onCategoryChanged(value);
                  }
                },
        ),

        const SizedBox(height: 19),

        // -----------------------------------------------------
        // QUANTITY
        // -----------------------------------------------------
        const Text(
          'Quantity',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 9),

        TextFormField(
          initialValue: initialQuantity,
          enabled: !isSaving,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: 'Enter quantity',
            prefixIcon: Icon(Icons.numbers_rounded),
          ),
          onChanged: onQuantityChanged,
        ),

        // -----------------------------------------------------
        // INLINE ERROR MESSAGE
        // -----------------------------------------------------
        if (errorText != null) ...[
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD5D1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.danger,
                  size: 19,
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: Text(
                    errorText,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ADD ITEM
  // ---------------------------------------------------------------------------

  Future<void> _showAddItemDialog() async {
    String itemName = '';
    String quantityText = '1';

    String selectedCategory = 'generalEssentials';

    bool isSaving = false;

    String? dialogError;

    PackingItem? duplicateItemToEdit;

    final PackingItem? addedItem = await showDialog<PackingItem>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,

              icon: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),

              title: const Text(
                'Add Packing Item',
                textAlign: TextAlign.center,
              ),

              content: _buildPackingItemFormFields(
                initialName: itemName,
                initialQuantity: quantityText,
                selectedCategory: selectedCategory,
                isSaving: isSaving,
                errorText: dialogError,

                onNameChanged: (value) {
                  itemName = value;

                  if (dialogError != null) {
                    setDialogState(() {
                      dialogError = null;
                    });
                  }
                },

                onCategoryChanged: (value) {
                  setDialogState(() {
                    selectedCategory = value;
                    dialogError = null;
                  });
                },

                onQuantityChanged: (value) {
                  quantityText = value;

                  if (dialogError != null) {
                    setDialogState(() {
                      dialogError = null;
                    });
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final String name = itemName.trim();

                          final int? quantity = int.tryParse(
                            quantityText.trim(),
                          );

                          if (name.isEmpty ||
                              quantity == null ||
                              quantity < 1) {
                            setDialogState(() {
                              dialogError =
                                  'Enter a valid item name and quantity.';
                            });

                            return;
                          }

                          final PackingItem? existingItem =
                              _findDuplicatePackingItem(name);

                          if (existingItem != null) {
                            final bool editExisting =
                                await _showDuplicatePackingItemDialog(
                                  existingItem,
                                );

                            if (!dialogContext.mounted) {
                              return;
                            }

                            if (editExisting) {
                              duplicateItemToEdit = existingItem;

                              Navigator.pop(dialogContext);
                            }

                            return;
                          }

                          setDialogState(() {
                            isSaving = true;

                            dialogError = null;
                          });

                          try {
                            final String itemId = await _packingService
                                .addPackingItem(
                                  tripId: widget.trip.id,
                                  name: name,
                                  category: selectedCategory,
                                  quantity: quantity,
                                );

                            if (!dialogContext.mounted) {
                              return;
                            }

                            Navigator.pop(
                              dialogContext,
                              PackingItem(
                                id: itemId,
                                name: name,
                                category: selectedCategory,
                                quantity: quantity,
                                packed: false,
                                source: 'user',
                              ),
                            );
                          } catch (e) {
                            debugPrint('PACKING ADD ERROR: $e');

                            if (!dialogContext.mounted) {
                              return;
                            }

                            setDialogState(() {
                              isSaving = false;

                              dialogError = 'Unable to add the packing item.';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (duplicateItemToEdit != null) {
      await _showEditItemDialog(duplicateItemToEdit!);

      return;
    }

    if (addedItem == null) {
      return;
    }

    setState(() {
      _packingItems.add(addedItem);

      _sortPackingItems();
    });
  }

  // ---------------------------------------------------------------------------
  // EDIT ITEM
  // ---------------------------------------------------------------------------

  Future<void> _showEditItemDialog(PackingItem item) async {
    String itemName = item.name;
    String quantityText = item.quantity.toString();
    String selectedCategory = item.category;

    bool isSaving = false;
    String? dialogError;

    final PackingItem? editedItem = await showDialog<PackingItem>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,

              // -------------------------------------------------
              // DIALOG ICON
              // -------------------------------------------------
              icon: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: AppColors.primary,
                  size: 29,
                ),
              ),

              title: const Text(
                'Edit Packing Item',
                textAlign: TextAlign.center,
              ),

              // -------------------------------------------------
              // SHARED PACKING ITEM FORM
              // -------------------------------------------------
              content: _buildPackingItemFormFields(
                initialName: itemName,
                initialQuantity: quantityText,
                selectedCategory: selectedCategory,
                isSaving: isSaving,
                errorText: dialogError,

                onNameChanged: (value) {
                  itemName = value;

                  if (dialogError != null) {
                    setDialogState(() {
                      dialogError = null;
                    });
                  }
                },

                onCategoryChanged: (value) {
                  setDialogState(() {
                    selectedCategory = value;
                    dialogError = null;
                  });
                },

                onQuantityChanged: (value) {
                  quantityText = value;

                  if (dialogError != null) {
                    setDialogState(() {
                      dialogError = null;
                    });
                  }
                },
              ),

              // -------------------------------------------------
              // DIALOG ACTIONS
              // -------------------------------------------------
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),

                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final String name = itemName.trim();

                          final int? quantity = int.tryParse(
                            quantityText.trim(),
                          );

                          // Validate name and quantity.
                          if (name.isEmpty ||
                              quantity == null ||
                              quantity < 1) {
                            setDialogState(() {
                              dialogError =
                                  'Enter a valid item name and quantity.';
                            });

                            return;
                          }

                          // Prevent duplicate packing item names.
                          final PackingItem? duplicateItem =
                              _findDuplicatePackingItem(
                                name,
                                excludeItemId: item.id,
                              );

                          if (duplicateItem != null) {
                            setDialogState(() {
                              dialogError =
                                  '"${duplicateItem.name}" is already '
                                  'in the packing list.';
                            });

                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                            dialogError = null;
                          });

                          try {
                            // Update the existing item in Firestore.
                            await _packingService.updatePackingItem(
                              tripId: widget.trip.id,
                              itemId: item.id,
                              name: name,
                              category: selectedCategory,
                              quantity: quantity,
                            );

                            if (!dialogContext.mounted) {
                              return;
                            }

                            Navigator.pop(
                              dialogContext,
                              item.copyWith(
                                name: name,
                                category: selectedCategory,
                                quantity: quantity,
                              ),
                            );
                          } catch (e) {
                            debugPrint('PACKING EDIT ERROR: $e');

                            if (!dialogContext.mounted) {
                              return;
                            }

                            setDialogState(() {
                              isSaving = false;
                              dialogError =
                                  'Unable to update the packing item.';
                            });
                          }
                        },

                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    // -----------------------------------------------------------
    // UPDATE LOCAL PACKING LIST AFTER SUCCESSFUL EDIT
    // -----------------------------------------------------------

    if (editedItem == null || !mounted) {
      return;
    }

    final int index = _packingItems.indexWhere(
      (value) => value.id == editedItem.id,
    );

    if (index == -1) {
      return;
    }

    setState(() {
      _packingItems[index] = editedItem;
      _sortPackingItems();
    });
  }

  // ---------------------------------------------------------------------------
  // DELETE ITEM
  // ---------------------------------------------------------------------------

  Future<void> _confirmDelete(PackingItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFFFECEB),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.danger,
              size: 29,
            ),
          ),

          title: const Text(
            'Delete Packing Item?',
            textAlign: TextAlign.center,
          ),

          content: Text(
            'Are you sure you want to remove '
            '"${item.name}" from your packing list?\n\n'
            'This action cannot be undone.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
              height: 1.5,
            ),
          ),

          actionsAlignment: MainAxisAlignment.center,

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),

            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    // Cancelled deletion.
    if (confirmed != true || !mounted) {
      return;
    }

    // Optimistically remove the item from the UI.
    setState(() {
      _packingItems.removeWhere((value) => value.id == item.id);
    });

    try {
      // Delete the packing item from Firestore.
      await _packingService.deletePackingItem(
        tripId: widget.trip.id,
        itemId: item.id,
      );
    } catch (e) {
      debugPrint('PACKING DELETE ERROR: $e');

      if (!mounted) return;

      // Restore the item if Firestore deletion fails.
      setState(() {
        _packingItems.add(item);
        _sortPackingItems();
      });

      await _showPackingFeedback(
        title: 'Unable to Delete Item',
        message:
            'The packing item could not be deleted. '
            'Please check your connection and try again.',
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.danger,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Packing List')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _isLoading || _isGeneratingAi || _errorMessage != null
          ? null
          : _showAddItemDialog,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add Item'),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    body: SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: () async {
          if (!_isGeneratingAi) await _loadPackingItems(showLoading: false);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
          children: [
            TravellerIntroCard(
              icon: Icons.luggage_outlined,
              title:
                  'Packing for ${_formatText(widget.trip.destinationCountryId)}',
              message:
                  '${_formatText(widget.trip.purpose)} · ${widget.trip.durationDays} days\n'
                  'Departs ${_formatDate(widget.trip.departureDate)}',
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      LinearProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Loading your packing list...'),
                    ],
                  ),
                ),
              ),
            if (!_isLoading && _errorMessage != null)
              TravellerStatusCard(
                icon: Icons.cloud_off_outlined,
                title: 'Unable to load packing list',
                message: 'Check your connection and try again.',
                actionText: 'Retry',
                onAction: () => _loadPackingItems(),
              ),
            if (!_isLoading && _errorMessage == null) ...[
              _buildProgressCard(),
              const SizedBox(height: 16),
              _buildRecommendationCard(),
              const SizedBox(height: 24),
              if (_packingItems.isEmpty)
                TravellerStatusCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'Start your packing list',
                  message:
                      'Add your own items or use optional AI suggestions for this trip.',
                  actionText: 'Add Item Manually',
                  onAction: _isGeneratingAi ? null : _showAddItemDialog,
                )
              else
                for (final category in _categories)
                  if (_packingItems.any(
                    (item) => item.category == category,
                  )) ...[
                    _buildCategoryHeader(category),
                    const SizedBox(height: 10),
                    ..._packingItems
                        .where((item) => item.category == category)
                        .map(_buildPackingItemCard),
                    const SizedBox(height: 18),
                  ],
            ],
          ],
        ),
      ),
    ),
  );

  Widget _buildProgressCard() {
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Packing progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              _packingItems.isEmpty ? 'No items yet' : '$_packingPercentage%',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$_packedCount of ${_packingItems.length} items packed · $_remainingCount remaining',
            ),
            if (_packingItems.isNotEmpty) ...[
              const SizedBox(height: 14),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _packingProgress),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 350),
                builder: (context, value, child) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(10),
                  backgroundColor: AppColors.primaryLight,
                  semanticsLabel: 'Packing completion',
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Packing progress is separate from Travel Readiness.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard() => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI packing suggestions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Optional suggestions based on your destination, purpose and travel dates.',
          ),
          const SizedBox(height: 14),
          if (_isGeneratingAi) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
            const Text('Preparing your suggestions...'),
          ] else if (_hasAiGeneratedItems)
            const Text(
              'Recommendations added. Review the items and quantities below.',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            FilledButton.icon(
              onPressed: _updatingItems.isNotEmpty
                  ? null
                  : _generateAiPackingList,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text(
                'Generate Suggestions',
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Review AI suggestions before using them. '
            'They do not replace official travel requirements.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Widget _buildCategoryHeader(String category) {
    final items = _packingItems
        .where((item) => item.category == category)
        .toList();
    final packed = items.where((item) => item.packed).length;

    return Row(
      children: [
        Icon(_categoryIcon(category), color: AppColors.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _categoryLabel(category),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$packed/${items.length}',
          style: const TextStyle(color: AppColors.secondaryText),
        ),
      ],
    );
  }

  Widget _buildPackingItemCard(PackingItem item) {
    final busy = _isGeneratingAi || _updatingItems.contains(item.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: 'Packed: ${item.name}',
                  child: Checkbox(
                    value: item.packed,
                    onChanged: busy
                        ? null
                        : (value) {
                            if (value != null) _updatePackedStatus(item, value);
                          },
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      item.name,
                      style: TextStyle(
                        color: item.packed
                            ? AppColors.secondaryText
                            : AppColors.navy,
                        fontWeight: FontWeight.w700,
                        decoration: item.packed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ),
                if (_updatingItems.contains(item.id))
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  PopupMenuButton<String>(
                    tooltip: 'Item options',
                    enabled: !busy,
                    onSelected: (value) {
                      if (value == 'edit') _showEditItemDialog(item);
                      if (value == 'delete') _confirmDelete(item);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit Item')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete Item',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _packingBadge('Qty ${item.quantity}'),
                  _packingBadge(
                    item.source == 'ai' ? 'AI Suggested' : 'Manual',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _packingBadge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 12, color: AppColors.primary),
    ),
  );
}
