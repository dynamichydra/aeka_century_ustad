import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:century_ai/core/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:century_ai/features/home/presentation/widgets/home_drawer.dart';
import 'package:century_ai/features/camera_pages/presentation/widgets/image_compare_slider.dart';
import 'package:century_ai/core/constants/image_strings.dart';
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
  final bool isExterior;

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
    this.isExterior = false,
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
  bool _hasNewUnappliedEdit =
      false; // Tracks if a new AI generation is available but not yet finalized
  final ValueNotifier<List<int>> _selectedIndicesNotifier = ValueNotifier([]);
  double _sliderPosition = 0.5;

  final UserEditsService _userEditsService = UserEditsService();
  final String _ownerEmail = "anisasru2@gmail.com";
  List<EditRecord> _userEdits = [];

  /// ID of the edit_history row that the current session is built upon.
  /// Null for the first edit on an original image.
  String? _parentEditId;
  bool _isLoadingEdits = false;

  // Dummy versions fallback if no network edits yet

  // Rectangle Selection Variables
  SelectionRect? _selection;
  Offset? _dragStart;
  SelectionMode _mode = SelectionMode.none;

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
      final allEdits = await _userEditsService.getEdits(
        _ownerEmail,
        furnitureId: widget.image_id,
      );
      final filteredNetwork = allEdits
          .where((e) => e.furnitureId == widget.image_id)
          .toList();

      // 2. Fetch from SQLite (ALL EDITS FOR THIS FURNITURE)
      final localEdits = await EditHistoryRepository.getEditsByFurnitureId(
        widget.image_id!,
      );

      // 3. Convert local to EditRecord (Use SQLite's session_id as the primary identifier if synchronized, fallback to local UUID)
      final convertedLocal = localEdits
          .map(
            (e) => EditRecord(
              id: (e.sessionId.isNotEmpty && e.sessionId != 'default_session')
                  ? e.sessionId
                  : e.id,
              originalImageUrl: e.originalImagePath,
              editedImageUrl: e.editedImagePath,
              ownerId: e.ownerId,
              furnitureId: e.furnitureId,
              createdAt: e.editedAt,
              laminateName: e.laminateName,
              usedLaminatesJson: e.usedLaminates,
            ),
          )
          .toList();

      // 4. Merge and De-duplicate using record ID, Filename, and Laminate/Timestamp correlation
      final Map<String, EditRecord> uniqueMap = {};
      String getFileName(String path) => path.split('/').last.split('?').first;

      // Add Network records first (as the source of truth for remote URLs)
      for (var net in filteredNetwork) {
        if (net.id.isNotEmpty) {
          uniqueMap[net.id] = net;
        } else {
          final fallbackKey = getFileName(net.editedImageUrl);
          uniqueMap[fallbackKey] = net;
        }
      }

      // Add Local records only if they aren't already represented in uniqueMap by ID, Filename, or closely-matching metadata
      for (var record in convertedLocal) {
        final key = record.id;
        final fallbackKey = getFileName(record.editedImageUrl);

        // Check if this local record matches any already added network record by ID
        if (uniqueMap.containsKey(key)) {
          final existingNet = uniqueMap[key]!;
          if (existingNet.usedLaminatesJson == null ||
              existingNet.usedLaminatesJson!.isEmpty) {
            uniqueMap[key] = EditRecord(
              id: existingNet.id,
              originalImageUrl: existingNet.originalImageUrl,
              editedImageUrl: existingNet.editedImageUrl,
              ownerId: existingNet.ownerId,
              furnitureId: existingNet.furnitureId,
              createdAt: existingNet.createdAt,
              laminateName: record.laminateName,
              usedLaminatesJson: record.usedLaminatesJson,
            );
          }
          continue;
        }

        // Check if this local record matches any already added network record by Filename
        if (uniqueMap.containsKey(fallbackKey)) {
          final existingNet = uniqueMap[fallbackKey]!;
          if (existingNet.usedLaminatesJson == null ||
              existingNet.usedLaminatesJson!.isEmpty) {
            uniqueMap[fallbackKey] = EditRecord(
              id: existingNet.id,
              originalImageUrl: existingNet.originalImageUrl,
              editedImageUrl: existingNet.editedImageUrl,
              ownerId: existingNet.ownerId,
              furnitureId: existingNet.furnitureId,
              createdAt: existingNet.createdAt,
              laminateName: record.laminateName,
              usedLaminatesJson: record.usedLaminatesJson,
            );
          }
          continue;
        }

        // Deep/intelligent check to see if this local record represents the same edit as an existing network record (within 5 minutes)
        bool isDuplicate = false;
        for (var existingNet in uniqueMap.values) {
          final diffSeconds = record.createdAt
              .difference(existingNet.createdAt)
              .inSeconds
              .abs();
          if (diffSeconds < 300) {
            final netKey = existingNet.id.isNotEmpty
                ? existingNet.id
                : getFileName(existingNet.editedImageUrl);
            if (existingNet.usedLaminatesJson == null ||
                existingNet.usedLaminatesJson!.isEmpty) {
              uniqueMap[netKey] = EditRecord(
                id: existingNet.id,
                originalImageUrl: existingNet.originalImageUrl,
                editedImageUrl: existingNet.editedImageUrl,
                ownerId: existingNet.ownerId,
                furnitureId: existingNet.furnitureId,
                createdAt: existingNet.createdAt,
                laminateName: record.laminateName,
                usedLaminatesJson: record.usedLaminatesJson,
              );
            }
            isDuplicate = true;
            break;
          }
        }

        if (!isDuplicate) {
          uniqueMap[key] = record;
        }
      }

      if (mounted) {
        setState(() {
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
      itemType: widget.isExterior ? "Exteria" : "Laminates",
    );
    if (cached != null && cached.isNotEmpty) {
      debugPrint("✅ Using cached textures for $_selectedCategory - $subCat");
      if (mounted) {
        setState(() {
          _apiTextures = cached;
          _isLoadingTextures = false;
          // Ensure selection is valid
          // Removed auto-selection of first texture
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
        itemType: widget.isExterior ? "Exteria" : "Laminates",
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
              itemType: widget.isExterior ? "Exteria" : "Laminates",
            );

            // Removed auto-selection of first texture
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
    final cached = _cacheService.getHexTextures(
      hex,
      itemType: widget.isExterior ? "Exteria" : "Laminates",
    );
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
        itemType: widget.isExterior ? "Exteria" : "Laminates",
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
              _cacheService.saveHexTextures(
                hex,
                _apiTextures,
                itemType: widget.isExterior ? "Exteria" : "Laminates",
              );
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

  static const Map<String, List<String>> _laminateCategoriesMap = {
    "Abstract Patterns": [
      "All",
      "Glitters",
      "Exclusives",
      "Wallpaper",
      "Noir Collection",
      "Patterns",
      "Textile",
      "Cane",
      "Fabric",
      "High Gloss",
      "Adaluxe",
      "Urban Leather",
      "Linen",
      "Tessuto",
      "Iyo Petal",
      "Lusio",
    ],
    "Woodgrains": [
      "All",
      "Woodgrains",
      "Synchro Series",
      "Evoke Oak",
      "Willow Wood",
      "Exotic Woodgrains",
      "Pinkora",
      "Vava Oxford",
      "Crasse",
      "Natural Horizontal",
      "Horizontal",
      "White Woods",
      "Acacia",
      "Ash",
      "Hickory, Elm & Chestnut",
      "Maple",
      "Pine",
      "Beech & Anegre",
      "Cherry & Pear",
      "Sapeli, Mahogany & Rosewood",
      "Teak",
      "Walnut",
      "Oak",
      "Wenge",
      "Dyed Wood",
    ],
    "Stones": [
      "All",
      "Stones",
      "Archi Concrete",
      "Slate",
      "Kering Matne",
      "Black",
      "White",
    ],
    "Solid": [
      "All",
      "Yellow & Orange",
      "Green",
      "Grey",
      "Voilet",
      "Blue",
      "Red",
      "Pink",
      "Brown & Beige",
    ],
  };

  /// Category/subcategory map for Exteria (exterior laminates)
  static const Map<String, List<String>> _exteriaCategoriesMap = {
    "Abstract Patterns": [
      "All",
      "Cement",
      "Grunge & Rustic",
      "Others",
    ],
    "Woodgrains": [
      "All",
      "Dark",
      "Medium",
      "Light",
    ],
    "Stones": [
      "All",
      "Marble",
      "Travertine",
      "Ivory",
    ],
    "Solid": [
      "All",
      "Green",
      "White",
      "Blue",
      "Yellow",
      "Grey",
      "Other",
    ],
  };

  Map<String, List<String>> get _activeCategoriesMap =>
      widget.isExterior ? _exteriaCategoriesMap : _laminateCategoriesMap;

  List<String> categoriesRow1 = [""];
  List<String> categoriesRow2 = [""];

  Future<void> getLamCategory() async {
    if (mounted) {
      setState(() {
        categoriesRow1 = _activeCategoriesMap.keys.toList();
        if (_selectedCategory == null && categoriesRow1.isNotEmpty) {
          _selectedCategory = categoriesRow1.first;
          _selectedSubCategory = "All";
        }
      });

      if (_selectedCategory != null) {
        _fetchSubCategoriesFor(_selectedCategory!);
        await _fetchTextures();
      }
    }
  }

  void _fetchSubCategoriesFor(String categoryName) {
    if (mounted) {
      setState(() {
        categoriesRow2 = _activeCategoriesMap[categoryName] ?? [];
      });
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
          // Clear laminate selection and coordinate dot immediately upon successful AI Try-on
          setState(() {
            _selectedTexture = null;
            _selection = null;
            _hasNewUnappliedEdit =
                true; // Mark that a new generated design is available to apply
          });
          context.read<ImageEditCubit>().clearSelection();

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
          child: BlocBuilder<ImageEditCubit, ImageEditState>(
            builder: (context, state) {
              final isApplying = state.isApplyLoading || _isPrecaching || _isUploading;
              return AbsorbPointer(
                absorbing: isApplying,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        // Top Image Preview Area (Fixed Height)
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.40,
                          child: ValueListenableBuilder<List<int>>(
                            valueListenable: _selectedIndicesNotifier,
                            builder: (context, selectedIndices, child) {
                              if (state.isApplyLoading || _isPrecaching) {
                                return _buildGeneratingBlock();
                              }
                              return _compareExpanded
                                  ? _buildTopComparisonSection(selectedIndices)
                                  : RepaintBoundary(
                                      child: _buildImageOverlaySection(),
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

                    // ── Full-screen upload overlay ─────────────────────────────
                    if (_isUploading)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.45),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3.5,
                                    color: TColors.primary,
                                  ),
                                ),
                                SizedBox(height: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
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
              onTap: () {
                final newPath = _userEdits.isNotEmpty
                    ? _userEdits[selectedIndices[0]].editedImageUrl
                    : widget.imageFile.path;

                setState(() {
                  _sessionId = const Uuid().v4(); // START NEW SESSION
                  _baseImage = newPath; // UPDATE BASE IMAGE
                  _currentAssetPreview =
                      null; // Clear overlay since it's now the base
                  _selectedIndicesNotifier.value =
                      []; // CLEAR SELECTIONS FOR NEW SESSION
                  _hasAppliedOnce = true;
                  _compareExpanded = false;
                  _editExpanded = true;
                  // CLEAR PREVIOUS LAMINATE AND AREA SO IT DOESN'T AUTO-APPLY
                  _selectedTexture = null;
                  _selectedColor = null;
                  _selectedCategory = null;
                  _selectedSubCategory = null;
                  _selection = null;
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
        onSelect: () {
          context.push(
            AppRoutes.imageFinalize,
            extra: {
              'editedImage': widget.imageFile.path,
              'usedLaminates': <Map<String, dynamic>>[],
            },
          );
          // Original image has no laminates — nothing to fetch
        },
        onEdit: () {
          setState(() {
            _sessionId = const Uuid().v4(); // START NEW SESSION
            _baseImage = widget.imageFile.path; // RESET TO ORIGINAL
            _parentEditId = null; // editing from original — no parent
            _currentAssetPreview = null;
            _selectedIndicesNotifier.value =
                []; // CLEAR SELECTIONS FOR NEW SESSION
            _hasAppliedOnce = true;
            _compareExpanded = false;
            _editExpanded = true;
            // CLEAR PREVIOUS LAMINATE AND AREA SO IT DOESN'T AUTO-APPLY
            _selectedTexture = null;
            _selectedColor = null;
            _selectedCategory = null;
            _selectedSubCategory = null;
            _selection = null;
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
            final record = _userEdits[index];
            // Walk the full parent chain in SQLite for cumulative laminates
            List<Map<String, dynamic>> usedLaminates = [];
            try {
              usedLaminates =
                  await EditHistoryRepository.getCumulativeLaminates(record.id);
            } catch (e) {
              debugPrint('getCumulativeLaminates error: $e');
            }

            // Fallback: current session history → record list → selected texture
            if (usedLaminates.isEmpty) {
              final cubit = context.read<ImageEditCubit>();
              for (var item in cubit.state.generatedHistory) {
                if (item['laminate'] != null) {
                  final lam = item['laminate'] as Map<String, dynamic>;
                  if (!usedLaminates.any((e) => e['id'] == lam['id'])) {
                    usedLaminates.add(lam);
                  }
                }
                if (item['generated'] == imgPath) break;
              }
              if (usedLaminates.isEmpty) {
                usedLaminates.addAll(record.usedLaminatesList);
              }
              if (usedLaminates.isEmpty && _selectedTexture != null) {
                usedLaminates.add(_selectedTexture!);
              }
            }

            if (context.mounted) {
              context.push(
                AppRoutes.imageFinalize,
                extra: {'editedImage': imgPath, 'usedLaminates': usedLaminates},
              );
            }
          },
          onEdit: () {
            final editRecord = _userEdits[index];
            setState(() {
              _sessionId = const Uuid().v4(); // START NEW SESSION
              _baseImage = imgPath; // UPDATE BASE IMAGE
              _parentEditId = editRecord.id; // track ancestry chain
              _currentAssetPreview =
                  null; // Clear overlay since it's now the base
              _selectedIndicesNotifier.value =
                  []; // CLEAR SELECTIONS FOR NEW SESSION
              _hasAppliedOnce = true;
              _compareExpanded = false;
              _editExpanded = true;
              // CLEAR PREVIOUS LAMINATE AND AREA SO IT DOESN'T AUTO-APPLY
              _selectedTexture = null;
              _selectedColor = null;
              _selectedCategory = null;
              _selectedSubCategory = null;
              _selection = null;
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
                    : Image.file(
                        widget.imageFile,
                        fit: BoxFit.cover,
                        cacheWidth: 400,
                      ))
              : (isNetwork
                    ? Image.network(
                        path!,
                        fit: BoxFit.cover,
                        cacheWidth: 400,
                        errorBuilder: (c, e, s) => Image.file(
                          widget.imageFile,
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                        ),
                      )
                    : (path!.startsWith('/') || path.contains('tryon_result'))
                    ? Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        cacheWidth: 400,
                        errorBuilder: (c, e, s) => Image.file(
                          widget.imageFile,
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                        ),
                      )
                    : Image.asset(
                        path,
                        fit: BoxFit.cover,
                        cacheWidth: 400,
                        errorBuilder: (c, e, s) => Image.file(
                          widget.imageFile,
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                        ),
                      )),
          _buildOverlayButtons(
            bottom: 8,
            isGrid: true,
            showRemove: !isOriginal,
            showSelect: !isOriginal,
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
    bool showSelect = true,
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
          if (showSelect) ...[
            const SizedBox(width: 8),
            _buildCircleButton(
              icon: "tick.png",
              onTap: onSelect ?? () {},
              size: iconSize,
              padding: padding,
            ),
          ],
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

  SelectionMode _hitTestHandles(Offset localPosition) {
    if (_selection == null) return SelectionMode.none;

    final double touchRadius = 24.0;

    final double left = _selection!.left;
    final double top = _selection!.top;
    final double right = _selection!.left + _selection!.width;
    final double bottom = _selection!.top + _selection!.height;

    final Offset topLeft = Offset(left, top);
    final Offset topRight = Offset(right, top);
    final Offset bottomLeft = Offset(left, bottom);
    final Offset bottomRight = Offset(right, bottom);

    // 1. Check corners first
    if ((localPosition - topLeft).distance <= touchRadius) {
      return SelectionMode.resizeTopLeft;
    }
    if ((localPosition - topRight).distance <= touchRadius) {
      return SelectionMode.resizeTopRight;
    }
    if ((localPosition - bottomLeft).distance <= touchRadius) {
      return SelectionMode.resizeBottomLeft;
    }
    if ((localPosition - bottomRight).distance <= touchRadius) {
      return SelectionMode.resizeBottomRight;
    }

    // Helper to calculate distance from point to vertical segment
    double distToVert(Offset p, double targetX, double startY, double endY) {
      final double clampedY = p.dy.clamp(startY, endY);
      return (p - Offset(targetX, clampedY)).distance;
    }

    // Helper to calculate distance from point to horizontal segment
    double distToHoriz(Offset p, double targetY, double startX, double endX) {
      final double clampedX = p.dx.clamp(startX, endX);
      return (p - Offset(clampedX, targetY)).distance;
    }

    // 2. Check edges
    if (distToVert(localPosition, left, top, bottom) <= touchRadius) {
      return SelectionMode.resizeLeft;
    }
    if (distToVert(localPosition, right, top, bottom) <= touchRadius) {
      return SelectionMode.resizeRight;
    }
    if (distToHoriz(localPosition, top, left, right) <= touchRadius) {
      return SelectionMode.resizeTop;
    }
    if (distToHoriz(localPosition, bottom, left, right) <= touchRadius) {
      return SelectionMode.resizeBottom;
    }

    return SelectionMode.none;
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
            panEnabled: false,
            scaleEnabled: false,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                final viewSize = Size(
                  MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height * 0.40,
                );
                final localPos = event.localPosition;
                
                SelectionMode detectedMode = SelectionMode.none;
                if (_selection != null) {
                  detectedMode = _hitTestHandles(localPos);
                }
                
                if (detectedMode != SelectionMode.none) {
                  setState(() {
                    _mode = detectedMode;
                  });
                } else if (_selection != null && _selection!.rect.contains(localPos)) {
                  setState(() {
                    _mode = SelectionMode.moving;
                  });
                } else {
                  setState(() {
                    _dragStart = localPos;
                    _selection = SelectionRect(
                      left: localPos.dx.clamp(0.0, viewSize.width),
                      top: localPos.dy.clamp(0.0, viewSize.height),
                      width: 0,
                      height: 0,
                    );
                    _mode = SelectionMode.creating;
                  });
                }
              },
              onPointerMove: (event) {
                final viewSize = Size(
                  MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height * 0.40,
                );
                final localPos = event.localPosition;
                
                if (_mode == SelectionMode.creating && _dragStart != null) {
                  final double currentX = localPos.dx.clamp(0.0, viewSize.width);
                  final double currentY = localPos.dy.clamp(0.0, viewSize.height);
                  
                  final double left = math.min(_dragStart!.dx, currentX);
                  final double top = math.min(_dragStart!.dy, currentY);
                  final double width = (currentX - _dragStart!.dx).abs();
                  final double height = (currentY - _dragStart!.dy).abs();
                  
                  setState(() {
                    _selection = SelectionRect(
                      left: left,
                      top: top,
                      width: width,
                      height: height,
                    );
                  });
                } else if (_mode == SelectionMode.moving && _selection != null) {
                  double newLeft = _selection!.left + event.delta.dx;
                  double newTop = _selection!.top + event.delta.dy;
                  
                  newLeft = newLeft.clamp(0.0, viewSize.width - _selection!.width);
                  newTop = newTop.clamp(0.0, viewSize.height - _selection!.height);
                  
                  setState(() {
                    _selection!.left = newLeft;
                    _selection!.top = newTop;
                  });
                } else if (_selection != null) {
                  double left = _selection!.left;
                  double top = _selection!.top;
                  double right = _selection!.left + _selection!.width;
                  double bottom = _selection!.top + _selection!.height;
                  
                  final double localX = localPos.dx.clamp(0.0, viewSize.width);
                  final double localY = localPos.dy.clamp(0.0, viewSize.height);
                  
                  switch (_mode) {
                    case SelectionMode.resizeTopLeft:
                      left = localX.clamp(0.0, right - 10.0);
                      top = localY.clamp(0.0, bottom - 10.0);
                      break;
                    case SelectionMode.resizeTopRight:
                      right = localX.clamp(left + 10.0, viewSize.width);
                      top = localY.clamp(0.0, bottom - 10.0);
                      break;
                    case SelectionMode.resizeBottomLeft:
                      left = localX.clamp(0.0, right - 10.0);
                      bottom = localY.clamp(top + 10.0, viewSize.height);
                      break;
                    case SelectionMode.resizeBottomRight:
                      right = localX.clamp(left + 10.0, viewSize.width);
                      bottom = localY.clamp(top + 10.0, viewSize.height);
                      break;
                    case SelectionMode.resizeLeft:
                      left = localX.clamp(0.0, right - 10.0);
                      break;
                    case SelectionMode.resizeRight:
                      right = localX.clamp(left + 10.0, viewSize.width);
                      break;
                    case SelectionMode.resizeTop:
                      top = localY.clamp(0.0, bottom - 10.0);
                      break;
                    case SelectionMode.resizeBottom:
                      bottom = localY.clamp(top + 10.0, viewSize.height);
                      break;
                    default:
                      break;
                  }
                  
                  setState(() {
                    _selection = SelectionRect(
                      left: left,
                      top: top,
                      width: right - left,
                      height: bottom - top,
                    );
                  });
                }
              },
              onPointerUp: (event) {
                if (_selection != null) {
                  if (_selection!.width < 10.0 || _selection!.height < 10.0) {
                    setState(() {
                      _selection = null;
                      _mode = SelectionMode.none;
                    });
                    context.read<ImageEditCubit>().clearSelection();
                    return;
                  }
                }
                
                setState(() {
                  _mode = SelectionMode.none;
                });
                
                if (_selection != null) {
                  final viewSize = Size(
                    MediaQuery.of(context).size.width,
                    MediaQuery.of(context).size.height * 0.40,
                  );
                  
                  final Offset localTopLeft = Offset(_selection!.left, _selection!.top);
                  final Offset localBottomRight = Offset(_selection!.left + _selection!.width, _selection!.top + _selection!.height);
                  
                  final Offset originalTopLeft = _mapLocalToOriginal(localTopLeft, viewSize);
                  final Offset originalBottomRight = _mapLocalToOriginal(localBottomRight, viewSize);
                  
                  final int originalLeft = originalTopLeft.dx.round();
                  final int originalTop = originalTopLeft.dy.round();
                  final int originalRight = originalBottomRight.dx.round();
                  final int originalBottom = originalBottomRight.dy.round();
                  
                  final areaData = {
                    "left": originalLeft,
                    "top": originalTop,
                    "right": originalRight,
                    "bottom": originalBottom,
                  };
                  
                  debugPrint("Selected Area (Original Coordinates): $areaData");
                  context.read<ImageEditCubit>().selectArea(areaData);
                }
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

                  // Selected Coordinate Dot overlay removed and replaced with selection painter
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: SelectionPainter(
                          selection: _selection?.rect,
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

    final imageWidget = Padding(
      padding: const EdgeInsets.all(5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl.isNotEmpty
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
            if (isSelected)
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFD9D9D9),
                      width: 5,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _showTextureDetailPopup(
                    context,
                    Map<String, dynamic>.from(texture as Map),
                  );
                },
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 0.8,
                        ),
                      ),
                      child: const Icon(
                        Icons.visibility_outlined,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTap: () {
        if (_selection == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please select an area on the image first."),
              backgroundColor: Colors.amber,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
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
    if (state.currentGeneratedImage == null) return;
    if (_isUploading) return;
    setState(() => _isUploading = true);

    try {
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

      // 1. POST TO SERVER (THE FINAL STACKED IMAGE ON TOP)
      String? responseId;
      if (widget.image_id != null) {
        try {
          debugPrint(
            '\n================== API TRACE: APPLY / FINALIZE ==================',
          );
          debugPrint(
            '📡 API_LOG: Hit /me/edits to save top final stacked image to backend.',
          );
          debugPrint(
            '=========================================================\n',
          );
          final EditRecord? record = await _userEditsService.postEdit(
            editedFile: File(state.currentGeneratedImage!),
            furnitureId: widget.image_id!,
            email: _ownerEmail,
          );
          if (record != null && record.id.isNotEmpty) {
            responseId = record.id;
            debugPrint(
              "✅ Applied design successfully posted to server. Record ID: $responseId",
            );
          }
        } catch (e) {
          debugPrint("❌ Failed to post applied design to server: $e");
        }
      }

      // 2. SAVE TO LOCAL DATABASE WITH RESPONSE ID AS THE SESSION ID
      // Generate the final record ID upfront so we can track it as the
      // parent for any subsequent editing session.
      final String newEditId = responseId ?? const Uuid().v4();
      if (widget.image_id != null) {
        try {
          final cubit = context.read<ImageEditCubit>();
          await cubit.saveToDatabase(
            imgPath: state.currentGeneratedImage!,
            laminate: state.selectedPattern,
            customSessionId: newEditId,
            parentEditId: _parentEditId, // link to ancestor
          );
          // This finalized edit now becomes the parent for the next session
          _parentEditId = newEditId;
        } catch (e) {
          debugPrint("❌ Error saving local edit: $e");
        }
      }
      final String finalizedImage = state.currentGeneratedImage!;
      if (mounted) {
        setState(() {
          _baseImage =
              finalizedImage; // Set the base to the newly finalized stacked image
          _currentAssetPreview =
              null; // Clear the preview overlay since it is now the base
          _compareExpanded = true;
          _editExpanded = false;
          _hasAppliedOnce = true;
          _hasNewUnappliedEdit =
              false; // Reset since the current edit has been successfully finalized

          // CLEAR PREVIOUS LAMINATE AND AREA SO IT DOESN'T AUTO-APPLY ON NEXT EDIT
          _selectedTexture = null;
          _selectedColor = null;
          _selectedSubCategory = null;
          _selection = null;
        });

        // RE-INIT CUBIT WITH NEW SESSION STARTING FROM THE FINALIZED IMAGE BASE
        context.read<ImageEditCubit>().initOriginalImage(
          _baseImage,
          furnitureId: widget.image_id,
          ownerId: _ownerEmail,
          sessionId: _sessionId,
        );
        _fetchUserEditHistory(); // REFRESH UI FOR NEW SESSION
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _navigateToFinalizePage() async {
    List<Map<String, dynamic>> usedLaminates = [];
    String finalImage = widget.imageFile.path;

    final selectedIndices = _selectedIndicesNotifier.value;
    if (selectedIndices.isNotEmpty && _userEdits.isNotEmpty) {
      final selectedIndex = selectedIndices.first;
      if (selectedIndex >= 0 && selectedIndex < _userEdits.length) {
        final selectedRecord = _userEdits[selectedIndex];
        finalImage = selectedRecord.editedImageUrl;
        // Walk the full parent chain for cumulative laminates
        try {
          usedLaminates = await EditHistoryRepository.getCumulativeLaminates(
            selectedRecord.id,
          );
        } catch (e) {
          debugPrint('getCumulativeLaminates error: $e');
          usedLaminates = List.from(selectedRecord.usedLaminatesList);
        }
      }
    } else if (_userEdits.isNotEmpty) {
      final latestRecord = _userEdits.first;
      finalImage = latestRecord.editedImageUrl;
      try {
        usedLaminates = await EditHistoryRepository.getCumulativeLaminates(
          latestRecord.id,
        );
      } catch (e) {
        debugPrint('getCumulativeLaminates error: $e');
        usedLaminates = List.from(latestRecord.usedLaminatesList);
      }
    } else {
      // Fallback: pull from in-memory cubit history (no DB record yet)
      final state = context.read<ImageEditCubit>().state;
      final cubit = context.read<ImageEditCubit>();
      for (var item in cubit.state.generatedHistory) {
        if (item['laminate'] != null) {
          final lam = item['laminate'] as Map<String, dynamic>;
          if (!usedLaminates.any((element) => element['id'] == lam['id'])) {
            usedLaminates.add(lam);
          }
        }
        if (item['generated'] == state.currentGeneratedImage) break;
      }
      if (usedLaminates.isEmpty && _selectedTexture != null) {
        usedLaminates.add(_selectedTexture!);
      }
      finalImage = state.currentGeneratedImage ?? widget.imageFile.path;
    }

    if (mounted) {
      context.push(
        AppRoutes.imageFinalize,
        extra: {'editedImage': finalImage, 'usedLaminates': usedLaminates},
      );
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
                          onTap: _navigateToFinalizePage,
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
                    final bool hasResult =
                        state.currentGeneratedImage != null &&
                        _hasNewUnappliedEdit;

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
                      onTap: _navigateToFinalizePage,
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

class SelectionRect {
  double left;
  double top;
  double width;
  double height;

  SelectionRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  Rect get rect => Rect.fromLTWH(left, top, width, height);
}

enum SelectionMode {
  none,
  creating,
  moving,
  resizeTopLeft,
  resizeTopRight,
  resizeBottomLeft,
  resizeBottomRight,
  resizeLeft,
  resizeRight,
  resizeTop,
  resizeBottom,
}

class SelectionPainter extends CustomPainter {
  final Rect? selection;

  SelectionPainter({required this.selection});

  @override
  void paint(Canvas canvas, Size size) {
    if (selection == null) return;

    final double left = selection!.left;
    final double top = selection!.top;
    final double right = selection!.right;
    final double bottom = selection!.bottom;
    final double width = selection!.width;
    final double height = selection!.height;

    // 1. Draw dark background overlay outside selection
    final Paint overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.45)
      ..style = PaintingStyle.fill;

    final Path backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path selectionPath = Path()..addRect(selection!);
    final Path overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      selectionPath,
    );
    canvas.drawPath(overlayPath, overlayPaint);

    // 2. Draw Rule of Thirds grid lines inside selection
    final Paint gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(left + width / 3, top), Offset(left + width / 3, bottom), gridPaint);
    canvas.drawLine(Offset(left + 2 * width / 3, top), Offset(left + 2 * width / 3, bottom), gridPaint);
    canvas.drawLine(Offset(left, top + height / 3), Offset(right, top + height / 3), gridPaint);
    canvas.drawLine(Offset(left, top + 2 * height / 3), Offset(right, top + 2 * height / 3), gridPaint);

    // 3. Draw thin selection border
    final Paint borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(selection!, borderPaint);

    // 4. Draw thick corner crop handles (L-shape)
    final Paint handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final double cornerLength = 16.0;

    // Top-Left
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), handlePaint);
    canvas.drawLine(Offset(left, top), Offset(left, top + cornerLength), handlePaint);

    // Top-Right
    canvas.drawLine(Offset(right, top), Offset(right - cornerLength, top), handlePaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLength), handlePaint);

    // Bottom-Left
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLength, bottom), handlePaint);
    canvas.drawLine(Offset(left, bottom), Offset(left, bottom - cornerLength), handlePaint);

    // Bottom-Right
    canvas.drawLine(Offset(right, bottom), Offset(right - cornerLength, bottom), handlePaint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLength), handlePaint);

    // 5. Draw thick edge middle handles (horizontal / vertical bars)
    final double midX = (left + right) / 2;
    final double midY = (top + bottom) / 2;
    final double edgeLength = 12.0;

    // Left Edge Middle
    canvas.drawLine(Offset(left, midY - edgeLength), Offset(left, midY + edgeLength), handlePaint);
    // Right Edge Middle
    canvas.drawLine(Offset(right, midY - edgeLength), Offset(right, midY + edgeLength), handlePaint);
    // Top Edge Middle
    canvas.drawLine(Offset(midX - edgeLength, top), Offset(midX + edgeLength, top), handlePaint);
    // Bottom Edge Middle
    canvas.drawLine(Offset(midX - edgeLength, bottom), Offset(midX + edgeLength, bottom), handlePaint);
  }

  @override
  bool shouldRepaint(covariant SelectionPainter oldDelegate) {
    return oldDelegate.selection != selection;
  }
}
