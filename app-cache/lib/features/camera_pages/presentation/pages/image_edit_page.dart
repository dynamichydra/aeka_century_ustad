import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
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
import 'package:material_symbols_icons/material_symbols_icons.dart';

// Extracted Architectural Imports
import 'package:century_ai/features/camera_pages/models/selection_models.dart';
import 'package:century_ai/features/camera_pages/services/coordinate_mapper.dart';
import 'package:century_ai/features/camera_pages/services/measurement_service.dart';
import 'package:century_ai/features/camera_pages/controllers/history_controller.dart';
import 'package:century_ai/features/camera_pages/controllers/texture_controller.dart';
import 'package:century_ai/features/camera_pages/controllers/selection_controller.dart';
import 'package:century_ai/features/camera_pages/controllers/zoom_controller.dart';

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

class _ImageEditPageState extends State<ImageEditPage>
    with SingleTickerProviderStateMixin {
  final SelectionController _selectionController = const SelectionController();
  late final TextureController _textureController;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _widthEditController = TextEditingController();
  final TextEditingController _heightEditController = TextEditingController();
  double? _systemArea;
  double _customWidthInches = 24.0;
  double _customHeightInches = 30.0;
  bool _editingWidth = false;
  bool _editingHeight = false;
  bool _justSaved = false;

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
  bool _isSearching = false;

  bool _compareExpanded = false;
  bool _editExpanded = true;
  bool _hasAppliedOnce = false;
  bool _hasNewUnappliedEdit =
      false; // Tracks if a new AI generation is available but not yet finalized
  final ValueNotifier<List<int>> _selectedIndicesNotifier = ValueNotifier([]);
  double _sliderPosition = 0.5;

  final UserEditsService _userEditsService = UserEditsService();
  final String _ownerEmail = "user13@gmail.com";
  List<EditRecord> _userEdits = [];

  /// ID of the edit_history row that the current session is built upon.
  /// Null for the first edit on an original image.
  String? _parentEditId;
  bool _isLoadingEdits = false;

  // ── Marching ants animation (preview mode) ────────────────────────────────
  late final AnimationController _marchingAntsController;
  ui.Image? _decodedMaskImage; // decoded mask for the preview painter
  Path? _maskFillPath; // path for reverse selection overlay hole
  Path? _maskEdgePath; // path for marching ants outline

  // Dummy versions fallback if no network edits yet

  // Rectangle Selection Variables
  SelectionRect? _selection;
  SelectionRect? _backupSelection;
  Offset? _dragStart;
  SelectionMode _mode = SelectionMode.none;
  final Map<int, Offset> _activePointers = {};
  bool _isPanning = false;
  double _initialPointerDistance = 1.0;
  double _containScale = 1.0;
  double _minScale = 1.0;
  double _minZoomLimit = 1.0;
  double _initialScale = 1.0;

  // Track the most recent edit session info.
  // When an edit completes, we store its database ID so further edits
  // can link back to it via parent_edit_id.

  final TransformationController _transformationController =
      TransformationController();

  double? _originalImageWidth;
  double? _originalImageHeight;

  Future<void> _getImageDimensions() async {
    try {
      // Evict from cache to get fresh dimensions and pixels from disk
      await FileImage(widget.imageFile).evict();
      await FileImage(File(_baseImage)).evict();

      final Completer<ui.Image> completer = Completer();
      final ImageStream stream = FileImage(
        File(_baseImage),
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
        final double imgW = image.width.toDouble();
        final double imgH = image.height.toDouble();

        // Viewport size for the top image area
        final double vpW = MediaQuery.of(context).size.width;
        final double vpH = MediaQuery.of(context).size.height * 0.40;

        // coverScale = scale at which the image exactly fills the viewport (BoxFit.cover math)
        final double coverScale = math.max(vpW / imgW, vpH / imgH);
        // containScale = scale at which the entire image fits inside the viewport (BoxFit.contain math)
        final double containScale = math.min(vpW / imgW, vpH / imgH);
        final double minZoom = containScale / coverScale;

        setState(() {
          _originalImageWidth = imgW;
          _originalImageHeight = imgH;
          // _minScale stores the cover scale for OverflowBox sizing.
          // TransformationController stays at identity — OverflowBox
          // centres the image in the Stack, matching BoxFit.cover visually at scale 1.0.
          _minScale = coverScale;
          _containScale = containScale;
          _minZoomLimit = minZoom;
          // _initialScale stays 1.0 (the TC baseline for pinch gestures).
        });
        debugPrint(
          '📸 Image: ${imgW}x${imgH} | VP: ${vpW}x${vpH} | containScale: $containScale',
        );
      }
    } catch (e) {
      debugPrint('❌ Error getting image dimensions: $e');
    }
  }

  double get _currentDisplayScale {
    // if (_hasAppliedOnce) {
    //   return _containScale;
    // }
    return _minScale;
  }

  double get _currentMinZoomLimit {
    // if (_hasAppliedOnce) {
    //   return 1.0;
    // }
    return _minZoomLimit;
  }

  Size _getViewSize(BuildContext context) {
    return CoordinateMapper.getViewSize(
      MediaQuery.of(context).size.width,
      MediaQuery.of(context).size.height,
    );
  }

  Rect _getImageRect(BuildContext context) {
    return CoordinateMapper.getImageRect(
      viewSize: _getViewSize(context),
      originalImageWidth: _originalImageWidth,
      originalImageHeight: _originalImageHeight,
      currentDisplayScale: _currentDisplayScale,
    );
  }

  Offset _mapLocalToOriginal(Offset localPos, Size viewSize) {
    return CoordinateMapper.mapLocalToOriginal(
      localPos: localPos,
      viewSize: viewSize,
      originalImageWidth: _originalImageWidth,
      originalImageHeight: _originalImageHeight,
      currentDisplayScale: _currentDisplayScale,
    );
  }

  void _zoomIn() {
    final double vpW = MediaQuery.of(context).size.width;
    final double vpH = MediaQuery.of(context).size.height * 0.40;
    setState(() {
      _transformationController.value = ZoomController.calculateZoomIn(
        currentMatrix: _transformationController.value,
        minZoomLimit: _currentMinZoomLimit,
        maxScale: 4.0,
        viewportWidth: vpW,
        viewportHeight: vpH,
        originalImageWidth: _originalImageWidth,
        originalImageHeight: _originalImageHeight,
        displayScale: _currentDisplayScale,
      );
    });
  }

  void _zoomOut() {
    final double vpW = MediaQuery.of(context).size.width;
    final double vpH = MediaQuery.of(context).size.height * 0.40;
    setState(() {
      _transformationController.value = ZoomController.calculateZoomOut(
        currentMatrix: _transformationController.value,
        minZoomLimit: _currentMinZoomLimit,
        maxScale: 4.0,
        viewportWidth: vpW,
        viewportHeight: vpH,
        originalImageWidth: _originalImageWidth,
        originalImageHeight: _originalImageHeight,
        displayScale: _currentDisplayScale,
      );
    });
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
    _marchingAntsController.dispose();
    _decodedMaskImage?.dispose();
    _transformationController.dispose();
    _searchController.dispose();
    _areaController.dispose();
    _widthEditController.dispose();
    _heightEditController.dispose();
    _selectedIndicesNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _textureController = TextureController(
      laminateApi: _laminateApi,
      cacheService: _cacheService,
      isExterior: widget.isExterior,
    );
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

    // Initialize marching ants animation controller
    _marchingAntsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

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
              systemArea: e.systemArea,
              userArea: e.userArea,
            ),
          )
          .toList();

      final merged = HistoryController.mergeAndDeduplicate(
        networkEdits: filteredNetwork,
        localEdits: convertedLocal,
      );

      if (mounted) {
        setState(() {
          _userEdits = merged;
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

  Future<void> _fetchTexturesBySku(String skuId) async {
    if (skuId.trim().isEmpty) return;

    setState(() {
      _apiTextures = [];
      _isLoadingTextures = true;
      _isSearching = true;
    });

    try {
      final list = await _textureController.fetchTexturesBySku(skuId);
      if (mounted) {
        setState(() {
          _apiTextures = list;
          _isLoadingTextures = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error searching textures by SKU: $e");
      if (mounted) {
        setState(() {
          _isLoadingTextures = false;
          _apiTextures = [];
        });
      }
    }
  }

  void _clearSearchAndRestore() {
    setState(() {
      _searchController.clear();
      _isSearching = false;
      _apiTextures = [];
    });
    if (_selectedColor != null) {
      _fetchTexturesByColor();
    } else if (_selectedCategory != null) {
      _fetchTextures();
    } else {
      getLamCategory();
    }
  }

  Future<void> _fetchTextures() async {
    if (_selectedCategory == null) return;

    setState(() {
      _isLoadingTextures = true;
    });

    try {
      final list = await _textureController.fetchTexturesByCategory(
        category: _selectedCategory!,
        subcategory: _selectedSubCategory,
      );
      if (mounted) {
        setState(() {
          _apiTextures = list;
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

    setState(() {
      _isLoadingTextures = true;
    });

    try {
      final list = await _textureController.fetchTexturesByColor(_selectedColor!["hex"]);
      if (mounted) {
        setState(() {
          _apiTextures = list;
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

  Map<String, List<String>> get _activeCategoriesMap => _textureController.activeCategoriesMap;

  List<String> categoriesRow1 = [""];
  List<String> categoriesRow2 = [""];

  Future<void> getLamCategory() async {
    if (mounted) {
      setState(() {
        categoriesRow1 = _textureController.getCategories();
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
        categoriesRow2 = _textureController.getSubCategories(categoryName);
      });
    }
  }

  // ── Mask decoding for preview painter ──────────────────────────────────────
  Future<void> _decodeMaskImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final Path fillPath = Path();
      final Path edgePath = Path();

      if (byteData != null) {
        int whiteCount = 0;
        int blackCount = 0;
        final int width = image.width;
        final int height = image.height;

        bool isWhite(int x, int y) {
          if (x < 0 || x >= width || y < 0 || y >= height) return false;
          final int offset = (y * width + x) * 4;
          final int r = byteData.getUint8(offset);
          final int g = byteData.getUint8(offset + 1);
          final int b = byteData.getUint8(offset + 2);
          return r > 200 && g > 200 && b > 200; // luminance threshold
        }

        for (int y = 0; y < height; y++) {
          int startX = -1;
          for (int x = 0; x < width; x++) {
            final white = isWhite(x, y);
            if (white) {
              whiteCount++;
              if (startX == -1) startX = x;

              // Check if edge
              if (!isWhite(x - 1, y) ||
                  !isWhite(x + 1, y) ||
                  !isWhite(x, y - 1) ||
                  !isWhite(x, y + 1)) {
                edgePath.addRect(
                  Rect.fromLTWH(x.toDouble() - 1, y.toDouble() - 1, 3.0, 3.0),
                );
              }
            } else {
              blackCount++;
              if (startX != -1) {
                fillPath.addRect(
                  Rect.fromLTRB(
                    startX.toDouble(),
                    y.toDouble(),
                    x.toDouble(),
                    (y + 1).toDouble(),
                  ),
                );
                startX = -1;
              }
            }
          }
          if (startX != -1) {
            fillPath.addRect(
              Rect.fromLTRB(
                startX.toDouble(),
                y.toDouble(),
                width.toDouble(),
                (y + 1).toDouble(),
              ),
            );
          }
        }

        debugPrint('--- Mask Pixel Stats ---');
        debugPrint('Mask Width: $width | Height: $height');
        debugPrint('White Pixels: $whiteCount | Black Pixels: $blackCount');
      }

      if (mounted) {
        setState(() {
          _decodedMaskImage?.dispose();
          _decodedMaskImage = image;
          _maskFillPath = fillPath;
          _maskEdgePath = edgePath;
        });
      }
    } catch (e) {
      debugPrint('❌ _decodeMaskImage error: $e');
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
        }

        // V4 flow: When a new edited image arrives, directly replace the preview
        if (state.editedImageFile != null &&
            !state.isGenerating &&
            !state.isApplyLoading) {
          final newImage = state.editedImageFile!;
          if (_currentAssetPreview != newImage) {
            setState(() {
              _selection = null;
              _selectedTexture = null;
              _baseImage = newImage;
              _hasNewUnappliedEdit = true;
              _isPrecaching = true;
              _currentAssetPreview = newImage;
            });
            final imageProvider = FileImage(File(newImage));
            precacheImage(imageProvider, context)
                .then((_) {
                  if (mounted) {
                    setState(() {
                      _isPrecaching = false;
                    });
                  }
                })
                .catchError((e) {
                  if (mounted) setState(() => _isPrecaching = false);
                });
          }
        }

        // When undo returns to original (editedImageFile is null), clear the preview
        if (state.editedImageFile == null &&
            state.currentGeneratedImage == null) {
          if (_currentAssetPreview != null) {
            setState(() {
              _currentAssetPreview = null;
              _baseImage = state.originalImage ?? widget.imageFile.path;
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
              final isApplying =
                  state.isApplyLoading || _isPrecaching || _isUploading;
              return AbsorbPointer(
                absorbing: isApplying,
                child: Stack(
                  children: [
                    Column(
                      children: [
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
                                      child: _buildImageOverlaySection(state),
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
          BlocBuilder<ImageEditCubit, ImageEditState>(
            builder: (context, state) {
              final bool canUndo =
                  state.generatedHistory.isNotEmpty || (_parentEditId != null);
              final bool canRedo = state.redoHistory.isNotEmpty;
              return _buildHeaderTile(
                title: "Edit & Design",
                iconImg: "edit.png",
                isActive: _editExpanded,
                showArrow: _hasAppliedOnce,
                onTap: _hasAppliedOnce
                    ? () {
                        setState(() {
                          _editExpanded = !_editExpanded;
                          if (_editExpanded) _compareExpanded = false;
                        });
                      }
                    : () {},
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: canUndo ? 1.0 : 0.4,
                      child: GestureDetector(
                        onTap: canUndo ? () => _handleUndo(state) : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Symbols.undo, // Curved arrow pointing left
                                color: Colors.black.withOpacity(0.7),
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Undo",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // const SizedBox(width: 8),
                    // Opacity(
                    //   opacity: canRedo ? 1.0 : 0.4,
                    //   child: GestureDetector(
                    //     onTap: canRedo ? () => _handleRedo(state) : null,
                    //     child: Container(
                    //       padding: const EdgeInsets.symmetric(
                    //         horizontal: 10,
                    //         vertical: 4,
                    //       ),
                    //       decoration: BoxDecoration(
                    //         color: Colors.white,
                    //         borderRadius: BorderRadius.circular(20),
                    //         border: Border.all(
                    //           color: Colors.grey.shade300,
                    //           width: 0.8,
                    //         ),
                    //       ),
                    //       child: Row(
                    //         mainAxisSize: MainAxisSize.min,
                    //         children: [
                    //           Icon(
                    //             Symbols.redo, // Curved arrow pointing right
                    //             color: Colors.black.withOpacity(0.7),
                    //             size: 12,
                    //           ),
                    //           const SizedBox(width: 4),
                    //           Text(
                    //             "Redo",
                    //             style: TextStyle(
                    //               fontSize: 10,
                    //               fontWeight: FontWeight.w500,
                    //               color: Colors.black.withOpacity(0.7),
                    //             ),
                    //           ),
                    //         ],
                    //       ),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              );
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
    Widget? trailing,
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
            if (trailing != null)
              trailing
            else if (showArrow)
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
          const SizedBox(height: 8),
          if (!_isSearching) ...[
            const Text(
              "Select Color",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            _buildColorSelection(),
            const Text(
              "Select Textures & Patterns",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            _buildCategorySelection(),
            const SizedBox(height: 12),
          ],
          RepaintBoundary(child: _buildTextureSelection()),
          if (_selection != null) ...[
            const SizedBox(height: 8),
            // _buildAreaInputSection(),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildAreaInputSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.square_foot, color: TColors.primary, size: 16),
              const SizedBox(width: 6),
              const Text(
                "Laminate Area Required",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "System Prediction",
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.black45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _systemArea != null ? "$_systemArea sq. ft." : "--",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "User Override",
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.black45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _areaController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 0,
                          ),
                          suffixText: "sq. ft.",
                          suffixStyle: const TextStyle(
                            fontSize: 9,
                            color: Colors.black45,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: TColors.primary,
                            ),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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



  Widget _buildImageOverlaySection(ImageEditState state) {
    return Stack(
      children: [
        InteractiveViewer(
          clipBehavior: Clip.none,
          transformationController: _transformationController,
          minScale: _currentMinZoomLimit,
          maxScale: 4.0,
          boundaryMargin: EdgeInsets.zero,
          panEnabled: false,
          scaleEnabled: false,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              _activePointers[event.pointer] = event.position;

              if (_activePointers.length == 1) {
                _backupSelection = _selection;
              }

              if (_activePointers.length >= 2) {
                setState(() {
                  _selection = _backupSelection;
                  _mode = SelectionMode.none;
                  _isPanning = true;

                  // Initialize pinch baseline
                  final keys = _activePointers.keys.toList();
                  final p1 = _activePointers[keys[0]]!;
                  final p2 = _activePointers[keys[1]]!;
                  _initialPointerDistance = (p1 - p2).distance;
                  if (_initialPointerDistance < 1.0) {
                    _initialPointerDistance = 1.0;
                  }
                  _initialScale = _transformationController.value
                      .getMaxScaleOnAxis();
                });
                return;
              }

              if (_isPanning) return;

              final localPos = event.localPosition;
              _dragStart = localPos;
              final Rect imageRect = _getImageRect(context);
              final double imgL = imageRect.left;
              final double imgR = imageRect.right;
              final double imgT = imageRect.top;
              final double imgB = imageRect.bottom;

              if (_selection != null &&
                  (_selectionController.isPointInHorizontalOverlay(
                        selection: _selection,
                        localPos: localPos,
                        imageRect: imageRect,
                      ) ||
                      _selectionController.isPointInVerticalOverlay(
                        selection: _selection,
                        localPos: localPos,
                        imageRect: imageRect,
                      ))) {
                return;
              }

              SelectionMode detectedMode = SelectionMode.none;
              if (_selection != null) {
                detectedMode = _selectionController.hitTestHandles(
                  selection: _selection,
                  localPosition: localPos,
                );
              }

              double snap(double val, double minBound, double maxBound) {
                return val.clamp(minBound, maxBound);
              }

              if (detectedMode != SelectionMode.none) {
                setState(() {
                  _mode = detectedMode;
                });
              } else if (_selection == null) {
                setState(() {
                  _dragStart = Offset(
                    snap(localPos.dx, imgL, imgR),
                    snap(localPos.dy, imgT, imgB),
                  );
                  _selection = SelectionRect(
                    left: _dragStart!.dx,
                    top: _dragStart!.dy,
                    width: 0,
                    height: 0,
                  );
                  _mode = SelectionMode.creating;
                  _editingWidth = false;
                  _editingHeight = false;
                });
              } else {
                setState(() {
                  _mode = SelectionMode.none;
                });
              }
            },
            onPointerMove: (event) {
              if (_activePointers.length >= 2 || _isPanning) {
                final Offset? oldPos = _activePointers[event.pointer];
                _activePointers[event.pointer] = event.position;

                if (oldPos != null && oldPos != event.position) {
                  final viewSize = Size(
                    MediaQuery.of(context).size.width,
                    MediaQuery.of(context).size.height * 0.40,
                  );

                  _transformationController.value = ZoomController.calculatePinchPan(
                    currentMatrix: _transformationController.value,
                    activePointers: _activePointers,
                    eventPosition: event.position,
                    oldPos: oldPos,
                    viewSize: viewSize,
                    originalImageWidth: _originalImageWidth,
                    originalImageHeight: _originalImageHeight,
                    displayScale: _currentDisplayScale,
                    initialPointerDistance: _initialPointerDistance,
                    initialScale: _initialScale,
                    minZoomLimit: _currentMinZoomLimit,
                    maxScale: 4.0,
                  );
                }
                return;
              }

              final localPos = event.localPosition;
              final Rect imageRect = _getImageRect(context);


              if (_mode == SelectionMode.creating && _dragStart != null) {
                setState(() {
                  _selection = _selectionController.createSelection(
                    dragStart: _dragStart!,
                    currentPos: localPos,
                    imageRect: imageRect,
                  );
                });
              } else if (_mode == SelectionMode.moving && _selection != null) {
                setState(() {
                  _selection = _selectionController.moveSelection(
                    selection: _selection!,
                    delta: event.delta,
                    imageRect: imageRect,
                  );
                });
              } else if (_selection != null && _mode != SelectionMode.none) {
                setState(() {
                  _selection = _selectionController.resizeSelection(
                    selection: _selection!,
                    mode: _mode,
                    localPos: localPos,
                    imageRect: imageRect,
                  );
                });
              }
            },
            onPointerUp: (event) {
              if (_justSaved) {
                _justSaved = false;
                _activePointers.remove(event.pointer);
                if (_activePointers.isEmpty) {
                  _backupSelection = null;
                }
                return;
              }
              final localPos = event.localPosition;
              final Rect imageRect = _getImageRect(context);
              if (_backupSelection != null && _dragStart != null) {
                final double dragDistance = (localPos - _dragStart!).distance;
                if (dragDistance < 5.0 &&
                    !_backupSelection!.rect.contains(localPos) &&
                    !_selectionController.isPointInHorizontalOverlay(
                      selection: _selection,
                      localPos: localPos,
                      imageRect: imageRect,
                    ) &&
                    !_selectionController.isPointInVerticalOverlay(
                      selection: _selection,
                      localPos: localPos,
                      imageRect: imageRect,
                    )) {
                  setState(() {
                    _selection = null;
                    _mode = SelectionMode.none;
                    _editingWidth = false;
                    _editingHeight = false;
                  });
                  context.read<ImageEditCubit>().clearSelection();
                  _activePointers.remove(event.pointer);
                  _backupSelection = null;
                  _dragStart = null;
                  return;
                }
              }

              _activePointers.remove(event.pointer);

              if (_activePointers.isEmpty) {
                _backupSelection = null;
              }

              if (_isPanning) {
                if (_activePointers.isEmpty) {
                  setState(() {
                    _isPanning = false;
                  });
                }
                return;
              }

              if (_selection != null) {
                if (_selection!.width < 10.0 || _selection!.height < 10.0) {
                  setState(() {
                    _selection = null;
                    _mode = SelectionMode.none;
                    _editingWidth = false;
                    _editingHeight = false;
                  });
                  context.read<ImageEditCubit>().clearSelection();
                  return;
                }
              }

              final SelectionMode finishedMode = _mode;
              setState(() {
                _mode = SelectionMode.none;
              });

              if (_selection != null && finishedMode != SelectionMode.none) {
                final double calculatedW = MeasurementService.calculateWidthInchesFromPixelWidth(_selection!.width);
                final double calculatedH = MeasurementService.calculateHeightInchesFromPixelHeight(_selection!.height);

                double newW = _customWidthInches;
                double newH = _customHeightInches;
                if (finishedMode == SelectionMode.resizeLeft ||
                    finishedMode == SelectionMode.resizeRight) {
                  newW = calculatedW;
                } else if (finishedMode == SelectionMode.resizeTop ||
                    finishedMode == SelectionMode.resizeBottom) {
                  newH = calculatedH;
                } else {
                  // Corner resize, moving, or creating updates both
                  newW = calculatedW;
                  newH = calculatedH;
                }

                final double systemVal = MeasurementService.calculateAreaInSqFt(newW, newH);

                setState(() {
                  _customWidthInches = newW;
                  _customHeightInches = newH;
                  _systemArea = systemVal;
                  _areaController.text = systemVal.toString();
                  _editingWidth = false;
                  _editingHeight = false;
                });

                final viewSize = Size(
                  MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height * 0.40,
                );

                final Offset localTopLeft = Offset(
                  _selection!.left,
                  _selection!.top,
                );
                final Offset localBottomRight = Offset(
                  _selection!.left + _selection!.width,
                  _selection!.top + _selection!.height,
                );

                final Offset originalTopLeft = _mapLocalToOriginal(
                  localTopLeft,
                  viewSize,
                );
                final Offset originalBottomRight = _mapLocalToOriginal(
                  localBottomRight,
                  viewSize,
                );

                final int originalLeft = originalTopLeft.dx.round();
                final int originalTop = originalTopLeft.dy.round();
                final int originalRight = originalBottomRight.dx.round();
                final int originalBottom = originalBottomRight.dy.round();

                final areaData = {
                  "left": originalLeft,
                  "top": originalTop,
                  "right": originalRight,
                  "bottom": originalBottom,
                  "obj_w": _customWidthInches,
                  "obj_h": _customHeightInches,
                };

                debugPrint(
                  "Selected Area (Original Coordinates): $areaData | System Area prediction: $systemVal",
                );
                context.read<ImageEditCubit>().selectArea(areaData);
              }
            },
            onPointerCancel: (event) {
              _activePointers.remove(event.pointer);
              if (_activePointers.isEmpty) {
                setState(() {
                  _isPanning = false;
                  _mode = SelectionMode.none;
                  _backupSelection = null;
                });
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Base Image — rendered via OverflowBox so the full
                // BoxFit.cover-equivalent display size overflows the Stack
                // bounds. ClipRect (outermost) clips to the viewport.
                // This lets users pan to reveal landscape/portrait overflow
                // WITHOUT changing the coordinate system: OverflowBox centres
                // the child at (vpW/2, vpH/2) in Stack space — identical to
                // where BoxFit.cover would render it — so _mapLocalToOriginal
                // with viewSize=(vpW, vpH) stays mathematically correct.
                if (_originalImageWidth != null)
                  OverflowBox(
                    alignment: Alignment.center,
                    maxWidth: double.infinity,
                    maxHeight: double.infinity,
                    child: _baseImage.startsWith('http')
                        ? Image.network(
                            _baseImage,
                            width: _originalImageWidth! * _currentDisplayScale,
                            height:
                                _originalImageHeight! * _currentDisplayScale,
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                            cacheWidth: 800,
                          )
                        : Image.file(
                            File(_baseImage),
                            width: _originalImageWidth! * _currentDisplayScale,
                            height:
                                _originalImageHeight! * _currentDisplayScale,
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                            cacheWidth: 800,
                          ),
                  )
                else
                  // Fallback before dimensions load: BoxFit.cover fills viewport
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

                // Applied Design Layer — same OverflowBox treatment
                if (_currentAssetPreview != null &&
                    _currentAssetPreview!.isNotEmpty)
                  if (_originalImageWidth != null)
                    OverflowBox(
                      alignment: Alignment.center,
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      child: _currentAssetPreview!.startsWith('http')
                          ? Image.network(
                              _currentAssetPreview!,
                              width:
                                  _originalImageWidth! * _currentDisplayScale,
                              height:
                                  _originalImageHeight! * _currentDisplayScale,
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                              cacheWidth: 800,
                            )
                          : (_currentAssetPreview!.startsWith('/') ||
                                _currentAssetPreview!.contains('tryon_result'))
                          ? Image.file(
                              File(_currentAssetPreview!),
                              width:
                                  _originalImageWidth! * _currentDisplayScale,
                              height:
                                  _originalImageHeight! * _currentDisplayScale,
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                              cacheWidth: 800,
                            )
                          : Image.asset(
                              _currentAssetPreview!,
                              width:
                                  _originalImageWidth! * _currentDisplayScale,
                              height:
                                  _originalImageHeight! * _currentDisplayScale,
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                            ),
                    )
                  else
                    // Fallback before dimensions load
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
                Builder(
                  builder: (context) {
                    return Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: SelectionPainter(
                            selection: _selection?.rect,
                            imageRect: _getImageRect(context),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (_selection != null) ...[
                  Builder(
                    builder: (context) {
                      final Rect imageRect = _getImageRect(context);
                      final Size viewSize = _getViewSize(context);

                      // Calculate available space on each side
                      final double spaceBelow =
                          imageRect.bottom -
                          (_selection!.top + _selection!.height);
                      final double spaceAbove = _selection!.top - imageRect.top;
                      final double spaceRight =
                          imageRect.right -
                          (_selection!.left + _selection!.width);
                      final double spaceLeft =
                          _selection!.left - imageRect.left;

                      // Decide which side to display the horizontal indicator (arrow/label)
                      // Height of horizontal label is ~40px. Let's flip to bottom if top space is < 45px, or flip to top if bottom space is < 45px.
                      bool showHorizontalArrowAtTop = false;
                      if (_selection!.top - imageRect.top < 45.0) {
                        showHorizontalArrowAtTop = false;
                      } else if (imageRect.bottom - (_selection!.top + _selection!.height) < 45.0) {
                        showHorizontalArrowAtTop = true;
                      } else {
                        showHorizontalArrowAtTop = spaceBelow < 50.0 && spaceAbove > spaceBelow;
                      }

                      // Decide which side to display the vertical indicator (arrow/label)
                      // Width of vertical inline editor is ~120px. We show on the right if left space is < 125px, or show on the left if right space is < 125px.
                      bool showVerticalArrowAtLeft = false;
                      if (_selection!.left - imageRect.left < 125.0) {
                        showVerticalArrowAtLeft = false;
                      } else if (imageRect.right - (_selection!.left + _selection!.width) < 125.0) {
                        showVerticalArrowAtLeft = true;
                      } else {
                        showVerticalArrowAtLeft = spaceRight < 120.0 && spaceLeft > spaceRight;
                      }

                      final double horizontalArrowTop = showHorizontalArrowAtTop
                          ? _selection!.top - 18
                          : _selection!.top + _selection!.height + 8;

                      final double horizontalLabelTop = showHorizontalArrowAtTop
                          ? _selection!.top - 42
                          : _selection!.top + _selection!.height + 22;

                      double verticalArrowLeft = showVerticalArrowAtLeft
                          ? _selection!.left - 18
                          : _selection!.left + _selection!.width + 8;

                      double verticalLabelLeft = showVerticalArrowAtLeft
                          ? _selection!.left - (_editingHeight ? 128.0 : 80.0)
                          : _selection!.left + _selection!.width + 22;

                      // Clamp coordinates to prevent clipping off screen/image edges
                      final double screenW = viewSize.width;
                      verticalArrowLeft = verticalArrowLeft.clamp(
                        imageRect.left + 2,
                        imageRect.right - 12,
                      );
                      verticalLabelLeft = verticalLabelLeft.clamp(
                        8.0,
                        screenW - 128.0, // Prevent inline editor (width ~120px) from overflowing right screen edge
                      );

                      double horizontalLabelLeft =
                          _selection!.left + (_selection!.width - 150) / 2;
                      horizontalLabelLeft = horizontalLabelLeft.clamp(
                        8.0,
                        screenW - 158.0, // Prevent inline editor (width 150px) from overflowing right screen edge
                      );

                      final double horizontalLabelTopClamped = horizontalLabelTop.clamp(8.0, viewSize.height - 48.0);
                      final double verticalLabelTopClamped = (_selection!.top + (_selection!.height - 40) / 2).clamp(8.0, viewSize.height - 48.0);

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Horizontal double arrow line
                          Positioned(
                            left: _selection!.left,
                            top: horizontalArrowTop,
                            width: _selection!.width,
                            height: 10,
                            child: CustomPaint(
                              painter: DashedLinePainter(axis: Axis.horizontal),
                            ),
                          ),
                          // Vertical double arrow line
                          Positioned(
                            left: verticalArrowLeft,
                            top: _selection!.top,
                            width: 10,
                            height: _selection!.height,
                            child: CustomPaint(
                              painter: DashedLinePainter(axis: Axis.vertical),
                            ),
                          ),
                          // Horizontal dimension label / inline editor
                          Positioned(
                            left: horizontalLabelLeft,
                            top: horizontalLabelTopClamped,
                            width: 150,
                            child: Center(
                              child: _editingWidth
                                  ? _buildInlineEditor(
                                      controller: _widthEditController,
                                      onSave: () {
                                        _justSaved = true;
                                        setState(() {
                                          final parsedW = double.tryParse(
                                            _widthEditController.text,
                                          );
                                          if (parsedW != null && parsedW > 0) {
                                            _customWidthInches = parsedW;
                                          }
                                          _recalculateArea();
                                          _notifyCubitOfSelection();
                                        });

                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (mounted) {
                                                setState(() {
                                                  _editingWidth = false;
                                                });
                                              }
                                            });
                                      },
                                    )
                                  : _buildDisplayLabel(
                                      value: _customWidthInches,
                                      onTap: () {
                                        setState(() {
                                          _widthEditController.text =
                                              _customWidthInches
                                                  .round()
                                                  .toString();
                                          _editingWidth = true;
                                        });
                                      },
                                    ),
                            ),
                          ),
                          // Vertical dimension label / inline editor
                          Positioned(
                            left: verticalLabelLeft,
                            top: verticalLabelTopClamped,
                            child: Center(
                              child: _editingHeight
                                  ? _buildInlineEditor(
                                      controller: _heightEditController,
                                      onSave: () {
                                        _justSaved = true;
                                        setState(() {
                                          final parsedH = double.tryParse(
                                            _heightEditController.text,
                                          );
                                          if (parsedH != null && parsedH > 0) {
                                            _customHeightInches = parsedH;
                                          }
                                          _recalculateArea();
                                          _notifyCubitOfSelection();
                                        });

                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (mounted) {
                                                setState(() {
                                                  _editingHeight = false;
                                                });
                                              }
                                            });
                                      },
                                    )
                                  : _buildDisplayLabel(
                                      value: _customHeightInches,
                                      onTap: () {
                                        setState(() {
                                          _heightEditController.text =
                                              _customHeightInches
                                                  .round()
                                                  .toString();
                                          _editingHeight = true;
                                        });
                                      },
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
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
        // Preview Full Image Button (Eye Button)
        Positioned(
          bottom: 24,
          left: 16,
          child: GestureDetector(
            onTap: () => _showFullImagePopup(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: const Icon(
                Icons.visibility,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
        // Redundant overlay removed as it's now handled by _buildGeneratingBlock in the main stack
        const SizedBox.shrink(),
      ],
    );
  }

  Future<void> _handleUndo(ImageEditState state) async {
    if (state.generatedHistory.isNotEmpty) {
      context.read<ImageEditCubit>().undoLastEdit();
      final newState = context.read<ImageEditCubit>().state;
      setState(() {
        _currentAssetPreview = newState.editedImageFile;
        _baseImage = newState.editedImageFile ?? newState.originalImage ?? widget.imageFile.path;
        if (newState.generatedHistory.isEmpty) {
          _hasNewUnappliedEdit = false;
          _hasAppliedOnce = false;
        }
      });
    } else if (_parentEditId != null) {
      setState(() => _isLoadingEdits = true);
      try {
        final parentRecord = await EditHistoryRepository.getEditById(
          _parentEditId!,
        );
        if (parentRecord != null) {
          await EditHistoryRepository.deleteEdit(_parentEditId!);

          setState(() {
            _parentEditId = parentRecord.parentEditId;
            _baseImage = parentRecord.originalImagePath;
            _currentAssetPreview = null;
            _selection = null;
            _systemArea = null;
            _areaController.clear();
            _hasNewUnappliedEdit = false;
          });

          context.read<ImageEditCubit>().initOriginalImage(
            _baseImage,
            furnitureId: widget.image_id,
            ownerId: _ownerEmail,
            sessionId: _sessionId,
          );
          await _fetchUserEditHistory();
        } else {
          await EditHistoryRepository.deleteEdit(_parentEditId!);
          setState(() {
            _parentEditId = null;
            _baseImage = widget.imageFile.path;
            _currentAssetPreview = null;
            _selection = null;
            _systemArea = null;
            _areaController.clear();
            _hasAppliedOnce = false;
            _compareExpanded = false;
            _editExpanded = true;
            _hasNewUnappliedEdit = false;
          });
          context.read<ImageEditCubit>().initOriginalImage(
            _baseImage,
            furnitureId: widget.image_id,
            ownerId: _ownerEmail,
            sessionId: _sessionId,
          );
          await _fetchUserEditHistory();
        }
      } catch (e) {
        debugPrint("❌ Error performing database undo: $e");
      } finally {
        setState(() => _isLoadingEdits = false);
      }
    }
  }

  Future<void> _handleRedo(ImageEditState state) async {
    if (state.redoHistory.isNotEmpty) {
      context.read<ImageEditCubit>().redoLastEdit();
      final newState = context.read<ImageEditCubit>().state;
      setState(() {
        _currentAssetPreview = newState.editedImageFile;
        _baseImage = newState.editedImageFile ?? newState.originalImage ?? widget.imageFile.path;
        if (newState.generatedHistory.isNotEmpty) {
          _hasNewUnappliedEdit = true;
        }
      });
    }
  }

  void _recalculateArea() {
    final double val = MeasurementService.calculateAreaInSqFt(_customWidthInches, _customHeightInches);
    setState(() {
      _systemArea = val;
      _areaController.text = val.toString();
    });
  }

  void _notifyCubitOfSelection() {
    if (_selection == null) return;
    final viewSize = Size(
      MediaQuery.of(context).size.width,
      MediaQuery.of(context).size.height * 0.40,
    );

    final Offset localTopLeft = Offset(_selection!.left, _selection!.top);
    final Offset localBottomRight = Offset(
      _selection!.left + _selection!.width,
      _selection!.top + _selection!.height,
    );

    final Offset originalTopLeft = _mapLocalToOriginal(localTopLeft, viewSize);
    final Offset originalBottomRight = _mapLocalToOriginal(
      localBottomRight,
      viewSize,
    );

    final int originalLeft = originalTopLeft.dx.round();
    final int originalTop = originalTopLeft.dy.round();
    final int originalRight = originalBottomRight.dx.round();
    final int originalBottom = originalBottomRight.dy.round();

    final areaData = {
      "left": originalLeft,
      "top": originalTop,
      "right": originalRight,
      "bottom": originalBottom,
      "obj_w": _customWidthInches,
      "obj_h": _customHeightInches,
    };

    context.read<ImageEditCubit>().selectArea(areaData);
  }

  Widget _buildDisplayLabel({
    required double value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${value.round()} in",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.7),
                    offset: const Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit,
              color: Colors.white,
              size: 11,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.7),
                  offset: const Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineEditor({
    required TextEditingController controller,
    required VoidCallback onSave,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300, width: 0.8),
            ),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.zero,
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            "in",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSave,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(
                  0xFFE53935,
                ), // Century Ply brand red checkmark button
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
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
        controller: _searchController,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w100),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            _fetchTexturesBySku(value.trim());
          } else {
            _clearSearchAndRestore();
          }
        },
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF7F7F7),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 16,
          ),
          suffixIconConstraints: const BoxConstraints(
            maxWidth: 54,
            maxHeight: 32,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isSearching || _searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: _clearSearchAndRestore,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.close, size: 14, color: Colors.grey),
                  ),
                ),
              GestureDetector(
                onTap: () {
                  if (_searchController.text.trim().isNotEmpty) {
                    _fetchTexturesBySku(_searchController.text.trim());
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 5, top: 5, bottom: 5),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
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
              ),
            ],
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
            _isSearching
                ? "No laminates found for \"${_searchController.text}\"."
                : (_selectedCategory == null && _selectedColor == null)
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

  void _showFullImagePopup(BuildContext context) {
    final String imageToShow =
        (_currentAssetPreview != null && _currentAssetPreview!.isNotEmpty)
        ? _currentAssetPreview!
        : _baseImage;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          child: Stack(
            children: [
              // Image Container
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.white,
                    child: imageToShow.startsWith('http')
                        ? Image.network(
                            imageToShow,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          )
                        : (imageToShow.startsWith('/') ||
                              imageToShow.contains('tryon_result') ||
                              imageToShow.contains('data/user') ||
                              imageToShow.contains('emulator') ||
                              imageToShow.contains('storage/emulated'))
                        ? Image.file(
                            File(imageToShow),
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          )
                        : Image.asset(
                            imageToShow,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                  ),
                ),
              ),
              // Close Button
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
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
      final String newEditId = responseId ?? const Uuid().v4();
      if (widget.image_id != null) {
        try {
          final cubit = context.read<ImageEditCubit>();
          final double? userVal = double.tryParse(_areaController.text);
          await cubit.saveToDatabase(
            imgPath: state.currentGeneratedImage!,
            laminate: state.selectedPattern,
            customSessionId: newEditId,
            parentEditId: _parentEditId, // link to ancestor
            systemArea: _systemArea,
            userArea: userVal ?? _systemArea,
          );
          _parentEditId = newEditId;
        } catch (e) {
          debugPrint("❌ Error saving local edit: $e");
        }
      }
      final String finalizedImage = state.currentGeneratedImage!;
      if (mounted) {
        setState(() {
          _baseImage = finalizedImage;
          _currentAssetPreview = null;
          _compareExpanded = true;
          _editExpanded = false;
          _hasAppliedOnce = true;
          _hasNewUnappliedEdit = false;

          // CLEAR PREVIOUS STATE
          _selectedTexture = null;
          _selectedColor = null;
          _selectedSubCategory = null;
          _selection = null;
          _systemArea = null;
          _areaController.clear();
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
      final double area =
          latestRecord.userArea ?? latestRecord.systemArea ?? 5.0;
      final int est = (area * 2.0).round();
      usedLaminates = usedLaminates.map((e) {
        final m = Map<String, dynamic>.from(e);
        m['estimatedSheets'] = m['estimatedSheets'] ?? est;
        return m;
      }).toList();
    } else {
      // Fallback: pull from in-memory cubit history (no DB record yet)
      final state = context.read<ImageEditCubit>().state;
      final cubit = context.read<ImageEditCubit>();
      final double currentArea =
          double.tryParse(_areaController.text) ?? _systemArea ?? 5.0;
      final int currentEst = (currentArea * 2.0).round();
      for (var item in cubit.state.generatedHistory) {
        if (item['laminate'] != null) {
          final lam = Map<String, dynamic>.from(item['laminate'] as Map);
          lam['estimatedSheets'] = lam['estimatedSheets'] ?? currentEst;
          if (!usedLaminates.any((element) => element['id'] == lam['id'])) {
            usedLaminates.add(lam);
          }
        }
        if (item['generated'] == state.currentGeneratedImage) break;
      }
      if (usedLaminates.isEmpty && _selectedTexture != null) {
        final lam = Map<String, dynamic>.from(_selectedTexture!);
        lam['estimatedSheets'] = lam['estimatedSheets'] ?? currentEst;
        usedLaminates.add(lam);
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



class SelectionPainter extends CustomPainter {
  final Rect? selection;
  final Rect imageRect;

  SelectionPainter({required this.selection, required this.imageRect});

  @override
  void paint(Canvas canvas, Size size) {
    if (selection == null) return;

    // 1. Draw dark background overlay outside selection, restricted to imageRect
    final Paint overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.45)
      ..style = PaintingStyle.fill;

    final Path imagePath = Path()..addRect(imageRect.inflate(2.0));

    final double left = selection!.left;
    final double top = selection!.top;
    final double right = selection!.right;
    final double bottom = selection!.bottom;
    final double width = selection!.width;
    final double height = selection!.height;

    final Path selectionPath = Path()..addRect(selection!);
    final Path overlayPath = Path.combine(
      PathOperation.difference,
      imagePath,
      selectionPath,
    );
    canvas.drawPath(overlayPath, overlayPaint);

    // 2. Draw Rule of Thirds grid lines inside selection
    final Paint gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(left + width / 3, top),
      Offset(left + width / 3, bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(left + 2 * width / 3, top),
      Offset(left + 2 * width / 3, bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(left, top + height / 3),
      Offset(right, top + height / 3),
      gridPaint,
    );
    canvas.drawLine(
      Offset(left, top + 2 * height / 3),
      Offset(right, top + 2 * height / 3),
      gridPaint,
    );

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
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      handlePaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left, top + cornerLength),
      handlePaint,
    );

    // Top-Right
    canvas.drawLine(
      Offset(right, top),
      Offset(right - cornerLength, top),
      handlePaint,
    );
    canvas.drawLine(
      Offset(right, top),
      Offset(right, top + cornerLength),
      handlePaint,
    );

    // Bottom-Left
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + cornerLength, bottom),
      handlePaint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left, bottom - cornerLength),
      handlePaint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right - cornerLength, bottom),
      handlePaint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - cornerLength),
      handlePaint,
    );

    // 5. Draw thick edge middle handles (horizontal / vertical bars)
    final double midX = (left + right) / 2;
    final double midY = (top + bottom) / 2;
    final double edgeLength = 12.0;

    // Left Edge Middle
    canvas.drawLine(
      Offset(left, midY - edgeLength),
      Offset(left, midY + edgeLength),
      handlePaint,
    );
    // Right Edge Middle
    canvas.drawLine(
      Offset(right, midY - edgeLength),
      Offset(right, midY + edgeLength),
      handlePaint,
    );
    // Top Edge Middle
    canvas.drawLine(
      Offset(midX - edgeLength, top),
      Offset(midX + edgeLength, top),
      handlePaint,
    );
    // Bottom Edge Middle
    canvas.drawLine(
      Offset(midX - edgeLength, bottom),
      Offset(midX + edgeLength, bottom),
      handlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant SelectionPainter oldDelegate) {
    return oldDelegate.selection != selection;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Marching Ants Selection Painter
// ─────────────────────────────────────────────────────────────────────────────
class MarchingAntsMaskPainter extends CustomPainter {
  final ui.Image maskImage;
  final double progress; // 0.0 to 1.0 from AnimationController
  final Path? fillPath;
  final Path? edgePath;

  MarchingAntsMaskPainter({
    required this.maskImage,
    required this.progress,
    this.fillPath,
    this.edgePath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // ── Compute BoxFit.cover transform ─────────────────────────────────────
    final double imgW = maskImage.width.toDouble();
    final double imgH = maskImage.height.toDouble();

    // Uniform scale factor (contain = take the SMALLER of the two ratios)
    final double scale =
        (size.width / imgW).clamp(0.0, double.infinity) <
            (size.height / imgH).clamp(0.0, double.infinity)
        ? size.width / imgW
        : size.height / imgH;

    final double dx = (size.width - imgW * scale) / 2.0;
    final double dy = (size.height - imgH * scale) / 2.0;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    if (fillPath != null) {
      // 1. Darkened reverse-selection overlay
      final Path maskRect = Path()..addRect(Rect.fromLTWH(0, 0, imgW, imgH));
      final Path outsidePath = Path.combine(
        PathOperation.difference,
        maskRect,
        fillPath!,
      );

      canvas.drawPath(
        outsidePath,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.55)
          ..style = PaintingStyle.fill,
      );
    } else {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, imgW, imgH),
        Paint()..color = Colors.black.withValues(alpha: 0.30),
      );
    }

    if (edgePath != null) {
      // 2. Marching ants — animated diagonal stripe shader
      final double shiftAmt = progress * 40;
      final Paint antPaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(20, 20),
          [Colors.white, Colors.white, Colors.black, Colors.black],
          [0.0, 0.5, 0.5, 1.0],
          TileMode.repeated,
          Float64List.fromList([
            1,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            1,
            0,
            shiftAmt,
            shiftAmt,
            0,
            1,
          ]),
        )
        ..style = PaintingStyle.fill;
      canvas.drawPath(edgePath!, antPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MarchingAntsMaskPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.maskImage != maskImage ||
        oldDelegate.fillPath != fillPath ||
        oldDelegate.edgePath != edgePath;
  }
}

extension on _ImageEditPageState {
  Widget _buildPreviewApprovalBar(ImageEditState state) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Does this look right?",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "The laminate will be applied to the highlighted area.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Cancel Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<ImageEditCubit>().undoLastEdit();
                  },
                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                  label: const Text(
                    "Cancel",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Accept Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // V4: image is already applied, just dismiss
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check, size: 18, color: Colors.white),
                  label: const Text(
                    "Accept",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  final Axis axis;
  DashedLinePainter({required this.axis});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final double dashWidth = 4.0;
    final double dashSpace = 4.0;

    final path = Path();
    if (axis == Axis.horizontal) {
      // Draw left arrowhead
      path.moveTo(6, size.height / 2 - 4);
      path.lineTo(0, size.height / 2);
      path.lineTo(6, size.height / 2 + 4);

      // Draw right arrowhead
      path.moveTo(size.width - 6, size.height / 2 - 4);
      path.lineTo(size.width, size.height / 2);
      path.lineTo(size.width - 6, size.height / 2 + 4);

      // Draw dashed line
      for (double i = 6; i < size.width - 6; i += dashWidth + dashSpace) {
        path.moveTo(i, size.height / 2);
        path.lineTo(
          i + dashWidth > size.width - 6 ? size.width - 6 : i + dashWidth,
          size.height / 2,
        );
      }
    } else {
      // Draw top arrowhead
      path.moveTo(size.width / 2 - 4, 6);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width / 2 + 4, 6);

      // Draw bottom arrowhead
      path.moveTo(size.width / 2 - 4, size.height - 6);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width / 2 + 4, size.height - 6);

      // Draw dashed line
      for (double i = 6; i < size.height - 6; i += dashWidth + dashSpace) {
        path.moveTo(size.width / 2, i);
        path.lineTo(
          size.width / 2,
          i + dashWidth > size.height - 6 ? size.height - 6 : i + dashWidth,
        );
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DashedLinePainter oldDelegate) => false;
}
