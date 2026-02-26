import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/features/camera_pages/dummy_data.dart';

class ImageEditPage extends StatefulWidget {
  final File imageFile;
  final Color? pickedColor;

  const ImageEditPage({super.key, required this.imageFile, this.pickedColor});

  @override
  State<ImageEditPage> createState() => _ImageEditPageState();
}

class _ImageEditPageState extends State<ImageEditPage> {
  final TextEditingController _searchController = TextEditingController();
  
  Map<String, dynamic>? _selectedColor;
  String _selectedCategory = "Woodgrains";
  Map<String, dynamic>? _selectedTexture;
  String? _currentAssetPreview; // Track the design selected from comparison

  @override
  void initState() {
    super.initState();
    if (widget.pickedColor != null) {
      _selectedColor = {
        "name": "Picked Color",
        "hex": '#${widget.pickedColor!.value.toRadixString(16).padLeft(8, '0').substring(2)}',
        "id": 999,
      };
    }
  }

  final List<Map<String, dynamic>> featuredColors = [
    {"name": "Yellow/Orange", "hex": "#FFB84D", "id": 101},
    {"name": "Reddish Brown", "hex": "#B36B5E", "id": 102},
    {"name": "Black", "hex": "#000000", "id": 103},
    {"name": "Blue", "hex": "#667EEA", "id": 104},
    {"name": "Brown", "hex": "#6B271E", "id": 105},
  ];

  final List<String> categoriesRow1 = ["Abstract Patterns", "Woodgrains", "Stones", "Solid"];
  final List<String> categoriesRow2 = ["All", "Wallpaper", "Fabric", "Weave", "Artiste Collection", "Herringbone"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Column(
          children: [
            // Top Image Preview Area (matches image_preview_page)
            _buildImageOverlaySection(),

            // Design Tools Section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Iconsax.edit_2, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Edit & Design",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSearchBar(),
                    
                    const SizedBox(height: 20),
                    const Text("Select Color", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    _buildColorSelection(),

                    const SizedBox(height: 20),
                    const Text("Select Categories", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    _buildCategorySelection(),

                    const SizedBox(height: 20),
                    const Text("Select Textures & Patterns", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    _buildTextureSelection(),
                    
                    const SizedBox(height: 80), // Padding for bottom bar
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildImageOverlaySection() {
    return Stack(
      children: [
        if (_currentAssetPreview != null)
          Image.asset(
            _currentAssetPreview!,
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.45,
            fit: BoxFit.cover,
          )
        else
          Image.file(
            widget.imageFile,
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.45,
            fit: BoxFit.cover,
          ),
        
        // Dashed Bounding Boxes (Simulated Positions)
        _buildDashedBox(top: 40, left: 100, width: 80, height: 100),
        _buildDashedBox(top: 150, left: 150, width: 120, height: 80),
        _buildDashedBox(top: 250, left: 50, width: 100, height: 120),
        
        // Hand Icon Instruction Overlay
        Center(
          child: Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.touch_app_outlined, color: Colors.white, size: 36),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "Tap on the object to apply laminates",
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Compare Button (Bottom Right)
        Positioned(
          bottom: 16,
          right: 16,
          child: GestureDetector(
            onTap: () async {
              final result = await context.push("/compare_image", extra: widget.imageFile);
              if (result != null && result is String) {
                setState(() {
                  _currentAssetPreview = result;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Iconsax.copy, color: Colors.black, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashedBox({required double top, required double left, required double width, required double height}) {
    return Positioned(
      top: top,
      left: left,
      child: CustomPaint(
        size: Size(width, height),
        painter: _DashedRectPainter(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Search categories",
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: null,
          suffixIcon: const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Icon(Iconsax.setting_4, color: Colors.grey, size: 20),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildColorSelection() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: featuredColors.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
                    ),
                    child: const Icon(Iconsax.pen_tool, color: Colors.blue),
                  ),
                  const SizedBox(height: 4),
                  const Text("Colour Picker", style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            );
          }
          final colorData = featuredColors[index - 1];
          final isSelected = _selectedColor?["id"] == colorData["id"];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedColor = colorData),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 75,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Color(int.parse(colorData["hex"].replaceFirst('#', '0xFF'))),
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    colorData["name"],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? Colors.black : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      children: [
        _buildChipRow(categoriesRow1),
        const SizedBox(height: 8),
        _buildChipRow(categoriesRow2),
      ],
    );
  }

  Widget _buildChipRow(List<String> labels) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: labels.map((label) {
          final isSelected = _selectedCategory == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.grey[600],
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedCategory = label),
              backgroundColor: Colors.white,
              selectedColor: Colors.white,
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
                side: BorderSide(color: isSelected ? Colors.black87 : Colors.grey[200]!),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextureSelection() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: laminationList.length,
        itemBuilder: (context, index) {
          final texture = laminationList[index];
          final isSelected = _selectedTexture?["id"] == texture["id"];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTexture = texture),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      texture["image"],
                      width: 80,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "1553 MI", // Placeholder ID from design
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.black : Colors.grey,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 80,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: IconButton(
              icon: const Icon(Icons.menu, color: Colors.black),
              onPressed: () {},
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // Navigate to finalize page with the current edited state
                context.push("/image_finalize", extra: {
                  'editedImage': _currentAssetPreview ?? widget.imageFile, 
                  'selectedColor': _selectedColor ?? featuredColors[0],
                  'selectedLamination': _selectedTexture ?? laminationList[0],
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 4,
                side: BorderSide.none,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                "Apply",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 5.0;

    final path = Path();
    
    // Top line
    for (double i = 0; i < size.width; i += dashWidth + dashSpace) {
      path.moveTo(i, 0);
      path.lineTo(i + dashWidth > size.width ? size.width : i + dashWidth, 0);
    }
    
    // Bottom line
    for (double i = 0; i < size.width; i += dashWidth + dashSpace) {
      path.moveTo(i, size.height);
      path.lineTo(i + dashWidth > size.width ? size.width : i + dashWidth, size.height);
    }
    
    // Left line
    for (double i = 0; i < size.height; i += dashWidth + dashSpace) {
      path.moveTo(0, i);
      path.lineTo(0, i + dashWidth > size.height ? size.height : i + dashWidth);
    }
    
    // Right line
    for (double i = 0; i < size.height; i += dashWidth + dashSpace) {
      path.moveTo(size.width, i);
      path.lineTo(size.width, i + dashWidth > size.height ? size.height : i + dashWidth);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}