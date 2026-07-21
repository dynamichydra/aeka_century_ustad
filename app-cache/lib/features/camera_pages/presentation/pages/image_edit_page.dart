import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:century_ai/core/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide SelectionRect;
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

int rectanglesNeeded({
  required double bigWidth,
  required double bigHeight,
  required double smallWidth,
  required double smallHeight,
}) {
  if (bigWidth <= 0 ||
      bigHeight <= 0 ||
      smallWidth <= 0 ||
      smallHeight <= 0 ||
      bigWidth.isNaN ||
      bigHeight.isNaN ||
      smallWidth.isNaN ||
      smallHeight.isNaN) {
    return 1;
  }

  final columns = (bigWidth / smallWidth).ceil();
  final rows = (bigHeight / smallHeight).ceil();
  final total = columns * rows;

  return total > 0 ? total : 1;
}

class ImageEditPage extends StatefulWidget {
  final File imageFile;
  final Color? pickedColor;
  final String? image_id;
  final String? originalImageUrl;
  final String? imageUrl;
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
    this.originalImageUrl,
    this.imageUrl,
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
  bool? _feedbackLiked;

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

  final ScrollController _horizontalScrollController = ScrollController();
  int _currentPage = 1;
  bool _hasMoreTextures = true;
  bool _isFetchingMore = false;
  static const int _pageSize = 25;

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
  bool _isDrawingNewSelection = false;
  final Map<int, Offset> _activePointers = {};
  bool _isPanning = false;
  bool _interactingWithOverlay = false;
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

  Offset _getWidthCardPosition({
    required Rect vpSelection,
    required double cardW,
    required double cardH,
    required double vpW,
    required double vpH,
    // Visible image rect in viewport coordinates. When the image has white
    // space around it (zoomed out) labels are constrained to the image edge;
    // when zoomed in and the image fills the screen this equals the viewport.
    Rect? visibleImageRect,
  }) {
    // Effective bounds: use visible image rect when tighter than viewport
    final double minX = visibleImageRect != null
        ? (visibleImageRect.left + 4)
        : 8.0;
    final double maxX = visibleImageRect != null
        ? (visibleImageRect.right - 4)
        : (vpW - 8.0);
    final double minY = visibleImageRect != null
        ? (visibleImageRect.top + 4)
        : 8.0;
    final double maxY = visibleImageRect != null
        ? (visibleImageRect.bottom - 4)
        : (vpH - 8.0);

    final candidates = [
      // 1. Bottom Center (default)
      Offset(
        vpSelection.left + (vpSelection.width - cardW) / 2,
        vpSelection.bottom + 22,
      ),
      // 2. Top Center
      Offset(
        vpSelection.left + (vpSelection.width - cardW) / 2,
        vpSelection.top - 42,
      ),
      // 3. Bottom Left
      Offset(vpSelection.left, vpSelection.bottom + 22),
      // 4. Bottom Right
      Offset(vpSelection.right - cardW, vpSelection.bottom + 22),
      // 5. Top Left
      Offset(vpSelection.left, vpSelection.top - 42),
      // 6. Top Right
      Offset(vpSelection.right - cardW, vpSelection.top - 42),
    ];

    for (final pos in candidates) {
      if (pos.dx >= minX &&
          pos.dx + cardW <= maxX &&
          pos.dy >= minY &&
          pos.dy + cardH <= maxY) {
        return pos;
      }
    }

    // 7. Floating (clamped inside effective bounds)
    final double spaceBelow = maxY - vpSelection.bottom;
    final double spaceAbove = vpSelection.top - minY;
    double defaultY = (spaceBelow < 50.0 && spaceAbove > spaceBelow)
        ? vpSelection.top - 42
        : vpSelection.bottom + 22;

    double x = vpSelection.left + (vpSelection.width - cardW) / 2;
    return Offset(
      x.clamp(minX, maxX - cardW),
      defaultY.clamp(minY, maxY - cardH),
    );
  }

