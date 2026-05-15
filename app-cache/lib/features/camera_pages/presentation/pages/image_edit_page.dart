import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:century_ai/db/db_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:century_ai/features/home/presentation/widgets/home_drawer.dart';
import 'package:century_ai/features/camera_pages/presentation/widgets/image_compare_slider.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/features/camera_pages/data/dummy_data.dart';
import 'package:century_ai/core/network/apis/laminate_api.dart'; // Added API Import
import 'package:century_ai/core/network/cache/laminate_cache_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:century_ai/cubit/image_edit/image_edit_cubit.dart';
import 'package:century_ai/cubit/image_edit/image_edit_state.dart';
import 'package:century_ai/router/app_routes.dart';
import 'package:century_ai/features/camera_pages/data/models/edit_record.dart';
import 'package:century_ai/features/camera_pages/data/services/user_edits_service.dart';
import 'package:lottie/lottie.dart';
import 'package:uuid/uuid.dart';
import 'package:century_ai/db/repositories/edit_history_repository.dart';

class ImageEditPage extends StatefulWidget {
  final File imageFile;
  final Color? pickedColor;
  final String? image_id;

  final bool scrollableEditSection;
  final bool showTextureDetailOnTap;
  final double textureListHeight;
  final double textureThumbWidth;
  final double textureThumbHeight;

  const ImageEditPage({
    super.key,
    required this.imageFile,
    this.pickedColor,
    this.image_id,
    this.scrollableEditSection = false,
    this.showTextureDetailOnTap = true,
    this.textureListHeight = 120,
    this.textureThumbWidth = 90,
    this.textureThumbHeight = 75,
  });

  @override
  State<ImageEditPage> createState() => _ImageEditPageState();
}

class _ImageEditPageState extends State<ImageEditPage> {
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic>? _selectedColor;
  String? _selectedCategory;
  String? _selectedSubCategory;
  List<Map<String, dynamic>> _lamCategories = [];
  Map<String, dynamic>? _selectedTexture;
  String? _currentAssetPreview; // Track the design selected from comparison
  String _sessionId = ""; // Unique ID for this editing session
  late String
  _baseImage; // The image currently being used as a base for editing

  final LaminateService _laminateApi = LaminateService();
  final LaminateCacheService _cacheService = LaminateCacheService();
  bool _isEditVisible = true;
  bool _isLoadingTextures = false;
  bool _isPrecaching = false;
  bool _isUploading = false;
  List<dynamic> _apiTextures = [];

  bool _compareExpanded = false;
  bool _editExpanded = true;
  bool _hasAppliedOnce = false;
  final ValueNotifier<List<int>> _selectedIndicesNotifier = ValueNotifier([]);
  double _sliderPosition = 0.5;

  final UserEditsService _userEditsService = UserEditsService();
  final String _ownerEmail = "anisasru1@gmail.com";
  List<EditRecord> _userEdits = [];
  bool _isLoadingEdits = false;

  // Dummy versions fallback if no network edits yet

  // Dynamic Tap Variables
  Map<String, dynamic>? _lastTapCoordinate;
  Offset? _tapPosForDot;
  bool _isShortTap = true;
  bool _isLongTap = false;

  final TransformationController _transformationController =
      TransformationController();

  double? _originalImageWidth;
  double? _originalImageHeight;

