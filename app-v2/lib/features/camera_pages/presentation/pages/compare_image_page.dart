import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:century_ai/features/camera_pages/presentation/widgets/image_compare_slider.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/features/camera_pages/data/dummy_data.dart';

import 'package:century_ai/db/repositories/edit_history_repository.dart';
import 'package:century_ai/db/models/edit_history_data.dart';

/// A single comparable item — either the original image or an edited version.
class CompareItem {
  final bool isOriginal;
  final File imageFile;
  final EditHistoryData? edit;
  final String label;

  const CompareItem({
    required this.isOriginal,
    required this.imageFile,
    this.edit,
    required this.label,
  });

  /// The path to return when the user taps edit/select on this item.
  String? get editedImagePath => edit?.editedImagePath;

  /// Whether the image is served over network.
  bool get isNetwork => edit != null && edit!.editedImagePath.startsWith('http');
}

class CompareImagePage extends StatefulWidget {
  final File originalImage;
  final String? furnitureId;
  final String? sessionId;

  const CompareImagePage({
    super.key,
    required this.originalImage,
    this.furnitureId,
    this.sessionId,
  });

  @override
  State<CompareImagePage> createState() => _CompareImagePageState();
}

class _CompareImagePageState extends State<CompareImagePage> {
  /// All available items for comparison (Original + all edits).
  List<CompareItem> _allItems = [];

  /// Currently selected items for the top comparison view. Max 4.
  final List<CompareItem> _selectedItems = [];

