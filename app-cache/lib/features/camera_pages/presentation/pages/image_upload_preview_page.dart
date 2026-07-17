import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/cubit/products/products_cubit.dart';
import 'package:century_ai/cubit/products/products_state.dart';
import 'package:century_ai/cubit/upload/upload_cubit.dart';
import 'package:century_ai/cubit/upload/upload_state.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:century_ai/db/models/selected_image_data.dart';
import 'package:century_ai/db/repositories/selected_images_repository.dart';
import 'package:century_ai/features/camera_pages/data/services/preview_service.dart';
import 'package:century_ai/router/app_routes.dart';

class ImageUploadPreviewPage extends StatefulWidget {
  final File imageFile;
  final String image_category;
  final String? sub_category;

  const ImageUploadPreviewPage({
    super.key,
    required this.imageFile,
    required this.image_category,
    this.sub_category,
  });

  @override
  State<ImageUploadPreviewPage> createState() => _ImageUploadPreviewPageState();
}

class _ImageUploadPreviewPageState extends State<ImageUploadPreviewPage> {
  File? _currentFile;
  String? _currentAsset;
  SelectedImageData? _currentSelection;
  List<SelectedImageData> _exploreImages = [];
  final List<SelectedImageData> _history = [];
  bool _isImageLoading = false;
  bool _isLoading = false;

  String? _currentApplicationType;
  final PreviewService _previewService = PreviewService();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _currentFile = widget.imageFile;

    // Check if the global UploadCubit is already complete for this file
    final uploadState = context.read<UploadCubit>().state;
    final bool isThisFile = uploadState.croppedFile?.path == widget.imageFile.path;
    if (isThisFile && uploadState.uploadCompleted) {
      _currentApplicationType = uploadState.applicationType;
      _currentSelection = SelectedImageData(
        id: uploadState.imageId ?? _buildImageIdFromPath(widget.imageFile.path),
        imageData: const <int>[],
        imagePath: widget.imageFile.path,
        category: widget.image_category,
        subcategory: widget.sub_category,
        selectedAt: DateTime.now(),
        applicationType: uploadState.applicationType,
      );
    } else {
      _currentSelection = SelectedImageData(
        id: _buildImageIdFromPath(widget.imageFile.path),
        imageData: const <int>[],
        imagePath: widget.imageFile.path,
        category: widget.image_category,
        subcategory: widget.sub_category,
        selectedAt: DateTime.now(),
      );
    }

