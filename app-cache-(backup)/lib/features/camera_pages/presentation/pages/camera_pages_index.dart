import 'dart:io';
import 'package:camera/camera.dart';
import 'package:century_ai/features/home/presentation/widgets/home_drawer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:century_ai/router/app_routes.dart';
import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/cubit/products/products_cubit.dart';
import 'package:century_ai/db/models/selected_image_data.dart';
import 'package:century_ai/db/repositories/selected_images_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CameraPagesIndex extends StatefulWidget {
  final bool fromColorPicker;
  final File? originalImage;
  const CameraPagesIndex({super.key, this.fromColorPicker = false, this.originalImage});

  @override
  State<CameraPagesIndex> createState() => _CameraPagesIndexState();
}

class _CameraPagesIndexState extends State<CameraPagesIndex> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  CameraController? _controller;
  bool _isReady = false;
  final double _bottomBarHeight = 140;

  bool _isImageTaken = false;
  File? _capturedFile;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (!mounted) return;

    setState(() => _isReady = true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (!_controller!.value.isInitialized) return;

    final XFile file = await _controller!.takePicture();
    final File imageFile = File(file.path);

    setState(() {
      _isImageTaken = true;
      _capturedFile = imageFile;
    });

    if (!mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: TColors.primary),
      ),
    );

    try {
      final productsCubit = context.read<ProductsCubit>();
      final newProduct = await productsCubit.uploadProductImageNew(imageFile);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss loader

      if (newProduct == null) {
        setState(() {
          _isImageTaken = false;
          _capturedFile = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to upload image to server.")),
        );
        return;
      }

      final imageBytes = await compute((File f) => f.readAsBytesSync(), imageFile);
      final imageId = newProduct.id;

      await SelectedImagesRepository.saveImage(
        SelectedImageData(
          id: imageId,
          imageData: imageBytes,
          imagePath: imageFile.path,
          category: 'Uploaded Image',
          subcategory: 'User Upload',
          selectedAt: DateTime.now(),
        ),
      );

      if (!mounted) return;
      if (widget.fromColorPicker) {
        context.pushReplacement(AppRoutes.imageColorPicker, extra: {
          'imageFile': imageFile,
          'image_id': imageId,
          'originalImage': widget.originalImage,
        });
      } else {
        context.pushReplacement(AppRoutes.imagePreview, extra: {
          'imageFile': imageFile,
          'image_id': imageId,
          'image_category': "Uploaded Image",
          'sub_category': "User Upload",
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImageTaken = false;
          _capturedFile = null;
        });
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error processing image: $e")),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null || !mounted) return;

    final File imageFile = File(image.path);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: TColors.primary),
      ),
    );

    try {
      final productsCubit = context.read<ProductsCubit>();
      final newProduct = await productsCubit.uploadProductImageNew(imageFile);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss loader

      if (newProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to upload image to server.")),
        );
        return;
      }

      final imageBytes = await compute((File f) => f.readAsBytesSync(), imageFile);
      final imageId = newProduct.id;

      await SelectedImagesRepository.saveImage(
        SelectedImageData(
          id: imageId,
          imageData: imageBytes,
          imagePath: imageFile.path,
          category: 'Uploaded Image',
          subcategory: 'User Upload',
          selectedAt: DateTime.now(),
        ),
      );

      if (!mounted) return;
      if (widget.fromColorPicker) {
        context.pushReplacement(AppRoutes.imageColorPicker, extra: {
          'imageFile': imageFile,
          'image_id': imageId,
          'originalImage': widget.originalImage,
        });
      } else {
        context.pushReplacement(AppRoutes.imagePreview, extra: {
          'imageFile': imageFile,
          'image_id': imageId,
          'image_category': "Uploaded Image",
          'sub_category': "User Upload",
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error processing image: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: const HomeDrawer(),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 📷 Camera Preview or Static Captured Image (full screen)
          Positioned.fill(
            child: RepaintBoundary(
              child: _isImageTaken && _capturedFile != null
                  ? Image.file(_capturedFile!, fit: BoxFit.cover)
                  : CameraPreview(_controller!),
            ),
          ),

          // 🟦 Capture Area Overlay (stays above camera)
          const _CaptureOverlay(),

          // ⬜ WHITE BOTTOM PANEL
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: _bottomBarHeight,
            child: Container(color: Colors.white),
          ),

          // 🔘 Capture Button (inside white area)
          Positioned(
            bottom: (_bottomBarHeight / 2) - 36,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  SizedBox(width: 5),
                  GestureDetector(
                    onTap: () {
                      Scaffold.of(context).openDrawer();
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE5E5E5),
                          width: 0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 3,
                            color: Color(0xFF646464),
                            offset: const Offset(0, 2),
                          ),
                        ],
                        color: Colors.white,
                      ),
                      child: const Center(child: Icon(Icons.menu, size: 24)),
                    ),
                  ),
                  GestureDetector(
                    onTap: _capture,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE5E5E5),
                          width: 0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 3,
                            color: Color(0xFF646464),
                            offset: const Offset(0, 4),
                          ),
                        ],
                        color: Colors.white,
                      ),
                      child: Center(
                        child: Icon(Icons.camera_alt, size: 36),
                        // child: SvgPicture.asset("assets/icons/app_icons/image_flash.svg"),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _pickFromGallery,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE5E5E5),
                          width: 0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 3,
                            color: Color(0xFF646464),
                            offset: const Offset(0, 2),
                          ),
                        ],
                        color: Colors.white,
                      ),
                      child: Center(
                        // child: SvgPicture.asset(
                        //   "assets/icons/app_icons/images.svg",
                        // ),
                        child: Icon(Icons.file_upload_outlined),
                      ),
                    ),
                  ),
                  SizedBox(width: 5),
                ],
              ),
            ),
          ),

          // Custom App Button
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.clear, color: Colors.white),
                  onPressed: () => {context.pop()},
                ),
                IconButton(
                  icon: Icon(Icons.flash_off_rounded, color: Colors.white),
                  onPressed: () => {},
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 45,
            left: 7,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios, color: Colors.black),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureOverlay extends StatelessWidget {
  const _CaptureOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _OverlayPainter(),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withOpacity(0.6);

    final captureRect = Rect.fromLTWH(
      20,
      size.height * 0.22,
      size.width - 40,
      size.height * 0.45,
    );

    // Draw 4 rectangles around the capture area instead of using saveLayer + clear
    // Top
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, captureRect.top), dimPaint);
    // Bottom
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        captureRect.bottom,
        size.width,
        size.height - captureRect.bottom,
      ),
      dimPaint,
    );
    // Left
    canvas.drawRect(
      Rect.fromLTWH(0, captureRect.top, captureRect.left, captureRect.height),
      dimPaint,
    );
    // Right
    canvas.drawRect(
      Rect.fromLTWH(
        captureRect.right,
        captureRect.top,
        size.width - captureRect.right,
        captureRect.height,
      ),
      dimPaint,
    );

    // White border
    canvas.drawRRect(
      RRect.fromRectAndRadius(captureRect, const Radius.circular(16)),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