  double _sliderPosition = 0.5;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadEditHistory();
  }

  Future<void> _loadEditHistory() async {
    if (widget.furnitureId == null && widget.sessionId == null) return;

    setState(() => _isLoading = true);
    try {
      final List<EditHistoryData> edits;
      if (widget.sessionId != null) {
        edits = await EditHistoryRepository.getEditsBySessionId(
          widget.sessionId!,
        );
      } else {
        edits = await EditHistoryRepository.getEditsByFurnitureId(
          widget.furnitureId!,
        );
      }

      setState(() {
        _isLoading = false;
        _buildItemsList(edits);
      });
    } catch (e) {
      debugPrint("Error loading edit history: $e");
      setState(() => _isLoading = false);
    }
  }

  /// Builds the unified _allItems list and sets initial selection.
  void _buildItemsList(List<EditHistoryData> edits) {
    final items = <CompareItem>[];

    // Original is just another item in the list
    items.add(CompareItem(
      isOriginal: true,
      imageFile: widget.originalImage,
      label: "Original",
    ));

    // Add each edit as a CompareItem
    for (final edit in edits) {
      items.add(CompareItem(
        isOriginal: false,
        imageFile: File(edit.editedImagePath),
        edit: edit,
        label: "Edited",
      ));
    }

    _allItems = items;

    // Auto-select: Original + first edit for initial comparison
    _selectedItems.clear();
    if (_allItems.length >= 2) {
      _selectedItems.add(_allItems[0]); // Original
      _selectedItems.add(_allItems[1]); // First edit
    } else if (_allItems.isNotEmpty) {
      _selectedItems.add(_allItems[0]); // Only Original available
    }
  }

  /// Toggle selection of a CompareItem. Max 4 selected, min 1.
  void _toggleSelection(CompareItem item) {
    setState(() {
      if (_selectedItems.contains(item)) {
        if (_selectedItems.length > 1) {
          _selectedItems.remove(item);
        }
      } else {
        if (_selectedItems.length < 4) {
          _selectedItems.add(item);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            /// ---------------- TOP COMPARISON SECTION ----------------
            Expanded(flex: 5, child: _buildTopComparisonSection()),

            /// ---------------- BOTTOM SELECTION SECTION ----------------
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    _selectedItems.length == 1
                        ? const SizedBox(height: 12)
                        : const SizedBox(height: 0),
                    // Header: Compare & Select
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Iconsax.maximize_1, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Select & Compare",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        /*IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down),
                          onPressed: () {},
                        ),*/
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Grid of Versions (bottom gallery)
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _allItems.length <= 1
                          ? const Center(
                              child: Text(
                                "No versions available for comparison",
                              ),
                            )
                          : GridView.builder(
                              itemCount: _allItems.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.8,
                                  ),
                              itemBuilder: (context, index) {
                                final item = _allItems[index];
                                return _buildGalleryTile(item);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a single thumbnail tile in the bottom gallery.
  Widget _buildGalleryTile(CompareItem item) {
    final isSelected = _selectedItems.contains(item);

    return GestureDetector(
      onTap: () => _toggleSelection(item),
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    item.imageFile,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
            ],
          ),
          // Selection Indicator (Top Left)
          Positioned(
            top: 4,
            left: 4,
            child: Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 18,
              color: isSelected ? Colors.black : Colors.black54,
            ),
          ),
          // "Original" label only for the original image
          if (item.isOriginal)
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black45,
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: const Text(
                  "Original",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Top comparison area — layout decided purely by selected count & content.
  Widget _buildTopComparisonSection() {
    final count = _selectedItems.length;

    // Nothing selected
    if (count == 0) {
      return const Center(
        child: Text(
          "Select images to compare",
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
      );
    }

    // Single image selected — show it full
    if (count == 1) {
      final item = _selectedItems[0];
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(item.imageFile, fit: BoxFit.cover),
          if (!item.isOriginal)
            Positioned(
              bottom: 24,
              right: 16,
              child: _buildCircleButton(
                icon: Iconsax.edit_2,
                onTap: () => context.pop(item.editedImagePath),
                size: 20,
                padding: 8,
              ),
            ),
        ],
      );
    }

    // Exactly 2 selected AND one is Original → Slider mode
    if (count == 2 && _selectedItems.any((item) => item.isOriginal)) {
      final originalItem = _selectedItems.firstWhere((item) => item.isOriginal);
      final editItem = _selectedItems.firstWhere((item) => !item.isOriginal);

      return Stack(
        children: [
          ImageCompareSlider(
            before: originalItem.imageFile,
            after: editItem.isNetwork
                ? editItem.editedImagePath!
                : editItem.imageFile,
            isAfterNetwork: editItem.isNetwork,
            position: _sliderPosition,
            onChanged: (val) => setState(() => _sliderPosition = val),
          ),
          Positioned(
            bottom: 24,
            right: 16,
            child: _buildCircleButton(
              icon: Iconsax.edit_2,
              onTap: () {
                context.pop(editItem.editedImagePath);
              },
              size: 20,
              padding: 8,
            ),
          ),
        ],
      );
    }

    // All other cases → Grid comparison
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: count > 2 ? 2 : count,
        childAspectRatio: 1.0,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        final item = _selectedItems[index];

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 0.5),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(item.imageFile, fit: BoxFit.cover),

              if (!item.isOriginal)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: _buildCircleButton(
                    icon: Iconsax.edit_2,
                    onTap: () => context.pop(item.editedImagePath),
                    size: 14,
                    padding: 6,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverlayButtons({
    required double bottom,
    required bool isGrid,
    bool showRemove = false,
    VoidCallback? onRemove,
    VoidCallback? onEdit,
  }) {
    final double iconSize = isGrid ? 16 : 20;
    final double padding = isGrid ? 6 : 8;

    return Positioned(
      bottom: bottom,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Edit Button
          _buildCircleButton(
            icon: Iconsax.edit_2,
            onTap: onEdit ?? () => context.pop(),
            size: iconSize,
            padding: padding,
          ),
          const SizedBox(width: 8),

          // Select Button (Tick)
          _buildCircleButton(
            icon: Iconsax.tick_circle,
            onTap: () {}, // Save selection logic
            size: iconSize,
            padding: padding,
          ),

          if (showRemove) ...[
            const SizedBox(width: 8),
            // Close Button / Cancel
            _buildCircleButton(
              icon: Iconsax.close_circle,
              onTap: onRemove ?? () {},
              size: iconSize,
              padding: padding,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
    required double padding,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: size, color: Colors.black),
      ),
    );
  }
}
