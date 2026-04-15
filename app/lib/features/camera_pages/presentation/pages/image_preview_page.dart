import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:century_ai/router/app_routes.dart';
import 'package:century_ai/features/camera_pages/data/services/preview_service.dart';
import 'package:century_ai/db/repositories/selected_images_repository.dart';

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
  bool _isLoading = false;
  final PreviewService _previewService = PreviewService();

  final List<String> exploreImages = [
    'assets/images/furniture/page_13_r.jpg',
    'assets/images/furniture/page_23_r.jpg',
    'assets/images/furniture/page_24_l.jpg',
    'assets/images/furniture/page_43_r.jpg',
    'assets/images/furniture/page_51_r.jpg',
    'assets/images/furniture/page_76_l.jpg',
    'assets/images/furniture/page_88_l.jpg',
    'assets/images/furniture/page_90_l.jpg',
    'assets/images/furniture/page_125_r.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _loadImage();
    print("==============");
    print("image_id: ${widget.image_id}");
    print("image_category: ${widget.image_category}");
    print("sub_category: ${widget.sub_category}");
    print("==============");
  }

  Future<void> _loadImage() async {
    // Try to load from SQLite if image_id is provided
    if (widget.image_id != null) {
      try {
        final selectedImage = await SelectedImagesRepository.getImage(
          widget.image_id!,
        );
        if (selectedImage != null) {
          print("✅ Loaded image from SQLite with ID: ${widget.image_id}");
          // Write the image data to a temporary file
          final tempDir = await getTemporaryDirectory();
          final fileName =
              'sqlite_${widget.image_id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(selectedImage.imageData);

          if (mounted) {
            setState(() {
              _currentFile = file;
            });
          }
          return;
        }
      } catch (e) {
        print("❌ Error loading image from SQLite: $e");
      }
    }

    // Fallback to the passed imageFile
    if (mounted) {
      setState(() {
        _currentFile = widget.imageFile;
      });
    }
  }

  Future<void> _simulateApiCall(String assetPath) async {
    setState(() {
      _isLoading = true;
    });

    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 1500));

    // Log details as requested
    await _previewService.logPreviewDetails(
      imageCategory: widget.image_category,
      subCategory: widget.sub_category ?? "N/A",
      interiorFurniture:
          "Generic Furniture", // Placeholder as per user's sample
      isTrending: true,
      isLiked: false,
    );

    if (mounted) {
      setState(() {
        _currentAsset = assetPath;
        _currentFile = null;
        _isLoading = false;
      });
    }
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
        final fileName = _currentAsset!.replaceAll("/", "_");
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
        );
        fileToEdit = file;
      } catch (e) {
        debugPrint("Error saving asset for editing: $e");
        return;
      }
    }

    if (fileToEdit != null && mounted) {
      context.push(
        route,
        extra: {
          'imageFile': fileToEdit,
          'image_id': widget.image_id,
        },
      );
    }
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
                  // Top Image Section with Overlays
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: _currentFile != null
                            ? Image.file(
                                _currentFile!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Image.asset(
                                _currentAsset!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                      ),
                      // -- Overlays --
                      if (!_isLoading) ...[
                        _buildBoundingBox(
                          top: 50,
                          left: 30,
                          width: 120,
                          height: 120,
                        ),
                        _buildBoundingBox(
                          top: 140,
                          left: 210,
                          width: 120,
                          height: 80,
                        ),
                        _buildBoundingBox(
                          top: 250,
                          left: 10,
                          width: 100,
                          height: 100,
                        ),

                        // Center Instruction
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
                                  "Tap on the object to apply laminates",
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
                      "More Products to Explore",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  // Product Grid
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
                    itemCount: exploreImages.length,
                    itemBuilder: (context, index) {
                      if (_isLoading) {
                        return Shimmer.fromColors(
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
                        );
                      }
                      return GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () => _simulateApiCall(exploreImages[index]),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.asset(
                                exploreImages[index],
                                fit: BoxFit.cover,
                                height: double.infinity,
                                width: double.infinity,
                              ),
                            ),
                            // Corner Icons
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
                  ),
                  const SizedBox(height: 100), // Space for bottom button
                ],
              ),
            ),

            // Floating Edit Button
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

                  // child: Row(
                  //   mainAxisSize: MainAxisSize.min,
                  //   children: [
                  //     SizedBox(
                  //       width: 130,
                  //       height: 44,
                  //       child: ElevatedButton(
                  //         style: ElevatedButton.styleFrom(
                  //           backgroundColor: Colors.white,
                  //           foregroundColor: Colors.black,
                  //           padding: EdgeInsets.zero,
                  //           elevation: 0,
                  //           side: BorderSide.none,
                  //           shape: RoundedRectangleBorder(
                  //             borderRadius: BorderRadius.circular(30),
                  //           ),
                  //         ),
                  //         onPressed: _handleEdit,
                  //         child: Row(
                  //           mainAxisAlignment: MainAxisAlignment.center,
                  //           spacing: 8,
                  //           children: [
                  //             Image.asset(
                  //               "assets/icons/app_icons/edit.png",
                  //               height: 14,
                  //             ),
                  //             const Text(
                  //               "Edit",
                  //               style: TextStyle(
                  //                 color: Colors.black,
                  //                 fontWeight: FontWeight.w600,
                  //                 fontSize: 14,
                  //               ),
                  //             ),
                  //           ],
                  //         ),
                  //       ),
                  //     ),
                  //     const SizedBox(width: 12),
                  //     SizedBox(
                  //       width: 160,
                  //       height: 44,
                  //       child: ElevatedButton(
                  //         style: ElevatedButton.styleFrom(
                  //           backgroundColor: Colors.white,
                  //           foregroundColor: Colors.black,
                  //           padding: EdgeInsets.zero,
                  //           elevation: 0,
                  //           side: BorderSide.none,
                  //           shape: RoundedRectangleBorder(
                  //             borderRadius: BorderRadius.circular(30),
                  //           ),
                  //         ),
                  //         onPressed: _handleScrollEdit,
                  //         child: const Row(
                  //           mainAxisAlignment: MainAxisAlignment.center,
                  //           spacing: 8,
                  //           children: [
                  //             Icon(Icons.unfold_more, size: 18),
                  //             Text(
                  //               "Edit Scroll",
                  //               style: TextStyle(
                  //                 color: Colors.black,
                  //                 fontWeight: FontWeight.w600,
                  //                 fontSize: 14,
                  //               ),
                  //             ),
                  //           ],
                  //         ),
                  //       ),
                  //     ),
                  //   ],
                  // ),
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
                                "assets/icons/app_icons/edit.png",
                                height: 14,
                              ),
                              const Text(
                                "Edit",
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