  Offset _getHeightCardPosition({
    required Rect vpSelection,
    required double cardW,
    required double cardH,
    required double vpW,
    required double vpH,
    // Visible image rect in viewport coordinates. When the image has white
    // space around it (zoomed out) labels are constrained to the image edge;
    // when zoomed in and the image fills the screen this equals the viewport.
    Rect? visibleImageRect,
  }) {
    // Effective bounds: use visible image rect when tighter than viewport
    final double minX = visibleImageRect != null
        ? (visibleImageRect.left + 4)
        : 8.0;
    final double maxX = visibleImageRect != null
        ? (visibleImageRect.right - 4)
        : (vpW - 8.0);
    final double minY = visibleImageRect != null
        ? (visibleImageRect.top + 4)
        : 8.0;
    final double maxY = visibleImageRect != null
        ? (visibleImageRect.bottom - 4)
        : (vpH - 8.0);

    final candidates = [
      // 1. Right Center (default)
      Offset(
        vpSelection.right + 22,
        vpSelection.top + (vpSelection.height - cardH) / 2,
      ),
      // 2. Left Center
      Offset(
        vpSelection.left - 22 - cardW,
        vpSelection.top + (vpSelection.height - cardH) / 2,
      ),
      // 3. Top Right
      Offset(vpSelection.right + 22, vpSelection.top),
      // 4. Bottom Right
      Offset(vpSelection.right + 22, vpSelection.bottom - cardH),
      // 5. Top Left
      Offset(vpSelection.left - 22 - cardW, vpSelection.top),
      // 6. Bottom Left
      Offset(vpSelection.left - 22 - cardW, vpSelection.bottom - cardH),
    ];

    for (final pos in candidates) {
      if (pos.dx >= minX &&
          pos.dx + cardW <= maxX &&
          pos.dy >= minY &&
          pos.dy + cardH <= maxY) {
        return pos;
      }
    }

    // 7. Floating (clamped inside effective bounds)
    final double spaceRight = maxX - vpSelection.right;
    final double spaceLeft = vpSelection.left - minX;
    double defaultX = (spaceRight < 120.0 && spaceLeft > spaceRight)
        ? vpSelection.left - 22 - cardW
        : vpSelection.right + 22;

    double y = vpSelection.top + (vpSelection.height - cardH) / 2;
    return Offset(
      defaultX.clamp(minX, maxX - cardW),
      y.clamp(minY, maxY - cardH),
    );
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

  /// Returns the visible portion of the image within the viewport,
  /// accounting for zoom and pan transformations.
  /// Used only for overlay positioning — NOT for coordinate mapping.
  Rect _getVisibleImageRect(BuildContext context) {
    final Rect baseRect = _getImageRect(context);
    final Matrix4 matrix = _transformationController.value;
    final Offset tl = MatrixUtils.transformPoint(matrix, baseRect.topLeft);
    final Offset br = MatrixUtils.transformPoint(matrix, baseRect.bottomRight);
    final Rect transformed = Rect.fromPoints(tl, br);
    final Size viewSize = _getViewSize(context);
    final Rect viewport = Rect.fromLTWH(0, 0, viewSize.width, viewSize.height);
    return transformed.intersect(viewport);
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
      if (currentSelected.length < 4) {
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
    _horizontalScrollController.dispose();
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
    _horizontalScrollController.addListener(_onHorizontalScroll);
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
        originalImageUrl: widget.originalImageUrl,
        imageUrl: widget.imageUrl,
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

  void _onHorizontalScroll() {
    if (_horizontalScrollController.hasClients &&
        _horizontalScrollController.position.pixels >=
            _horizontalScrollController.position.maxScrollExtent - 200) {
      _fetchMoreTextures();
    }
  }

  Future<void> _fetchTextures() async {
    if (_selectedCategory == null) return;

    setState(() {
      _isLoadingTextures = true;
      _currentPage = 1;
      _hasMoreTextures = true;
      _isFetchingMore = false;
    });

    try {
      final list = await _textureController.fetchTexturesByCategory(
        category: _selectedCategory!,
        subcategory: _selectedSubCategory,
        page: 1,
        pageLimit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _apiTextures = list;
          _isLoadingTextures = false;
          if (list.length < _pageSize) {
            _hasMoreTextures = false;
          }
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

  Future<void> _fetchMoreTextures() async {
    if (_selectedCategory == null || _isFetchingMore || !_hasMoreTextures)
      return;

    setState(() {
      _isFetchingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final list = await _textureController.fetchTexturesByCategory(
        category: _selectedCategory!,
        subcategory: _selectedSubCategory,
        page: nextPage,
        pageLimit: _pageSize,
      );

      if (mounted) {
        setState(() {
          if (list.isEmpty) {
            _hasMoreTextures = false;
          } else {
            _apiTextures.addAll(list);
            _currentPage = nextPage;
            if (list.length < _pageSize) {
              _hasMoreTextures = false;
            }
          }
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching more textures: $e");
      if (mounted) {
        setState(() {
          _isFetchingMore = false;
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
      final list = await _textureController.fetchTexturesByColor(
        _selectedColor!["hex"],
      );
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

  Map<String, List<String>> get _activeCategoriesMap =>
      _textureController.activeCategoriesMap;

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
        if (state.isGenerating) {
          setState(() {
            _feedbackLiked = null;
          });
        }
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
              return Stack(
                children: [
                  Column(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.40,
                        child: ValueListenableBuilder<List<int>>(
                          valueListenable: _selectedIndicesNotifier,
                          builder: (context, selectedIndices, child) {
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
              final isApplying =
                  context.read<ImageEditCubit>().state.isApplyLoading ||
                  _isPrecaching ||
                  _isUploading ||
                  context.read<ImageEditCubit>().state.isGenerating;
              if (isApplying) return;
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
              final bool isApplying =
                  state.isApplyLoading ||
                  _isPrecaching ||
                  _isUploading ||
                  state.isGenerating;
              return _buildHeaderTile(
                title: "Edit & Design",
                iconImg: "edit.png",
                isActive: _editExpanded,
                showArrow: _hasAppliedOnce,
                onTap: _hasAppliedOnce
                    ? () {
                        if (isApplying) return;
                        setState(() {
                          _editExpanded = !_editExpanded;
                          if (_editExpanded) _compareExpanded = false;
                        });
                      }
                    : () {},
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selection != null) ...[
                      GestureDetector(
                        onTap: () {
                          if (isApplying) return;
                          setState(() {
                            _selection = null;
                            _mode = SelectionMode.none;
                            _editingWidth = false;
                            _editingHeight = false;
                          });
                          context.read<ImageEditCubit>().clearSelection();
                        },
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
                              // Icon(
                              //   Icons.clear,
                              //   color: Colors.black.withOpacity(0.7),
                              //   size: 12,
                              // ),
                              // const SizedBox(width: 4),
                              Text(
                                "Clear Selection",
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
                      const SizedBox(width: 8),
                    ],
                    Opacity(
                      opacity:
                          (canUndo &&
                              !(state.isApplyLoading ||
                                  _isPrecaching ||
                                  _isUploading ||
                                  state.isGenerating))
                          ? 1.0
                          : 0.4,
                      child: GestureDetector(
                        onTap:
                            (canUndo &&
                                !(state.isApplyLoading ||
                                    _isPrecaching ||
                                    _isUploading ||
                                    state.isGenerating))
                            ? () => _handleUndo(state)
                            : null,
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
                    const SizedBox(width: 8),
                    Opacity(
                      opacity:
                          (canUndo &&
                              !(state.isApplyLoading ||
                                  _isPrecaching ||
                                  _isUploading ||
                                  state.isGenerating))
                          ? 1.0
                          : 0.4,
                      child: GestureDetector(
                        onTap:
                            (canUndo &&
                                !(state.isApplyLoading ||
                                    _isPrecaching ||
                                    _isUploading ||
                                    state.isGenerating))
                            ? () {
                                final newVal = (_feedbackLiked == true)
                                    ? null
                                    : true;
                                setState(() {
                                  _feedbackLiked = newVal;
                                });
                                if (newVal == true) {
                                  context.read<ImageEditCubit>().submitFeedback(
                                    "THUMBS_UP",
                                  );
                                }
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _feedbackLiked == true
                                ? Colors.green.shade50
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _feedbackLiked == true
                                  ? Colors.green
                                  : Colors.grey.shade300,
                              width: 0.8,
                            ),
                          ),
                          child: Icon(
                            _feedbackLiked == true
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                            color: _feedbackLiked == true
                                ? Colors.green
                                : Colors.black.withOpacity(0.7),
                            size: 12,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),
                    Opacity(
                      opacity:
                          (canUndo &&
                              !(state.isApplyLoading ||
                                  _isPrecaching ||
                                  _isUploading ||
                                  state.isGenerating))
                          ? 1.0
                          : 0.4,
                      child: GestureDetector(
                        onTap:
                            (canUndo &&
                                !(state.isApplyLoading ||
                                    _isPrecaching ||
                                    _isUploading ||
                                    state.isGenerating))
                            ? () {
                                final newVal = (_feedbackLiked == false)
                                    ? null
                                    : false;
                                setState(() {
                                  _feedbackLiked = newVal;
                                });
                                if (newVal == false) {
                                  context.read<ImageEditCubit>().submitFeedback(
                                    "THUMBS_DOWN",
                                  );
                                }
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _feedbackLiked == false
                                ? Colors.red.shade50
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _feedbackLiked == false
                                  ? Colors.red
                                  : Colors.grey.shade300,
                              width: 0.8,
                            ),
                          ),
                          child: Icon(
                            _feedbackLiked == false
                                ? Icons.thumb_down
                                : Icons.thumb_down_outlined,
                            color: _feedbackLiked == false
                                ? Colors.red
                                : Colors.black.withOpacity(0.7),
                            size: 12,
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
    // When nothing is selected, show only the original
    if (selectedIndices.isEmpty) {
      return _buildComparisonItem(
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
        },
        onEdit: () {
          setState(() {
            _sessionId = const Uuid().v4();
            _baseImage = widget.imageFile.path;
            _parentEditId = null;
            _currentAssetPreview = null;
            _selectedIndicesNotifier.value = [];
            _hasAppliedOnce = true;
            _compareExpanded = false;
            _editExpanded = true;
            _selectedTexture = null;
            _selectedColor = null;
            _selectedCategory = null;
            _selectedSubCategory = null;
            _selection = null;
          });
          context.read<ImageEditCubit>().initOriginalImage(
            _baseImage,
            furnitureId: widget.image_id,
            ownerId: _ownerEmail,
            sessionId: _sessionId,
          );
          _fetchUserEditHistory();
        },
      );
    }

    // Exactly 1 selected → Slider (Original vs selected edit)
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
                  _sessionId = const Uuid().v4();
                  _baseImage = newPath;
                  _currentAssetPreview = null;
                  _selectedIndicesNotifier.value = [];
                  _hasAppliedOnce = true;
                  _compareExpanded = false;
                  _editExpanded = true;
                  _selectedTexture = null;
                  _selectedColor = null;
                  _selectedCategory = null;
                  _selectedSubCategory = null;
                  _selection = null;
                });
                context.read<ImageEditCubit>().initOriginalImage(
                  newPath,
                  furnitureId: widget.image_id,
                  ownerId: _ownerEmail,
                  sessionId: _sessionId,
                );
                _fetchUserEditHistory();
              },
              size: 20,
              padding: 8,
            ),
          ),
        ],
      );
    }

    // 2-3 selected → show Original + selected edits in grid
    // 4 selected → show only the 4 selected edits (no Original)
    final List<Widget> items = [];
    final bool includeOriginal = selectedIndices.length < 4;

    if (includeOriginal) {
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
          },
          onEdit: () {
            setState(() {
              _sessionId = const Uuid().v4();
              _baseImage = widget.imageFile.path;
              _parentEditId = null;
              _currentAssetPreview = null;
              _selectedIndicesNotifier.value = [];
              _hasAppliedOnce = true;
              _compareExpanded = false;
              _editExpanded = true;
              _selectedTexture = null;
              _selectedColor = null;
              _selectedCategory = null;
              _selectedSubCategory = null;
              _selection = null;
            });
            context.read<ImageEditCubit>().initOriginalImage(
              _baseImage,
              furnitureId: widget.image_id,
              ownerId: _ownerEmail,
              sessionId: _sessionId,
            );
            _fetchUserEditHistory();
          },
        ),
      );
    }

    // Add selected edited versions
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
            List<Map<String, dynamic>> usedLaminates = [];
            try {
              usedLaminates =
                  await EditHistoryRepository.getCumulativeLaminates(record.id);
            } catch (e) {
              debugPrint('getCumulativeLaminates error: $e');
            }

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
              _sessionId = const Uuid().v4();
              _baseImage = imgPath;
              _parentEditId = editRecord.id;
              _currentAssetPreview = null;
              _selectedIndicesNotifier.value = [];
              _hasAppliedOnce = true;
              _compareExpanded = false;
              _editExpanded = true;
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

            context.read<ImageEditCubit>().initOriginalImage(
              _baseImage,
              furnitureId: widget.image_id,
              ownerId: _ownerEmail,
              sessionId: _sessionId,
            );
            _fetchUserEditHistory();
          },
        ),
      );
    }

    final totalItems = items.length;

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
    return ClipRect(
      child: Stack(
        children: [
          Listener(
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

              final Matrix4 matrix = _transformationController.value;
              final Matrix4 inverse = Matrix4.inverted(matrix);
              final Offset localPos = MatrixUtils.transformPoint(
                inverse,
                event.localPosition,
              );
              _dragStart = localPos;
              final Rect imageRect = _getImageRect(context);
              final double imgL = imageRect.left;
              final double imgR = imageRect.right;
              final double imgT = imageRect.top;
              final double imgB = imageRect.bottom;
              final Size viewSize = _getViewSize(context);

              final Offset vpPos = MatrixUtils.transformPoint(matrix, localPos);

              // Get current zoom scale for touch target sizing
              final double zoomScale = _transformationController.value
                  .getMaxScaleOnAxis();

              // 1. High Priority: Check if tap hit a resize handle or selection body
              SelectionMode detectedMode = SelectionMode.none;
              if (_selection != null) {
                detectedMode = _selectionController.hitTestHandles(
                  selection: _selection,
                  localPosition: localPos,
                  imageRect: imageRect,
                  zoomScale: zoomScale,
                );
              }

              if (detectedMode != SelectionMode.none) {
                setState(() {
                  _mode = detectedMode;
                });
                return;
              }

              // 2. Medium Priority: Check if tap is on an overlay widget or measurement lines.
              // If so, let the overlay handle the event and skip all selection logic
              if (_selection != null) {
                final Offset vpTopLeft = MatrixUtils.transformPoint(
                  matrix,
                  Offset(_selection!.left, _selection!.top),
                );
                final Offset vpBottomRight = MatrixUtils.transformPoint(
                  matrix,
                  Offset(
                    _selection!.left + _selection!.width,
                    _selection!.top + _selection!.height,
                  ),
                );
                final Rect vpSelection = Rect.fromPoints(
                  vpTopLeft,
                  vpBottomRight,
                );

                final double widthCardW = _editingWidth ? 110.0 : 60.0;
                final Rect visibleImgRect = _getVisibleImageRect(context);
                final Offset widthCardPos = _getWidthCardPosition(
                  vpSelection: vpSelection,
                  cardW: widthCardW,
                  cardH: 40.0,
                  vpW: viewSize.width,
                  vpH: viewSize.height,
                  visibleImageRect: visibleImgRect,
                );
                final Rect widthCardRect = Rect.fromLTWH(
                  widthCardPos.dx,
                  widthCardPos.dy,
                  widthCardW,
                  40.0,
                ).inflate(12.0);

                final double heightCardW = _editingHeight ? 110.0 : 60.0;
                final Offset heightCardPos = _getHeightCardPosition(
                  vpSelection: vpSelection,
                  cardW: heightCardW,
                  cardH: 40.0,
                  vpW: viewSize.width,
                  vpH: viewSize.height,
                  visibleImageRect: visibleImgRect,
                );
                final Rect heightCardRect = Rect.fromLTWH(
                  heightCardPos.dx,
                  heightCardPos.dy,
                  heightCardW,
                  40.0,
                ).inflate(12.0);

                final bool widthAxisAtTop = widthCardPos.dy < vpSelection.top;
                final double horizontalArrowTop = widthAxisAtTop
                    ? vpSelection.top - 18
                    : vpSelection.bottom + 8;
                final bool inWidthAxis =
                    vpPos.dx >= vpSelection.left - 12.0 &&
                    vpPos.dx <= vpSelection.right + 12.0 &&
                    (vpPos.dy - (horizontalArrowTop + 5)).abs() <= 20.0;

                final bool heightAxisAtLeft =
                    heightCardPos.dx < vpSelection.left;
                final double verticalArrowLeft = heightAxisAtLeft
                    ? vpSelection.left - 18
                    : vpSelection.right + 8;
                final bool inHeightAxis =
                    vpPos.dy >= vpSelection.top - 12.0 &&
                    vpPos.dy <= vpSelection.bottom + 12.0 &&
                    (vpPos.dx - (verticalArrowLeft + 5)).abs() <= 20.0;

                if (widthCardRect.contains(vpPos) ||
                    heightCardRect.contains(vpPos) ||
                    inWidthAxis ||
                    inHeightAxis) {
                  _interactingWithOverlay = true;
                  return;
                }
              }

              // 3. Low Priority: Tapped elsewhere inside the image viewport canvas.
              // Prepare for creating a new selection if they drag, but do not clear selection immediately.
              setState(() {
                _dragStart = localPos;
                _mode = SelectionMode.creating;
                _isDrawingNewSelection = false;
              });
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

                  _transformationController.value =
                      ZoomController.calculatePinchPan(
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

              final Matrix4 matrix = _transformationController.value;
              final Matrix4 inverse = Matrix4.inverted(matrix);
              final Offset localPos = MatrixUtils.transformPoint(
                inverse,
                event.localPosition,
              );
              final Rect imageRect = _getImageRect(context);

              if (_mode == SelectionMode.creating && _dragStart != null) {
                if (!_isDrawingNewSelection) {
                  final double dragDistance = (localPos - _dragStart!).distance;
                  if (dragDistance >= 5.0) {
                    final double imgL = imageRect.left;
                    final double imgR = imageRect.right;
                    final double imgT = imageRect.top;
                    final double imgB = imageRect.bottom;
                    setState(() {
                      _isDrawingNewSelection = true;
                      // Clamp the drag start point to the image bounds when drawing starts
                      final Offset clampedStart = Offset(
                        _dragStart!.dx.clamp(imgL, imgR),
                        _dragStart!.dy.clamp(imgT, imgB),
                      );
                      _dragStart = clampedStart;
                      _selection = SelectionRect(
                        left: clampedStart.dx,
                        top: clampedStart.dy,
                        width: 0,
                        height: 0,
                      );
                      _editingWidth = false;
                      _editingHeight = false;
                    });
                    context.read<ImageEditCubit>().clearSelection();
                  }
                }

                if (_isDrawingNewSelection) {
                  setState(() {
                    _selection = _selectionController.createSelection(
                      dragStart: _dragStart!,
                      currentPos: localPos,
                      imageRect: imageRect,
                    );
                  });
                }
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
              // If we were interacting with an overlay (label/editor),
              // skip all selection logic on pointer up
              if (_interactingWithOverlay) {
                _interactingWithOverlay = false;
                _activePointers.remove(event.pointer);
                if (_activePointers.isEmpty) {
                  _backupSelection = null;
                }
                return;
              }
              if (_justSaved) {
                _justSaved = false;
                _activePointers.remove(event.pointer);
                if (_activePointers.isEmpty) {
                  _backupSelection = null;
                }
                return;
              }
              final Matrix4 matrix = _transformationController.value;
              final Matrix4 inverse = Matrix4.inverted(matrix);
              final Offset localPos = MatrixUtils.transformPoint(
                inverse,
                event.localPosition,
              );
              final Size viewSize = _getViewSize(context);

              // 1. If we were preparing to create a selection but never actually dragged (simple tap)
              if (_mode == SelectionMode.creating) {
                final double dragDistance = _dragStart != null
                    ? (localPos - _dragStart!).distance
                    : 0.0;
                if (!_isDrawingNewSelection || dragDistance < 5.0) {
                  final Matrix4 matrix = _transformationController.value;
                  final Offset vpPos = MatrixUtils.transformPoint(
                    matrix,
                    localPos,
                  );

                  bool clickedOverlay = false;
                  if (_backupSelection != null) {
                    final Offset vpTopLeft = MatrixUtils.transformPoint(
                      matrix,
                      Offset(_backupSelection!.left, _backupSelection!.top),
                    );
                    final Offset vpBottomRight = MatrixUtils.transformPoint(
                      matrix,
                      Offset(
                        _backupSelection!.left + _backupSelection!.width,
                        _backupSelection!.top + _backupSelection!.height,
                      ),
                    );
                    final Rect vpSelection = Rect.fromPoints(
                      vpTopLeft,
                      vpBottomRight,
                    );

                    final double widthCardW = _editingWidth ? 110.0 : 60.0;
                    final Rect visibleImgRect2 = _getVisibleImageRect(context);
                    final Offset widthCardPos = _getWidthCardPosition(
                      vpSelection: vpSelection,
                      cardW: widthCardW,
                      cardH: 40.0,
                      vpW: viewSize.width,
                      vpH: viewSize.height,
                      visibleImageRect: visibleImgRect2,
                    );
                    final Rect widthCardRect = Rect.fromLTWH(
                      widthCardPos.dx,
                      widthCardPos.dy,
                      widthCardW,
                      40.0,
                    ).inflate(12.0);

                    final double heightCardW = _editingHeight ? 110.0 : 60.0;
                    final Offset heightCardPos = _getHeightCardPosition(
                      vpSelection: vpSelection,
                      cardW: heightCardW,
                      cardH: 40.0,
                      vpW: viewSize.width,
                      vpH: viewSize.height,
                      visibleImageRect: visibleImgRect2,
                    );
                    final Rect heightCardRect = Rect.fromLTWH(
                      heightCardPos.dx,
                      heightCardPos.dy,
                      heightCardW,
                      40.0,
                    ).inflate(12.0);

                    final bool widthAxisAtTop =
                        widthCardPos.dy < vpSelection.top;
                    final double horizontalArrowTop = widthAxisAtTop
                        ? vpSelection.top - 18
                        : vpSelection.bottom + 8;
                    final bool inWidthAxis =
                        vpPos.dx >= vpSelection.left - 12.0 &&
                        vpPos.dx <= vpSelection.right + 12.0 &&
                        (vpPos.dy - (horizontalArrowTop + 5)).abs() <= 20.0;

                    final bool heightAxisAtLeft =
                        heightCardPos.dx < vpSelection.left;
                    final double verticalArrowLeft = heightAxisAtLeft
                        ? vpSelection.left - 18
                        : vpSelection.right + 8;
                    final bool inHeightAxis =
                        vpPos.dy >= vpSelection.top - 12.0 &&
                        vpPos.dy <= vpSelection.bottom + 12.0 &&
                        (vpPos.dx - (verticalArrowLeft + 5)).abs() <= 20.0;

                    if (widthCardRect.contains(vpPos) ||
                        heightCardRect.contains(vpPos) ||
                        inWidthAxis ||
                        inHeightAxis) {
                      clickedOverlay = true;
                    }
                  }

                  if (clickedOverlay) {
                    // Tap on overlay: keep the selection!
                    setState(() {
                      _selection = _backupSelection;
                      _mode = SelectionMode.none;
                    });
                  } else {
                    // Tap anywhere else (outside selection, handles, and overlays): keep selection!
                    setState(() {
                      if (_backupSelection != null) {
                        _selection = _backupSelection;
                      }
                      _mode = SelectionMode.none;
                    });
                  }

                  _activePointers.remove(event.pointer);
                  _backupSelection = null;
                  _dragStart = null;
                  _isDrawingNewSelection = false;
                  return;
                }
              }

              // 2. If a resize/move gesture finished or a tap on an active handle/body occurred
              if (_backupSelection != null &&
                  _dragStart != null &&
                  _mode != SelectionMode.creating) {
                final double dragDistance = (localPos - _dragStart!).distance;
                if (dragDistance < 5.0) {
                  final Matrix4 matrix = _transformationController.value;
                  final Offset vpPos = MatrixUtils.transformPoint(
                    matrix,
                    localPos,
                  );
                  final double zoomScale = matrix.getMaxScaleOnAxis();

                  final Rect imageRect = _getImageRect(context);
                  // Check if tap hit a resize handle or selection body
                  final SelectionMode mode = _selectionController
                      .hitTestHandles(
                        selection: _backupSelection,
                        localPosition: localPos,
                        imageRect: imageRect,
                        zoomScale: zoomScale,
                      );

                  bool clickedOverlay = false;
                  if (_selection != null) {
                    final Offset vpTopLeft = MatrixUtils.transformPoint(
                      matrix,
                      Offset(_selection!.left, _selection!.top),
                    );
                    final Offset vpBottomRight = MatrixUtils.transformPoint(
                      matrix,
                      Offset(
                        _selection!.left + _selection!.width,
                        _selection!.top + _selection!.height,
                      ),
                    );
                    final Rect vpSelection = Rect.fromPoints(
                      vpTopLeft,
                      vpBottomRight,
                    );

                    final double widthCardW = _editingWidth ? 110.0 : 60.0;
                    final Rect visibleImgRect2 = _getVisibleImageRect(context);
                    final Offset widthCardPos = _getWidthCardPosition(
                      vpSelection: vpSelection,
                      cardW: widthCardW,
                      cardH: 40.0,
                      vpW: viewSize.width,
                      vpH: viewSize.height,
                      visibleImageRect: visibleImgRect2,
                    );
                    final Rect widthCardRect = Rect.fromLTWH(
                      widthCardPos.dx,
                      widthCardPos.dy,
                      widthCardW,
                      40.0,
                    ).inflate(12.0);

                    final double heightCardW = _editingHeight ? 110.0 : 60.0;
                    final Offset heightCardPos = _getHeightCardPosition(
                      vpSelection: vpSelection,
                      cardW: heightCardW,
                      cardH: 40.0,
                      vpW: viewSize.width,
                      vpH: viewSize.height,
                      visibleImageRect: visibleImgRect2,
                    );
                    final Rect heightCardRect = Rect.fromLTWH(
                      heightCardPos.dx,
                      heightCardPos.dy,
                      heightCardW,
                      40.0,
                    ).inflate(12.0);

                    final bool widthAxisAtTop =
                        widthCardPos.dy < vpSelection.top;
                    final double horizontalArrowTop = widthAxisAtTop
                        ? vpSelection.top - 18
                        : vpSelection.bottom + 8;
                    final bool inWidthAxis =
                        vpPos.dx >= vpSelection.left - 12.0 &&
                        vpPos.dx <= vpSelection.right + 12.0 &&
                        (vpPos.dy - (horizontalArrowTop + 5)).abs() <= 20.0;

                    final bool heightAxisAtLeft =
                        heightCardPos.dx < vpSelection.left;
                    final double verticalArrowLeft = heightAxisAtLeft
                        ? vpSelection.left - 18
                        : vpSelection.right + 8;
                    final bool inHeightAxis =
                        vpPos.dy >= vpSelection.top - 12.0 &&
                        vpPos.dy <= vpSelection.bottom + 12.0 &&
                        (vpPos.dx - (verticalArrowLeft + 5)).abs() <= 20.0;

                    if (widthCardRect.contains(vpPos) ||
                        heightCardRect.contains(vpPos) ||
                        inWidthAxis ||
                        inHeightAxis) {
                      clickedOverlay = true;
                    }
                  }

                  // Keep the selection if tapped outside selection body/handles/overlays
                  if (mode == SelectionMode.none && !clickedOverlay) {
                    setState(() {
                      if (_backupSelection != null) {
                        _selection = _backupSelection;
                      }
                      _mode = SelectionMode.none;
                    });
                    _activePointers.remove(event.pointer);
                    _backupSelection = null;
                    _dragStart = null;
                    _isDrawingNewSelection = false;
                    return;
                  }
                }
              }

              _activePointers.remove(event.pointer);

              if (_activePointers.isEmpty) {
                _backupSelection = null;
              }

              _isDrawingNewSelection = false;

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
                final double calculatedW =
                    MeasurementService.calculateWidthInchesFromPixelWidth(
                      _selection!.width,
                    );
                final double calculatedH =
                    MeasurementService.calculateHeightInchesFromPixelHeight(
                      _selection!.height,
                    );

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

                final double systemVal = MeasurementService.calculateAreaInSqFt(
                  newW,
                  newH,
                );

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
            child: InteractiveViewer(
              clipBehavior: Clip.none,
              transformationController: _transformationController,
              minScale: _currentMinZoomLimit,
              maxScale: 4.0,
              boundaryMargin: EdgeInsets.zero,
              panEnabled: false,
              scaleEnabled: false,
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
                              width:
                                  _originalImageWidth! * _currentDisplayScale,
                              height:
                                  _originalImageHeight! * _currentDisplayScale,
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                              cacheWidth: 800,
                            )
                          : Image.file(
                              File(_baseImage),
                              width:
                                  _originalImageWidth! * _currentDisplayScale,
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
                                    _originalImageHeight! *
                                    _currentDisplayScale,
                                fit: BoxFit.fill,
                                gaplessPlayback: true,
                                cacheWidth: 800,
                              )
                            : (_currentAssetPreview!.startsWith('/') ||
                                  _currentAssetPreview!.contains(
                                    'tryon_result',
                                  ))
                            ? Image.file(
                                File(_currentAssetPreview!),
                                width:
                                    _originalImageWidth! * _currentDisplayScale,
                                height:
                                    _originalImageHeight! *
                                    _currentDisplayScale,
                                fit: BoxFit.fill,
                                gaplessPlayback: true,
                                cacheWidth: 800,
                              )
                            : Image.asset(
                                _currentAssetPreview!,
                                width:
                                    _originalImageWidth! * _currentDisplayScale,
                                height:
                                    _originalImageHeight! *
                                    _currentDisplayScale,
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

                  if (!(state.isApplyLoading || _isPrecaching))
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
                ],
              ),
            ),
          ),
          if (state.isApplyLoading || _isPrecaching) ...[
            // Viewport-bounded blur overlay
            Builder(
              builder: (context) {
                final Size viewSize = _getViewSize(context);
                final Rect visibleImgRect = _getVisibleImageRect(context);

                Rect? vpSel;
                if (_selection != null) {
                  final Matrix4 matrix = _transformationController.value;
                  final Offset vpTopLeft = MatrixUtils.transformPoint(
                    matrix,
                    Offset(_selection!.left, _selection!.top),
                  );
                  final Offset vpBottomRight = MatrixUtils.transformPoint(
                    matrix,
                    Offset(
                      _selection!.left + _selection!.width,
                      _selection!.top + _selection!.height,
                    ),
                  );
                  vpSel = Rect.fromPoints(vpTopLeft, vpBottomRight);
                }

                return Positioned.fill(
                  child: ClipRect(
                    child: ClipPath(
                      clipper: InvertedRectClipper(
                        selection: vpSel,
                        imageRect: visibleImgRect,
                      ),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(color: Colors.black.withOpacity(0.4)),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_selection != null)
              Builder(
                builder: (context) {
                  final Matrix4 matrix = _transformationController.value;
                  final Offset vpTopLeft = MatrixUtils.transformPoint(
                    matrix,
                    Offset(_selection!.left, _selection!.top),
                  );
                  final Offset vpBottomRight = MatrixUtils.transformPoint(
                    matrix,
                    Offset(
                      _selection!.left + _selection!.width,
                      _selection!.top + _selection!.height,
                    ),
                  );
                  final Rect vpSel = Rect.fromPoints(vpTopLeft, vpBottomRight);
                  return Positioned.fill(
                    child: AIProcessingOverlay(
                      selectionRect: vpSel,
                      visibleImageRect: _getVisibleImageRect(context),
                    ),
                  );
                },
              ),
          ],

          if (_selection != null && !(state.isApplyLoading || _isPrecaching))
            Builder(
              builder: (context) {
                final Size viewSize = _getViewSize(context);
                final double vpW = viewSize.width;
                final double vpH = viewSize.height;
                final Matrix4 matrix = _transformationController.value;

                final Offset vpTopLeft = MatrixUtils.transformPoint(
                  matrix,
                  Offset(_selection!.left, _selection!.top),
                );
                final Offset vpBottomRight = MatrixUtils.transformPoint(
                  matrix,
                  Offset(
                    _selection!.left + _selection!.width,
                    _selection!.top + _selection!.height,
                  ),
                );
                final Rect vpSelection = Rect.fromPoints(
                  vpTopLeft,
                  vpBottomRight,
                );

                // Calculate positions for Width and Height cards using priorities
                final double widthCardW = _editingWidth ? 110.0 : 80.0;
                final double widthCardH = 40.0;
                final Rect visibleImgRectOverlay = _getVisibleImageRect(
                  context,
                );
                final Offset widthCardPos = _getWidthCardPosition(
                  vpSelection: vpSelection,
                  cardW: widthCardW,
                  cardH: widthCardH,
                  vpW: vpW,
                  vpH: vpH,
                  visibleImageRect: visibleImgRectOverlay,
                );

                final double heightCardW = _editingHeight ? 110.0 : 80.0;
                final double heightCardH = 40.0;
                final Offset heightCardPos = _getHeightCardPosition(
                  vpSelection: vpSelection,
                  cardW: heightCardW,
                  cardH: heightCardH,
                  vpW: vpW,
                  vpH: vpH,
                  visibleImageRect: visibleImgRectOverlay,
                );

                // Decide whether dashed lines (measurement axes) should be Top/Bottom or Left/Right
                // Width dashed line is top or bottom of the selection based on chosen card position
                final bool widthAxisAtTop = widthCardPos.dy < vpSelection.top;
                final double horizontalArrowTop = widthAxisAtTop
                    ? vpSelection.top - 18
                    : vpSelection.bottom + 8;

                // Height dashed line is left or right of the selection based on chosen card position
                final bool heightAxisAtLeft =
                    heightCardPos.dx < vpSelection.left;
                final double verticalArrowLeft = heightAxisAtLeft
                    ? vpSelection.left - 18
                    : vpSelection.right + 8;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Horizontal double arrow line
                    Positioned(
                      left: vpSelection.left,
                      top: horizontalArrowTop,
                      width: vpSelection.width,
                      height: 10,
                      child: CustomPaint(
                        painter: DashedLinePainter(axis: Axis.horizontal),
                      ),
                    ),
                    // Vertical double arrow line
                    Positioned(
                      left: verticalArrowLeft,
                      top: vpSelection.top,
                      width: 10,
                      height: vpSelection.height,
                      child: CustomPaint(
                        painter: DashedLinePainter(axis: Axis.vertical),
                      ),
                    ),
                    // Horizontal dimension label / inline editor
                    Positioned(
                      left: widthCardPos.dx,
                      top: widthCardPos.dy,
                      width: widthCardW,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) {
                          _interactingWithOverlay = true;
                        },
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
                                          _customWidthInches.round().toString();
                                      _editingWidth = true;
                                    });
                                  },
                                ),
                        ),
                      ),
                    ),
                    // Vertical dimension label / inline editor
                    Positioned(
                      left: heightCardPos.dx,
                      top: heightCardPos.dy,
                      width: heightCardW,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) {
                          _interactingWithOverlay = true;
                        },
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
                    ),
                  ],
                );
              },
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
          // Progress status card showing lamination steps during API generation
          if ((state.isApplyLoading || _isPrecaching) && _selection == null)
            Align(
              alignment: Alignment.center,
              child: const ProgressStatusCard(),
            ),
        ],
      ),
    );
  }

  Future<void> _handleUndo(ImageEditState state) async {
    setState(() {
      _feedbackLiked = null;
    });
    if (state.generatedHistory.isNotEmpty) {
      context.read<ImageEditCubit>().undoLastEdit();
      final newState = context.read<ImageEditCubit>().state;
      setState(() {
        _currentAssetPreview = newState.editedImageFile;
        _baseImage =
            newState.editedImageFile ??
            newState.originalImage ??
            widget.imageFile.path;
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
        _baseImage =
            newState.editedImageFile ??
            newState.originalImage ??
            widget.imageFile.path;
        if (newState.generatedHistory.isNotEmpty) {
          _hasNewUnappliedEdit = true;
        }
      });
    }
  }

  void _recalculateArea() {
    final double val = MeasurementService.calculateAreaInSqFt(
      _customWidthInches,
      _customHeightInches,
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.00),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${value.round()} in",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit, color: Colors.white, size: 12),
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
        controller: _horizontalScrollController,
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

  Future<void> _showDimensionInputDialog(
    BuildContext context,
    dynamic texture,
  ) async {
    final cubit = context.read<ImageEditCubit>();
    final lengthController = TextEditingController();
    final breadthController = TextEditingController();
    String selectedUnit = 'ft'; // Default unit: Feet
    String? errorMessage;

    final String skuName =
        texture["sku"] ?? texture["name"] ?? texture["title"] ?? "Laminate";

    void convertInputs(String oldUnit, String newUnit) {
      final lText = lengthController.text.trim();
      final bText = breadthController.text.trim();
      if (lText.isNotEmpty) {
        final double? val = double.tryParse(lText);
        if (val != null && val > 0) {
          if (oldUnit == 'ft' && newUnit == 'in') {
            lengthController.text = (val * 12).round().toString();
          } else if (oldUnit == 'in' && newUnit == 'ft') {
            final converted = val / 12.0;
            lengthController.text = converted % 1 == 0
                ? converted.toInt().toString()
                : converted.toStringAsFixed(1);
          }
        }
      }
      if (bText.isNotEmpty) {
        final double? val = double.tryParse(bText);
        if (val != null && val > 0) {
          if (oldUnit == 'ft' && newUnit == 'in') {
            breadthController.text = (val * 12).round().toString();
          } else if (oldUnit == 'in' && newUnit == 'ft') {
            final converted = val / 12.0;
            breadthController.text = converted % 1 == 0
                ? converted.toInt().toString()
                : converted.toStringAsFixed(1);
          }
        }
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false, // Mandatory modal
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              backgroundColor: Colors.white,
              clipBehavior: Clip.antiAlias,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFEA202C), Color(0xFFC01520)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.square_foot_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Enter Area Dimensions",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  skuName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dialog Body
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Exact dimensions are required before applying this laminate.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Error Banner
                          if (errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFFCDD2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Color(0xFFD32F2F),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      errorMessage!,
                                      style: const TextStyle(
                                        color: Color(0xFFD32F2F),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Unit Toggle Header & Selector
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Select Unit",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F2F7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (selectedUnit != 'ft') {
                                          setDialogState(() {
                                            convertInputs(selectedUnit, 'ft');
                                            selectedUnit = 'ft';
                                            errorMessage = null;
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selectedUnit == 'ft'
                                              ? Colors.white
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: selectedUnit == 'ft'
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.08),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Text(
                                          "Feet (ft)",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: selectedUnit == 'ft'
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: selectedUnit == 'ft'
                                                ? const Color(0xFFEA202C)
                                                : Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        if (selectedUnit != 'in') {
                                          setDialogState(() {
                                            convertInputs(selectedUnit, 'in');
                                            selectedUnit = 'in';
                                            errorMessage = null;
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selectedUnit == 'in'
                                              ? Colors.white
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: selectedUnit == 'in'
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.08),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Text(
                                          "Inches (in)",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: selectedUnit == 'in'
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: selectedUnit == 'in'
                                                ? const Color(0xFFEA202C)
                                                : Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Length Input
                          TextField(
                            controller: lengthController,
                            keyboardType: selectedUnit == 'in'
                                ? TextInputType.number
                                : const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: selectedUnit == 'in'
                                ? [FilteringTextInputFormatter.digitsOnly]
                                : null,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              labelText: "Length ($selectedUnit)*",
                              hintText: selectedUnit == 'in' ? "e.g. 102" : "e.g. 8.5",
                              prefixIcon: const Icon(Icons.height_rounded, size: 18),
                              suffixText: selectedUnit,
                              suffixStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black45,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF9F9FB),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFEA202C),
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Breadth Input
                          TextField(
                            controller: breadthController,
                            keyboardType: selectedUnit == 'in'
                                ? TextInputType.number
                                : const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: selectedUnit == 'in'
                                ? [FilteringTextInputFormatter.digitsOnly]
                                : null,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              labelText: "Breadth ($selectedUnit)*",
                              hintText: selectedUnit == 'in' ? "e.g. 48" : "e.g. 4.0",
                              prefixIcon: const Icon(Icons.swap_horiz_rounded, size: 18),
                              suffixText: selectedUnit,
                              suffixStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black45,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF9F9FB),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFEA202C),
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    side: const BorderSide(color: Color(0xFFD1D1D6)),
                                  ),
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop();
                                  },
                                  child: const Text(
                                    "Cancel",
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: const Color(0xFFEA202C),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () {
                                    final lengthText = lengthController.text.trim();
                                    final breadthText = breadthController.text.trim();

                                    if (lengthText.isEmpty || breadthText.isEmpty) {
                                      setDialogState(() {
                                        errorMessage = "Both Length and Breadth are required.";
                                      });
                                      return;
                                    }

                                    if (selectedUnit == 'in') {
                                      if (lengthText.contains('.') || breadthText.contains('.')) {
                                        setDialogState(() {
                                          errorMessage = "Decimal numbers are not allowed for Inches. Please enter whole numbers.";
                                        });
                                        return;
                                      }
                                    }

                                    final double? lengthVal = double.tryParse(lengthText);
                                    final double? breadthVal = double.tryParse(breadthText);

                                    if (lengthVal == null ||
                                        lengthVal <= 0 ||
                                        breadthVal == null ||
                                        breadthVal <= 0) {
                                      setDialogState(() {
                                        errorMessage = "Please enter valid positive numbers (> 0). Zero and negative values are not allowed.";
                                      });
                                      return;
                                    }

                                    // Convert final measurements to whole positive numbers (round to nearest whole number)
                                    int finalLengthInches;
                                    int finalBreadthInches;

                                    if (selectedUnit == 'in') {
                                      finalLengthInches = lengthVal.round();
                                      finalBreadthInches = breadthVal.round();
                                    } else {
                                      finalLengthInches = (lengthVal * 12.0).round();
                                      finalBreadthInches = (breadthVal * 12.0).round();
                                    }

                                    if (finalLengthInches <= 0 || finalBreadthInches <= 0) {
                                      setDialogState(() {
                                        errorMessage = "Calculated dimensions must be positive integers.";
                                      });
                                      return;
                                    }

                                    final int finalAreaSqInches = finalLengthInches * finalBreadthInches;
                                    final double areaSqFt = finalAreaSqInches / 144.0;

                                    // Print final whole positive number results to console
                                    debugPrint("==================================================");
                                    debugPrint("📐 DIMENSIONS CONFIRMED FOR: $skuName");
                                    debugPrint("   Input Unit: $selectedUnit");
                                    debugPrint("   Raw Input: Length=$lengthText, Breadth=$breadthText");
                                    debugPrint("   Final Length: $finalLengthInches in (whole positive number)");
                                    debugPrint("   Final Breadth: $finalBreadthInches in (whole positive number)");
                                    debugPrint("   Final Area: $areaSqFt sq. ft. ($finalAreaSqInches sq. in.)");
                                    debugPrint("==================================================");

                                    Navigator.of(dialogContext).pop();

                                    // Apply the laminate with calculated area and updated dimensions
                                    setState(() {
                                      _selectedTexture = texture;
                                      _customWidthInches = finalLengthInches.toDouble();
                                      _customHeightInches = finalBreadthInches.toDouble();
                                      _areaController.text = areaSqFt.toStringAsFixed(2);
                                    });

                                    // Explicitly update Cubit area payload with new obj_w and obj_h
                                    if (_selection != null) {
                                      _notifyCubitOfSelection();
                                    }

                                    // Set pattern and trigger API generation with user inputs
                                    cubit.selectPattern(texture);
                                    if (cubit.state.selectedArea != null && !cubit.state.isGenerating) {
                                      cubit.generateAIImage();
                                    }
                                  },
                                  child: const Text(
                                    "Continue",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextureThumbnail(dynamic texture, {required bool isGrid}) {
    final isSelected = _selectedTexture?["id"] == texture["id"];
    final imageUrl = texture["coverImage"] ?? "";
    final label =
        (texture["sku"] != null && texture["sku"].toString().isNotEmpty)
        ? texture["sku"].toString()
        : (texture["name"] ?? "");

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
        final isApplying =
            context.read<ImageEditCubit>().state.isApplyLoading ||
            _isPrecaching ||
            _isUploading ||
            context.read<ImageEditCubit>().state.isGenerating;
        if (isApplying) return;
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
        // Mandatory dimension prompt before applying laminate
        _showDimensionInputDialog(context, texture);
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
                  child: InteractiveViewer(
                    clipBehavior: Clip.none,
                    panEnabled: true,
                    scaleEnabled: true,
                    minScale: 1.0,
                    maxScale: 5.0,
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
        final double h = _customHeightInches;
        final double w = _customWidthInches;
        final double selectionAreaSqFt = (h * w) / 144.0;
        final double area =
            selectedRecord.userArea ??
            selectedRecord.systemArea ??
            selectionAreaSqFt;
        final double ratio = selectionAreaSqFt > 0
            ? (area / selectionAreaSqFt)
            : 1.0;
        final int opt1 = rectanglesNeeded(
          bigWidth: w,
          bigHeight: h,
          smallWidth: 96.0,
          smallHeight: 48.0,
        );
        final int opt2 = rectanglesNeeded(
          bigWidth: w,
          bigHeight: h,
          smallWidth: 48.0,
          smallHeight: 96.0,
        );
        final int baseSheets = opt1 < opt2 ? opt1 : opt2;
        final double sheetsNeeded = ratio * baseSheets;
        int est = sheetsNeeded.ceil();
        if (est < 1) est = 1;

        usedLaminates = usedLaminates.map((e) {
          final m = Map<String, dynamic>.from(e);
          m['estimatedSheets'] = m['estimatedSheets'] ?? est;
          return m;
        }).toList();
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
      final double h = _customHeightInches;
      final double w = _customWidthInches;
      final double selectionAreaSqFt = (h * w) / 144.0;
      final double area =
          latestRecord.userArea ?? latestRecord.systemArea ?? selectionAreaSqFt;
      final double ratio = selectionAreaSqFt > 0
          ? (area / selectionAreaSqFt)
          : 1.0;
      final int opt1 = rectanglesNeeded(
        bigWidth: w,
        bigHeight: h,
        smallWidth: 96.0,
        smallHeight: 48.0,
      );
      final int opt2 = rectanglesNeeded(
        bigWidth: w,
        bigHeight: h,
        smallWidth: 48.0,
        smallHeight: 96.0,
      );
      final int baseSheets = opt1 < opt2 ? opt1 : opt2;
      final double sheetsNeeded = ratio * baseSheets;
      int est = sheetsNeeded.ceil();
      if (est < 1) est = 1;

      usedLaminates = usedLaminates.map((e) {
        final m = Map<String, dynamic>.from(e);
        m['estimatedSheets'] = m['estimatedSheets'] ?? est;
        return m;
      }).toList();
    } else {
      // Fallback: pull from in-memory cubit history (no DB record yet)
      final state = context.read<ImageEditCubit>().state;
      final cubit = context.read<ImageEditCubit>();
      final double h = _customHeightInches;
      final double w = _customWidthInches;
      final double selectionAreaSqFt = (h * w) / 144.0;
      final double currentArea =
          double.tryParse(_areaController.text) ??
          _systemArea ??
          selectionAreaSqFt;
      final double ratio = selectionAreaSqFt > 0
          ? (currentArea / selectionAreaSqFt)
          : 1.0;
      final int opt1 = rectanglesNeeded(
        bigWidth: w,
        bigHeight: h,
        smallWidth: 96.0,
        smallHeight: 48.0,
      );
      final int opt2 = rectanglesNeeded(
        bigWidth: w,
        bigHeight: h,
        smallWidth: 48.0,
        smallHeight: 96.0,
      );
      final int baseSheets = opt1 < opt2 ? opt1 : opt2;
      final double sheetsNeeded = ratio * baseSheets;
      int currentEst = sheetsNeeded.ceil();
      if (currentEst < 1) currentEst = 1;

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
                    final bool isApplying =
                        state.isApplyLoading ||
                        _isPrecaching ||
                        _isUploading ||
                        state.isGenerating;
                    final bool hasResult =
                        state.currentGeneratedImage != null &&
                        _hasNewUnappliedEdit;

                    return ElevatedButton(
                      onPressed: (isApplying || !hasResult)
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
                          color: (isApplying || !hasResult)
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
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round;

    final double cornerLength = 7.5;

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
    final double edgeLength = 8.0;

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

class InvertedRectClipper extends CustomClipper<Path> {
  final Rect? selection;
  final Rect imageRect;

  InvertedRectClipper({required this.selection, required this.imageRect});

  @override
  Path getClip(Size size) {
    if (selection == null) {
      return Path()..addRect(imageRect);
    }
    final Path path = Path()..addRect(imageRect);
    final Path selPath = Path()..addRect(selection!);
    return Path.combine(PathOperation.difference, path, selPath);
  }

  @override
  bool shouldReclip(covariant InvertedRectClipper oldClipper) {
    return oldClipper.selection != selection ||
        oldClipper.imageRect != imageRect;
  }
}

class AIProcessingOverlay extends StatefulWidget {
  final Rect selectionRect;
  final Rect visibleImageRect;

  const AIProcessingOverlay({
    super.key,
    required this.selectionRect,
    required this.visibleImageRect,
  });

  @override
  State<AIProcessingOverlay> createState() => _AIProcessingOverlayState();
}

class _AIProcessingOverlayState extends State<AIProcessingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Stopwatch _stopwatch;
  Timer? _statusTimer;
  int _currentTextStep = 0;
  int _fakeProgress = 0;
  double _fakeProgressDouble = 0.0;

  double _t1Start = 0.0;
  double _t1End = 0.0;
  double _t2Start = 0.0;
  double _t2End = 0.0;
  double _t3Start = 0.0;
  double _t3End = 0.0;
  double _t4Start = 0.0;
  double _t4End = 0.0;
  double _t5Start = 0.0;

  final List<String> _steps = [
    "Perspective aligned",
    "Lighting matched",
    "Texture applied",
    "Edge refinement",
    "Final rendering",
  ];

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();

    // Generate randomized durations between 4.0 and 7.0 seconds for each stage
    final random = math.Random();
    final double d0 = 4.5 + random.nextDouble() * 2.5;
    final double d1 = 4.5 + random.nextDouble() * 2.5;
    final double d2 = 4.5 + random.nextDouble() * 2.5;
    final double d3 = 4.5 + random.nextDouble() * 2.5;
    const double overlap = 0.5;

    _t1Start = 0.0;
    _t1End = d0;

    _t2Start = _t1End - overlap;
    _t2End = _t2Start + d1;

    _t3Start = _t2End - overlap;
    _t3End = _t3Start + d2;

    _t4Start = _t3End - overlap;
    _t4End = _t4Start + d3;

    _t5Start = _t4End;

    // Repeating 60fps trigger to keep repainting continuously
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _statusTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        double elapsed = _stopwatch.elapsedMilliseconds / 1000.0;
        int newStep = 0;
        if (elapsed >= _t5Start)
          newStep = 4;
        else if (elapsed >= _t4Start)
          newStep = 3;
        else if (elapsed >= _t3Start)
          newStep = 2;
        else if (elapsed >= _t2Start)
          newStep = 1;

        // Wave-like random speeds: some periods fast surge, some slow stall
        final int phase = (elapsed.toInt()) % 5;
        double speedFactor = 1.0;
        if (phase == 0) {
          speedFactor = 2.4; // Quick surge
        } else if (phase == 2) {
          speedFactor = 0.2; // Slow stall
        } else if (phase == 4) {
          speedFactor = 1.6; // Moderate surge
        } else {
          speedFactor = 0.8;
        }

        // Increment the float progress
        _fakeProgressDouble += (0.4 * speedFactor);
        if (_fakeProgressDouble > 99.0) {
          _fakeProgressDouble = 99.0;
        }
        int targetProgress = _fakeProgressDouble.toInt();

        if (newStep != _currentTextStep || targetProgress != _fakeProgress) {
          setState(() {
            _currentTextStep = newStep;
            _fakeProgress = targetProgress;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Rect vpSel = widget.selectionRect;
    final Rect imgRect = widget.visibleImageRect;
    const double safePad = 8.0;
    // Consistent gap between selection edge and text
    const double gap = 10.0;
    const double insetPad = 12.0;
    // Estimated sizes for the text elements
    const double textHeight = 16.0;
    const double percentHeight = 16.0;
    const double textWidth = 180.0;
    const double percentWidth = 150.0;

    // Decide whether to place labels outside or inside the selection
    final bool showOutside =
        vpSel.top > (gap + textHeight + safePad + 10) && vpSel.left > insetPad;

    // Status text: above selection (outside) or just inside top-left
    double textLeft = showOutside ? vpSel.left : vpSel.left + insetPad;
    double textTop = showOutside
        ? vpSel.top - gap - textHeight
        : vpSel.top + insetPad;

    // Percentage text: below selection (outside) or just inside bottom-left
    double percentLeft = showOutside ? vpSel.left : vpSel.left + insetPad;
    double percentTop = showOutside
        ? vpSel.bottom + gap
        : vpSel.bottom - insetPad - percentHeight;

    // Clamp text position within the visible image rect
    textLeft = textLeft.clamp(
      imgRect.left + safePad,
      (imgRect.right - textWidth - safePad).clamp(
        imgRect.left + safePad,
        double.infinity,
      ),
    );
    textTop = textTop.clamp(
      imgRect.top + safePad,
      (imgRect.bottom - textHeight - safePad).clamp(
        imgRect.top + safePad,
        double.infinity,
      ),
    );

    // Clamp percentage position within the visible image rect
    percentLeft = percentLeft.clamp(
      imgRect.left + safePad,
      (imgRect.right - percentWidth - safePad).clamp(
        imgRect.left + safePad,
        double.infinity,
      ),
    );
    percentTop = percentTop.clamp(
      imgRect.top + safePad,
      (imgRect.bottom - percentHeight - safePad).clamp(
        imgRect.top + safePad,
        double.infinity,
      ),
    );

    return ClipRect(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fromRect(
            rect: vpSel,
            child: ClipRect(
              child: CustomPaint(
                size: Size(vpSel.width, vpSel.height),
                painter: StepSpecificPainter(
                  animation: _animationController,
                  stopwatch: _stopwatch,
                  t1Start: _t1Start,
                  t1End: _t1End,
                  t2Start: _t2Start,
                  t2End: _t2End,
                  t3Start: _t3Start,
                  t3End: _t3End,
                  t4Start: _t4Start,
                  t4End: _t4End,
                  t5Start: _t5Start,
                ),
              ),
            ),
          ),
          Positioned(
            left: textLeft,
            top: textTop,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Row(
                key: ValueKey<int>(_currentTextStep),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _steps[_currentTextStep],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 4,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Progress percentage indicator at the bottom right of the selection
          Positioned(
            left: percentLeft,
            top: percentTop,
            child: Text(
              "Rendering... $_fakeProgress%",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 4,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StepSpecificPainter extends CustomPainter {
  final Animation<double> animation;
  final Stopwatch stopwatch;
  final double t1Start;
  final double t1End;
  final double t2Start;
  final double t2End;
  final double t3Start;
  final double t3End;
  final double t4Start;
  final double t4End;
  final double t5Start;

  StepSpecificPainter({
    required this.animation,
    required this.stopwatch,
    required this.t1Start,
    required this.t1End,
    required this.t2Start,
    required this.t2End,
    required this.t3Start,
    required this.t3End,
    required this.t4Start,
    required this.t4End,
    required this.t5Start,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.clipRect(rect);

    double elapsed = stopwatch.elapsedMilliseconds / 1000.0;

    // Constant base dimming overlay
    double baseOpacity = 0.6;
    if (baseOpacity > 0) {
      canvas.drawRect(
        rect,
        Paint()..color = Colors.black.withOpacity(baseOpacity),
      );
    }

    // Overlapping Pipeline Stages (using Stopwatch time so they never freeze)
    if (elapsed > t1Start && elapsed < t1End)
      _drawPerspectiveGrid(canvas, size, _mapTime(elapsed, t1Start, t1End));
    if (elapsed > t2Start && elapsed < t2End)
      _drawLighting(canvas, size, _mapTime(elapsed, t2Start, t2End));
    if (elapsed > t3Start && elapsed < t3End)
      _drawTextureMapping(canvas, size, _mapTime(elapsed, t3Start, t3End));
    if (elapsed > t4Start && elapsed < t4End)
      _drawEdgeRefinement(canvas, size, _mapTime(elapsed, t4Start, t4End));
    if (elapsed > t5Start) _drawFinalRender(canvas, size, elapsed - t5Start);
  }

  double _mapTime(double elapsed, double start, double end) {
    return ((elapsed - start) / (end - start)).clamp(0.0, 1.0);
  }

  void _drawPerspectiveGrid(Canvas canvas, Size size, double progress) {
    double fade = (1.0 - progress).clamp(0.0, 1.0);
    if (fade <= 0) return;

    final Paint gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.2 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    double spacing = size.width / 8;
    int vLines = (size.width / spacing).ceil();
    int hLines = (size.height / spacing).ceil();

    for (int i = 0; i <= vLines; i++) {
      double x = i * spacing;
      double distanceToCenter = (x - size.width / 2).abs();
      double lineProgress = (progress * 2.0 - distanceToCenter / size.width)
          .clamp(0.0, 1.0);
      if (lineProgress > 0) {
        double startY = size.height / 2 * (1 - lineProgress);
        double endY = size.height - startY;
        canvas.drawLine(Offset(x, startY), Offset(x, endY), gridPaint);
      }
    }

    for (int i = 0; i <= hLines; i++) {
      double y = i * spacing;
      double distanceToCenter = (y - size.height / 2).abs();
      double lineProgress = (progress * 2.0 - distanceToCenter / size.height)
          .clamp(0.0, 1.0);
      if (lineProgress > 0) {
        double startX = size.width / 2 * (1 - lineProgress);
        double endX = size.width - startX;
        canvas.drawLine(Offset(startX, y), Offset(endX, y), gridPaint);
      }
    }
  }

  void _drawLighting(Canvas canvas, Size size, double progress) {
    double alpha = math.sin(progress * math.pi);
    if (alpha <= 0) return;

    final double gradientOffset = math.sin(progress * 2 * math.pi) * 0.5 + 0.5;
    final Paint lightPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * gradientOffset, size.height * 0.5),
        math.max(size.width, size.height) * 0.8,
        [Colors.amber.withOpacity(0.3 * alpha), Colors.transparent],
      )
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), lightPaint);
  }

  void _drawTextureMapping(Canvas canvas, Size size, double progress) {
    double fade = math.sin(progress * math.pi); // Fade in and out
    if (fade <= 0) return;

    final Paint pointPaint = Paint()..strokeWidth = 1.0;

    double spacing = 8.0;
    int cols = (size.width / spacing).ceil();
    int rows = (size.height / spacing).ceil();

    for (int i = 0; i <= cols; i++) {
      for (int j = 0; j <= rows; j++) {
        // Deterministic pseudo-random value
        double hash = ((i * 12.9898 + j * 78.233) * 43758.5453) % 1.0;
        hash = hash.abs();

        double spatialOffset = (i / cols + j / rows) / 2.0;

        // Continuous looping evolution for each point
        double localTime = (progress * 10.0 + hash + spatialOffset);
        double cycle = (localTime % 1.0);

        double particleAlpha = math.sin(cycle * math.pi) * fade;

        if (particleAlpha > 0.05) {
          pointPaint.color = Colors.white.withOpacity(0.3 * particleAlpha);
          double x = i * spacing;
          double y = j * spacing;

          if (hash > 0.5) {
            canvas.drawCircle(Offset(x, y), 1.0 + particleAlpha, pointPaint);
          } else {
            canvas.drawLine(
              Offset(x - particleAlpha * 2, y),
              Offset(x + particleAlpha * 2, y),
              pointPaint,
            );
            canvas.drawLine(
              Offset(x, y - particleAlpha * 2),
              Offset(x, y + particleAlpha * 2),
              pointPaint,
            );
          }
        }
      }
    }
  }

  void _drawEdgeRefinement(Canvas canvas, Size size, double progress) {
    double fade = math.sin(progress * math.pi);
    if (fade <= 0) return;

    final Path borderPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    double perimeter = 2 * size.width + 2 * size.height;

    // Base edge that gently solidifies
    final Paint basePaint = Paint()
      ..color = Colors.white.withOpacity(0.05 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(borderPath, basePaint);

    // Fast moving glowing tracers
    final Paint glowPaint = Paint()
      ..color = Colors.white.withOpacity(fade)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    final Paint corePaint = Paint()
      ..color = Colors.white.withOpacity(fade)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    int numTracers = 3;
    double tracerLength = perimeter * 0.15;

    for (int i = 0; i < numTracers; i++) {
      // Continuous uninterrupted movement
      double speed = 1.0 + i * 0.3;
      double startOffset = (i / numTracers) * perimeter;
      double currentDist =
          (startOffset + progress * 6.0 * perimeter * speed) % perimeter;

      Path tracer = _extractPath(borderPath, currentDist, tracerLength);
      canvas.drawPath(tracer, glowPaint);
      canvas.drawPath(tracer, corePaint);
    }
  }

  Path _extractPath(Path source, double start, double length) {
    Path dest = Path();
    for (final ui.PathMetric metric in source.computeMetrics()) {
      if (start + length > metric.length) {
        dest.addPath(metric.extractPath(start, metric.length), Offset.zero);
        dest.addPath(
          metric.extractPath(0, (start + length) - metric.length),
          Offset.zero,
        );
      } else {
        dest.addPath(metric.extractPath(start, start + length), Offset.zero);
      }
    }
    return dest;
  }

  void _drawFinalRender(Canvas canvas, Size size, double stageElapsed) {
    // Loop the wave sweep continuously every 2.0 seconds based on stageElapsed
    double animationValue = (stageElapsed / 2.0) % 1.0;

    // Restrict drawing strictly to selection boundaries
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    const double cellSpacing = 12.0;
    final int cols = (size.width / cellSpacing).ceil();
    final int rows = (size.height / cellSpacing).ceil();

    // 1. Draw thin, highly transparent background grid lines (red at 3% opacity)
    final Paint linePaint = Paint()
      ..color = Colors.red.withOpacity(0.03)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int col = 0; col <= cols; col++) {
      final double x = col * cellSpacing;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (int row = 0; row <= rows; row++) {
      final double y = row * cellSpacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // 2. Wave calculation: sweep vertically continuously without pausing
    final double waveProgress = animationValue;
    final double waveCenter = waveProgress * (rows + 4) - 2.0;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        // Deterministic seed based on cell coordinates and prime numbers
        final int seed = row * 197 + col * 307;

        // Phase offset and time factor - use continuous stageElapsed to prevent modulo wrapping glitches
        final double phase = (seed % 100) / 100.0 * 2.0 * math.pi;
        final double timeScale = 1.0 + ((seed % 4) * 0.15);
        final double angle = (stageElapsed * 2.0 * math.pi * timeScale) + phase;
        final double baseOsc = (math.sin(angle) + 1.0) / 2.0; // 0.0 to 1.0

        // Spatial clustering (moving zone of active cells)
        final double clusterVal =
            (math.sin(col * 0.3 + stageElapsed * 2.0 * math.pi) +
                math.cos(row * 0.3 - stageElapsed * 2.0 * math.pi * 1.3) +
                2.0) /
            4.0;

        // Vertical wave boost (sweeps top to bottom rapidly)
        double waveBoost = 0.0;
        final double distToWave = (row.toDouble() - waveCenter).abs();
        if (distToWave < 3.5) {
          waveBoost = (1.0 - (distToWave / 3.5)) * 0.15;
        }

        // Determine activation threshold and calculate final opacity
        final double threshold = 0.58 + ((seed % 8) * 0.04); // 0.58 to 0.90
        double cellOpacity = 0.0;

        if (baseOsc > threshold) {
          final double normalizedActive =
              (baseOsc - threshold) / (1.0 - threshold);
          // Blends the activation strength with the spatial cluster factor
          cellOpacity =
              0.03 + (normalizedActive * 0.09 * (0.2 + 0.8 * clusterVal));
        } else {
          // Extremely subtle background pixel breathing
          cellOpacity = 0.003 + (baseOsc * 0.012);
        }

        // Apply processing wave boost
        cellOpacity += waveBoost;
        cellOpacity = cellOpacity.clamp(0.0, 0.22);

        // Render the active cell
        if (cellOpacity > 0.015) {
          final Paint cellPaint = Paint()
            ..color = Colors.red.withOpacity(cellOpacity)
            ..style = PaintingStyle.fill;

          final Rect cellRect = Rect.fromLTWH(
            col * cellSpacing + 0.75,
            row * cellSpacing + 0.75,
            cellSpacing - 1.5,
            cellSpacing - 1.5,
          );
          canvas.drawRect(cellRect, cellPaint);

          // Optional tiny center glow for high-activity cells
          if (cellOpacity > 0.16) {
            final Paint glowPaint = Paint()
              ..color = Colors.white.withOpacity(0.6)
              ..style = PaintingStyle.fill;
            canvas.drawCircle(
              Offset(
                col * cellSpacing + cellSpacing / 2.0,
                row * cellSpacing + cellSpacing / 2.0,
              ),
              0.8,
              glowPaint,
            );
          }
        }
      }
    }

    // 3. Draw a very subtle selection boundary border (30% opacity red)
    final Paint borderPaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);
  }

  @override
  bool shouldRepaint(covariant StepSpecificPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}

class RegionScanningOverlay extends StatefulWidget {
  final Rect rect;

  const RegionScanningOverlay({super.key, required this.rect});

  @override
  State<RegionScanningOverlay> createState() => _RegionScanningOverlayState();
}

class _RegionScanningOverlayState extends State<RegionScanningOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.rect.width, widget.rect.height),
          painter: _ScanningPainter(animationValue: _controller.value),
        );
      },
    );
  }
}

class _ScanningPainter extends CustomPainter {
  final double animationValue;

  _ScanningPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Restrict drawing strictly to selection boundaries
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    const double cellSpacing = 12.0;
    final int cols = (size.width / cellSpacing).ceil();
    final int rows = (size.height / cellSpacing).ceil();

    // 1. Draw thin, highly transparent background grid lines (red at 3% opacity)
    final Paint linePaint = Paint()
      ..color = Colors.red.withOpacity(0.03)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int col = 0; col <= cols; col++) {
      final double x = col * cellSpacing;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (int row = 0; row <= rows; row++) {
      final double y = row * cellSpacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // 2. Wave calculation: sweep vertically (top to bottom) during the first 35% of cycle, then pause
    final bool isWaveActive = animationValue < 0.35;
    final double waveProgress = isWaveActive ? (animationValue / 0.35) : 0.0;
    final double waveCenter = waveProgress * (rows + 4) - 2.0;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        // Deterministic seed based on cell coordinates and prime numbers
        final int seed = row * 197 + col * 307;

        // Phase offset and time factor for cell animation
        final double phase = (seed % 100) / 100.0 * 2.0 * math.pi;
        final double timeScale = 1.0 + ((seed % 4) * 0.15);
        final double angle =
            (animationValue * 2.0 * math.pi * timeScale) + phase;
        final double baseOsc = (math.sin(angle) + 1.0) / 2.0; // 0.0 to 1.0

        // Spatial clustering (moving zone of active cells)
        final double clusterVal =
            (math.sin(col * 0.3 + animationValue * 2.0 * math.pi) +
                math.cos(row * 0.3 - animationValue * 2.0 * math.pi * 1.3) +
                2.0) /
            4.0;

        // Vertical wave boost (sweeps top to bottom rapidly, then pauses)
        double waveBoost = 0.0;
        if (isWaveActive) {
          final double distToWave = (row.toDouble() - waveCenter).abs();
          if (distToWave < 3.5) {
            waveBoost = (1.0 - (distToWave / 3.5)) * 0.15;
          }
        }

        // Determine activation threshold and calculate final opacity
        final double threshold = 0.58 + ((seed % 8) * 0.04); // 0.58 to 0.90
        double cellOpacity = 0.0;

        if (baseOsc > threshold) {
          final double normalizedActive =
              (baseOsc - threshold) / (1.0 - threshold);
          // Blends the activation strength with the spatial cluster factor
          cellOpacity =
              0.03 + (normalizedActive * 0.09 * (0.2 + 0.8 * clusterVal));
        } else {
          // Extremely subtle background pixel breathing
          cellOpacity = 0.003 + (baseOsc * 0.012);
        }

        // Apply processing wave boost
        cellOpacity += waveBoost;
        cellOpacity = cellOpacity.clamp(0.0, 0.22);

        // Render the active cell
        if (cellOpacity > 0.015) {
          final Paint cellPaint = Paint()
            ..color = Colors.red.withOpacity(cellOpacity)
            ..style = PaintingStyle.fill;

          final Rect cellRect = Rect.fromLTWH(
            col * cellSpacing + 0.75,
            row * cellSpacing + 0.75,
            cellSpacing - 1.5,
            cellSpacing - 1.5,
          );
          canvas.drawRect(cellRect, cellPaint);

          // Optional tiny center glow for high-activity cells
          if (cellOpacity > 0.16) {
            final Paint glowPaint = Paint()
              ..color = Colors.white.withOpacity(0.6)
              ..style = PaintingStyle.fill;
            canvas.drawCircle(
              Offset(
                col * cellSpacing + cellSpacing / 2.0,
                row * cellSpacing + cellSpacing / 2.0,
              ),
              0.8,
              glowPaint,
            );
          }
        }
      }
    }

    // 3. Draw a very subtle selection boundary border (30% opacity red)
    final Paint borderPaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ScanningPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class ProgressStatusCard extends StatefulWidget {
  const ProgressStatusCard({super.key});

  @override
  State<ProgressStatusCard> createState() => _ProgressStatusCardState();
}

class _ProgressStatusCardState extends State<ProgressStatusCard> {
  int _currentStep = 0;
  Timer? _timer;
  final List<String> _steps = [
    "Measuring the area...",
    "Cutting the lamination...",
    "Applying the lamination...",
    "Finalizing...",
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (mounted) {
        setState(() {
          if (_currentStep < _steps.length - 1) {
            _currentStep++;
          } else {
            _timer?.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _steps[_currentStep],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
