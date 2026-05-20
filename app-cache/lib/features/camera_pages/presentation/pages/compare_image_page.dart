import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:century_ai/features/camera_pages/presentation/widgets/image_compare_slider.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/features/camera_pages/data/dummy_data.dart';

import 'package:century_ai/db/repositories/edit_history_repository.dart';
import 'package:century_ai/db/models/edit_history_data.dart';

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
  // Track selected design indices. Original image is always included.
  // Limit designs to 3 (Total 4 including Original).
  final List<int> _selectedIndices = [0]; 
  double _sliderPosition = 0.5;

  // Saved versions - initialized as empty since ProductImages is removed
  List<EditHistoryData> _savedVersions = [];
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
        edits = await EditHistoryRepository.getEditsBySessionId(widget.sessionId!);
      } else {
        edits = await EditHistoryRepository.getEditsByFurnitureId(widget.furnitureId!);
      }
      
      setState(() {
        _savedVersions = edits;
        _isLoading = false;
        // Automatically select the first edit if available for comparison
        if (_savedVersions.isNotEmpty && _selectedIndices.length == 1) {
          _selectedIndices.add(1); // Index 0 is Original, so 1 is first edit
        }
      });
    } catch (e) {
      debugPrint("Error loading edit history: $e");
      setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        if (_selectedIndices.length > 1) {
          _selectedIndices.remove(index);
        }
      } else {
        if (_selectedIndices.length < 3) {
          _selectedIndices.add(index);
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
            Expanded(
              flex: 5,
              child: _buildTopComparisonSection(),
            ),

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
                    _selectedIndices.length == 1 ? const SizedBox(height: 12) : const SizedBox(height: 0),
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
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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

                    // Grid of Versions
                    Expanded(
                      child: _isLoading 
                        ? const Center(child: CircularProgressIndicator())
                        : _savedVersions.isEmpty 
                        ? const Center(child: Text("No versions available for comparison"))
                        : GridView.builder(
                          itemCount: _savedVersions.length + 1, // +1 for Original
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.8,
                          ),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              // Original Image Tile
                              final isSelected = _selectedIndices.contains(0);
                              return GestureDetector(
                                onTap: () => _toggleSelection(0),
                                child: Stack(
                                  children: [
                                    Column(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.file(
                                              widget.originalImage,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: Icon(
                                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                        size: 18,
                                        color: isSelected ? Colors.black : Colors.black54,
                                      ),
                                    ),
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
                                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final version = _savedVersions[index - 1];
                            final isSelected = _selectedIndices.contains(index);
                            
                            return GestureDetector(
                              onTap: () => _toggleSelection(index),
                              child: Stack(
                                children: [
                                  Column(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(
                                            File(version.editedImagePath),
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
                                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                      size: 18,
                                      color: isSelected ? Colors.black : Colors.black54,
                                    ),
                                  ),


                                ],
                              ),
                            );
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

  Widget _buildTopComparisonSection() {
    // Total items to compare = Original Image + Selected Designs
    final totalItems = 1 + (_savedVersions.isEmpty ? 0 : _selectedIndices.length);

    if (_selectedIndices.length == 1 && _selectedIndices.contains(0)) {
       return Image.file(widget.originalImage, fit: BoxFit.cover);
    }

    if (_selectedIndices.length == 2 && _selectedIndices.contains(0)) {
      // Single Design Selection vs Original -> Slider View
      final selectedEditIndex = _selectedIndices.firstWhere((i) => i != 0) - 1;
      final selectedEdit = _savedVersions[selectedEditIndex];

      return Stack(
        children: [
          ImageCompareSlider(
            before: widget.originalImage,
            after: selectedEdit.editedImagePath.startsWith('http') 
                ? selectedEdit.editedImagePath 
                : File(selectedEdit.editedImagePath),
            isAfterNetwork: selectedEdit.editedImagePath.startsWith('http'),
            position: _sliderPosition,
            onChanged: (val) => setState(() => _sliderPosition = val),
          ),
          // Edit Button in Bottom Right
          Positioned(
            bottom: 24,
            right: 16,
            child: _buildCircleButton(
              icon: Iconsax.edit_2, 
              onTap: () {
                context.pop(selectedEdit.editedImagePath);
              },
              size: 20,
              padding: 8,
            ),
          ),
        ],
      );
    } else {
      // Multi Selection (could be multiple edits or edit without original) -> Grid View
      return GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _selectedIndices.length > 2 ? 2 : 1,
          childAspectRatio: 1.0,
        ),
        itemCount: _selectedIndices.length,
        itemBuilder: (context, index) {
          final selectedIdx = _selectedIndices[index];
          final isOriginal = selectedIdx == 0;
          final String? imagePath = isOriginal ? null : _savedVersions[selectedIdx - 1].editedImagePath;
          
          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 0.5),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isOriginal)
                  Image.file(widget.originalImage, fit: BoxFit.cover)
                else
                  Image.file(File(imagePath!), fit: BoxFit.cover),
                
                if (!isOriginal)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: _buildCircleButton(
                      icon: Iconsax.edit_2, 
                      onTap: () => context.pop(imagePath),
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
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, size: size, color: Colors.black),
      ),
    );
  }
}
