import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/packing_item.dart';
import '../models/trip.dart';
import '../services/packing_ai_service.dart';
import '../services/packing_service.dart';

class PackingScreen extends StatefulWidget {
  final Trip trip;

  const PackingScreen({
    super.key,
    required this.trip,
  });

  @override
  State<PackingScreen> createState() =>
      _PackingScreenState();
}

class _PackingScreenState
    extends State<PackingScreen> {
  final PackingService _packingService =
  PackingService();

  final PackingAiService _packingAiService =
  PackingAiService();

  List<PackingItem> _packingItems = [];

  final Set<String> _updatingItems = {};

  bool _isLoading = true;
  bool _isGeneratingAi = false;

  String? _errorMessage;

  static const Color _primaryColor =
  Color(0xFF087F8C);

  static const Color _darkTextColor =
  Color(0xFF102A43);

  static const Color _backgroundColor =
  Color(0xFFF7F9FB);

  static const Color _borderColor =
  Color(0xFFE1E7EC);

  static const List<String> _categories = [
    'clothing',
    'toiletries',
    'electronics',
    'healthComfort',
    'activityEssentials',
    'generalEssentials',
    'other',
  ];

  static const Map<String, int>
  _categoryOrder = {
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

  Future<void> _loadPackingItems({
    bool showLoading = true,
  }) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<PackingItem> items =
      await _packingService
          .getPackingItems(
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
      debugPrint(
        'PACKING LOAD ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
        'Unable to load the packing list.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // DISPLAY HELPERS
  // ---------------------------------------------------------------------------

  String _categoryLabel(
      String category,
      ) {
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

  IconData _categoryIcon(
      String category,
      ) {
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

  String _formatText(
      String value,
      ) {
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

  String _formatDate(
      DateTime date,
      ) {
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

  String _normalizeItemName(
      String name,
      ) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
  }

  PackingItem?
  _findDuplicatePackingItem(
      String name, {
        String? excludeItemId,
      }) {
    final String normalizedName =
    _normalizeItemName(name);

    for (final PackingItem item
    in _packingItems) {
      if (excludeItemId != null &&
          item.id == excludeItemId) {
        continue;
      }

      if (_normalizeItemName(
        item.name,
      ) ==
          normalizedName) {
        return item;
      }
    }

    return null;
  }

  void _sortPackingItems() {
    _packingItems.sort(
          (a, b) {
        final int categoryA =
            _categoryOrder[
            a.category] ??
                99;

        final int categoryB =
            _categoryOrder[
            b.category] ??
                99;

        final int categoryComparison =
        categoryA.compareTo(
          categoryB,
        );

        if (categoryComparison != 0) {
          return categoryComparison;
        }

        return a.name
            .toLowerCase()
            .compareTo(
          b.name.toLowerCase(),
        );
      },
    );
  }

  int get _packedCount {
    return _packingItems
        .where(
          (item) => item.packed,
    )
        .length;
  }

  int get _remainingCount {
    final int remaining =
        _packingItems.length -
            _packedCount;

    return remaining < 0
        ? 0
        : remaining;
  }

  double get _packingProgress {
    if (_packingItems.isEmpty) {
      return 0;
    }

    return _packedCount /
        _packingItems.length;
  }

  int get _packingPercentage {
    return (_packingProgress * 100)
        .round();
  }

  bool get _hasAiGeneratedItems {
    return _packingItems.any(
          (item) => item.source == 'ai',
    );
  }

  // ---------------------------------------------------------------------------
  // DUPLICATE HANDLING
  // ---------------------------------------------------------------------------

  Future<bool>
  _showDuplicatePackingItemDialog(
      PackingItem existingItem,
      ) async {
    final bool? editExisting =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.content_copy_outlined,
            color: _primaryColor,
            size: 30,
          ),
          title: const Text(
            'Item Already Exists',
            textAlign: TextAlign.center,
          ),
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
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
              const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
              ),
              label: const Text(
                'Edit Existing',
              ),
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

  Future<void>
  _generateAiPackingList()
  async {
    if (_isGeneratingAi ||
        _hasAiGeneratedItems) {
      return;
    }

    setState(() {
      _isGeneratingAi = true;
    });

    try {
      final List<Map<String, dynamic>>
      generatedItems =
      await _packingAiService
          .generatePackingItems(
        destination:
        widget.trip.destinationCountryId,
        purpose:
        widget.trip.purpose,
        durationDays:
        widget.trip.durationDays,
        departureDate:
        widget.trip.departureDate,
      );

      if (!mounted) return;

      // Prevent generated items from duplicating existing manual items.
      final Set<String> existingNames =
      _packingItems
          .map(
            (item) =>
            _normalizeItemName(
              item.name,
            ),
      )
          .toSet();

      final Set<String>
      generatedNames = {};

      final List<PackingItem>
      packingItems = [];

      for (final Map<String, dynamic>
      item in generatedItems) {
        final String name =
        item['name']
            .toString()
            .trim();

        final String normalizedName =
        _normalizeItemName(name);

        if (name.isEmpty) {
          continue;
        }

        // Skip an item already in the traveller's list.
        if (existingNames.contains(
          normalizedName,
        )) {
          continue;
        }

        // Skip duplicate names returned by the generation service.
        if (generatedNames.contains(
          normalizedName,
        )) {
          continue;
        }

        generatedNames.add(
          normalizedName,
        );

        packingItems.add(
          PackingItem(
            id: '',
            name: name,
            category:
            item['category']
                .toString(),
            quantity:
            item['quantity'] as int,
            packed: false,
            source: 'ai',
          ),
        );
      }

      if (packingItems.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'No new recommendations were added because '
                    'the suggested items are already in the '
                    'packing list.',
              ),
            ),
          );

        return;
      }

      await _packingService
          .addGeneratedPackingItems(
        tripId: widget.trip.id,
        items: packingItems,
      );

      if (!mounted) return;

      await _loadPackingItems(
        showLoading: false,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${packingItems.length} contextual packing '
                  'recommendations were added.',
            ),
          ),
        );
    } catch (e) {
      debugPrint(
        'AI PACKING GENERATION ERROR: $e',
      );

      if (!mounted) return;

      final String errorText =
      e.toString().toLowerCase();

      final bool
      isTemporaryGeminiError =
          errorText.contains('503') ||
              errorText.contains(
                'temporarily busy',
              ) ||
              errorText.contains(
                'high demand',
              ) ||
              errorText.contains(
                'unavailable',
              );

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isTemporaryGeminiError
                  ? 'The packing recommendation service '
                  'is temporarily busy. Please wait '
                  'a moment and try again.'
                  : 'Unable to generate packing '
                  'recommendations. Please try again.',
            ),
          ),
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

  Future<void> _updatePackedStatus(
      PackingItem item,
      bool packed,
      ) async {
    if (_updatingItems.contains(
      item.id,
    )) {
      return;
    }

    final int itemIndex =
    _packingItems.indexWhere(
          (value) => value.id == item.id,
    );

    if (itemIndex == -1) {
      return;
    }

    final bool previousValue =
        item.packed;

    setState(() {
      _updatingItems.add(
        item.id,
      );

      _packingItems[itemIndex] =
          item.copyWith(
            packed: packed,
          );
    });

    try {
      await _packingService
          .updatePackedStatus(
        tripId: widget.trip.id,
        itemId: item.id,
        packed: packed,
      );
    } catch (e) {
      debugPrint(
        'PACKING STATUS ERROR: $e',
      );

      if (!mounted) return;

      final int currentIndex =
      _packingItems.indexWhere(
            (value) =>
        value.id == item.id,
      );

      if (currentIndex != -1) {
        setState(() {
          _packingItems[currentIndex] =
              _packingItems[
              currentIndex]
                  .copyWith(
                packed: previousValue,
              );
        });
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update the packing item.',
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

  // ---------------------------------------------------------------------------
  // ADD ITEM
  // ---------------------------------------------------------------------------

  Future<void>
  _showAddItemDialog()
  async {
    String itemName = '';
    String quantityText = '1';

    String selectedCategory =
        'generalEssentials';

    bool isSaving = false;

    String? dialogError;

    PackingItem?
    duplicateItemToEdit;

    final PackingItem? addedItem =
    await showDialog<PackingItem>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder:
              (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Add Packing Item',
              ),
              content:
              SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    TextFormField(
                      autofocus: true,
                      initialValue:
                      itemName,
                      textCapitalization:
                      TextCapitalization
                          .sentences,
                      decoration:
                      InputDecoration(
                        labelText:
                        'Item name',
                        hintText:
                        'e.g. Water bottle',
                        prefixIcon:
                        const Icon(
                          Icons
                              .inventory_2_outlined,
                        ),
                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            12,
                          ),
                        ),
                      ),
                      onChanged:
                          (value) {
                        itemName =
                            value;
                      },
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    DropdownButtonFormField<
                        String>(
                      initialValue:
                      selectedCategory,
                      isExpanded: true,
                      decoration:
                      InputDecoration(
                        labelText:
                        'Category',
                        prefixIcon:
                        const Icon(
                          Icons
                              .category_outlined,
                        ),
                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            12,
                          ),
                        ),
                      ),
                      items: _categories
                          .map(
                            (category) {
                          return DropdownMenuItem<
                              String>(
                            value:
                            category,
                            child: Text(
                              _categoryLabel(
                                category,
                              ),
                            ),
                          );
                        },
                      ).toList(),
                      onChanged: isSaving
                          ? null
                          : (value) {
                        if (value ==
                            null) {
                          return;
                        }

                        selectedCategory =
                            value;
                      },
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    TextFormField(
                      initialValue:
                      quantityText,
                      keyboardType:
                      TextInputType
                          .number,
                      inputFormatters: [
                        FilteringTextInputFormatter
                            .digitsOnly,
                      ],
                      decoration:
                      InputDecoration(
                        labelText:
                        'Quantity',
                        prefixIcon:
                        const Icon(
                          Icons
                              .numbers_rounded,
                        ),
                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            12,
                          ),
                        ),
                      ),
                      onChanged:
                          (value) {
                        quantityText =
                            value;
                      },
                    ),

                    if (dialogError !=
                        null) ...[
                      const SizedBox(
                        height: 12,
                      ),
                      Align(
                        alignment:
                        Alignment
                            .centerLeft,
                        child: Text(
                          dialogError!,
                          style:
                          TextStyle(
                            color: Theme.of(
                              context,
                            )
                                .colorScheme
                                .error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text(
                    'Cancel',
                  ),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                    final String
                    name =
                    itemName
                        .trim();

                    final int?
                    quantity =
                    int.tryParse(
                      quantityText
                          .trim(),
                    );

                    if (name
                        .isEmpty ||
                        quantity ==
                            null ||
                        quantity <
                            1) {
                      setDialogState(
                            () {
                          dialogError =
                          'Enter a valid item name and quantity.';
                        },
                      );

                      return;
                    }

                    final PackingItem?
                    existingItem =
                    _findDuplicatePackingItem(
                      name,
                    );

                    if (existingItem !=
                        null) {
                      final bool
                      editExisting =
                      await _showDuplicatePackingItemDialog(
                        existingItem,
                      );

                      if (!dialogContext
                          .mounted) {
                        return;
                      }

                      if (editExisting) {
                        duplicateItemToEdit =
                            existingItem;

                        Navigator.pop(
                          dialogContext,
                        );
                      }

                      return;
                    }

                    setDialogState(
                          () {
                        isSaving =
                        true;

                        dialogError =
                        null;
                      },
                    );

                    try {
                      final String
                      itemId =
                      await _packingService
                          .addPackingItem(
                        tripId: widget
                            .trip.id,
                        name: name,
                        category:
                        selectedCategory,
                        quantity:
                        quantity,
                      );

                      if (!dialogContext
                          .mounted) {
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                        PackingItem(
                          id:
                          itemId,
                          name:
                          name,
                          category:
                          selectedCategory,
                          quantity:
                          quantity,
                          packed:
                          false,
                          source:
                          'user',
                        ),
                      );
                    } catch (e) {
                      debugPrint(
                        'PACKING ADD ERROR: $e',
                      );

                      if (!dialogContext
                          .mounted) {
                        return;
                      }

                      setDialogState(
                            () {
                          isSaving =
                          false;

                          dialogError =
                          'Unable to add the packing item.';
                        },
                      );
                    }
                  },
                  child: isSaving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2,
                    ),
                  )
                      : const Text(
                    'Add',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (duplicateItemToEdit !=
        null) {
      await _showEditItemDialog(
        duplicateItemToEdit!,
      );

      return;
    }

    if (addedItem == null) {
      return;
    }

    setState(() {
      _packingItems.add(
        addedItem,
      );

      _sortPackingItems();
    });
  }

  // ---------------------------------------------------------------------------
  // EDIT ITEM
  // ---------------------------------------------------------------------------

  Future<void>
  _showEditItemDialog(
      PackingItem item,
      ) async {
    String itemName = item.name;

    String quantityText =
    item.quantity.toString();

    String selectedCategory =
        item.category;

    bool isSaving = false;

    String? dialogError;

    final PackingItem? editedItem =
    await showDialog<PackingItem>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder:
              (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Edit Packing Item',
              ),
              content:
              SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue:
                      itemName,
                      textCapitalization:
                      TextCapitalization
                          .sentences,
                      decoration:
                      InputDecoration(
                        labelText:
                        'Item name',
                        prefixIcon:
                        const Icon(
                          Icons
                              .inventory_2_outlined,
                        ),
                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            12,
                          ),
                        ),
                      ),
                      onChanged:
                          (value) {
                        itemName =
                            value;
                      },
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    DropdownButtonFormField<
                        String>(
                      initialValue:
                      selectedCategory,
                      isExpanded: true,
                      decoration:
                      InputDecoration(
                        labelText:
                        'Category',
                        prefixIcon:
                        const Icon(
                          Icons
                              .category_outlined,
                        ),
                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            12,
                          ),
                        ),
                      ),
                      items: _categories
                          .map(
                            (category) {
                          return DropdownMenuItem<
                              String>(
                            value:
                            category,
                            child: Text(
                              _categoryLabel(
                                category,
                              ),
                            ),
                          );
                        },
                      ).toList(),
                      onChanged: isSaving
                          ? null
                          : (value) {
                        if (value ==
                            null) {
                          return;
                        }

                        selectedCategory =
                            value;
                      },
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    TextFormField(
                      initialValue:
                      quantityText,
                      keyboardType:
                      TextInputType
                          .number,
                      inputFormatters: [
                        FilteringTextInputFormatter
                            .digitsOnly,
                      ],
                      decoration:
                      InputDecoration(
                        labelText:
                        'Quantity',
                        prefixIcon:
                        const Icon(
                          Icons
                              .numbers_rounded,
                        ),
                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            12,
                          ),
                        ),
                      ),
                      onChanged:
                          (value) {
                        quantityText =
                            value;
                      },
                    ),

                    if (dialogError !=
                        null) ...[
                      const SizedBox(
                        height: 12,
                      ),
                      Align(
                        alignment:
                        Alignment
                            .centerLeft,
                        child: Text(
                          dialogError!,
                          style:
                          TextStyle(
                            color: Theme.of(
                              context,
                            )
                                .colorScheme
                                .error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text(
                    'Cancel',
                  ),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                    final String
                    name =
                    itemName
                        .trim();

                    final int?
                    quantity =
                    int.tryParse(
                      quantityText
                          .trim(),
                    );

                    if (name
                        .isEmpty ||
                        quantity ==
                            null ||
                        quantity <
                            1) {
                      setDialogState(
                            () {
                          dialogError =
                          'Enter a valid item name and quantity.';
                        },
                      );

                      return;
                    }

                    final PackingItem?
                    duplicateItem =
                    _findDuplicatePackingItem(
                      name,
                      excludeItemId:
                      item.id,
                    );

                    if (duplicateItem !=
                        null) {
                      setDialogState(
                            () {
                          dialogError =
                          '"${duplicateItem.name}" is already '
                              'in the packing list.';
                        },
                      );

                      return;
                    }

                    setDialogState(
                          () {
                        isSaving =
                        true;

                        dialogError =
                        null;
                      },
                    );

                    try {
                      await _packingService
                          .updatePackingItem(
                        tripId: widget
                            .trip.id,
                        itemId:
                        item.id,
                        name: name,
                        category:
                        selectedCategory,
                        quantity:
                        quantity,
                      );

                      if (!dialogContext
                          .mounted) {
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                        item.copyWith(
                          name:
                          name,
                          category:
                          selectedCategory,
                          quantity:
                          quantity,
                        ),
                      );
                    } catch (e) {
                      debugPrint(
                        'PACKING EDIT ERROR: $e',
                      );

                      if (!dialogContext
                          .mounted) {
                        return;
                      }

                      setDialogState(
                            () {
                          isSaving =
                          false;

                          dialogError =
                          'Unable to update the packing item.';
                        },
                      );
                    }
                  },
                  child: isSaving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2,
                    ),
                  )
                      : const Text(
                    'Save',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (editedItem == null ||
        !mounted) {
      return;
    }

    final int index =
    _packingItems.indexWhere(
          (value) =>
      value.id == editedItem.id,
    );

    if (index == -1) {
      return;
    }

    setState(() {
      _packingItems[index] =
          editedItem;

      _sortPackingItems();
    });
  }

  // ---------------------------------------------------------------------------
  // DELETE ITEM
  // ---------------------------------------------------------------------------

  Future<void> _confirmDelete(
      PackingItem item,
      ) async {
    final bool? confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Color(0xFFC62828),
            size: 30,
          ),
          title: const Text(
            'Delete Packing Item',
            textAlign: TextAlign.center,
          ),
          content: Text(
            'Remove "${item.name}" from '
                'the packing list?',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
              const Text('Cancel'),
            ),
            FilledButton(
              style:
              FilledButton.styleFrom(
                backgroundColor:
                const Color(
                  0xFFC62828,
                ),
                foregroundColor:
                Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
              const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    setState(() {
      _packingItems.removeWhere(
            (value) =>
        value.id == item.id,
      );
    });

    try {
      await _packingService
          .deletePackingItem(
        tripId: widget.trip.id,
        itemId: item.id,
      );
    } catch (e) {
      debugPrint(
        'PACKING DELETE ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _packingItems.add(
          item,
        );

        _sortPackingItems();
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to delete the packing item.',
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      _backgroundColor,

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Packing List',
          style: TextStyle(
            color: _darkTextColor,
            fontWeight:
            FontWeight.w700,
          ),
        ),
      ),

      floatingActionButton:
      FloatingActionButton.extended(
        backgroundColor:
        _primaryColor,
        foregroundColor:
        Colors.white,
        onPressed:
        _showAddItemDialog,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Add Item',
          style: TextStyle(
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
    if (_isLoading) {
      return const Center(
        child:
        CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_packingItems.isEmpty) {
      return _buildEmptyState();
    }

    final List<String>
    visibleCategories =
    _categories
        .where(
          (category) =>
          _packingItems.any(
                (item) =>
            item.category ==
                category,
          ),
    )
        .toList();

    return RefreshIndicator(
      onRefresh: () =>
          _loadPackingItems(
            showLoading: false,
          ),
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding:
        const EdgeInsets.fromLTRB(
          16,
          18,
          16,
          110,
        ),
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
                    fontWeight:
                    FontWeight.w800,
                    color:
                    _darkTextColor,
                  ),
                ),
              ),

              Text(
                '${_packingItems.length} items',
                style: const TextStyle(
                  fontSize: 12,
                  color:
                  Colors.black54,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          for (final String category
          in visibleCategories) ...[
            _buildCategoryHeader(
              category,
            ),

            const SizedBox(height: 9),

            ..._packingItems
                .where(
                  (item) =>
              item.category ==
                  category,
            )
                .map(
                  (item) =>
                  _buildPackingItemCard(
                    item,
                  ),
            ),

            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return RefreshIndicator(
      onRefresh: () =>
          _loadPackingItems(
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
            'Unable to load packing list',
            textAlign:
            TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight:
              FontWeight.w700,
              color:
              _darkTextColor,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _errorMessage!,
            textAlign:
            TextAlign.center,
            style: const TextStyle(
              color:
              Colors.black54,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Pull down to try again.',
            textAlign:
            TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color:
              Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: () =>
          _loadPackingItems(
            showLoading: false,
          ),
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding:
        const EdgeInsets.fromLTRB(
          24,
          50,
          24,
          110,
        ),
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color:
                const Color(
                  0xFFE8F6F7,
                ),
                borderRadius:
                BorderRadius.circular(
                  24,
                ),
              ),
              child: const Icon(
                Icons.luggage_outlined,
                size: 42,
                color:
                _primaryColor,
              ),
            ),
          ),

          const SizedBox(height: 22),

          const Text(
            'Start Your Packing List',
            textAlign:
            TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight:
              FontWeight.w800,
              color:
              _darkTextColor,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Add items manually or generate contextual '
                'packing recommendations based on this trip.',
            textAlign:
            TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color:
              Colors.black54,
            ),
          ),

          const SizedBox(height: 26),

          _buildRecommendationCard(),

          const SizedBox(height: 18),

          SizedBox(
            height: 50,
            child:
            OutlinedButton.icon(
              style:
              OutlinedButton.styleFrom(
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
                    14,
                  ),
                ),
              ),
              onPressed:
              _showAddItemDialog,
              icon: const Icon(
                Icons.add_rounded,
              ),
              label: const Text(
                'Add Item Manually',
                style: TextStyle(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripSummary() {
    return Container(
      width: double.infinity,
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color:
              const Color(
                0xFFE8F6F7,
              ),
              borderRadius:
              BorderRadius.circular(
                14,
              ),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color:
              _primaryColor,
              size: 26,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  _formatText(
                    widget.trip
                        .destinationCountryId,
                  ),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight:
                    FontWeight.w800,
                    color:
                    _darkTextColor,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  '${_formatText(widget.trip.purpose)}'
                      ' • '
                      '${widget.trip.durationDays} days',
                  style:
                  const TextStyle(
                    fontSize: 12.5,
                    color:
                    Colors.black54,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  'Departure: '
                      '${_formatDate(widget.trip.departureDate)}',
                  style:
                  const TextStyle(
                    fontSize: 11.5,
                    color:
                    Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(18),
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
          const Color(
            0xFFCBE8EB,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
            children: [
              const Text(
                'Packing Progress',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight:
                  FontWeight.w800,
                  color:
                  _darkTextColor,
                ),
              ),

              Text(
                '$_packingPercentage%',
                style:
                const TextStyle(
                  fontSize: 20,
                  fontWeight:
                  FontWeight.w800,
                  color:
                  _primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          ClipRRect(
            borderRadius:
            BorderRadius.circular(
              20,
            ),
            child:
            LinearProgressIndicator(
              value:
              _packingProgress,
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
                  '$_packedCount of '
                      '${_packingItems.length} packed',
                  style:
                  const TextStyle(
                    fontSize: 12.5,
                    color:
                    Colors.black54,
                  ),
                ),
              ),

              if (_remainingCount > 0)
                Text(
                  '$_remainingCount remaining',
                  style:
                  const TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w600,
                    color: Color(
                      0xFF9B5713,
                    ),
                  ),
                )
              else
                const Text(
                  'All packed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w700,
                    color: Color(
                      0xFF177245,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard() {
    final bool alreadyGenerated =
        _hasAiGeneratedItems;

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: const [
          BoxShadow(
            color:
            Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color:
                  const Color(
                    0xFFE8F6F7,
                  ),
                  borderRadius:
                  BorderRadius
                      .circular(
                    14,
                  ),
                ),
                child: Icon(
                  alreadyGenerated
                      ? Icons
                      .check_circle_outline_rounded
                      : Icons
                      .auto_awesome_outlined,
                  color:
                  _primaryColor,
                  size: 24,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    const Text(
                      'Contextual Packing Recommendations',
                      style:
                      TextStyle(
                        fontSize: 15.5,
                        fontWeight:
                        FontWeight
                            .w800,
                        color:
                        _darkTextColor,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      alreadyGenerated
                          ? 'Recommendations have been added to this packing list.'
                          : 'Personalised using your destination, purpose, duration and departure date.',
                      style:
                      const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color:
                        Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          if (!alreadyGenerated)
            SizedBox(
              width: double.infinity,
              height: 48,
              child:
              FilledButton.icon(
                style:
                FilledButton
                    .styleFrom(
                  backgroundColor:
                  _primaryColor,
                  foregroundColor:
                  Colors.white,
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius
                        .circular(
                      13,
                    ),
                  ),
                ),
                onPressed:
                _isGeneratingAi
                    ? null
                    : _generateAiPackingList,
                icon:
                _isGeneratingAi
                    ? const SizedBox(
                  width:
                  18,
                  height:
                  18,
                  child:
                  CircularProgressIndicator(
                    strokeWidth:
                    2,
                    color:
                    Colors.white,
                  ),
                )
                    : const Icon(
                  Icons
                      .auto_awesome_outlined,
                ),
                label: Text(
                  _isGeneratingAi
                      ? 'Generating Recommendations...'
                      : 'Generate Recommendations',
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight
                        .w700,
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFFEAF7F1,
                ),
                borderRadius:
                BorderRadius
                    .circular(
                  12,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons
                        .check_circle_outline_rounded,
                    size: 19,
                    color:
                    Color(
                      0xFF177245,
                    ),
                  ),

                  SizedBox(width: 9),

                  Expanded(
                    child: Text(
                      'Contextual recommendations added',
                      style:
                      TextStyle(
                        fontSize:
                        12.5,
                        fontWeight:
                        FontWeight
                            .w600,
                        color:
                        Color(
                          0xFF177245,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          const Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 17,
                color:
                Colors.black45,
              ),

              SizedBox(width: 7),

              Expanded(
                child: Text(
                  'Packing recommendations are supplementary '
                      'and do not replace your regulatory travel '
                      'requirements.',
                  style:
                  TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color:
                    Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(
      String category,
      ) {
    final int count =
        _packingItems
            .where(
              (item) =>
          item.category ==
              category,
        )
            .length;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color:
            const Color(
              0xFFE8F6F7,
            ),
            borderRadius:
            BorderRadius.circular(
              10,
            ),
          ),
          child: Icon(
            _categoryIcon(
              category,
            ),
            size: 18,
            color:
            _primaryColor,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            _categoryLabel(
              category,
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight:
              FontWeight.w800,
              color:
              _darkTextColor,
            ),
          ),
        ),

        Container(
          padding:
          const EdgeInsets
              .symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color:
            const Color(
              0xFFF0F4F6,
            ),
            borderRadius:
            BorderRadius.circular(
              20,
            ),
          ),
          child: Text(
            '$count',
            style:
            const TextStyle(
              fontSize: 11,
              fontWeight:
              FontWeight.w700,
              color:
              Color(
                0xFF627D98,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPackingItemCard(
      PackingItem item,
      ) {
    final bool isUpdating =
    _updatingItems.contains(
      item.id,
    );

    final bool isRecommendation =
        item.source == 'ai';

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color: item.packed
              ? const Color(
            0xFFB9E2D0,
          )
              : _borderColor,
        ),
      ),
      child: Padding(
        padding:
        const EdgeInsets.fromLTRB(
          10,
          9,
          6,
          9,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: Checkbox(
                value: item.packed,
                activeColor:
                _primaryColor,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                    5,
                  ),
                ),
                onChanged: isUpdating
                    ? null
                    : (value) {
                  if (value ==
                      null) {
                    return;
                  }

                  _updatePackedStatus(
                    item,
                    value,
                  );
                },
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight:
                      FontWeight.w700,
                      color:
                      _darkTextColor,
                      decoration:
                      item.packed
                          ? TextDecoration
                          .lineThrough
                          : null,
                      decorationColor:
                      Colors.black45,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    crossAxisAlignment:
                    WrapCrossAlignment
                        .center,
                    children: [
                      Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration:
                        BoxDecoration(
                          color:
                          const Color(
                            0xFFF0F4F6,
                          ),
                          borderRadius:
                          BorderRadius
                              .circular(
                            20,
                          ),
                        ),
                        child: Text(
                          'Qty ${item.quantity}',
                          style:
                          const TextStyle(
                            fontSize:
                            10.5,
                            fontWeight:
                            FontWeight
                                .w600,
                            color:
                            Color(
                              0xFF486581,
                            ),
                          ),
                        ),
                      ),

                      Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration:
                        BoxDecoration(
                          color: isRecommendation
                              ? const Color(
                            0xFFE8F6F7,
                          )
                              : const Color(
                            0xFFF4F1FA,
                          ),
                          borderRadius:
                          BorderRadius
                              .circular(
                            20,
                          ),
                        ),
                        child: Text(
                          isRecommendation
                              ? 'Recommended'
                              : 'Manual',
                          style:
                          TextStyle(
                            fontSize:
                            10.5,
                            fontWeight:
                            FontWeight
                                .w600,
                            color: isRecommendation
                                ? _primaryColor
                                : const Color(
                              0xFF654C87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (isUpdating)
              const Padding(
                padding:
                EdgeInsets.all(
                  12,
                ),
                child: SizedBox(
                  width: 19,
                  height: 19,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              PopupMenuButton<String>(
                tooltip:
                'Item options',
                onSelected:
                    (value) {
                  if (value ==
                      'edit') {
                    _showEditItemDialog(
                      item,
                    );
                  }

                  if (value ==
                      'delete') {
                    _confirmDelete(
                      item,
                    );
                  }
                },
                itemBuilder:
                    (context) {
                  return const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .edit_outlined,
                          ),
                          SizedBox(
                            width:
                            10,
                          ),
                          Text(
                            'Edit',
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value:
                      'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .delete_outline,
                            color:
                            Color(
                              0xFFC62828,
                            ),
                          ),
                          SizedBox(
                            width:
                            10,
                          ),
                          Text(
                            'Delete',
                            style:
                            TextStyle(
                              color:
                              Color(
                                0xFFC62828,
                              ),
                            ),
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
}