  Future<void> _getImageDimensions() async {
    try {
      final Completer<ui.Image> completer = Completer();
      final ImageStream stream = FileImage(
        widget.imageFile,
      ).resolve(ImageConfiguration.empty);
      stream.addListener(
        ImageStreamListener((ImageInfo info, bool _) {
          if (!completer.isCompleted) {
            completer.complete(info.image);
          }
        }),
      );
      final ui.Image image = await completer.future;
      if (mounted) {
        setState(() {
          _originalImageWidth = image.width.toDouble();
          _originalImageHeight = image.height.toDouble();
        });
        debugPrint(
          '📸 Original Image Size: ${_originalImageWidth}x${_originalImageHeight}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error getting image dimensions: $e');
    }
  }

  Offset _mapLocalToOriginal(Offset localPos, Size viewSize) {
    if (_originalImageWidth == null || _originalImageHeight == null) {
      return localPos;
    }

    final double imageWidth = _originalImageWidth!;
    final double imageHeight = _originalImageHeight!;
    final double viewWidth = viewSize.width;
    final double viewHeight = viewSize.height;

    // BoxFit.cover logic: it scales the image to the smallest scale that covers the view
    final double scale = (viewWidth / imageWidth > viewHeight / imageHeight)
        ? viewWidth / imageWidth
        : viewHeight / imageHeight;

    final double scaledWidth = imageWidth * scale;
    final double scaledHeight = imageHeight * scale;

    // Offset is usually centered
    final double offsetX = (viewWidth - scaledWidth) / 2;
    final double offsetY = (viewHeight - scaledHeight) / 2;

    final double mappedX = (localPos.dx - offsetX) / scale;
    final double mappedY = (localPos.dy - offsetY) / scale;

    // Clamp to image boundaries
    return Offset(mappedX.clamp(0, imageWidth), mappedY.clamp(0, imageHeight));
  }

  void _zoomIn() {
    final double currentScale = _transformationController.value
        .getMaxScaleOnAxis();
    final double newScale = (currentScale + 0.5).clamp(1.0, 4.0);
    _transformationController.value = Matrix4.identity()..scale(newScale);
  }

  void _zoomOut() {
    final double currentScale = _transformationController.value
        .getMaxScaleOnAxis();
    final double newScale = (currentScale - 0.5).clamp(1.0, 4.0);
    _transformationController.value = Matrix4.identity()..scale(newScale);
  }

  void _toggleSelection(int index) {
    final currentSelected = List<int>.from(_selectedIndicesNotifier.value);
    if (currentSelected.contains(index)) {
      if (currentSelected.length > 1) {
        currentSelected.remove(index);
        _selectedIndicesNotifier.value = currentSelected;
      }
    } else {
      if (currentSelected.length < 3) {
        currentSelected.add(index);
        _selectedIndicesNotifier.value = currentSelected;

        if (_userEdits.isNotEmpty) {
          // Log comparison for network image if needed
          // Currently cubit expects ProductImageModel
        }
      }
    }
  }

  List<Map<String, dynamic>> _featuredColors = [
    {"name": "Yellow/Orange", "hex": "#FFB84D", "id": 101},
    {"name": "Reddish Brown", "hex": "#B36B5E", "id": 102},
    {"name": "Black", "hex": "#000000", "id": 103},
    {"name": "Blue", "hex": "#667EEA", "id": 104},
    {"name": "Brown", "hex": "#6B271E", "id": 105},
  ];

  @override
  void dispose() {
    _transformationController.dispose();
    _searchController.dispose();
    _selectedIndicesNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _sessionId = const Uuid().v4();
    _baseImage = widget.imageFile.path;
    _getImageDimensions();
    getLamCategory();
    if (widget.pickedColor != null) {
      final hex =
          '#${widget.pickedColor!.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      _selectedColor = {"name": "Picked Color", "hex": hex, "id": 999};
      _featuredColors.insert(0, _selectedColor!);
      _fetchTexturesByColor();
    }
    _fetchUserEditHistory();

    // Initialize Cubit with original image
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ImageEditCubit>().initOriginalImage(
        widget.imageFile.path,
        furnitureId: widget.image_id,
        ownerId: _ownerEmail,
        sessionId: _sessionId,
      );
    });
  }

  Future<void> _fetchUserEditHistory() async {
    if (widget.image_id == null) return;

    setState(() => _isLoadingEdits = true);
    try {
      // 1. Fetch from Network
      final allEdits = await _userEditsService.getEdits(_ownerEmail);
      final filteredNetwork = allEdits
          .where((e) => e.furnitureId == widget.image_id)
          .toList();

      // 2. Fetch from SQLite (ALL EDITS FOR THIS FURNITURE)
      final localEdits = await EditHistoryRepository.getEditsByFurnitureId(
        widget.image_id!,
      );

      // 3. Convert local to EditRecord
      final convertedLocal = localEdits
          .map(
            (e) => EditRecord(
              id: e.id,
              originalImageUrl: e.originalImagePath,
              editedImageUrl: e.editedImagePath,
              ownerId: e.ownerId,
              furnitureId: e.furnitureId,
              createdAt: e.editedAt,
              laminateName: e.laminateName,
            ),
          )
          .toList();

      // 4. Merge and De-duplicate using Filename
      final Map<String, EditRecord> uniqueMap = {};
      String getFileName(String path) => path.split('/').last.split('?').first;

      // Add Local
      for (var record in convertedLocal) {
        uniqueMap[getFileName(record.editedImageUrl)] = record;
      }

      // Add Network
      for (var net in filteredNetwork) {
        final key = getFileName(net.editedImageUrl);
        if (!uniqueMap.containsKey(key)) {
          uniqueMap[key] = net;
        }
      }

      if (mounted) {
        setState(() {
          // Add In-Memory designs from Cubit
          final cubitHistory = context
              .read<ImageEditCubit>()
              .state
              .generatedHistory;
          for (var h in cubitHistory) {
            final path = h['generated'] as String;
            final key = getFileName(path);
            if (!uniqueMap.containsKey(key)) {
              uniqueMap[key] = EditRecord(
                id: "mem_${DateTime.now().millisecondsSinceEpoch}",
                originalImageUrl: h['original'] ?? "",
                editedImageUrl: path,
                ownerId: _ownerEmail,
                furnitureId: widget.image_id ?? "",
                createdAt: DateTime.now(),
                laminateName: (h['laminate'] as Map<String, dynamic>?)?['name']
                    ?.toString(),
              );
            }
          }

          _userEdits = uniqueMap.values.toList();
          // Sort by creation time descending (latest first)
          _userEdits.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          _isLoadingEdits = false;
          // auto-select first one if available to show comparison
          if (_userEdits.isNotEmpty && _selectedIndicesNotifier.value.isEmpty) {
            _selectedIndicesNotifier.value = [0];
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching user edits: $e");
      if (mounted) setState(() => _isLoadingEdits = false);
    }
  }

  Future<void> _fetchTextures() async {
    if (_selectedCategory == null) return;

    String subCat =
        (_selectedSubCategory == "All" || _selectedSubCategory == null)
        ? ""
        : _selectedSubCategory!;

    // 1. Try cache first BEFORE showing loading state
    final cached = _cacheService.getCategoryTextures(
      _selectedCategory!,
      subCat,
    );
    if (cached != null && cached.isNotEmpty) {
      debugPrint("✅ Using cached textures for $_selectedCategory - $subCat");
      if (mounted) {
        setState(() {
          _apiTextures = cached;
          _isLoadingTextures = false;
          // Ensure selection is valid
          if (_selectedTexture == null && _apiTextures.isNotEmpty) {
            _selectedTexture = _apiTextures[0];
          }
        });
      }
      return;
    }

    // 2. Only show loading if NOT in cache
    setState(() {
      _apiTextures = [];
      _isLoadingTextures = true;
    });

    try {
      final response = await _laminateApi.fetchByCategory(
        category: _selectedCategory!,
        subcategory: subCat,
        itemType: "Laminates",
      );

      if (mounted) {
        setState(() {
          if (response != null &&
              response is Map &&
              response['laminates'] != null) {
            _apiTextures = response['laminates'] as List<dynamic>;

            // Save to cache
            _cacheService.saveCategoryTextures(
              _selectedCategory!,
              subCat,
              _apiTextures,
            );

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
      debugPrint("❌ Error fetching textures: $e");
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

    final hex = _selectedColor!["hex"];

    // 1. Try cache first BEFORE showing loading state
    final cached = _cacheService.getHexTextures(hex);
    if (cached != null && cached.isNotEmpty) {
      debugPrint("✅ Using cached textures for hex: $hex");
      if (mounted) {
        setState(() {
          _apiTextures = cached;
          _isLoadingTextures = false;
        });
      }
      return;
    }

    // 2. Only show loading if NOT in cache
    setState(() {
      _apiTextures = [];
      _isLoadingTextures = true;
    });

    try {
      final response = await _laminateApi.fetchByHex(
        hexCodes: [hex],
        itemType: "Laminates",
      );

      if (mounted) {
        setState(() {
          if (response != null && response is Map && response.isNotEmpty) {
            if (response.containsKey('laminates') &&
                response['laminates'] != null) {
              _apiTextures = response['laminates'] as List<dynamic>;
            } else {
              final key = response.keys.first;
              if (response[key] is List) {
                _apiTextures = response[key] as List<dynamic>;
              } else {
                _apiTextures = [];
              }
            }

            // Save to cache
            if (_apiTextures.isNotEmpty) {
              _cacheService.saveHexTextures(hex, _apiTextures);
            }
          } else {
            _apiTextures = [];
          }
          _isLoadingTextures = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching textures by color: $e");
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
      final db = await DbCore.database;
      final result = await db.query("lam_category");

      if (result.isNotEmpty && mounted) {
        setState(() {
          _lamCategories = result;
          categoriesRow1 = result.map((e) => e["name"].toString()).toList();
          if (_selectedCategory == null && categoriesRow1.isNotEmpty) {
            _selectedCategory = categoriesRow1.first;
            _selectedSubCategory = "All";
          }
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
      final db = await DbCore.database;
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
    return BlocListener<ImageEditCubit, ImageEditState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        } else if (state.successMessage != null) {
          if (state.editedImageFile != null) {
            setState(() {
              _isPrecaching = true;
              _currentAssetPreview = state.editedImageFile;
            });
            final imageProvider = FileImage(File(state.editedImageFile!));
            precacheImage(imageProvider, context)
                .then((_) {
                  if (mounted) {
                    setState(() {
                      _isPrecaching = false;
                    });
                  }
                })
                .catchError((e) {
                  if (mounted) {
                    setState(() {
                      _isPrecaching = false;
                    });
                  }
                });
          }
        }
      },
      child: Scaffold(
        drawer: const HomeDrawer(),
        backgroundColor: const Color(0xFFF8F8F8),
        body: SafeArea(
          child: Column(
            children: [
              // Top Image Preview Area (Fixed Height)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.40,
                child: ValueListenableBuilder<List<int>>(
                  valueListenable: _selectedIndicesNotifier,
                  builder: (context, selectedIndices, child) {
                    return BlocBuilder<ImageEditCubit, ImageEditState>(
                      builder: (context, state) {
                        if (state.isApplyLoading || _isPrecaching) {
                          return _buildGeneratingBlock();
                        }
                        return _compareExpanded
                            ? _buildTopComparisonSection(selectedIndices)
                            : RepaintBoundary(
                                child: _buildImageOverlaySection(),
                              );
                      },
                    );
                  },
                ),
              ),

              // Collapsible Headers & Content (Accordion Style)
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 0),
                          child: _buildCollapsibleHeaders(),
                        ),
                      ),
                      // Fixed Bottom Bar Area (Edit Mode)
                      if (_editExpanded)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _buildBottomBarFixed(),
                        ),
                      // Fixed Bottom Bar Area (Compare Mode)
                      if (_compareExpanded)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _buildBottomBarFixed2(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsibleHeaders() {
    return Column(
      children: [
        if (_hasAppliedOnce) ...[
          // Compare & select Header
          _buildHeaderTile(
            title: "Compare & select",
            iconImg: "compare.png",
            isActive: _compareExpanded,
            showArrow: true,
            onTap: () {
              setState(() {
                _compareExpanded = !_compareExpanded;
                if (_compareExpanded) {
                  _editExpanded = false;
                } else {
                  _editExpanded = true;
                }
              });
            },
          ),
          if (_compareExpanded)
            Expanded(
              child: SingleChildScrollView(child: _buildCompareContent()),
            ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
        ],

        // Edit & Design Header (Hidden if Compare is expanded)
        if (!_compareExpanded)
          _buildHeaderTile(
            title: "Edit & Design",
            iconImg: "edit.png",
            isActive: _editExpanded,
            showArrow: _hasAppliedOnce,
            onTap: () {
              setState(() {
                _editExpanded = !_editExpanded;
                if (_editExpanded) _compareExpanded = false;
              });
            },
          ),
        if (_editExpanded && !_compareExpanded)
          Expanded(child: SingleChildScrollView(child: _buildEditContent())),
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
        height: 30,
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
          // const SizedBox(height: 4),
          _buildSearchBar(),
          const SizedBox(height: 8),
          const Text(
            "Select Color",
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          _buildColorSelection(),
          // const SizedBox(height: 4),
          // const Text(
          //   "Select Categories",
          //   style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          // ),
          // const SizedBox(height: 4),
          // const SizedBox(height: 6),
          const Text(
            "Select Textures & Patterns",
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          _buildCategorySelection(),
          const SizedBox(height: 12),
          RepaintBoundary(child: _buildTextureSelection()),
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
          BlocBuilder<ImageEditCubit, ImageEditState>(
            builder: (context, state) {
              return ValueListenableBuilder<List<int>>(
                valueListenable: _selectedIndicesNotifier,
                builder: (context, selectedIndices, child) {
                  final bool isLoading = state.isApplyLoading || _isPrecaching;
                  if (_userEdits.isEmpty && !isLoading) {
                    return const SizedBox(
                      height: 120,
                      child: Center(
                        child: Text(
                          "No comparison versions available yet.\nApply a design to see versions here.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    );
                  }

                  final int itemCount = _userEdits.length + (isLoading ? 1 : 0);

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: itemCount,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                    itemBuilder: (context, index) {
                      // Show loading placeholder if loading
                      if (isLoading && index == 0) {
                        return _buildLoadingVersionPlaceholder();
                      }

                      // Adjust index further if loader is present
                      final editIndex = isLoading ? index - 1 : index;
                      if (editIndex < 0)
                        return const SizedBox.shrink(); // Safety check for loader

                      final String imgPath =
                          _userEdits[editIndex].editedImageUrl;
                      final isSelected = selectedIndices.contains(editIndex);

                      return GestureDetector(
                        onTap: () {
                          _toggleSelection(editIndex);
                        },
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: imgPath.startsWith('http')
                                  ? Image.network(
                                      imgPath,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      cacheWidth: 200,
                                      errorBuilder: (c, e, s) => Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Image.file(
                                      File(imgPath),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      cacheWidth: 200,
                                      errorBuilder: (c, e, s) => Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
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
                                color: isSelected
                                    ? Colors.black
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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

  Widget _buildTopComparisonSection(List<int> selectedIndices) {
    final totalItems = 1 + selectedIndices.length;

    if (selectedIndices.length == 1) {
      return Stack(
        children: [
          ImageCompareSlider(
            before: widget.imageFile.path,
            after: _userEdits[selectedIndices[0]].editedImageUrl,
            isAfterNetwork: _userEdits[selectedIndices[0]].editedImageUrl
                .startsWith('http'),
            position: _sliderPosition,
            onChanged: (val) => _sliderPosition = val,
          ),
          Positioned(
            bottom: 24,
            right: 16,
            child: _buildCircleButton(
              icon: "edit.png",
              onTap: () async {
                final newPath = _userEdits.isNotEmpty
                    ? _userEdits[selectedIndices[0]].editedImageUrl
                    : widget.imageFile.path;
                // SAVE TO DATABASE BEFORE STARTING NEW SESSION
                final cubit = context.read<ImageEditCubit>();
                final historyItem = cubit.state.generatedHistory.firstWhere(
                  (h) => h['generated'] == newPath,
                  orElse: () => {},
                );
                await cubit.saveToDatabase(
                  imgPath: newPath,
                  laminate: historyItem['laminate'] as Map<String, dynamic>?,
                );

                setState(() {
                  _sessionId = const Uuid().v4(); // START NEW SESSION
                  _baseImage = newPath; // UPDATE BASE IMAGE
                  _currentAssetPreview = null; // Clear overlay since it's now the base
                  _selectedIndicesNotifier.value = []; // CLEAR SELECTIONS FOR NEW SESSION
                  _hasAppliedOnce = true;
                  _compareExpanded = false;
                  _editExpanded = true;
                  // CLEAR PREVIOUS LAMINATE AND AREA SO IT DOESN'T AUTO-APPLY
                  _selectedTexture = null;
                  _selectedColor = null;
                  _selectedCategory = null;
                  _selectedSubCategory = null;
                  _tapPosForDot = null;
                  _lastTapCoordinate = null;
                });
                // RE-INIT CUBIT WITH NEW IMAGE AND SESSION
                context.read<ImageEditCubit>().initOriginalImage(
                  newPath,
                  furnitureId: widget.image_id,
                  ownerId: _ownerEmail,
                  sessionId: _sessionId,
                );
                _fetchUserEditHistory(); // REFRESH UI FOR NEW SESSION
              },
              size: 20,
              padding: 8,
            ),
          ),
        ],
      );
    }

    // Dynamic Layout to fill space for 2, 3, or 4 total items
    final List<Widget> items = [];

    // Add Original
    items.add(
      _buildComparisonItem(
        path: null,
        isOriginal: true,
        onRemove: () {},
        onSelect: () {}, // Not applicable for original
        onEdit: () {
          setState(() {
            _sessionId = const Uuid().v4(); // START NEW SESSION
            _baseImage = widget.imageFile.path; // RESET TO ORIGINAL
            _currentAssetPreview = null;
            _selectedIndicesNotifier.value = []; // CLEAR SELECTIONS FOR NEW SESSION
            _hasAppliedOnce = true;
            _compareExpanded = false;
            _editExpanded = true;
            // CLEAR PREVIOUS LAMINATE AND AREA SO IT DOESN'T AUTO-APPLY
            _selectedTexture = null;
            _selectedColor = null;
            _selectedCategory = null;
            _selectedSubCategory = null;
            _tapPosForDot = null;
            _lastTapCoordinate = null;
          });
          // RE-INIT CUBIT WITH NEW SESSION
          context.read<ImageEditCubit>().initOriginalImage(
            _baseImage,
            furnitureId: widget.image_id,
            ownerId: _ownerEmail,
            sessionId: _sessionId,
          );
          _fetchUserEditHistory(); // REFRESH UI FOR NEW SESSION
        },
      ),
    );

    // Add Selected Versions
    for (int i = 0; i < selectedIndices.length; i++) {
      final index = selectedIndices[i];
      final String imgPath = _userEdits[index].editedImageUrl;

      items.add(
        _buildComparisonItem(
          path: imgPath,
          isOriginal: false,
          isNetwork: imgPath.startsWith('http'),
          onRemove: () => _toggleSelection(index),
          onSelect: () async {
            // 1. SAVE TO LOCAL DATABASE
            final cubit = context.read<ImageEditCubit>();
            final historyItem = cubit.state.generatedHistory.firstWhere(
              (h) => h['generated'] == imgPath,
              orElse: () => {},
            );
            await cubit.saveToDatabase(
              imgPath: imgPath,
              laminate: historyItem['laminate'] as Map<String, dynamic>?,
            );

            // 2. POST TO SERVER (THIS IS THE FINAL SELECTION)
            if (widget.image_id != null) {
              try {
                await _userEditsService.postEdit(
                  editedFile: File(imgPath),
                  furnitureId: widget.image_id!,
                  email: _ownerEmail,
                );
                debugPrint("✅ Final image posted to server on selection");
              } catch (e) {
                debugPrint("❌ Failed to post final image to server: $e");
              }
            }

            final List<Map<String, dynamic>> usedLaminates = [];
            for (var item in cubit.state.generatedHistory) {
              if (item['laminate'] != null) {
                final lam = item['laminate'] as Map<String, dynamic>;
                if (!usedLaminates.any((element) => element['id'] == lam['id'])) {
                  usedLaminates.add(lam);
                }
              }
            }
            if (usedLaminates.isEmpty && _selectedTexture != null) {
              usedLaminates.add(_selectedTexture!);
            }

            context.push(
              AppRoutes.imageFinalize,
              extra: {
                'editedImage': imgPath,
                'usedLaminates': usedLaminates,
              },
            );
          },
          onEdit: () async {
            // SAVE TO DATABASE BEFORE STARTING NEW SESSION
            final cubit = context.read<ImageEditCubit>();
            final historyItem = cubit.state.generatedHistory.firstWhere(
              (h) => h['generated'] == imgPath,
              orElse: () => {},
            );
            await cubit.saveToDatabase(
              imgPath: imgPath,
              laminate: historyItem['laminate'] as Map<String, dynamic>?,
            );

            setState(() {
              _sessionId = const Uuid().v4(); // START NEW SESSION
              _baseImage = imgPath; // UPDATE BASE IMAGE
              _currentAssetPreview = null; // Clear overlay since it's now the base
              _selectedIndicesNotifier.value = []; // CLEAR SELECTIONS FOR NEW SESSION
              _hasAppliedOnce = true;
              _compareExpanded = false;
              _editExpanded = true;
              // CLEAR PREVIOUS LAMINATE AND AREA SO IT DOESN'T AUTO-APPLY
              _selectedTexture = null;
              _selectedColor = null;
              _selectedCategory = null;
              _selectedSubCategory = null;
              _tapPosForDot = null;
              _lastTapCoordinate = null;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Continuing edit with selected design..."),
                  duration: Duration(seconds: 2),
                ),
              );
            }

            // RE-INIT CUBIT WITH NEW IMAGE AND SESSION
            context.read<ImageEditCubit>().initOriginalImage(
              _baseImage,
              furnitureId: widget.image_id,
              ownerId: _ownerEmail,
              sessionId: _sessionId,
            );
            _fetchUserEditHistory(); // REFRESH UI FOR NEW SESSION
          },
        ),
      );
    }

    // ENSURE TOTAL ITEMS HANDLED (Limit to 4 for the split view, or keep as is)
    // Actually, let's keep the logic but the Original is already items[0].

    if (totalItems == 1) {
      return items[0];
    } else if (totalItems == 2) {
      return Row(children: items.map((e) => Expanded(child: e)).toList());
    } else if (totalItems == 3) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: items[0]),
                Expanded(child: items[1]),
              ],
            ),
          ),
          Expanded(child: items[2]),
        ],
      );
    } else {
      // totalItems == 4
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: items[0]),
                Expanded(child: items[1]),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: items[2]),
                Expanded(child: items[3]),
              ],
            ),
          ),
        ],
      );
    }
  }

  Widget _buildComparisonItem({
    required String? path,
    required bool isOriginal,
    bool isNetwork = false,
    required VoidCallback onRemove,
    required VoidCallback onEdit,
    required VoidCallback onSelect,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 0.5),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          isOriginal
              ? (widget.imageFile.path.startsWith('http')
                    ? Image.network(
                        widget.imageFile.path,
                        fit: BoxFit.cover,
                        cacheWidth: 400,
                      )
                    : Image.file(widget.imageFile, fit: BoxFit.cover))
              : (isNetwork
                    ? Image.network(
                        path!,
                        fit: BoxFit.cover,
                        cacheWidth: 400,
                        errorBuilder: (c, e, s) =>
                            Image.file(widget.imageFile, fit: BoxFit.cover),
                      )
                    : (path!.startsWith('/') || path.contains('tryon_result'))
                    ? Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        cacheWidth: 400,
                        errorBuilder: (c, e, s) =>
                            Image.file(widget.imageFile, fit: BoxFit.cover),
                      )
                    : Image.asset(
                        path,
                        fit: BoxFit.cover,
                        cacheWidth: 400,
                        errorBuilder: (c, e, s) =>
                            Image.file(widget.imageFile, fit: BoxFit.cover),
                      )),
          _buildOverlayButtons(
            bottom: 8,
            isGrid: true,
            showRemove: !isOriginal,
            onRemove: onRemove,
            onSelect: onSelect,
            onEdit: onEdit,
          ),
        ],
      ),
    );
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
            onTap: onEdit ?? () {}, // USE SAME LOGIC AS EDIT
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
    return Stack(
      children: [
        ClipRect(
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 1.0,
            maxScale: 4.0,
            boundaryMargin: const EdgeInsets.all(20),
            child: GestureDetector(
              onTapDown: (details) {
                final viewSize = Size(
                  MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height * 0.40,
                );
                final mappedPos = _mapLocalToOriginal(
                  details.localPosition,
                  viewSize,
                );

                debugPrint(
                  '📍 Coordinate Selected (Tap): Screen(x: ${details.localPosition.dx.toStringAsFixed(1)}, y: ${details.localPosition.dy.toStringAsFixed(1)}) -> Image(x: ${mappedPos.dx.toInt()}, y: ${mappedPos.dy.toInt()})',
                );

                setState(() {
                  _lastTapCoordinate = {"x": mappedPos.dx, "y": mappedPos.dy};
                  _tapPosForDot = details.localPosition;
                  _isShortTap = true;
                  _isLongTap = false;
                });

                // Automatically trigger area selection in Cubit
                context.read<ImageEditCubit>().selectArea(_lastTapCoordinate!);
              },
              onLongPressStart: (details) {
                final viewSize = Size(
                  MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height * 0.40,
                );
                final mappedPos = _mapLocalToOriginal(
                  details.localPosition,
                  viewSize,
                );

                debugPrint(
                  '📍 Coordinate Selected (Long Press): Screen(x: ${details.localPosition.dx.toStringAsFixed(1)}, y: ${details.localPosition.dy.toStringAsFixed(1)}) -> Image(x: ${mappedPos.dx.toInt()}, y: ${mappedPos.dy.toInt()})',
                );

                setState(() {
                  _lastTapCoordinate = {"x": mappedPos.dx, "y": mappedPos.dy};
                  _tapPosForDot = details.localPosition;
                  _isShortTap = false;
                  _isLongTap = true;
                });

                // Automatically trigger area selection in Cubit
                context.read<ImageEditCubit>().selectArea(_lastTapCoordinate!);
              },
              child: Stack(
                children: [
                  // Base Image (Dynamic)
                  _baseImage.startsWith('http')
                      ? Image.network(
                          _baseImage,
                          width: double.infinity,
                          height: MediaQuery.of(context).size.height * 0.40,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          cacheWidth: 800,
                        )
                      : Image.file(
                          File(_baseImage),
                          width: double.infinity,
                          height: MediaQuery.of(context).size.height * 0.40,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          cacheWidth: 800,
                        ),

                  // Applied Design Layer
                  if (_currentAssetPreview != null &&
                      _currentAssetPreview!.isNotEmpty)
                    _currentAssetPreview!.startsWith('http')
                        ? Image.network(
                            _currentAssetPreview!,
                            width: double.infinity,
                            height: MediaQuery.of(context).size.height * 0.40,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            cacheWidth: 800,
                          )
                        : (_currentAssetPreview!.startsWith('/') ||
                              _currentAssetPreview!.contains('tryon_result'))
                        ? Image.file(
                            File(_currentAssetPreview!),
                            width: double.infinity,
                            height: MediaQuery.of(context).size.height * 0.40,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            cacheWidth: 800,
                          )
                        : Image.asset(
                            _currentAssetPreview!,
                            width: double.infinity,
                            height: MediaQuery.of(context).size.height * 0.40,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),

                  // Selected Coordinate Dot
                  if (_tapPosForDot != null)
                    Positioned(
                      left: _tapPosForDot!.dx - 12,
                      top: _tapPosForDot!.dy - 12,
                      child: IgnorePointer(
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Zoom Controls
        Positioned(
          bottom: 24,
          right: 16,
          child: Row(
            children: [
              _buildZoomButton(icon: Icons.zoom_out, onTap: _zoomOut),
              const SizedBox(width: 8),
              _buildZoomButton(icon: Icons.zoom_in, onTap: _zoomIn),
            ],
          ),
        ),
        // Redundant overlay removed as it's now handled by _buildGeneratingBlock in the main stack
        const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildGeneratingBlock() {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.40,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        image: DecorationImage(
          image: _baseImage.startsWith('http')
              ? NetworkImage(_baseImage) as ImageProvider
              : FileImage(File(_baseImage)),
          fit: BoxFit.cover,
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Premium AI Lottie Animation (Local)
                  Lottie.asset(
                    'assets/images/animations/ai_star_ui_animation.json',
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black, size: 24),
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
      height: 30,
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
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _featuredColors.length + 1,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 15),
            child: _buildColorItem(index),
          );
        },
      ),
    );
  }

  Widget _buildColorItem(int index) {
    if (index == 0) {
      return GestureDetector(
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
              width: 60,
              height: 30,
              child: Center(
                child: Image.asset(
                  "assets/icons/app_icons/color-picker.png",
                  width: 60,
                  height: 30,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Colour Picker",
              style: TextStyle(fontSize: 8, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final colorData = _featuredColors[index - 1];
    final isSelected = _selectedColor?["id"] == colorData["id"];
    return GestureDetector(
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
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              color: isSelected ? Colors.black : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        _buildChipRow(categoriesRow1, _selectedCategory, (val) {
          setState(() {
            if (_selectedCategory != val) {
              _selectedCategory = val;
              _selectedSubCategory = "All";
              _fetchSubCategoriesFor(val);
              _fetchTextures();
            }
          });
        }),
        if (_selectedCategory != null && categoriesRow2.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSubCategoryMenu(categoriesRow2, _selectedSubCategory, (val) {
            setState(() {
              if (_selectedSubCategory != val) {
                _selectedSubCategory = val;
                _fetchTextures();
              }
            });
          }),
        ],
      ],
    );
  }

  Widget _buildSubCategoryMenu(
    List<String> labels,
    String? selectedItem,
    Function(String) onSelect,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: labels.map((label) {
          final isSelected = selectedItem == label;
          return GestureDetector(
            onTap: () => onSelect(label),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected
                        ? const Color(0xFFEA202C)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.black : const Color(0xFF5D5D5D),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChipRow(
    List<String> labels,
    String? selectedItem,
    Function(String) onSelect,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: labels.asMap().entries.map((entry) {
          final label = entry.value;
          final isSelected = selectedItem == label;
          return Padding(
            padding: EdgeInsets.only(
              right: entry.key != labels.length - 1 ? 8.0 : 0.0,
            ),
            child: _buildCategoryChip(label, isSelected, onSelect),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryChip(
    String label,
    bool isSelected,
    Function(String) onSelect,
  ) {
    return GestureDetector(
      onTap: () => onSelect(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFB5B5B5)
                : const Color(0xFFD9D9D9),
            width: 0.3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.075),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: const Color(0xFF5D5D5D),
          ),
        ),
      ),
    );
  }

  Widget _buildTextureSelection() {
    if (_isLoadingTextures) {
      return SizedBox(
        height: widget.textureListHeight,
        child: const Center(
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

    if (widget.scrollableEditSection) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _apiTextures.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemBuilder: (context, index) {
          return _buildTextureThumbnail(_apiTextures[index], isGrid: true);
        },
      );
    }

    return SizedBox(
      height: widget.textureListHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _apiTextures.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _buildTextureThumbnail(_apiTextures[index], isGrid: false),
          );
        },
      ),
    );
  }

  Widget _buildTextureThumbnail(dynamic texture, {required bool isGrid}) {
    final isSelected = _selectedTexture?["id"] == texture["id"];
    final imageUrl = texture["coverImage"] ?? "";
    final label = texture["sku"] ?? texture["name"] ?? "";

    final imageWidget = Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFFD9D9D9) : Colors.transparent,
          width: 5,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 200,
                    placeholder: (ctx, url) => Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(color: Colors.white),
                    ),
                    errorWidget: (ctx, url, err) =>
                        Container(color: Colors.grey[300]),
                  )
                : Container(color: Colors.grey[300]),
          ),
          if (isSelected && widget.showTextureDetailOnTap)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => _showTextureDetailPopup(context, texture),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.visibility_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "View Texture",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () {
        setState(() => _selectedTexture = texture);
        // Automatically trigger pattern selection in Cubit
        context.read<ImageEditCubit>().selectPattern(texture);
      },
      child: SizedBox(
        width: isGrid ? null : widget.textureThumbWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isGrid)
              Expanded(child: imageWidget)
            else
              SizedBox(
                height: widget.textureThumbHeight,
                width: widget.textureThumbWidth,
                child: imageWidget,
              ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? Colors.black : const Color(0xFF5D5D5D),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTextureDetailPopup(
    BuildContext context,
    Map<String, dynamic> texture,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final imageUrl = texture["coverImage"] ?? "";
        final label = texture["sku"] ?? texture["name"] ?? "";

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    if (imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => Container(
                          height: 300,
                          color: Colors.white,
                          child: const Icon(Icons.error_outline),
                        ),
                      )
                    else
                      Container(
                        height: 300,
                        color: Colors.white,
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),

                    // Close Button
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black26,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    // Label at the Bottom
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 4,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _finalizeEdit() async {
    final state = context.read<ImageEditCubit>().state;

    // Trigger comparison details API call
    if (state.selectedPattern != null) {
      final pattern = state.selectedPattern!;
      final model = ProductImageModel(
        id: pattern['id']?.toString() ?? '0',
        name: pattern['name']?.toString() ?? 'AI Design',
        image: pattern['coverImage']?.toString() ?? '',
        isTrending: false,
        category: _selectedCategory,
        subcategory: _selectedSubCategory,
      );
      context.read<ImageEditCubit>().compareImageSelected(model);
    }

    // ONLY SAVE TO LOCAL SQLITE WITH LAMINATES (NO SERVER POST YET)
    if (widget.image_id != null && state.currentGeneratedImage != null) {
      try {
        final cubit = context.read<ImageEditCubit>();
        await cubit.saveToDatabase(
          imgPath: state.currentGeneratedImage!,
          laminate: state.selectedPattern,
        );
        await _fetchUserEditHistory();
      } catch (e) {
        debugPrint("❌ Error saving local edit: $e");
      }
    }

    if (mounted) {
      setState(() {
        _compareExpanded = true;
        _editExpanded = false;
        _hasAppliedOnce = true;
      });
    }
  }

  bool get _isApplied => _hasAppliedOnce;

  Widget _buildBottomBarFixed() {
    if (!_editExpanded) {
      return const SizedBox.shrink();
    }
    return Builder(
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(color: Colors.transparent),
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
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                    ),
                  ),
                  const Spacer(),
                  BlocBuilder<ImageEditCubit, ImageEditState>(
                    builder: (context, state) {
                      return Visibility(
                        visible:
                            _hasAppliedOnce &&
                            _editExpanded &&
                            !state.isApplyLoading,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: GestureDetector(
                          onTap: _finalizeEdit,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black12,
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_forward,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 50),
                ],
              ),
              SizedBox(
                width: 120,
                height: 40,
                child: BlocBuilder<ImageEditCubit, ImageEditState>(
                  builder: (context, state) {
                    final bool isGenerating = state.isGenerating;
                    final bool isLoading = isGenerating || _isUploading;
                    final bool hasResult = state.currentGeneratedImage != null;

                    return ElevatedButton(
                      onPressed: (isLoading || !hasResult)
                          ? null
                          : _finalizeEdit,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        disabledBackgroundColor: Colors.grey[100],
                        disabledForegroundColor: Colors.black26,
                        side: BorderSide(
                          color: (isLoading || !hasResult)
                              ? Colors.transparent
                              : Colors.black12,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        "Apply",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBarFixed2() {
    if (!_compareExpanded) {
      return const SizedBox.shrink();
    }
    return Builder(
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 10,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12, width: 1),
                ),
                child: IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black, size: 20),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
              BlocBuilder<ImageEditCubit, ImageEditState>(
                builder: (context, state) {
                  return Visibility(
                    visible: _hasAppliedOnce && !state.isApplyLoading,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: GestureDetector(
                      onTap: () {
                        final cubit = context.read<ImageEditCubit>();
                        final List<Map<String, dynamic>> usedLaminates = [];
                        for (var item in cubit.state.generatedHistory) {
                          if (item['laminate'] != null) {
                            final lam = item['laminate'] as Map<String, dynamic>;
                            if (!usedLaminates.any((element) => element['id'] == lam['id'])) {
                              usedLaminates.add(lam);
                            }
                          }
                        }
                        if (usedLaminates.isEmpty && _selectedTexture != null) {
                          usedLaminates.add(_selectedTexture!);
                        }

                        context.push(
                          AppRoutes.imageFinalize,
                          extra: {
                            'editedImage':
                                state.currentGeneratedImage ??
                                widget.imageFile.path,
                            'usedLaminates': usedLaminates,
                          },
                        );
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12, width: 1),
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingVersionPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12, width: 0.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated Pulse Effect
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 0.6),
            duration: const Duration(milliseconds: 800),
            builder: (context, opacity, child) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(opacity),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            },
            onEnd:
                () {}, // Handled by repetition logic if using AnimationController
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Generating...",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
