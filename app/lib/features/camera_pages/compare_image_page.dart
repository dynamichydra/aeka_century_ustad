import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:century_ai/features/camera_pages/widgets/ImageCompareSlider.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/features/camera_pages/dummy_data.dart';

class CompareImagePage extends StatefulWidget {
  final File originalImage;

  const CompareImagePage({super.key, required this.originalImage});

  @override
  State<CompareImagePage> createState() => _CompareImagePageState();
}

class _CompareImagePageState extends State<CompareImagePage> {
  // Track selected design indices. Original image is always included.
  // Limit designs to 3 (Total 4 including Original).
  final List<int> _selectedIndices = [0]; 
  double _sliderPosition = 0.5;

  // Use the images defined in ProductImages within image_strings.dart
  final List<ProductImageModel> _savedVersions = ProductImages.productImages;

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
                      child: GridView.builder(
                        itemCount: _savedVersions.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                        itemBuilder: (context, index) {
                          final version = _savedVersions[index];
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
                                        child: Image.asset(
                                          version.image,
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

                                // Heart Icon (Top Right)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Icon(
                                    Icons.favorite,
                                    size: 18,
                                    color: index < 3 ? Colors.red : Colors.white70,
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
    final totalItems = 1 + _selectedIndices.length;

    if (_selectedIndices.length == 1) {
      // Single Design Selection -> Slider View (Original vs Selected)
      return Stack(
        children: [
          ImageCompareSlider(
            before: widget.originalImage,
            after: _savedVersions[_selectedIndices[0]].image,
            position: _sliderPosition,
            onChanged: (val) => setState(() => _sliderPosition = val),
          ),
          // ONLY Edit Button in Bottom Right for Slider mode
          Positioned(
            bottom: 24,
            right: 16,
            child: _buildCircleButton(
              icon: Iconsax.edit_2, 
              onTap: () {
                // Return the selected design asset path to the edit page
                context.pop(_savedVersions[_selectedIndices[0]].image);
              },
              size: 20,
              padding: 8,
            ),
          ),
        ],
      );
    } else {
      // Multi Selection -> Grid View
      return GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.0, // Square cells for better button visibility
        ),
        itemCount: totalItems,
        itemBuilder: (context, index) {
          final isOriginal = index == 0;
          final imageUrl = isOriginal ? null : _savedVersions[_selectedIndices[index - 1]].image;
          
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
                  Image.asset(imageUrl!, fit: BoxFit.cover),
                
                  _buildOverlayButtons(
                    bottom: 12, 
                    isGrid: true, 
                    showRemove: !isOriginal, 
                    onRemove: () => _toggleSelection(_selectedIndices[index - 1]),
                    onEdit: () => context.pop(imageUrl),
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
