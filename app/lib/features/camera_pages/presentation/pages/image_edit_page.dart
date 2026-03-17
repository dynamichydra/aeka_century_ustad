import 'dart:io';
import 'package:century_ai/db/db_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:century_ai/features/camera_pages/presentation/widgets/image_compare_slider.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/features/camera_pages/data/dummy_data.dart';
import 'package:century_ai/core/network/apis/laminate_api.dart'; // Added API Import
import 'package:century_ai/cubit/image_edit/image_edit_cubit.dart';
import 'package:century_ai/cubit/image_edit/image_edit_state.dart';
import 'package:century_ai/router/app_routes.dart';

class ImageEditPage extends StatefulWidget {
  final File imageFile;
  final Color? pickedColor;

  final bool scrollableEditSection;
  final double textureListHeight;
  final double textureThumbWidth;
  final double textureThumbHeight;

  const ImageEditPage({
    super.key,
    required this.imageFile,
    this.pickedColor,
    this.scrollableEditSection = false,
    this.textureListHeight = 72,
    this.textureThumbWidth = 60,
    this.textureThumbHeight = 40,
  });

  @override
  State<ImageEditPage> createState() => _ImageEditPageState();
}

class _ImageEditPageState extends State<ImageEditPage> {
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic>? _selectedColor;
  String? _selectedCategory = "Abstract Patterns";
  String? _selectedSubCategory = "All";
  List<Map<String, dynamic>> _lamCategories = [];
  Map<String, dynamic>? _selectedTexture;
  String? _currentAssetPreview; // Track the design selected from comparison

  final LaminateService _laminateApi = LaminateService();
  bool _isEditVisible = true;
  bool _isLoadingTextures = false;
  List<dynamic> _apiTextures = [];

  bool _compareExpanded = false;
  bool _editExpanded = true;
  bool _isApplied = false;
  final List<int> _selectedIndices = [0];
  double _sliderPosition = 0.5;
  final List<ProductImageModel> _savedVersions = ProductImages.productImages;

