import 'package:flutter/material.dart';

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

  // Loads the saved packing list for this trip.
  Future<void> _loadPackingItems() async {
    try {
      final List<PackingItem> items =
      await _packingService.getPackingItems(
        widget.trip.id,
      );

      if (!mounted) return;

      setState(() {
        _packingItems = items;
        _isLoading = false;
        _errorMessage = null;
        _sortPackingItems();
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

  String _normalizeItemName(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  PackingItem? _findDuplicatePackingItem(
      String name, {
        String? excludeItemId,
      }) {
    final String normalizedName =
    _normalizeItemName(name);

    for (final PackingItem item in _packingItems) {
      if (excludeItemId != null &&
          item.id == excludeItemId) {
        continue;
      }

      if (_normalizeItemName(item.name) ==
          normalizedName) {
        return item;
      }
    }

    return null;
  }

  Future<bool> _showDuplicatePackingItemDialog(
      PackingItem existingItem,
      ) async {
    final bool? editExisting =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Item Already Exists',
          ),
          content: Text(
            '"${existingItem.name}" is already in your '
                'packing list.\n\n'
                'You can edit the existing item if you '
                'want to change its quantity or category.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
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

  void _sortPackingItems() {
    _packingItems.sort((a, b) {
      final int categoryA =
          _categoryOrder[a.category] ?? 99;

      final int categoryB =
          _categoryOrder[b.category] ?? 99;

      final int categoryComparison =
      categoryA.compareTo(categoryB);

      if (categoryComparison != 0) {
        return categoryComparison;
      }

      return a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      );
    });
  }

  int get _packedCount {
    return _packingItems
        .where((item) => item.packed)
        .length;
  }

  double get _packingProgress {
    if (_packingItems.isEmpty) {
      return 0;
    }

    return _packedCount / _packingItems.length;
  }

  bool get _hasAiGeneratedItems {
    return _packingItems.any(
          (item) => item.source == 'ai',
    );
  }

  // Generates contextual packing suggestions using Gemini.
  Future<void> _generateAiPackingList() async {
    if (_isGeneratingAi || _hasAiGeneratedItems) {
      return;
    }

    setState(() {
      _isGeneratingAi = true;
    });

    try {
      final List<Map<String, dynamic>> generatedItems =
      await _packingAiService.generatePackingItems(
        destination: widget.trip.destinationCountryId,
        purpose: widget.trip.purpose,
        durationDays: widget.trip.durationDays,
        departureDate: widget.trip.departureDate,
      );

      if (!mounted) return;

      // Prevent Gemini items from duplicating existing manual items.
      final Set<String> existingNames =
      _packingItems
          .map(
            (item) =>
            _normalizeItemName(item.name),
      )
          .toSet();

      final Set<String> generatedNames = {};

      final List<PackingItem> packingItems = [];

      for (final Map<String, dynamic> item
      in generatedItems) {
        final String name =
        item['name'].toString().trim();

        final String normalizedName =
        _normalizeItemName(name);

        if (name.isEmpty) {
          continue;
        }

        // Skip an item already in the traveller's list.
        if (existingNames.contains(normalizedName)) {
          continue;
        }

        // Skip duplicate names returned by Gemini.
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No new Gemini suggestions were found because the recommended items are already in the packing list.',
            ),
          ),
        );

        return;
      }

      await _packingService.addGeneratedPackingItems(
        tripId: widget.trip.id,
        items: packingItems,
      );

      if (!mounted) return;

      await _loadPackingItems();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${packingItems.length} personalised packing suggestions were added.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('AI PACKING GENERATION ERROR: $e');

      if (!mounted) return;

      final String errorText =
      e.toString().toLowerCase();

      final bool isTemporaryGeminiError =
          errorText.contains('503') ||
              errorText.contains('temporarily busy') ||
              errorText.contains('high demand') ||
              errorText.contains('unavailable');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTemporaryGeminiError
                ? 'Gemini is temporarily busy. Please wait a moment and try again.'
                : 'Unable to generate the packing list. Please try again.',
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

  // Updates the UI immediately while saving the new status to Firestore.
  Future<void> _updatePackedStatus(
      PackingItem item,
      bool packed,
      ) async {
    if (_updatingItems.contains(item.id)) return;

    final int itemIndex =
    _packingItems.indexWhere(
          (value) => value.id == item.id,
    );

    if (itemIndex == -1) return;

    final bool previousValue = item.packed;

    setState(() {
      _updatingItems.add(item.id);

      _packingItems[itemIndex] = item.copyWith(
        packed: packed,
      );
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

      final int currentIndex =
      _packingItems.indexWhere(
            (value) => value.id == item.id,
      );

      if (currentIndex != -1) {
        setState(() {
          _packingItems[currentIndex] =
              _packingItems[currentIndex].copyWith(
                packed: previousValue,
              );
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update the packing item.',
          ),
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

  Future<void> _showAddItemDialog() async {
    String itemName = '';
    String quantityText = '1';
    String selectedCategory = 'generalEssentials';

    bool isSaving = false;
    String? dialogError;
    PackingItem? duplicateItemToEdit;

    final PackingItem? addedItem =
    await showDialog<PackingItem>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Packing Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: itemName,
                      decoration: const InputDecoration(
                        labelText: 'Item name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        itemName = value;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(
                            _categoryLabel(category),
                          ),
                        );
                      }).toList(),
                      onChanged: isSaving
                          ? null
                          : (value) {
                        if (value == null) return;

                        selectedCategory = value;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: quantityText,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        quantityText = value;
                      },
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogError!,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .error,
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
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                    final String name =
                    itemName.trim();

                    final int? quantity =
                    int.tryParse(
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
                    _findDuplicatePackingItem(
                      name,
                    );

                    if (existingItem != null) {
                      final bool editExisting =
                      await _showDuplicatePackingItemDialog(
                        existingItem,
                      );

                      if (!dialogContext.mounted) {
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

                    setDialogState(() {
                      isSaving = true;
                      dialogError = null;
                    });

                    try {
                      final String itemId =
                      await _packingService
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
                      debugPrint(
                        'PACKING ADD ERROR: $e',
                      );

                      if (!dialogContext.mounted) {
                        return;
                      }

                      setDialogState(() {
                        isSaving = false;
                        dialogError =
                        'Unable to add the packing item.';
                      });
                    }
                  },
                  child: isSaving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
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
      await _showEditItemDialog(
        duplicateItemToEdit!,
      );
      return;
    }

    if (addedItem == null) return;

    setState(() {
      _packingItems.add(addedItem);
      _sortPackingItems();
    });
  }

  Future<void> _showEditItemDialog(
      PackingItem item,
      ) async {
    String itemName = item.name;
    String quantityText = item.quantity.toString();
    String selectedCategory = item.category;

    bool isSaving = false;
    String? dialogError;

    final PackingItem? editedItem =
    await showDialog<PackingItem>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Packing Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: itemName,
                      decoration: const InputDecoration(
                        labelText: 'Item name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        itemName = value;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(
                            _categoryLabel(category),
                          ),
                        );
                      }).toList(),
                      onChanged: isSaving
                          ? null
                          : (value) {
                        if (value == null) return;

                        selectedCategory = value;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: quantityText,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        quantityText = value;
                      },
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogError!,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .error,
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
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                    final String name =
                    itemName.trim();

                    final int? quantity =
                    int.tryParse(
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
                      await _packingService
                          .updatePackingItem(
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
                      debugPrint(
                        'PACKING EDIT ERROR: $e',
                      );

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

    if (editedItem == null || !mounted) return;

    final int index =
    _packingItems.indexWhere(
          (value) => value.id == editedItem.id,
    );

    if (index == -1) return;

    setState(() {
      _packingItems[index] = editedItem;
      _sortPackingItems();
    });
  }

  Future<void> _confirmDelete(
      PackingItem item,
      ) async {
    final bool? confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Packing Item'),
          content: Text(
            'Remove "${item.name}" from the packing list?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _packingItems.removeWhere(
            (value) => value.id == item.id,
      );
    });

    try {
      await _packingService.deletePackingItem(
        tripId: widget.trip.id,
        itemId: item.id,
      );
    } catch (e) {
      debugPrint('PACKING DELETE ERROR: $e');

      if (!mounted) return;

      setState(() {
        _packingItems.add(item);
        _sortPackingItems();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to delete the packing item.',
          ),
        ),
      );
    }
  }

  Widget _buildGeminiGenerationSection({
    required bool hasExistingItems,
  }) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: _isGeneratingAi
              ? null
              : _generateAiPackingList,
          icon: _isGeneratingAi
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          )
              : const Icon(
            Icons.auto_awesome,
          ),
          label: Text(
            _isGeneratingAi
                ? 'Generating...'
                : 'Generate with Gemini',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          hasExistingItems
              ? 'Gemini will add personalised suggestions to the existing packing list without removing manually added items.'
              : 'Generate personalised suggestions using the destination, travel purpose, duration and departure date.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'AI-assisted packing suggestions are supplementary and do not replace the regulatory travel checklist.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Packing List'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
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
        onRefresh: _loadPackingItems,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 180),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_packingItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPackingItems,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
          ),
          children: [
            const SizedBox(height: 110),
            const Icon(
              Icons.luggage_outlined,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'No packing items yet.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Build the packing list manually or generate personalised suggestions with Gemini.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            _buildGeminiGenerationSection(
              hasExistingItems: false,
            ),
          ],
        ),
      );
    }

    final List<String> visibleCategories =
    _categories.where((category) {
      return _packingItems.any(
            (item) => item.category == category,
      );
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadPackingItems,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          100,
        ),
        children: [
          if (!_hasAiGeneratedItems) ...[
            _buildGeminiGenerationSection(
              hasExistingItems: true,
            ),
            const SizedBox(height: 24),
          ],
          const Text(
            'Packing Progress',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: _packingProgress,
          ),
          const SizedBox(height: 8),
          Text(
            '$_packedCount of '
                '${_packingItems.length} packed',
          ),
          const SizedBox(height: 24),
          for (final String category
          in visibleCategories) ...[
            Text(
              _categoryLabel(category),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ..._packingItems
                .where(
                  (item) =>
              item.category == category,
            )
                .map(
                  (item) =>
                  _buildPackingItemCard(item),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildPackingItemCard(
      PackingItem item,
      ) {
    final bool isUpdating =
    _updatingItems.contains(item.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Checkbox(
            value: item.packed,
            onChanged: isUpdating
                ? null
                : (value) {
              if (value == null) return;

              _updatePackedStatus(
                item,
                value,
              );
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: item.packed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quantity: ${item.quantity}',
                  ),
                ],
              ),
            ),
          ),
          if (isUpdating)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            )
          else
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditItemDialog(item);
                }

                if (value == 'delete') {
                  _confirmDelete(item);
                }
              },
              itemBuilder: (context) {
                return const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 10),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline),
                        SizedBox(width: 10),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ];
              },
            ),
        ],
      ),
    );
  }
}