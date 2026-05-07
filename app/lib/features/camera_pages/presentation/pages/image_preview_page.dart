import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/cubit/products/products_cubit.dart';
import 'package:century_ai/cubit/products/products_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:century_ai/db/models/selected_image_data.dart';
import 'package:century_ai/db/repositories/selected_images_repository.dart';
import 'package:century_ai/features/camera_pages/data/services/preview_service.dart';
import 'package:century_ai/router/app_routes.dart';

class ImagePreviewPage extends StatefulWidget {
  final File imageFile;
  final String image_category;
  final String? sub_category;
  final String? image_id;

  const ImagePreviewPage({
    super.key,
    required this.imageFile,
    required this.image_category,
    this.sub_category,
    this.image_id,
  });

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  File? _currentFile;
  String? _currentAsset;
  SelectedImageData? _currentSelection;
  List<SelectedImageData> _exploreImages = [];
  bool _isImageLoading = false;
  bool _isLoading = false;
  final PreviewService _previewService = PreviewService();

  @override
  void initState() {
    super.initState();
    _currentFile = widget.imageFile;
    _currentSelection = SelectedImageData(
      id: widget.image_id ?? _buildImageIdFromPath(widget.imageFile.path),
      imageData: const <int>[],
      imagePath: widget.imageFile.path,
      category: widget.image_category,
      subcategory: widget.sub_category,
      selectedAt: DateTime.now(),
    );
    _initializePreview();
  }

  Future<void> _initializePreview() async {
    await _hydrateCurrentSelectionFromDb();
    await _loadExploreImages();
  }

  Future<void> _hydrateCurrentSelectionFromDb() async {
    final imageId = widget.image_id;
    if (imageId == null) return;

    try {
      final selectedImage = await SelectedImagesRepository.getImage(imageId);
      if (selectedImage == null || !mounted) return;

      setState(() {
        _currentSelection = selectedImage;
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
          _currentFile = resolved.file;
          _currentAsset = resolved.assetPath;
          _isImageLoading = false;
          _isLoading = false;
        });
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
      // 1. Check if it already exists in SQLite
      final existing = await SelectedImagesRepository.getImage(product.id);
      if (existing != null) {
        await _selectExploreImage(existing);
        return;
      }

      // 2. Download the image bytes
      final dio = Dio();
      final response = await dio.get(
        product.image,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download image: ${response.statusCode}');
      }

      final Uint8List imageBytes = Uint8List.fromList(response.data);

      // 3. Save to a temporary file for the current session representation
      final tempDir = await getTemporaryDirectory();
      final fileName = 'downloaded_${product.id}.jpg';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      // 4. Save to SQLite
      final imageData = SelectedImageData(
        id: product.id,
        imageData: imageBytes,
        imagePath: file.path,
        category: product.category ?? widget.image_category,
        subcategory: product.subcategory ?? widget.sub_category,
        selectedAt: DateTime.now(),
      );

      await SelectedImagesRepository.saveImage(imageData);

      // 5. Update UI
      if (mounted) {
        setState(() {
          _currentSelection = imageData;
          _currentFile = file;
          _currentAsset = null;
          _isImageLoading = false;
          _isLoading = false;
        });

        // Trigger logging
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
          'image_id': _currentSelection?.id ?? widget.image_id,
        },
      );
    }
  }

  String _buildImageIdFromPath(String path) {
    return 'image_${Uri.encodeComponent(path.replaceAll('\\', '/'))}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      AspectRatio(aspectRatio: 1, child: _buildPreviewImage()),
                      if (!_isLoading && !_isImageLoading) ...[
                        Positioned(
                          bottom: 40,
                          left: 0,
                          right: 0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.touch_app_outlined,
                                color: Colors.white,
                                size: 40,
                              ),
                              const SizedBox(height: 8),
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
                                  'Tap on the object to apply laminates',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Text(
                      'More Products to Explore',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  BlocBuilder<ProductsCubit, ProductsState>(
                    builder: (context, state) {
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
                            child: AspectRatio(
                              aspectRatio: 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      final products = state.products;

                      if (products.isEmpty) {
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
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return GestureDetector(
                            onTap: () => _selectNetworkProduct(product),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    product.image,
                                    fit: BoxFit.cover,
                                    height: double.infinity,
                                    width: double.infinity,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Shimmer.fromColors(
                                            baseColor: Colors.grey[300]!,
                                            highlightColor: Colors.grey[100]!,
                                            child: Container(
                                              color: Colors.white,
                                            ),
                                          );
                                        },
                                    errorBuilder:
                                        (context, error, stackTrace) =>
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
                                const Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Icon(
                                    Icons.favorite_border,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 130,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.zero,
                            elevation: 0,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: _handleScrollEdit,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            spacing: 8,
                            children: [
                              Image.asset(
                                'assets/icons/app_icons/edit.png',
                                height: 14,
                              ),
                              const Text(
                                'Edit',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewImage() {
    if (_isImageLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentFile != null) {
      return Image.file(
        _currentFile!,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    if (_currentAsset != null && _currentAsset!.isNotEmpty) {
      return Image.asset(
        _currentAsset!,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return Container(
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

  Widget _buildExploreThumbnail(SelectedImageData image) {
    final savedPath = image.imagePath.trim();

    if (savedPath.startsWith('assets/')) {
      return Image.asset(
        savedPath,
        fit: BoxFit.cover,
        height: double.infinity,
        width: double.infinity,
      );
    }

    if (savedPath.isNotEmpty) {
      final file = File(savedPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          height: double.infinity,
          width: double.infinity,
        );
      }
    }

    if (image.imageData.isNotEmpty) {
      return Image.memory(
        Uint8List.fromList(image.imageData),
        fit: BoxFit.cover,
        height: double.infinity,
        width: double.infinity,
      );
    }

    return Container(
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined),
    );
  }

  Widget _buildBoundingBox({
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
}

class _ResolvedPreviewImage {
  final File? file;
  final String? assetPath;

  const _ResolvedPreviewImage({this.file, this.assetPath});
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

    for (double i = 0; i < size.width; i += dashWidth + dashSpace) {
      path.moveTo(i, 0);
      path.lineTo(i + dashWidth > size.width ? size.width : i + dashWidth, 0);
    }

    for (double i = 0; i < size.width; i += dashWidth + dashSpace) {
      path.moveTo(i, size.height);
      path.lineTo(
        i + dashWidth > size.width ? size.width : i + dashWidth,
        size.height,
      );
    }

    for (double i = 0; i < size.height; i += dashWidth + dashSpace) {
      path.moveTo(0, i);
      path.lineTo(0, i + dashWidth > size.height ? size.height : i + dashWidth);
    }

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