    _initializePreview();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializePreview() async {
    try {
      await FileImage(widget.imageFile).evict();
    } catch (_) {}
    await _hydrateCurrentSelectionFromDb();
    await _loadExploreImages();
    _refreshSimilarProducts();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      context.read<ProductsCubit>().loadMoreProducts();
    }
  }

  void _pushToHistory() {
    if (_currentSelection != null) {
      _history.add(_currentSelection!);
    }
  }

  Future<void> _popHistory() async {
    if (_history.isEmpty) return;
    final previous = _history.removeLast();

    setState(() {
      _isLoading = true;
    });

    try {
      final resolved = await _resolvePreviewImage(previous);
      if (mounted) {
        setState(() {
          _currentSelection = previous;
          _currentApplicationType = previous.applicationType;
          _currentFile = resolved.file;
          _currentAsset = resolved.assetPath;
          _isImageLoading = false;
          _isLoading = false;
        });
        _refreshSimilarProducts();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load previous image: $e')));
      }
    }
  }

  void _refreshSimilarProducts() {
    if (!mounted) return;
    final id = _currentSelection?.id;
    if (id == null || id.trim().isEmpty || id.startsWith('image_')) return; // Skip if it's the temporary path ID
    context.read<ProductsCubit>().fetchSimilarProducts(
      id,
      ownerId: "user13@gmail.com",
      limit: 12,
    );
  }

  Future<void> _hydrateCurrentSelectionFromDb() async {
    final imageId = _currentSelection?.id;
    if (imageId == null || imageId.startsWith('image_')) return;

    try {
      final selectedImage = await SelectedImagesRepository.getImage(imageId);
      if (selectedImage == null || !mounted) return;

      setState(() {
        _currentSelection = selectedImage;
        _currentApplicationType = selectedImage.applicationType;
      });
    } catch (e) {
      debugPrint('Error hydrating current image from SQLite: $e');
    }
  }

  Future<void> _loadExploreImages() async {
    final allImages = await SelectedImagesRepository.getAllImages();

    if (mounted) {
      setState(() {
        _exploreImages = allImages;
      });
    }
  }

  Future<void> _selectExploreImage(SelectedImageData image) async {
    if (_currentSelection != null && _currentSelection!.id != image.id) {
      _pushToHistory();
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final resolved = await _resolvePreviewImage(image);
      await _previewService.logPreviewDetails(
        imageCategory: image.category ?? widget.image_category,
        subCategory: image.subcategory ?? widget.sub_category ?? 'N/A',
        interiorFurniture: image.category ?? widget.image_category,
        isTrending: false,
        isLiked: false,
      );

      if (mounted) {
        setState(() {
          _currentSelection = image;
          _currentApplicationType = image.applicationType;
          _currentFile = resolved.file;
          _currentAsset = resolved.assetPath;
          _isImageLoading = false;
          _isLoading = false;
        });
        _refreshSimilarProducts();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load image: $e')));
      }
    }
  }

  Future<void> _selectNetworkProduct(ProductImageModel product) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final imageId = product.itemId ?? product.furnitureId ?? product.id;
      final existing = await SelectedImagesRepository.getImage(imageId);
      if (existing != null) {
        if (mounted) {
          setState(() {
            _currentApplicationType =
                product.applicationType ?? existing.applicationType;
          });
        }
        await _selectExploreImage(existing);
        return;
      }

      final file = await DefaultCacheManager().getSingleFile(product.image);
      final Uint8List imageBytes = await compute(
        (File f) => f.readAsBytesSync(),
        file,
      );

      final imageData = SelectedImageData(
        id: imageId,
        imageData: imageBytes,
        imagePath: product.image.startsWith('http') ? product.image : file.path,
        category: product.category ?? widget.image_category,
        subcategory: product.subcategory ?? widget.sub_category,
        selectedAt: DateTime.now(),
        applicationType: product.applicationType,
      );

      await SelectedImagesRepository.saveImage(imageData);

      if (mounted) {
        if (_currentSelection != null) {
          _pushToHistory();
        }
        setState(() {
          _currentApplicationType = product.applicationType;
          _currentSelection = imageData;
          _currentFile = file;
          _currentAsset = null;
          _isImageLoading = false;
          _isLoading = false;
        });
        _refreshSimilarProducts();

        await _previewService.logPreviewDetails(
          imageCategory: imageData.category ?? widget.image_category,
          subCategory: imageData.subcategory ?? widget.sub_category ?? 'N/A',
          interiorFurniture: imageData.category ?? widget.image_category,
          isTrending: product.isTrending,
          isLiked: false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error downloading image: $e')));
      }
    }
  }

  Future<_ResolvedPreviewImage> _resolvePreviewImage(
    SelectedImageData selectedImage,
  ) async {
    final savedPath = selectedImage.imagePath.trim();

    if (savedPath.isNotEmpty) {
      final savedFile = File(savedPath);
      if (await savedFile.exists()) {
        return _ResolvedPreviewImage(file: savedFile);
      }

      if (savedPath.startsWith('assets/')) {
        return _ResolvedPreviewImage(assetPath: savedPath);
      }
    }

    final tempDir = await getTemporaryDirectory();
    final fileName =
        'sqlite_${selectedImage.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(selectedImage.imageData);
    return _ResolvedPreviewImage(file: file);
  }

  Future<void> _handleEdit() async {
    await _handleEditRoute(AppRoutes.imageEdit);
  }

  Future<void> _handleScrollEdit() async {
    await _handleEditRoute(AppRoutes.imageEditScroll);
  }

  Future<void> _handleEditRoute(String route) async {
    File? fileToEdit = _currentFile;

    if (_currentAsset != null) {
      try {
        final byteData = await DefaultAssetBundle.of(
          context,
        ).load(_currentAsset!);
        final tempDir = await getTemporaryDirectory();
        final fileName = _currentAsset!.replaceAll('/', '_');
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
        );
        fileToEdit = file;
      } catch (e) {
        debugPrint('Error saving asset for editing: $e');
        return;
      }
    }

    if (fileToEdit != null && mounted) {
      context.push(
        route,
        extra: {
          'imageFile': fileToEdit,
          'image_id': _currentSelection?.id,
          'imageUrl': _currentSelection?.imagePath,
          'originalImageUrl': _currentSelection?.originalImageUrl,
          'applicationType':
              _currentApplicationType ??
              _currentSelection?.applicationType,
        },
      );
    }
  }

  String _buildImageIdFromPath(String path) {
    return 'image_${Uri.encodeComponent(path.replaceAll('\\', '/'))}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UploadCubit, UploadState>(
      listener: (context, state) {
        final bool isThisFile = state.croppedFile?.path == widget.imageFile.path;
        if (isThisFile && state.uploadCompleted && state.imageId != null) {
          if (_currentSelection?.id != state.imageId) {
            setState(() {
              _currentApplicationType = state.applicationType;
              _currentSelection = SelectedImageData(
                id: state.imageId!,
                imageData: const <int>[],
                imagePath: widget.imageFile.path,
                category: widget.image_category,
                subcategory: widget.sub_category,
                selectedAt: DateTime.now(),
                applicationType: state.applicationType,
              );
            });
            _refreshSimilarProducts();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8F8),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      AspectRatio(aspectRatio: 1, child: _buildPreviewImage()),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'More Products to Explore',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        GestureDetector(
                          onTap: _history.isNotEmpty ? _popHistory : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _history.isNotEmpty
                                    ? const Color(0xFFE2E8F0)
                                    : const Color(0xFFE2E8F0).withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_back_rounded,
                                  size: 14,
                                  color: _history.isNotEmpty
                                      ? const Color(0xFF475569)
                                      : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Back',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _history.isNotEmpty
                                        ? const Color(0xFF475569)
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BlocBuilder<ProductsCubit, ProductsState>(
                            builder: (context, state) {
                              return BlocBuilder<UploadCubit, UploadState>(
                                builder: (context, uploadState) {
                                  final bool isThisFile = uploadState.croppedFile?.path == widget.imageFile.path;
                                  final bool isUploading = isThisFile && uploadState.uploadInProgress;

                                  if (isUploading) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 40),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.0,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Preparing image...',
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  if (state.isLoading && state.products.isEmpty) {
                                    return GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3,
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 12,
                                            childAspectRatio: 1.0,
                                          ),
                                      itemCount: 6,
                                      itemBuilder: (context, index) => Shimmer.fromColors(
                                        baseColor: Colors.grey[300]!,
                                        highlightColor: Colors.grey[100]!,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final products = state.products;

                                  if (products.isEmpty && !state.isLoading) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        'No related images to explore.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    );
                                  }

                                  return Column(
                                    children: [
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 3,
                                              crossAxisSpacing: 12,
                                              mainAxisSpacing: 12,
                                              childAspectRatio: 1.0,
                                            ),
                                        itemCount: products.length,
                                        itemBuilder: (context, index) {
                                          final product = products[index];
                                          return GestureDetector(
                                            onTap: () => _selectNetworkProduct(product),
                                            child: Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: CachedNetworkImage(
                                                    imageUrl: product.image,
                                                    fit: BoxFit.cover,
                                                    height: double.infinity,
                                                    width: double.infinity,
                                                    memCacheWidth: 300,
                                                    placeholder: (context, url) =>
                                                        Shimmer.fromColors(
                                                          baseColor: Colors.grey[300]!,
                                                          highlightColor: Colors.grey[100]!,
                                                          child: Container(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                    errorWidget: (context, url, error) =>
                                                        Container(
                                                          color: Colors.grey[300],
                                                          child: const Icon(
                                                            Icons.error_outline,
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                                if (product.isTrending)
                                                  const Positioned(
                                                    top: 8,
                                                    left: 8,
                                                    child: Icon(
                                                      Icons.local_fire_department,
                                                      color: Colors.red,
                                                      size: 16,
                                                    ),
                                                  ),
                                                if (product.isFavorite)
                                                  const Positioned(
                                                    top: 8,
                                                    right: 8,
                                                    child: Icon(
                                                      Icons.favorite,
                                                      color: Colors.red,
                                                      size: 16,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                      if (state.isLoadingMore)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 16),
                                          child: Center(child: CircularProgressIndicator()),
                                        ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              BlocBuilder<UploadCubit, UploadState>(
                builder: (context, uploadState) {
                  final bool isThisFile = uploadState.croppedFile?.path == widget.imageFile.path;
                  final bool isUploading = isThisFile && uploadState.uploadInProgress;
                  final bool isEditDisabled = isUploading || (_currentApplicationType == null || _currentApplicationType!.isEmpty);

                  return Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isEditDisabled ? 0.02 : 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: 120,
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEditDisabled ? Colors.grey.shade200 : Colors.white,
                              foregroundColor: isEditDisabled ? Colors.black38 : Colors.black,
                              padding: EdgeInsets.zero,
                              elevation: 0,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: isEditDisabled ? null : _handleScrollEdit,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              spacing: 8,
                              children: [
                                Opacity(
                                  opacity: isEditDisabled ? 0.4 : 1.0,
                                  child: Image.asset(
                                    'assets/icons/app_icons/edit.png',
                                    height: 14,
                                  ),
                                ),
                                const Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
    );
  }

  Widget _buildPreviewImage() {
    if (_isImageLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    Widget imageWidget = const SizedBox.shrink();
    if (_currentFile != null) {
      imageWidget = Image.file(
        _currentFile!,
        width: double.infinity,
        fit: BoxFit.cover,
        cacheWidth: 800,
      );
    } else if (_currentAsset != null && _currentAsset!.isNotEmpty) {
      imageWidget = Image.asset(
        _currentAsset!,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } else {
      imageWidget = Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Text(
          'Image not available',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return imageWidget;
  }
}

class _ResolvedPreviewImage {
  final File? file;
  final String? assetPath;

  const _ResolvedPreviewImage({this.file, this.assetPath});
}
