import 'dart:io';
import 'package:camera/camera.dart';
import 'package:century_ai/features/home/presentation/widgets/home_drawer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
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

  Future<File> _cropToOverlay(File imageFile, Size screenSize) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final filePath = imageFile.path;

      final croppedBytes = await compute((Map<String, dynamic> params) {
        final Uint8List imgBytes = params['bytes'];
        final double screenW = params['screenW'];
        final double screenH = params['screenH'];
        final String path = params['path'];

        final image = img.decodeImage(imgBytes);
        if (image == null) return imgBytes;

        final orientedImage = img.bakeOrientation(image);

        final double imgW = orientedImage.width.toDouble();
        final double imgH = orientedImage.height.toDouble();

        // Calculate the BoxFit.cover scaling factor
        final double scale = (imgW / screenW) > (imgH / screenH)
            ? imgH / screenH
            : imgW / screenW;

        final double displayedW = imgW / scale;
        final double displayedH = imgH / scale;

        final double offsetX = (screenW - displayedW) / 2;
        final double offsetY = (screenH - displayedH) / 2;

        // Rectangle bounds from _OverlayPainter
        final double rectLeft = 20.0;
        final double rectTop = screenH * 0.22;
        final double rectWidth = screenW - 40.0;
        final double rectHeight = screenH * 0.45;

        // Map screen rectangle coordinates to image pixel space
        final int cropX = (((rectLeft - offsetX) * scale)).round().clamp(0, orientedImage.width - 1);
        final int cropY = (((rectTop - offsetY) * scale)).round().clamp(0, orientedImage.height - 1);
        final int cropW = ((rectWidth * scale)).round().clamp(1, orientedImage.width - cropX);
        final int cropH = ((rectHeight * scale)).round().clamp(1, orientedImage.height - cropY);

        final cropped = img.copyCrop(
          orientedImage,
          x: cropX,
          y: cropY,
          width: cropW,
          height: cropH,
        );

        return Uint8List.fromList(
          img.encodeNamedImage(path, cropped) ?? img.encodeJpg(cropped),
        );
      }, {
        'bytes': bytes,
        'screenW': screenSize.width,
        'screenH': screenSize.height,
        'path': filePath,
      });

      final croppedFile = File(filePath);
      await croppedFile.writeAsBytes(croppedBytes);
      return croppedFile;
    } catch (e) {
      debugPrint('Error cropping image to overlay: $e');
      return imageFile; // Fallback to original image on error
    }
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
      final screenSize = MediaQuery.of(context).size;
      final croppedFile = await _cropToOverlay(imageFile, screenSize);

      if (!mounted) return;
      setState(() {
        _capturedFile = croppedFile;
      });
      final productsCubit = context.read<ProductsCubit>();
      final newProduct = await productsCubit.uploadProductImageNew(croppedFile);

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

      final imageBytes = await compute((File f) => f.readAsBytesSync(), croppedFile);
      final imageId = newProduct.id;

      await SelectedImagesRepository.saveImage(
        SelectedImageData(
          id: imageId,
          imageData: imageBytes,
          imagePath: croppedFile.path,
          category: 'Uploaded Image',
          subcategory: 'User Upload',
          selectedAt: DateTime.now(),
        ),
      );

      if (!mounted) return;
      if (widget.fromColorPicker) {
        context.pushReplacement(AppRoutes.imageColorPicker, extra: {
          'imageFile': croppedFile,
          'image_id': imageId,
          'originalImage': widget.originalImage,
        });
      } else {
        context.pushReplacement(AppRoutes.imagePreview, extra: {
          'imageFile': croppedFile,
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
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.biggest;
                        double scale = size.aspectRatio * _controller!.value.aspectRatio;
                        if (scale < 1.0) {
                          scale = 1.0 / scale;
                        }
                        return ClipRect(
                          child: Transform.scale(
                            scale: scale,
                            child: Center(
                              child: CameraPreview(_controller!),
                            ),
                          ),
                        );
                      },
                    ),
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