  // Dynamic Tap Variables
  Map<String, dynamic> _lastTapCoordinate = {"x": 423, "y": 12};
  bool _isShortTap = true;
  bool _isLongTap = false;

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        if (_selectedIndices.length > 1) {
          _selectedIndices.remove(index);
        }
      } else {
        if (_selectedIndices.length < 3) {
          _selectedIndices.add(index);

          final selectedImage = _savedVersions[index];
          context.read<ImageEditCubit>().compareImageSelected(selectedImage);
        }
      }
    });
  }

  List<Map<String, dynamic>> _featuredColors = [
    {"name": "Yellow/Orange", "hex": "#FFB84D", "id": 101},
    {"name": "Reddish Brown", "hex": "#B36B5E", "id": 102},
    {"name": "Black", "hex": "#000000", "id": 103},
    {"name": "Blue", "hex": "#667EEA", "id": 104},
    {"name": "Brown", "hex": "#6B271E", "id": 105},
  ];

  @override
  void initState() {
    super.initState();
    getLamCategory();
    if (widget.pickedColor != null) {
      final hex =
          '#${widget.pickedColor!.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      _selectedColor = {"name": "Picked Color", "hex": hex, "id": 999};
      _featuredColors.insert(0, _selectedColor!);
      _fetchTexturesByColor();
    }
  }

  Future<void> _fetchTextures() async {
    if (_selectedCategory == null) return;

    setState(() => _isLoadingTextures = true);

    String subCat =
        (_selectedSubCategory == "All" || _selectedSubCategory == null)
        ? ""
        : _selectedSubCategory!;

    try {
      final response = await _laminateApi.fetchByCategory(
        category: _selectedCategory!,
        subcategory: subCat,
        itemType: "Laminates", // Default itemType, adjust if needed
      );

      if (mounted) {
        setState(() {
          if (response != null &&
              response is Map &&
              response['laminates'] != null) {
            _apiTextures = response['laminates'] as List<dynamic>;
            if (_selectedTexture == null && _apiTextures.isNotEmpty) {
              _selectedTexture = _apiTextures[0];
            }
          } else {
            _apiTextures = [];
          }
          _isLoadingTextures = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching textures: $e");
      if (mounted) {
        setState(() {
          _isLoadingTextures = false;
          _apiTextures = [];
        });
      }
    }
  }

  Future<void> _fetchTexturesByColor() async {
    if (_selectedColor == null) return;

    setState(() => _isLoadingTextures = true);

    try {
      final response = await _laminateApi.fetchByHex(
        hexCodes: [_selectedColor!["hex"]],
        itemType: "Laminates",
      );

      if (mounted) {
        setState(() {
          if (response != null && response is Map && response.isNotEmpty) {
            // Check if it's the category response structure first just in case
            if (response.containsKey('laminates') &&
                response['laminates'] != null) {
              _apiTextures = response['laminates'] as List<dynamic>;
            } else {
              // The response for find-nearest-laminates has the format: {"#FFB84D": [ {...}, {...} ]}
              // We can grab the first value because we only sent one hex code.
              final key = response.keys.first;
              if (response[key] is List) {
                _apiTextures = response[key] as List<dynamic>;
              } else {
                _apiTextures = [];
              }
            }
          } else {
            _apiTextures = [];
          }
          _isLoadingTextures = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching textures by color: $e");
      if (mounted) {
        setState(() {
          _isLoadingTextures = false;
          _apiTextures = [];
        });
      }
    }
  }

  List<String> categoriesRow1 = [""];
  List<String> categoriesRow2 = [""];

  Future<void> getLamCategory() async {
    try {
      final db = await DbHelper.database;
      final result = await db.query("lam_category");

      if (result.isNotEmpty && mounted) {
        setState(() {
          _lamCategories = result;
          categoriesRow1 = result.map((e) => e["name"].toString()).toList();
        });

        if (_selectedCategory != null) {
          await _fetchSubCategoriesFor(_selectedCategory!);
          await _fetchTextures();
        }
      }
    } catch (e) {
      debugPrint("Error fetching lam_category: $e");
    }
  }

  Future<void> _fetchSubCategoriesFor(String categoryName) async {
    // Find matching category map
    final match = _lamCategories.firstWhere(
      (e) => e["name"].toString() == categoryName,
      orElse: () => {},
    );

    final catId = match["id"];

    if (catId != null) {
      await getLamSubCategory(catId);
    } else {
      await getLamSubCategory(); // Fallback incase id is completely missing
    }
  }

  Future<void> getLamSubCategory([dynamic catId]) async {
    try {
      final db = await DbHelper.database;
      List<Map<String, dynamic>> result;

      if (catId != null) {
        result = await db.query(
          "lam_sub_category",
          where: "cat_id = ?",
          whereArgs: [catId],
        );
      } else {
        result = await db.query("lam_sub_category");
      }

      if (mounted) {
        setState(() {
          if (result.isNotEmpty) {
            categoriesRow2 = [
              "All",
              ...result.map((e) => e["name"].toString()),
            ];
          } else {
            categoriesRow2 = [];
            _selectedSubCategory = null;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching lam_sub_category: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ImageEditCubit(),
      child: BlocListener<ImageEditCubit, ImageEditState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F8F8),
          body: SafeArea(
            child: Column(
              children: [
                // Top Image Preview Area (Fixed Height)
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.40,
                  child: _compareExpanded
                      ? _buildTopComparisonSection()
                      : _buildImageOverlaySection(),
                ),

                // Collapsible Headers & Content (Accordion Style)
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      physics: widget.scrollableEditSection
                          ? const AlwaysScrollableScrollPhysics()
                          : (_editExpanded
                                ? const NeverScrollableScrollPhysics()
                                : const AlwaysScrollableScrollPhysics()),
                      child: _buildCollapsibleHeaders(),
                    ),
                  ),
                ),

                // Fixed Bottom Bar/Apply Button Area
                _buildBottomBarFixed(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsibleHeaders() {
    return Column(
      children: [
        if (_isApplied) ...[
          // Compare & select Header
          _buildHeaderTile(
            title: "Compare & select",
            iconImg: "compare.png",
            isActive: _compareExpanded,
            showArrow: _isEditVisible, // No arrow if it's the only header
            onTap: () {
              if (!_isEditVisible) return; // Non-collapsible if only header
              setState(() {
                _compareExpanded = !_compareExpanded;
                _editExpanded = !_compareExpanded;
              });
            },
          ),
          if (_compareExpanded) _buildCompareContent(),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
        ],

        // Edit & Design Header
        if (_isEditVisible) ...[
          _buildHeaderTile(
            title: "Edit & Design",
            iconImg: "edit.png",
            isActive: _editExpanded,
            showArrow: _isApplied,
            onTap: () {
              setState(() {
                _editExpanded = !_editExpanded;
                _compareExpanded = !_editExpanded;
              });
            },
          ),
          if (_editExpanded) _buildEditContent(),
        ],
      ],
    );
  }

  Widget _buildHeaderTile({
    required String title,
    required String iconImg,
    required bool isActive,
    required VoidCallback onTap,
    bool showArrow = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.white,
        child: Row(
          children: [
            Image.asset("assets/icons/app_icons/${iconImg}", height: 13),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            const Spacer(),
            if (showArrow)
              Icon(
                isActive
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                color: Colors.black,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          _buildSearchBar(),
          const SizedBox(height: 10),
          const Text(
            "Select Color",
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          _buildColorSelection(),
          const SizedBox(height: 6),
          const Text(
            "Select Categories",
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          _buildCategorySelection(),
          const SizedBox(height: 8),
          const Text(
            "Select Textures & Patterns",
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          _buildTextureSelection(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildCompareContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Builder(
            builder: (context) {
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _savedVersions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (context, index) {
                  final version = _savedVersions[index];
                  final isSelected = _selectedIndices.contains(index);
                  return GestureDetector(
                    onTap: () {
                      _toggleSelection(index);
                      // Already triggering context.read<ImageEditCubit>().compareImageSelected inside _toggleSelection
                      // but we need context. However, context is not easily passed into _toggleSelection since it's used elsewhere too.
                      // Let's modify _toggleSelection to accept context, or call the API directly here.
                      // Actually, the easiest way is to pass context to _toggleSelection.
                    },
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            version.image,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
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
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTopComparisonSection() {
    final totalItems = 1 + _selectedIndices.length;

    if (_selectedIndices.length == 1) {
      return Stack(
        children: [
          ImageCompareSlider(
            before: widget.imageFile,
            after: _savedVersions[_selectedIndices[0]].image,
            position: _sliderPosition,
            onChanged: (val) => setState(() => _sliderPosition = val),
          ),
          Positioned(
            bottom: 24,
            right: 16,
            child: _buildCircleButton(
              icon: "edit.png",
              onTap: () {
                setState(() {
                  _currentAssetPreview =
                      _savedVersions[_selectedIndices[0]].image;
                  _isEditVisible = true;
                  _compareExpanded = false;
                  _editExpanded = true;
                });
              },
              size: 20,
              padding: 8,
            ),
          ),
        ],
      );
    } else {
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      // The parent box is hardcoded to 40% of screen height
      final gridHeight = screenHeight * 0.40;
      final cellWidth = screenWidth / 2;
      final cellHeight = gridHeight / (totalItems > 2 ? 2 : 1);
      final aspectRatio = cellWidth / cellHeight;

      return Container(
        color: Colors.white,
        child: GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: aspectRatio,
          ),
          itemCount: totalItems,
          itemBuilder: (context, index) {
            final isOriginal = index == 0;
            final imageUrl = isOriginal
                ? null
                : _savedVersions[_selectedIndices[index - 1]].image;

            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 0.5),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  isOriginal
                      ? Image.file(widget.imageFile, fit: BoxFit.cover)
                      : Image.asset(imageUrl!, fit: BoxFit.cover),

                  _buildOverlayButtons(
                    bottom: 8,
                    isGrid: true,
                    showRemove: true,
                    onRemove: isOriginal
                        ? () {}
                        : () => _toggleSelection(_selectedIndices[index - 1]),
                    onSelect: () {
                      context.push(
                        AppRoutes.imageFinalize,
                        extra: {
                          'editedImage': imageUrl ?? widget.imageFile,
                          'selectedColor': _selectedColor,
                          'selectedLamination': _selectedTexture,
                        },
                      );
                    },
                    onEdit: () {
                      setState(() {
                        _currentAssetPreview = imageUrl;
                        _isEditVisible = true;
                        _compareExpanded = false;
                        _editExpanded = true;
                      });
                    },
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
  }

  Widget _buildOverlayButtons({
    required double bottom,
    required bool isGrid,
    bool showRemove = false,
    VoidCallback? onRemove,
    VoidCallback? onEdit,
    VoidCallback? onSelect,
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
          _buildCircleButton(
            icon: "edit.png",
            onTap:
                onEdit ??
                () => setState(() {
                  _isEditVisible = true;
                  _compareExpanded = false;
                  _editExpanded = true;
                }),
            size: iconSize,
            padding: padding,
          ),
          const SizedBox(width: 8),
          _buildCircleButton(
            icon: "tick.png",
            onTap: () {},
            size: iconSize,
            padding: padding,
          ),
          if (showRemove) ...[
            const SizedBox(width: 8),
            _buildCircleButton(
              icon: "cross.png",
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
    required String icon,
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
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: Image.asset(
            "assets/icons/app_icons/${icon}",
            height: 10,
            width: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildImageOverlaySection() {
    return GestureDetector(
      onTapDown: (details) {
        setState(() {
          _lastTapCoordinate = {
            "x": details.localPosition.dx,
            "y": details.localPosition.dy,
          };
          _isShortTap = true;
          _isLongTap = false;
        });
      },
      onLongPressStart: (details) {
        setState(() {
          _lastTapCoordinate = {
            "x": details.localPosition.dx,
            "y": details.localPosition.dy,
          };
          _isShortTap = false;
          _isLongTap = true;
        });
      },
      child: Stack(
        children: [
          if (_currentAssetPreview != null)
            Image.asset(
              _currentAssetPreview!,
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.40,
              fit: BoxFit.cover,
            )
          else
            Image.file(
              widget.imageFile,
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.40,
              fit: BoxFit.cover,
            ),

          // Dashed Bounding Boxes (Simulated Positions)
          _buildDashedBox(top: 40, left: 100, width: 80, height: 100),
          _buildDashedBox(top: 150, left: 150, width: 120, height: 80),
          _buildDashedBox(top: 250, left: 50, width: 100, height: 120),

          // Hand Icon Instruction Overlay
          Center(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.3,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.touch_app_outlined,
                    color: Colors.white,
                    size: 36,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
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
        ],
      ),
    );
  }

  Widget _buildDashedBox({
    required double top,
    required double left,
    required double width,
    required double height,
  }) {
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
      height: 35,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w100),
        decoration: InputDecoration(
          filled: true,
          fillColor: Color(0xFFF7F7F7),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 16,
          ),
          suffixIconConstraints: const BoxConstraints(
            maxWidth: 32,
            maxHeight: 32,
          ),
          suffixIcon: Container(
            margin: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 0,
                  spreadRadius: 1,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                "assets/icons/app_icons/ai_search.png",
                width: 14,
                height: 14,
              ),
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildColorSelection() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _featuredColors.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () async {
                  final Color? picked = await context.push<Color>(
                    AppRoutes.imageColorPicker,
                    extra: {
                      'imageFile': widget.imageFile,
                      'originalImage': widget.imageFile,
                    },
                  );
                  if (picked != null) {
                    final hex =
                        '#${picked.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                    setState(() {
                      _selectedCategory = null;
                      _selectedSubCategory = null;
                      _selectedColor = {
                        "name": "Picked Color",
                        "hex": hex,
                        "id": DateTime.now().millisecondsSinceEpoch,
                      };
                      _featuredColors.insert(0, _selectedColor!);
                    });
                    _fetchTexturesByColor();
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.asset(
                        "assets/icons/app_icons/color-picker.png",
                        width: 30,
                        height: 30,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Colour Picker",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }
          final colorData = _featuredColors[index - 1];
          final isSelected = _selectedColor?["id"] == colorData["id"];
          return Padding(
            padding: const EdgeInsets.only(right: 5),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = null;
                  _selectedSubCategory = null;
                  _selectedColor = colorData;
                });
                _fetchTexturesByColor();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color(
                        int.parse(colorData["hex"].replaceFirst('#', '0xFF')),
                      ),
                      borderRadius: BorderRadius.circular(4),
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 0.5)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    colorData["name"],
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChipRow(categoriesRow1, _selectedCategory, (val) {
          setState(() {
            _selectedCategory = val;
            _selectedSubCategory =
                "All"; // Revert to "All" when category changes
          });
          _fetchSubCategoriesFor(val);
          _fetchTextures(); // Fetch API when category changes
        }, isExpandedRow: true),
        const SizedBox(height: 0),
        if (categoriesRow2.isNotEmpty)
          _buildChipRow(categoriesRow2, _selectedSubCategory, (val) {
            setState(() => _selectedSubCategory = val);
            _fetchTextures(); // Fetch API when subcategory changes
          }, isExpandedRow: false),
      ],
    );
  }

  Widget _buildChipRow(
    List<String> labels,
    String? selectedItem,
    Function(String) onSelect, {
    bool isExpandedRow = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: isExpandedRow
          ? Row(
              children: labels.map((label) {
                final isSelected = selectedItem == label;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: label != labels.last ? 6.0 : 0.0,
                    ),
                    child: _buildChip(label, isSelected, onSelect, true),
                  ),
                );
              }).toList(),
            )
          : Wrap(
              spacing: 6,
              runSpacing: 0,
              children: labels.map((label) {
                final isSelected = selectedItem == label;
                return _buildChip(label, isSelected, onSelect, false);
              }).toList(),
            ),
    );
  }

  Widget _buildChip(
    String label,
    bool isSelected,
    Function(String) onSelect,
    bool isExpanded,
  ) {
    return ChoiceChip(
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      padding: EdgeInsets.zero,
      labelPadding: isExpanded
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: -2)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: -2),
      label: isExpanded
          ? SizedBox(
              width: double.infinity,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.grey[600],
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            )
          : Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.grey[600],
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
      selected: isSelected,
      onSelected: (val) => onSelect(label),
      backgroundColor: Colors.white,
      selectedColor: Colors.white,
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
        side: BorderSide(
          color: isSelected ? Colors.black87 : Colors.grey[200]!,
        ),
      ),
    );
  }

  Future<void> _showTextureDetailModal(
    BuildContext context,
    Map<String, dynamic> texture,
  ) async {
    final imageUrl = (texture["coverImage"] ?? "").toString();
    final title = (texture["sku"] ?? texture["name"] ?? "Texture").toString();

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: "Close",
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 360,
                              color: Colors.grey[100],
                              child: imageUrl.isNotEmpty
                                  ? InteractiveViewer(
                                      minScale: 1,
                                      maxScale: 4,
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (ctx, err, stack) =>
                                            Container(
                                              color: Colors.grey[300],
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.broken_image_outlined,
                                                color: Colors.black54,
                                              ),
                                            ),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.grey[300],
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.image_not_supported_outlined,
                                        color: Colors.black54,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            (texture["name"] ?? "").toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextureSelection() {
    if (_isLoadingTextures) {
      return SizedBox(
        height: widget.textureListHeight,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFEA202C),
          ),
        ),
      );
    }

    if (_apiTextures.isEmpty) {
      return SizedBox(
        height: widget.textureListHeight,
        child: Center(
          child: Text(
            (_selectedCategory == null && _selectedColor == null)
                ? "Select a color or category first."
                : "No laminates found.",
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ),
      );
    }

    return SizedBox(
      height: widget.textureListHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _apiTextures.length,
        itemBuilder: (context, index) {
          final texture = _apiTextures[index];
          final isSelected = _selectedTexture?["id"] == texture["id"];
          final imageUrl = texture["coverImage"] ?? "";
          final label = texture["sku"] ?? texture["name"] ?? "";

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTexture = texture);
                _showTextureDetailModal(context, texture);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: widget.textureThumbWidth,
                            height: widget.textureThumbHeight,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              width: widget.textureThumbWidth,
                              height: widget.textureThumbHeight,
                              color: Colors.grey[300],
                            ),
                          )
                        : Container(
                            width: widget.textureThumbWidth,
                            height: widget.textureThumbHeight,
                            color: Colors.grey[300],
                          ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: widget.textureThumbWidth,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? Colors.black : Colors.grey,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  void _applyChanges(BuildContext context) {
    if (_selectedTexture == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a texture pattern first."),
          backgroundColor: Colors.black87,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final textureId =
        _selectedTexture!["id"]?.toString() ??
        _selectedTexture!["sku"]?.toString() ??
        "unknown";
    final textureUrl =
        _selectedTexture!["coverImage"]?.toString() ?? "unknown_url";

    context.read<ImageEditCubit>().applyTextureSelected(
      textureId,
      textureUrl,
      _lastTapCoordinate,
      _isShortTap,
      _isLongTap,
    );

    setState(() {
      _isApplied = true;
      _isEditVisible = false;
      _compareExpanded = true;
      _editExpanded = false;
    });
  }

  Widget _buildBottomBarFixed() {
    if (!_editExpanded) {
      return const SizedBox.shrink();
    }
    return Builder(
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(color: Colors.white),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  const SizedBox(width: 50),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12, width: 1),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.menu,
                        color: Colors.black,
                        size: 20,
                      ),
                      onPressed: () {},
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              SizedBox(
                width: 120,
                height: 40,
                child: ElevatedButton(
                  onPressed: () => _applyChanges(context),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    side: const BorderSide(color: Colors.black12, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: BlocBuilder<ImageEditCubit, ImageEditState>(
                    builder: (context, state) {
                      if (state.isApplyLoading) {
                        return const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        );
                      }
                      return const Text(
                        "Apply",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
      path.lineTo(
        i + dashWidth > size.width ? size.width : i + dashWidth,
        size.height,
      );
    }

    // Left line
    for (double i = 0; i < size.height; i += dashWidth + dashSpace) {
      path.moveTo(0, i);
      path.lineTo(0, i + dashWidth > size.height ? size.height : i + dashWidth);
    }

    // Right line
    for (double i = 0; i < size.height; i += dashWidth + dashSpace) {
      path.moveTo(size.width, i);
      path.lineTo(
        size.width,
        i + dashWidth > size.height ? size.height : i + dashWidth,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
