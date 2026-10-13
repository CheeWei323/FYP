import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/packing_item.dart';
import '../models/trip.dart';
import '../services/packing_ai_service.dart';
import '../services/packing_service.dart';
import '../theme/app_theme.dart';

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

  static const Color _primaryColor = Color(0xFF087F8C);

  static const Color _darkTextColor = Color(0xFF102A43);

  static const Color _backgroundColor = Color(0xFFF7F9FB);

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

      final String errorText = e.toString().toLowerCase();

      final bool isTemporaryGeminiError =
          errorText.contains('503') ||
          errorText.contains('temporarily busy') ||
          errorText.contains('high demand') ||
          errorText.contains('unavailable');

      await _showPackingFeedback(
        title: 'Unable to Generate Suggestions',
        message: isTemporaryGeminiError
            ? 'The packing recommendation service is '
                  'temporarily busy. Please wait a moment '
                  'and try again.'
            : 'Packing suggestions could not be generated. '
                  'Please check your internet connection '
                  'and try again.',
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Packing List',
          style: TextStyle(color: _darkTextColor, fontWeight: FontWeight.w700),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        onPressed: _showAddItemDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Item',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_packingItems.isEmpty) {
      return _buildEmptyState();
    }

    final List<String> visibleCategories = _categories
        .where(
          (category) => _packingItems.any((item) => item.category == category),
        )
        .toList();

    return RefreshIndicator(
      onRefresh: () => _loadPackingItems(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
        children: [
          _buildTripSummary(),

          const SizedBox(height: 18),

          _buildProgressCard(),

          const SizedBox(height: 18),

          _buildRecommendationCard(),

          const SizedBox(height: 26),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Packing Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _darkTextColor,
                  ),
                ),
              ),

              Text(
                '${_packingItems.length} items',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),

          const SizedBox(height: 14),

          for (final String category in visibleCategories) ...[
            _buildCategoryHeader(category),

            const SizedBox(height: 9),

            ..._packingItems
                .where((item) => item.category == category)
                .map((item) => _buildPackingItemCard(item)),

            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return RefreshIndicator(
      onRefresh: () => _loadPackingItems(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 140),

          const Icon(Icons.cloud_off_outlined, size: 58, color: Colors.black38),

          const SizedBox(height: 18),

          const Text(
            'Unable to load packing list',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _darkTextColor,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),

          const SizedBox(height: 8),

          const Text(
            'Pull down to try again.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: () => _loadPackingItems(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 50, 24, 110),
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F6F7),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.luggage_outlined,
                size: 42,
                color: _primaryColor,
              ),
            ),
          ),

          const SizedBox(height: 22),

          const Text(
            'Start Your Packing List',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: _darkTextColor,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Add items manually or generate contextual '
            'packing recommendations based on this trip.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black54),
          ),

          const SizedBox(height: 26),

          _buildRecommendationCard(),

          const SizedBox(height: 18),

          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryColor,
                side: const BorderSide(color: Color(0xFF9BD2D7)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _showAddItemDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Item Manually',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripSummary() {
    final Trip trip = widget.trip;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.luggage_outlined,
                  color: AppColors.primary,
                  size: 25,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PACKING FOR',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      _formatText(trip.destinationCountryId),
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _buildPackingSummaryChip(
                Icons.explore_outlined,
                _formatText(trip.purpose),
              ),
              _buildPackingSummaryChip(
                Icons.schedule_outlined,
                '${trip.durationDays} days',
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: AppColors.primary,
                size: 19,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Departure: ${_formatDate(trip.departureDate)}',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------------
  // REUSABLE TRIP SUMMARY CHIP
  // -----------------------------------------------------------------------------

  Widget _buildPackingSummaryChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),

          const SizedBox(width: 7),

          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final int packed = _packedCount;
    final int total = _packingItems.length;
    final int remaining = _remainingCount;

    final double progress = _packingProgress;
    final int percentage = _packingPercentage;

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
          // HEADER
          // -----------------------------------------------------
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),

              const SizedBox(width: 13),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Packing Progress',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    SizedBox(height: 5),

                    Text(
                      'Keep track of the items prepared for your trip.',
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
          // PROGRESS SUMMARY
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
                        ? 'All items packed'
                        : '$remaining item'
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
          // PACKED AND TOTAL COUNTS
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
                  '$packed packed',
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

  Widget _buildRecommendationCard() {
    final bool alreadyGenerated = _hasAiGeneratedItems;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
          // RECOMMENDATION HEADER
          // -----------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  alreadyGenerated
                      ? Icons.check_circle_outline_rounded
                      : Icons.auto_awesome_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),

              const SizedBox(width: 13),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contextual Packing Recommendations',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),

                    SizedBox(height: 6),

                    Text(
                      'AI-assisted suggestions tailored to your trip.',
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

          const SizedBox(height: 18),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 16),

          // -----------------------------------------------------
          // PERSONALISATION INFORMATION
          // -----------------------------------------------------
          const Text(
            'BASED ON YOUR TRIP',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 11),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _RecommendationChip(
                icon: Icons.location_on_outlined,
                title: 'Destination',
              ),
              _RecommendationChip(
                icon: Icons.explore_outlined,
                title: 'Purpose',
              ),
              _RecommendationChip(
                icon: Icons.schedule_outlined,
                title: 'Duration',
              ),
              _RecommendationChip(
                icon: Icons.calendar_month_outlined,
                title: 'Departure',
              ),
            ],
          ),

          const SizedBox(height: 19),

          // -----------------------------------------------------
          // ANIMATED GENERATION STATUS
          // -----------------------------------------------------
          AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _isGeneratingAi
                ? Container(
                    key: const ValueKey('generating'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preparing your suggestions...',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        SizedBox(height: 7),

                        Text(
                          'Generating items based on your trip. '
                          'This may take a moment.',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),

                        SizedBox(height: 13),

                        ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  )
                : alreadyGenerated
                ? Container(
                    key: const ValueKey('generated'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF7F1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: AppColors.success,
                          size: 21,
                        ),

                        SizedBox(width: 10),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recommendations Added',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),

                              SizedBox(height: 5),

                              Text(
                                'Your AI suggestions are available '
                                'in the packing list below. '
                                'Review the items and quantities.',
                                style: TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 12,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : SizedBox(
                    key: const ValueKey('ready'),
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _generateAiPackingList,
                      icon: const Icon(Icons.auto_awesome_outlined, size: 19),
                      label: const Text('Generate Suggestions'),
                    ),
                  ),
          ),

          const SizedBox(height: 17),

          // -----------------------------------------------------
          // INFORMATION NOTE
          // -----------------------------------------------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),

                SizedBox(width: 9),

                Expanded(
                  child: Text(
                    'AI-generated packing suggestions are '
                    'optional and should be reviewed. '
                    'They do not replace official travel requirements.',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 11.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String category) {
    final List<PackingItem> categoryItems = _packingItems
        .where((item) => item.category == category)
        .toList();

    final int total = categoryItems.length;

    final int packed = categoryItems.where((item) => item.packed).length;

    final bool allPacked = total > 0 && packed == total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ---------------------------------------------------
          // CATEGORY ICON
          // ---------------------------------------------------
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              _categoryIcon(category),
              size: 22,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(width: 12),

          // ---------------------------------------------------
          // CATEGORY NAME AND COMPLETION STATUS
          // ---------------------------------------------------
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _categoryLabel(category),
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  allPacked ? 'All items packed' : '$packed of $total packed',
                  style: TextStyle(
                    color: allPacked
                        ? AppColors.success
                        : AppColors.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ---------------------------------------------------
          // CATEGORY ITEM COUNT
          // ---------------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: allPacked
                  ? const Color(0xFFEAF7F1)
                  : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$packed/$total',
              style: TextStyle(
                color: allPacked ? AppColors.success : AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackingItemCard(PackingItem item) {
    final bool isUpdating = _updatingItems.contains(item.id);
    final bool isRecommendation = item.source == 'ai';
    final bool isPacked = item.packed;

    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPacked ? const Color(0xFFB9E2D0) : AppColors.border,
          width: isPacked ? 1.3 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 12, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // -------------------------------------------------
            // PACKED CHECKBOX
            // -------------------------------------------------
            SizedBox(
              width: 46,
              height: 48,
              child: Checkbox(
                value: isPacked,
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                onChanged: isUpdating
                    ? null
                    : (bool? value) {
                        if (value == null) return;

                        _updatePackedStatus(item, value);
                      },
              ),
            ),

            const SizedBox(width: 8),

            // -------------------------------------------------
            // ITEM DETAILS
            // -------------------------------------------------
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      color: isPacked
                          ? AppColors.secondaryText
                          : AppColors.navy,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      decoration: isPacked
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: AppColors.secondaryText,
                    ),
                  ),

                  const SizedBox(height: 9),

                  // Badges automatically wrap on narrow phones.
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _buildPackingItemBadge(
                        label: 'Qty ${item.quantity}',
                        icon: Icons.inventory_2_outlined,
                        backgroundColor: const Color(0xFFF0F4F6),
                        foregroundColor: AppColors.secondaryText,
                      ),

                      _buildPackingItemBadge(
                        label: isRecommendation ? 'AI Suggested' : 'Manual',
                        icon: isRecommendation
                            ? Icons.auto_awesome_outlined
                            : Icons.edit_note_rounded,
                        backgroundColor: isRecommendation
                            ? AppColors.primaryLight
                            : const Color(0xFFF4F1FA),
                        foregroundColor: isRecommendation
                            ? AppColors.primary
                            : const Color(0xFF654C87),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // -------------------------------------------------
            // ITEM ACTIONS
            // -------------------------------------------------
            if (isUpdating)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              )
            else
              PopupMenuButton<String>(
                tooltip: 'Item options',
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.secondaryText,
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditItemDialog(item);
                  } else if (value == 'delete') {
                    _confirmDelete(item);
                  }
                },
                itemBuilder: (context) {
                  return const [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text('Edit Item'),
                        ],
                      ),
                    ),

                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.danger,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Delete Item',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackingItemBadge({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foregroundColor),

          const SizedBox(width: 5),

          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationChip extends StatelessWidget {
  final IconData icon;
  final String title;

  const _RecommendationChip({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
