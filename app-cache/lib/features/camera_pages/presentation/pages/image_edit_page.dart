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
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _widthEditController = TextEditingController();
  final TextEditingController _heightEditController = TextEditingController();
  double? _systemArea;
  double _customWidthInches = 24.0;
  double _customHeightInches = 30.0;
  bool _editingWidth = false;
  bool _editingHeight = false;

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
  double _initialScale = 1.0;

  /// Minimum allowed zoom scale — set to the initial viewport-fit scale so
  /// users can never zoom out far enough to reveal blank canvas.
  double _minScale = 1.0;

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
        final double imgW = image.width.toDouble();
        final double imgH = image.height.toDouble();

        // Viewport size for the top image area
        final double vpW = MediaQuery.of(context).size.width;
        final double vpH = MediaQuery.of(context).size.height * 0.40;

        // fitScale = scale at which the image exactly fills the viewport
        // (identical to BoxFit.cover math). Used for OverflowBox sizing.
        final double fitScale = math.max(vpW / imgW, vpH / imgH);

        setState(() {
          _originalImageWidth = imgW;
          _originalImageHeight = imgH;
          // _minScale stores the cover scale for OverflowBox sizing.
          // TransformationController stays at identity — OverflowBox
          // centres the image in the Stack, matching BoxFit.cover visually.
          _minScale = fitScale;
          // _initialScale stays 1.0 (the TC baseline for pinch gestures).
        });
        debugPrint(
          '📸 Image: ${imgW}x${imgH} | VP: ${vpW}x${vpH} | fitScale: $fitScale',
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
    final double vpW = MediaQuery.of(context).size.width;
    final double vpH = MediaQuery.of(context).size.height * 0.40;
    final double currentScale =
        _transformationController.value.getMaxScaleOnAxis();
    final double newScale = (currentScale + 0.5).clamp(1.0, 4.0);

    // Pan bounds for OverflowBox-rendered image at newScale
    final double imgDisplayW =
        _originalImageWidth != null ? _originalImageWidth! * _minScale : vpW;
    final double imgDisplayH =
        _originalImageHeight != null ? _originalImageHeight! * _minScale : vpH;
    final double imgLeft = (vpW - imgDisplayW) / 2.0;
    final double imgTop = (vpH - imgDisplayH) / 2.0;

    // Scale around viewport centre
    final double currentTx = _transformationController.value.storage[12];
    final double currentTy = _transformationController.value.storage[13];
    final double ratio = newScale / currentScale;
    double newTx = (vpW / 2.0) - (vpW / 2.0 - currentTx) * ratio;
    double newTy = (vpH / 2.0) - (vpH / 2.0 - currentTy) * ratio;

    newTx = newTx.clamp(
      vpW - newScale * (imgLeft + imgDisplayW),
      -newScale * imgLeft,
    );
    newTy = newTy.clamp(
      vpH - newScale * (imgTop + imgDisplayH),
      -newScale * imgTop,
    );

    _transformationController.value =
        Matrix4.identity()
          ..translate(newTx, newTy)
          ..scale(newScale);
  }

  void _zoomOut() {
    final double vpW = MediaQuery.of(context).size.width;
    final double vpH = MediaQuery.of(context).size.height * 0.40;
    final double currentScale =
        _transformationController.value.getMaxScaleOnAxis();
    final double newScale = (currentScale - 0.5).clamp(1.0, 4.0);

    // Pan bounds for OverflowBox-rendered image at newScale
    final double imgDisplayW =
        _originalImageWidth != null ? _originalImageWidth! * _minScale : vpW;
    final double imgDisplayH =
        _originalImageHeight != null ? _originalImageHeight! * _minScale : vpH;
    final double imgLeft = (vpW - imgDisplayW) / 2.0;
    final double imgTop = (vpH - imgDisplayH) / 2.0;

    final double currentTx = _transformationController.value.storage[12];
    final double currentTy = _transformationController.value.storage[13];
    final double ratio = newScale / currentScale;
    double newTx = (vpW / 2.0) - (vpW / 2.0 - currentTx) * ratio;
    double newTy = (vpH / 2.0) - (vpH / 2.0 - currentTy) * ratio;

    newTx = newTx.clamp(
      vpW - newScale * (imgLeft + imgDisplayW),
      -newScale * imgLeft,
    );
    newTy = newTy.clamp(
      vpH - newScale * (imgTop + imgDisplayH),
      -newScale * imgTop,
    );

    _transformationController.value =
        Matrix4.identity()
          ..translate(newTx, newTy)
          ..scale(newScale);
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
    "Abstract Patterns": ["All", "Cement", "Grunge & Rustic", "Others"],
    "Woodgrains": ["All", "Dark", "Medium", "Light"],
    "Stones": ["All", "Marble", "Travertine", "Ivory"],
    "Solid": ["All", "Green", "White", "Blue", "Yellow", "Grey", "Other"],
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

        // ── Preview entering: decode mask once
        if (state.showSelectionPreview &&
            state.pendingMaskBytes != null &&
            _decodedMaskImage == null) {
          _decodeMaskImage(state.pendingMaskBytes!);
        }

        // ── Preview leaving (Accept OR Cancel):
        // Always clear mask + selection in ONE atomic setState whenever
        // showSelectionPreview transitions to false while we hold a decoded mask.
        if (!state.showSelectionPreview && _decodedMaskImage != null) {
          final bool wasAccepted =
              state.currentGeneratedImage != null &&
              state.currentGeneratedImage != _baseImage;

          setState(() {
            _decodedMaskImage?.dispose();
            _decodedMaskImage = null;
            _maskFillPath = null;
            _maskEdgePath = null;
            _selection = null;
            _selectedTexture = null;

            if (wasAccepted) {
              _baseImage = state.currentGeneratedImage!;
              _hasNewUnappliedEdit = true;
            }
          });

          if (wasAccepted && state.editedImageFile != null) {
            setState(() {
              _isPrecaching = true;
              _currentAssetPreview = state.editedImageFile;
            });
            final imageProvider = FileImage(File(state.editedImageFile!));
            precacheImage(imageProvider, context)
                .then((_) {
                  if (mounted) setState(() => _isPrecaching = false);
                })
                .catchError((e) {
                  if (mounted) setState(() => _isPrecaching = false);
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
              final bool inPreview = state.showSelectionPreview;
              final isApplying =
                  (state.isApplyLoading && !inPreview) ||
                  _isPrecaching ||
                  _isUploading;
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
                              if ((state.isApplyLoading && !inPreview) ||
                                  _isPrecaching) {
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
                                // Preview approval bar — replaces all normal bottom bars
                                if (inPreview)
                                  Positioned.fill(
                                    child: _buildPreviewApprovalBar(state),
                                  ),
                                // Fixed Bottom Bar Area (Edit Mode)
                                if (!inPreview && _editExpanded)
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: _buildBottomBarFixed(),
                                  ),
                                // Fixed Bottom Bar Area (Compare Mode)
                                if (!inPreview && _compareExpanded)
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
              final bool canUndo = state.appliedLayers.isNotEmpty || (_parentEditId != null);
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
                trailing: Opacity(
                  opacity: canUndo ? 1.0 : 0.4,
                  child: GestureDetector(
                    onTap: canUndo ? () => _handleUndo(state) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          // const SizedBox(height: 4),
          // _buildSearchBar(),
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
          if (_selection != null) ...[
            const SizedBox(height: 8),
            _buildAreaInputSection(),
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
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          suffixText: "sq. ft.",
                          suffixStyle: const TextStyle(fontSize: 9, color: Colors.black45),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: TColors.primary),
                          ),
                        ),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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

  bool _isPointInHorizontalOverlay(Offset localPos) {
    if (_selection == null) return false;
    final double left = _selection!.left + (_selection!.width - 150) / 2;
    final double top = _selection!.top + _selection!.height + 22;
    final double right = left + 150;
    final double bottom = top + 50;
    return localPos.dx >= left && localPos.dx <= right && localPos.dy >= top && localPos.dy <= bottom;
  }

  bool _isPointInVerticalOverlay(Offset localPos) {
    if (_selection == null) return false;
    final double left = _selection!.left + _selection!.width + 22;
    final double top = _selection!.top + (_selection!.height - 40) / 2;
    final double right = left + 120;
    final double bottom = top + 40;
    return localPos.dx >= left && localPos.dx <= right && localPos.dy >= top && localPos.dy <= bottom;
  }

  Widget _buildImageOverlaySection(ImageEditState state) {
    final bool inPreview = state.showSelectionPreview;

    if (inPreview) {
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Show the full image using the same OverflowBox approach as edit
            // mode — no cropping, full image visible, landscape/portrait
            // overflow accessible. MarchingAntsMaskPainter (Positioned.fill)
            // self-computes its own BoxFit.cover transform so it aligns
            // correctly with the full viewport.
            if (_originalImageWidth != null)
              OverflowBox(
                alignment: Alignment.center,
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: _baseImage.startsWith('http')
                    ? Image.network(
                        _baseImage,
                        width: _originalImageWidth! * _minScale,
                        height: _originalImageHeight! * _minScale,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        cacheWidth: 800,
                      )
                    : Image.file(
                        File(_baseImage),
                        width: _originalImageWidth! * _minScale,
                        height: _originalImageHeight! * _minScale,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        cacheWidth: 800,
                      ),
              )
            else
              // Fallback before dimensions load
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

            // Mask overlay — Positioned.fill spans the full viewport;
            // MarchingAntsMaskPainter internally applies BoxFit.cover math
            // so the mask region correctly overlays the displayed image area.
            if (_decodedMaskImage != null)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _marchingAntsController,
                  builder: (_, __) => CustomPaint(
                    painter: MarchingAntsMaskPainter(
                      maskImage: _decodedMaskImage!,
                      progress: _marchingAntsController.value,
                      fillPath: _maskFillPath,
                      edgePath: _maskEdgePath,
                    ),
                  ),
                ),
              ),

            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '✦  Review before applying',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ClipRect(
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 1.0,
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

                final viewSize = Size(
                  MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height * 0.40,
                );
                final localPos = event.localPosition;

                if (_selection != null &&
                    (_isPointInHorizontalOverlay(localPos) ||
                     _isPointInVerticalOverlay(localPos))) {
                  return;
                }

                SelectionMode detectedMode = SelectionMode.none;
                if (_selection != null) {
                  detectedMode = _hitTestHandles(localPos);
                }

                if (detectedMode != SelectionMode.none) {
                  setState(() {
                    _mode = detectedMode;
                  });
                } else if (_selection != null &&
                    _selection!.rect.contains(localPos)) {
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
                    _editingWidth = false;
                    _editingHeight = false;
                  });
                }
              },
              onPointerMove: (event) {
                if (_activePointers.length >= 2 || _isPanning) {
                  final Offset? oldPos = _activePointers[event.pointer];
                  _activePointers[event.pointer] = event.position;

                  if (oldPos != null && oldPos != event.position) {
                    final Matrix4 matrix = _transformationController.value
                        .clone();
                    final double oldScale = matrix.getMaxScaleOnAxis();
                    final viewSize = Size(
                      MediaQuery.of(context).size.width,
                      MediaQuery.of(context).size.height * 0.40,
                    );

                    double targetScale = oldScale;
                    double scaleRatio = 1.0;

                    if (_activePointers.length >= 2) {
                      final keys = _activePointers.keys.toList();
                      final p1 = _activePointers[keys[0]]!;
                      final p2 = _activePointers[keys[1]]!;
                      final double currentDistance = (p1 - p2).distance;

                      if (_initialPointerDistance > 1.0) {
                        final double scaleFactor =
                            currentDistance / _initialPointerDistance;
                        // Clamp at 1.0: never zoom out below the cover-fill level
                        targetScale = (_initialScale * scaleFactor).clamp(
                          1.0,
                          4.0,
                        );
                        scaleRatio = targetScale / oldScale;
                      }
                    }

                    Offset sumNew = Offset.zero;
                    for (final pos in _activePointers.values) {
                      sumNew += pos;
                    }
                    final Offset newCentroid =
                        sumNew / _activePointers.length.toDouble();

                    final Offset sumOld = sumNew - event.position + oldPos;
                    final Offset oldCentroid =
                        sumOld / _activePointers.length.toDouble();

                    final double oldTx = matrix.storage[12];
                    final double oldTy = matrix.storage[13];

                    double newTx =
                        newCentroid.dx - (oldCentroid.dx - oldTx) * scaleRatio;
                    double newTy =
                        newCentroid.dy - (oldCentroid.dy - oldTy) * scaleRatio;

                    // Pan bounds: image (rendered via OverflowBox at _minScale)
                    // must always cover the entire viewport — no blank canvas.
                    final double imgDisplayW = _originalImageWidth != null
                        ? _originalImageWidth! * _minScale
                        : viewSize.width;
                    final double imgDisplayH = _originalImageHeight != null
                        ? _originalImageHeight! * _minScale
                        : viewSize.height;
                    // OverflowBox centres image in Stack → left edge in Stack coords:
                    final double imgLeft =
                        (viewSize.width - imgDisplayW) / 2.0;
                    final double imgTop =
                        (viewSize.height - imgDisplayH) / 2.0;

                    // At TransformationController scale=targetScale:
                    //   image left viewport position = targetScale*imgLeft + newTx
                    // Constraint: left ≤ 0 and right ≥ vpW, top ≤ 0 and bottom ≥ vpH
                    final double minTx =
                        viewSize.width - targetScale * (imgLeft + imgDisplayW);
                    final double maxTx = -targetScale * imgLeft;
                    final double minTy =
                        viewSize.height - targetScale * (imgTop + imgDisplayH);
                    final double maxTy = -targetScale * imgTop;

                    newTx = newTx.clamp(minTx, maxTx);
                    newTy = newTy.clamp(minTy, maxTy);

                    _transformationController.value = Matrix4.identity()
                      ..translate(newTx, newTy)
                      ..scale(targetScale);
                  }
                  return;
                }

                final viewSize = Size(
                  MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height * 0.40,
                );
                final localPos = event.localPosition;

                if (_mode == SelectionMode.creating && _dragStart != null) {
                  final double currentX = localPos.dx.clamp(
                    0.0,
                    viewSize.width,
                  );
                  final double currentY = localPos.dy.clamp(
                    0.0,
                    viewSize.height,
                  );

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
                } else if (_mode == SelectionMode.moving &&
                    _selection != null) {
                  double newLeft = _selection!.left + event.delta.dx;
                  double newTop = _selection!.top + event.delta.dy;

                  newLeft = newLeft.clamp(
                    0.0,
                    viewSize.width - _selection!.width,
                  );
                  newTop = newTop.clamp(
                    0.0,
                    viewSize.height - _selection!.height,
                  );

                  setState(() {
                    _selection!.left = newLeft;
                    _selection!.top = newTop;
                  });
                } else if (_selection != null && _mode != SelectionMode.none) {
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

                setState(() {
                  _mode = SelectionMode.none;
                });

                if (_selection != null) {
                  final double calculatedW = (_selection!.width / 10.0).roundToDouble();
                  final double calculatedH = (_selection!.height / 10.0).roundToDouble();
                  final double calculatedArea = (calculatedW * calculatedH) / 144.0;
                  final double systemVal = double.parse(calculatedArea.toStringAsFixed(1));
                  setState(() {
                    _customWidthInches = calculatedW;
                    _customHeightInches = calculatedH;
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
                  };

                  debugPrint("Selected Area (Original Coordinates): $areaData | System Area prediction: $systemVal");
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
                              width: _originalImageWidth! * _minScale,
                              height: _originalImageHeight! * _minScale,
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                              cacheWidth: 800,
                            )
                          : Image.file(
                              File(_baseImage),
                              width: _originalImageWidth! * _minScale,
                              height: _originalImageHeight! * _minScale,
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
                                width: _originalImageWidth! * _minScale,
                                height: _originalImageHeight! * _minScale,
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
                                width: _originalImageWidth! * _minScale,
                                height: _originalImageHeight! * _minScale,
                                fit: BoxFit.fill,
                                gaplessPlayback: true,
                                cacheWidth: 800,
                              )
                            : Image.asset(
                                _currentAssetPreview!,
                                width: _originalImageWidth! * _minScale,
                                height: _originalImageHeight! * _minScale,
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
                              height:
                                  MediaQuery.of(context).size.height * 0.40,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              cacheWidth: 800,
                            )
                          : (_currentAssetPreview!.startsWith('/') ||
                                _currentAssetPreview!.contains('tryon_result'))
                          ? Image.file(
                              File(_currentAssetPreview!),
                              width: double.infinity,
                              height:
                                  MediaQuery.of(context).size.height * 0.40,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              cacheWidth: 800,
                            )
                          : Image.asset(
                              _currentAssetPreview!,
                              width: double.infinity,
                              height:
                                  MediaQuery.of(context).size.height * 0.40,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),

                  // Selected Coordinate Dot overlay removed and replaced with selection painter
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: SelectionPainter(selection: _selection?.rect),
                      ),
                    ),
                  ),
                  if (_selection != null) ...[
                    // Horizontal bottom double arrow line
                    Positioned(
                      left: _selection!.left,
                      top: _selection!.top + _selection!.height + 8,
                      width: _selection!.width,
                      height: 10,
                      child: CustomPaint(
                        painter: DashedLinePainter(axis: Axis.horizontal),
                      ),
                    ),
                    // Vertical right double arrow line
                    Positioned(
                      left: _selection!.left + _selection!.width + 8,
                      top: _selection!.top,
                      width: 10,
                      height: _selection!.height,
                      child: CustomPaint(
                        painter: DashedLinePainter(axis: Axis.vertical),
                      ),
                    ),
                    // Horizontal dimension label / inline editor
                    Positioned(
                      left: _selection!.left + (_selection!.width - 150) / 2,
                      top: _selection!.top + _selection!.height + 22,
                      width: 150,
                      child: Center(
                        child: _editingWidth
                            ? _buildInlineEditor(
                                controller: _widthEditController,
                                onSave: () {
                                  setState(() {
                                    _customWidthInches =
                                        double.tryParse(_widthEditController.text) ?? _customWidthInches;
                                    _editingWidth = false;
                                    _recalculateArea();
                                  });
                                },
                              )
                            : _buildDisplayLabel(
                                value: _customWidthInches,
                                onTap: () {
                                  setState(() {
                                    _widthEditController.text = _customWidthInches.round().toString();
                                    _editingWidth = true;
                                  });
                                },
                              ),
                      ),
                    ),
                    // Vertical dimension label / inline editor
                    Positioned(
                      left: _selection!.left + _selection!.width + 22,
                      top: _selection!.top + (_selection!.height - 40) / 2,
                      child: Center(
                        child: _editingHeight
                            ? _buildInlineEditor(
                                controller: _heightEditController,
                                onSave: () {
                                  setState(() {
                                    _customHeightInches =
                                        double.tryParse(_heightEditController.text) ?? _customHeightInches;
                                    _editingHeight = false;
                                    _recalculateArea();
                                  });
                                },
                              )
                            : _buildDisplayLabel(
                                value: _customHeightInches,
                                onTap: () {
                                  setState(() {
                                    _heightEditController.text = _customHeightInches.round().toString();
                                    _editingHeight = true;
                                  });
                                },
                              ),
                      ),
                    ),
                  ],
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

  Future<void> _handleUndo(ImageEditState state) async {
    if (state.appliedLayers.isNotEmpty) {
      await context.read<ImageEditCubit>().undoLastLayer();
      setState(() {
        _currentAssetPreview = context.read<ImageEditCubit>().state.editedImageFile;
        if (context.read<ImageEditCubit>().state.appliedLayers.isEmpty) {
          _hasNewUnappliedEdit = false;
        }
      });
    } else if (_parentEditId != null) {
      setState(() => _isLoadingEdits = true);
      try {
        final parentRecord = await EditHistoryRepository.getEditById(_parentEditId!);
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

  void _recalculateArea() {
    final double calculatedArea = (_customWidthInches * _customHeightInches) / 144.0;
    final double val = double.parse(calculatedArea.toStringAsFixed(1));
    setState(() {
      _systemArea = val;
      _areaController.text = val.toString();
    });
  }

  Widget _buildDisplayLabel({
    required double value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
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
                color: const Color(0xFFE53935), // Century Ply brand red checkmark button
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 14,
              ),
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
      final double area = latestRecord.userArea ?? latestRecord.systemArea ?? 5.0;
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
      final double currentArea = double.tryParse(_areaController.text) ?? _systemArea ?? 5.0;
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

    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
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

    // Uniform scale factor (cover = take the LARGER of the two ratios)
    final double scale =
        (size.width / imgW).clamp(0.0, double.infinity) >
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
                    context.read<ImageEditCubit>().rejectPendingDesign();
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
                    context.read<ImageEditCubit>().acceptPendingDesign(
                      parentEditId: _parentEditId,
                    );
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
        path.lineTo(i + dashWidth > size.width - 6 ? size.width - 6 : i + dashWidth, size.height / 2);
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
        path.lineTo(size.width / 2, i + dashWidth > size.height - 6 ? size.height - 6 : i + dashWidth);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DashedLinePainter oldDelegate) => false;
}
