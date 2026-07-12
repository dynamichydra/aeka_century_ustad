import 'dart:io';
import 'dart:async';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:century_ai/features/camera_pages/presentation/widgets/upload_loader_dialog.dart';
import 'package:century_ai/features/home/presentation/widgets/home_drawer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:century_ai/router/app_routes.dart';
import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/cubit/products/products_cubit.dart';
import 'package:century_ai/cubit/upload/upload_cubit.dart';
import 'package:century_ai/db/models/selected_image_data.dart';
import 'package:century_ai/db/repositories/selected_images_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:century_ai/features/camera_pages/presentation/widgets/camera_tips_bottom_sheet.dart';

class CameraPagesIndex extends StatefulWidget {
  final bool fromColorPicker;
  final File? originalImage;
  const CameraPagesIndex({
    super.key,
    this.fromColorPicker = false,
    this.originalImage,
  });

  @override
  State<CameraPagesIndex> createState() => _CameraPagesIndexState();
}

// class __CameraPagesIndexState extends State<CameraPagesIndex> {
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//   CameraController? _controller;
//   bool _isReady = false;
//   final double _bottomBarHeight = 140;

//   bool _isImageTaken = false;
//   File? _capturedFile;
//   bool _isUploading = false;

//   @override
//   void initState() {
//     super.initState();
//     _initCamera();
//   }

//   Future<void> _initCamera() async {
//     final cameras = await availableCameras();

//     _controller = CameraController(
//       cameras.first,
//       ResolutionPreset.high,
//       enableAudio: false,
//     );

//     await _controller!.initialize();
//     if (!mounted) return;

//     setState(() => _isReady = true);
//   }

//   @override
//   void dispose() {
//     _controller?.dispose();
//     super.dispose();
//   }

//   Future<File> _cropToOverlay(File imageFile, Size screenSize) async {
//     try {
//       final bytes = await imageFile.readAsBytes();
//       final filePath = imageFile.path;

//       final croppedBytes = await compute((Map<String, dynamic> params) {
//         final Uint8List imgBytes = params['bytes'];
//         final double screenW = params['screenW'];
//         final double screenH = params['screenH'];
//         final String path = params['path'];

//         final image = img.decodeImage(imgBytes);
//         if (image == null) return imgBytes;

//         final orientedImage = img.bakeOrientation(image);

//         final double imgW = orientedImage.width.toDouble();
//         final double imgH = orientedImage.height.toDouble();

//         // Calculate the BoxFit.cover scaling factor
//         final double scale = (imgW / screenW) > (imgH / screenH)
//             ? imgH / screenH
//             : imgW / screenW;

//         final double displayedW = imgW / scale;
//         final double displayedH = imgH / scale;

//         final double offsetX = (screenW - displayedW) / 2;
//         final double offsetY = (screenH - displayedH) / 2;

//         // Rectangle bounds from _OverlayPainter
//         final double rectLeft = 20.0;
//         final double rectTop = screenH * 0.22;
//         final double rectWidth = screenW - 40.0;
//         final double rectHeight = screenH * 0.45;

//         // Map screen rectangle coordinates to image pixel space
//         final int cropX = (((rectLeft - offsetX) * scale)).round().clamp(0, orientedImage.width - 1);
//         final int cropY = (((rectTop - offsetY) * scale)).round().clamp(0, orientedImage.height - 1);
//         final int cropW = ((rectWidth * scale)).round().clamp(1, orientedImage.width - cropX);
//         final int cropH = ((rectHeight * scale)).round().clamp(1, orientedImage.height - cropY);

//         final cropped = img.copyCrop(
//           orientedImage,
//           x: cropX,
//           y: cropY,
//           width: cropW,
//           height: cropH,
//         );

//         return Uint8List.fromList(
//           img.encodeNamedImage(path, cropped) ?? img.encodeJpg(cropped),
//         );
//       }, {
//         'bytes': bytes,
//         'screenW': screenSize.width,
//         'screenH': screenSize.height,
//         'path': filePath,
//       });

//       final croppedFile = File(filePath);
//       await croppedFile.writeAsBytes(croppedBytes);
//       return croppedFile;
//     } catch (e) {
//       debugPrint('Error cropping image to overlay: $e');
//       return imageFile; // Fallback to original image on error
//     }
//   }

//   Future<void> _capture() async {
//     if (!_controller!.value.isInitialized) return;

//     final XFile file = await _controller!.takePicture();
//     File imageFile = File(file.path);
//     imageFile = await _fixOrientation(imageFile);

//     setState(() {
//       _isImageTaken = true;
//       _capturedFile = imageFile;
//     });

//     if (!mounted) return;

//     // Show loading dialog
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => const Center(
//         child: CircularProgressIndicator(color: TColors.primary),
//       ),
//     );

//     try {
//       final screenSize = MediaQuery.of(context).size;
//       final croppedFile = await _cropToOverlay(imageFile, screenSize);

//       if (!mounted) return;
//       setState(() {
//         _capturedFile = croppedFile;
//       });
//       final productsCubit = context.read<ProductsCubit>();
//       final newProduct = await productsCubit.uploadProductImageNew(croppedFile);

//       if (!mounted) return;
//       Navigator.of(context, rootNavigator: true).pop(); // Dismiss loader

//       if (newProduct == null) {
//         setState(() {
//           _isImageTaken = false;
//           _capturedFile = null;
//         });
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Failed to upload image to server.")),
//         );
//         return;
//       }

//       final imageBytes = await compute((File f) => f.readAsBytesSync(), croppedFile);
//       final imageId = newProduct.id;

//       await SelectedImagesRepository.saveImage(
//         SelectedImageData(
//           id: imageId,
//           imageData: imageBytes,
//           imagePath: croppedFile.path,
//           category: 'Uploaded Image',
//           subcategory: 'User Upload',
//           selectedAt: DateTime.now(),
//         ),
//       );

//       if (!mounted) return;
//       if (widget.fromColorPicker) {
//         context.pushReplacement(AppRoutes.imageColorPicker, extra: {
//           'imageFile': croppedFile,
//           'image_id': imageId,
//           'originalImage': widget.originalImage,
//         });
//       } else {
//         context.pushReplacement(AppRoutes.imagePreview, extra: {
//           'imageFile': croppedFile,
//           'image_id': imageId,
//           'image_category': "Uploaded Image",
//           'sub_category': "User Upload",
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _isImageTaken = false;
//           _capturedFile = null;
//         });
//         Navigator.of(context, rootNavigator: true).pop(); // Dismiss loader
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Error processing image: $e")),
//         );
//       }
//     }
//   }

//   Future<void> _pickFromGallery() async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? image = await picker.pickImage(source: ImageSource.gallery);

//     if (image == null || !mounted) return;

//     final File imageFile = File(image.path);

//     // Show loading dialog
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => const Center(
//         child: CircularProgressIndicator(color: TColors.primary),
//       ),
//     );

//     try {
//       final productsCubit = context.read<ProductsCubit>();
//       final newProduct = await productsCubit.uploadProductImageNew(imageFile);

//       if (!mounted) return;
//       Navigator.of(context, rootNavigator: true).pop(); // Dismiss loader

//       if (newProduct == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Failed to upload image to server.")),
//         );
//         return;
//       }

//       final imageBytes = await compute((File f) => f.readAsBytesSync(), imageFile);
//       final imageId = newProduct.id;

//       await SelectedImagesRepository.saveImage(
//         SelectedImageData(
//           id: imageId,
//           imageData: imageBytes,
//           imagePath: imageFile.path,
//           category: 'Uploaded Image',
//           subcategory: 'User Upload',
//           selectedAt: DateTime.now(),
//         ),
//       );

//       if (!mounted) return;
//       if (widget.fromColorPicker) {
//         context.pushReplacement(AppRoutes.imageColorPicker, extra: {
//           'imageFile': imageFile,
//           'image_id': imageId,
//           'originalImage': widget.originalImage,
//         });
//       } else {
//         context.pushReplacement(AppRoutes.imagePreview, extra: {
//           'imageFile': imageFile,
//           'image_id': imageId,
//           'image_category': "Uploaded Image",
//           'sub_category': "User Upload",
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         Navigator.of(context, rootNavigator: true).pop(); // Dismiss loader
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Error processing image: $e")),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (!_isReady) {
//       return Scaffold(
//         backgroundColor: Colors.black,
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }

//     return Scaffold(
//       key: _scaffoldKey,
//       drawer: const HomeDrawer(),
//       backgroundColor: Colors.white,
//       body: Stack(
//         children: [
//           // 📷 Camera Preview or Static Captured Image (full screen)
//           Positioned.fill(
//             child: RepaintBoundary(
//               child: _isImageTaken && _capturedFile != null
//                   ? Image.file(_capturedFile!, fit: BoxFit.cover)
//                   : LayoutBuilder(
//                       builder: (context, constraints) {
//                         final size = constraints.biggest;
//                         double scale = size.aspectRatio * _controller!.value.aspectRatio;
//                         if (scale < 1.0) {
//                           scale = 1.0 / scale;
//                         }
//                         return ClipRect(
//                           child: Transform.scale(
//                             scale: scale,
//                             child: Center(
//                               child: CameraPreview(_controller!),
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//             ),
//           ),

//           // 🟦 Capture Area Overlay (stays above camera)
//           const _CaptureOverlay(),

//           // ⬜ WHITE BOTTOM PANEL
//           Positioned(
//             bottom: 0,
//             left: 0,
//             right: 0,
//             height: _bottomBarHeight,
//             child: Container(color: Colors.white),
//           ),

//           // 🔘 Capture Button (inside white area)
//           Positioned(
//             bottom: (_bottomBarHeight / 2) - 36,
//             left: 0,
//             right: 0,
//             child: Center(
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   SizedBox(width: 5),
//                   GestureDetector(
//                     onTap: () {
//                       Scaffold.of(context).openDrawer();
//                     },
//                     child: Container(
//                       width: 50,
//                       height: 50,
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         border: Border.all(
//                           color: const Color(0xFFE5E5E5),
//                           width: 0,
//                         ),
//                         boxShadow: [
//                           BoxShadow(
//                             blurRadius: 3,
//                             color: Color(0xFF646464),
//                             offset: const Offset(0, 2),
//                           ),
//                         ],
//                         color: Colors.white,
//                       ),
//                       child: const Center(child: Icon(Icons.menu, size: 24)),
//                     ),
//                   ),
//                   GestureDetector(
//                     onTap: _capture,
//                     child: Container(
//                       width: 72,
//                       height: 72,
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         border: Border.all(
//                           color: const Color(0xFFE5E5E5),
//                           width: 0,
//                         ),
//                         boxShadow: [
//                           BoxShadow(
//                             blurRadius: 3,
//                             color: Color(0xFF646464),
//                             offset: const Offset(0, 4),
//                           ),
//                         ],
//                         color: Colors.white,
//                       ),
//                       child: Center(
//                         child: Icon(Icons.camera_alt, size: 36),
//                         // child: SvgPicture.asset("assets/icons/app_icons/image_flash.svg"),
//                       ),
//                     ),
//                   ),
//                   GestureDetector(
//                     onTap: _pickFromGallery,
//                     child: Container(
//                       width: 50,
//                       height: 50,
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         border: Border.all(
//                           color: const Color(0xFFE5E5E5),
//                           width: 0,
//                         ),
//                         boxShadow: [
//                           BoxShadow(
//                             blurRadius: 3,
//                             color: Color(0xFF646464),
//                             offset: const Offset(0, 2),
//                           ),
//                         ],
//                         color: Colors.white,
//                       ),
//                       child: Center(
//                         // child: SvgPicture.asset(
//                         //   "assets/icons/app_icons/images.svg",
//                         // ),
//                         child: Icon(Icons.file_upload_outlined),
//                       ),
//                     ),
//                   ),
//                   SizedBox(width: 5),
//                 ],
//               ),
//             ),
//           ),

//           // Custom App Button
//           Positioned(
//             top: 40,
//             left: 0,
//             right: 0,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.clear, color: Colors.white),
//                   onPressed: () => {context.pop()},
//                 ),
//                 IconButton(
//                   icon: Icon(Icons.flash_off_rounded, color: Colors.white),
//                   onPressed: () => {},
//                 ),
//               ],
//             ),
//           ),

//           Positioned(
//             bottom: 45,
//             left: 7,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.arrow_back_ios, color: Colors.black),
//                   onPressed: () => context.pop(),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

class _CameraPagesIndexState extends State<CameraPagesIndex> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  CameraController? _controller;
  bool _isReady = false;
  final double _bottomBarHeight = 140;

  bool _isImageTaken = false;
  File? _capturedFile;
  bool _isUploading = false; // NEW: track upload-in-progress state
  FlashMode _flashMode = FlashMode.off;
  FlashMode _selectedFlashMode = FlashMode.off;

  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoomLevel = 1.0;
  double _baseZoomLevel = 1.0;
  StreamSubscription<NativeDeviceOrientation>? _orientationSubscription;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initCamera();
    _orientationSubscription = NativeDeviceOrientationCommunicator()
        .onOrientationChanged(useSensor: true)
        .listen((orientation) {
      debugPrint('++++++++++++++++++++');
      debugPrint('++++++++++++++++++++');
      debugPrint('Device Orientation: $orientation');
      debugPrint('++++++++++++++++++++');
      debugPrint('++++++++++++++++++++');
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = GetStorage();
      final bool dontShow = box.read<bool>('dont_show_camera_tips') ?? false;
      if (!dontShow) {
        CameraTipsBottomSheet.show(context);
      }
    });
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

    try {
      await _controller!.unlockCaptureOrientation();
    } catch (e) {
      debugPrint('Error unlocking capture orientation: $e');
    }

    // Get zoom ranges
    try {
      _minZoomLevel = await _controller!.getMinZoomLevel();
      _maxZoomLevel = await _controller!.getMaxZoomLevel();
    } catch (e) {
      debugPrint('Error getting zoom levels: $e');
    }

    // Set initial flash mode on the controller
    try {
      await _controller!.setFlashMode(
        _flashMode == FlashMode.always ? FlashMode.torch : _flashMode,
      );
      _selectedFlashMode = _flashMode;
    } catch (e) {
      debugPrint('Error setting initial flash mode: $e');
    }

    setState(() => _isReady = true);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.off:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
      case FlashMode.torch:
        nextMode = FlashMode.off;
        break;
    }

    try {
      // If we are setting to always, use torch so the flash light stays on continuously
      await _controller!.setFlashMode(
        nextMode == FlashMode.always ? FlashMode.torch : nextMode,
      );
      if (mounted) {
        setState(() {
          _flashMode = nextMode;
          _selectedFlashMode = nextMode;
        });
      }
    } catch (e) {
      debugPrint('Error toggling flash mode: $e');
    }
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.always:
        return Icons.flash_on_rounded;
      case FlashMode.torch:
        return Icons.highlight_rounded;
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _orientationSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<File> _fixOrientation(
    File file, {
    required Orientation screenOrientation,
    required NativeDeviceOrientation deviceOrientation,
  }) async {
    try {
      final bytes = await file.readAsBytes();

      final fixedBytes = await compute(_normalizeImageOrientation, {
        'bytes': bytes,
        'screenOrientation': screenOrientation.name,
        'deviceOrientation': deviceOrientation.toString(),
      });

      await file.writeAsBytes(fixedBytes, flush: true);

      // Important: remove Flutter's cached version of the old pixels.
      await FileImage(file).evict();

      return file;
    } catch (e) {
      debugPrint('❌ Orientation fix failed: $e');
      return file;
    }
  }

  static Uint8List _normalizeImageOrientation(
    Map<String, dynamic> params,
  ) {
    final Uint8List bytes = params['bytes'];
    final String screenOrientation = params['screenOrientation'];
    final String deviceOrientation = params['deviceOrientation'];

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    // STEP 1:
    // Apply the camera's EXIF orientation exactly once.
    img.Image result = img.bakeOrientation(decoded);

    final bool wantsLandscape =
        screenOrientation == Orientation.landscape.name ||
        deviceOrientation.contains('landscapeLeft') ||
        deviceOrientation.contains('landscapeRight');

    final bool currentlyLandscape =
        result.width > result.height;

    debugPrint(
      '📸 Screen: $screenOrientation | '
      'Device: $deviceOrientation | '
      'After EXIF: ${result.width}x${result.height}',
    );

    // STEP 2:
    // Only rotate if the final pixel dimensions don't match the screen.
    if (wantsLandscape != currentlyLandscape) {
      int angle = 90;

      if (deviceOrientation.contains('landscapeLeft')) {
        angle = 270;
      } else if (deviceOrientation.contains('landscapeRight')) {
        angle = 90;
      }

      result = img.copyRotate(result, angle: angle);
    }

    // Handle upside-down portrait.
    if (!wantsLandscape &&
        deviceOrientation.contains('portraitDown')) {
      result = img.copyRotate(result, angle: 180);
    }

    // Prevent another reader from rotating it again.
    result.exif.imageIfd.orientation = 1;

    debugPrint(
      '✅ Final image: ${result.width}x${result.height}',
    );

    return Uint8List.fromList(
      img.encodeJpg(result, quality: 95),
    );
  }


  /// Crops the captured image to the overlay area using native dart:ui Canvas.
  /// This is much faster than the `image` package approach.
  Future<File> _cropToOverlay(File imageFile, Size screenSize) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final filePath = imageFile.path;

      // Decode using native dart:ui codec (GPU-accelerated)
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image srcImage = frameInfo.image;

      final double imgW = srcImage.width.toDouble();
      final double imgH = srcImage.height.toDouble();
      final double screenW = screenSize.width;
      final double screenH = screenSize.height;

      // BoxFit.cover math: find scale so image fills entire screen
      final double scale = (imgW / screenW) > (imgH / screenH)
          ? imgH / screenH
          : imgW / screenW;

      final double displayedW = imgW / scale;
      final double displayedH = imgH / scale;

      final double offsetX = (screenW - displayedW) / 2;
      final double offsetY = (screenH - displayedH) / 2;

      // Centered overlay rect matching ratio of edit page
      final double rectWidth = screenW - 32.0;
      final double ratio = screenW / (screenH * 0.40);
      final double rectHeight = rectWidth / ratio;
      final double rectLeft = 16.0;
      final double rectTop = (screenH - rectHeight) / 2;

      // Map screen coordinates to image pixel space
      final double cropX = ((rectLeft - offsetX) * scale).clamp(
        0.0,
        imgW - 1.0,
      );
      final double cropY = ((rectTop - offsetY) * scale).clamp(0.0, imgH - 1.0);
      final double cropW = (rectWidth * scale).clamp(1.0, imgW - cropX);
      final double cropH = (rectHeight * scale).clamp(1.0, imgH - cropY);

      // Use native Canvas to draw the cropped region
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      final Rect src = Rect.fromLTWH(cropX, cropY, cropW, cropH);
      final Rect dst = Rect.fromLTWH(0, 0, cropW, cropH);

      canvas.drawImageRect(
        srcImage,
        src,
        dst,
        Paint()..filterQuality = FilterQuality.high,
      );

      final ui.Picture picture = recorder.endRecording();
      final ui.Image croppedImage = await picture.toImage(
        cropW.round(),
        cropH.round(),
      );

      final ByteData? byteData = await croppedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      srcImage.dispose();
      croppedImage.dispose();

      if (byteData != null) {
        final Uint8List croppedBytes = byteData.buffer.asUint8List();
        final croppedFile = File(filePath);
        await croppedFile.writeAsBytes(croppedBytes);
        return croppedFile;
      }

      return imageFile;
    } catch (e) {
      debugPrint('Error cropping image to overlay: $e');
      return imageFile;
    }
  }

  /// Step 1: just capture + crop, then show for confirmation.
  /// Start upload in background immediately.
  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    // Capture the UI orientation BEFORE taking the photo.
    final Orientation screenOrientation = MediaQuery.orientationOf(context);

    final NativeDeviceOrientation deviceOrientation =
        await NativeDeviceOrientationCommunicator().orientation(
      useSensor: true,
    );

    try {
      // If flash mode is auto, temporarily set to always to force a single flash/blink on capture
      if (_flashMode == FlashMode.auto) {
        await _controller!.setFlashMode(FlashMode.always);
      }
    } catch (e) {
      debugPrint('Error setting flash mode for auto blink: $e');
    }

    final XFile file = await _controller!.takePicture();
    File imageFile = File(file.path);
    imageFile = await _fixOrientation(
      imageFile,
      screenOrientation: screenOrientation,
      deviceOrientation: deviceOrientation,
    );

    if (!mounted) return;

    // Small local loading indicator just for the crop step
    setState(() => _isUploading = true);

    try {
      // Turn flash off after taking picture
      try {
        await _controller!.setFlashMode(FlashMode.off);
      } catch (e) {
        debugPrint('Error turning off flash after capture: $e');
      }

      final croppedFile = imageFile;

      if (!mounted) return;
      setState(() {
        _isImageTaken = true;
        _capturedFile = croppedFile;
        _isUploading = false;
        _flashMode = FlashMode.off;
      });

      // Start upload automatically in the background
      if (mounted) {
        context.read<UploadCubit>().startUpload(croppedFile);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error processing image: $e")));
      }
    }
  }

  /// User tapped "Retake" — discard captured image, go back to live preview.
  void _retakePhoto() {
    context.read<UploadCubit>().reset();

    // Restore the user's previously selected flash mode on the camera controller
    try {
      if (_controller != null && _controller!.value.isInitialized) {
        _controller!.setFlashMode(
          _selectedFlashMode == FlashMode.always
              ? FlashMode.torch
              : _selectedFlashMode,
        );
      }
    } catch (e) {
      debugPrint('Error restoring flash mode on retake: $e');
    }

    setState(() {
      _isImageTaken = false;
      _capturedFile = null;
      _flashMode = _selectedFlashMode;
    });
  }

  /// Step 2: user confirmed — navigate instantly to ImagePreviewPage.
  Future<void> _confirmPhoto() async {
    if (_capturedFile == null) return;
    final croppedFile = _capturedFile!;

    // Confirm upload locally in the Cubit (will auto-save to SQLite when complete)
    context.read<UploadCubit>().confirm();

    if (!mounted) return;
    if (widget.fromColorPicker) {
      context.pushReplacement(
        AppRoutes.imageColorPicker,
        extra: {
          'imageFile': croppedFile,
          'image_id': context.read<UploadCubit>().state.imageId,
          'originalImage': widget.originalImage,
        },
      );
    } else {
      context.pushReplacement(
        AppRoutes.imageUploadPreview,
        extra: {
          'imageFile': croppedFile,
          'image_category': "Uploaded Image",
          'sub_category': "User Upload",
        },
      );
    }
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null || !mounted) return;

    File imageFile = File(image.path);

    // Resize if either dimension exceeds 1024 px.
    try {
      final lowerPath = image.path.toLowerCase();
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null && (decoded.width > 1024 || decoded.height > 1024)) {
        final resized = img.copyResize(
          decoded,
          width: decoded.width > decoded.height ? 1024 : -1,
          height: decoded.height >= decoded.width ? 1024 : -1,
        );
        final isJpeg =
            lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg');
        final encoded = isJpeg
            ? img.encodeJpg(resized, quality: 90)
            : img.encodePng(resized);
        final resizedFile = File(
          '${imageFile.parent.path}/resized_${image.name}',
        );
        await resizedFile.writeAsBytes(encoded);
        imageFile = resizedFile;
        debugPrint(
          '🖼️ Image resized from ${decoded.width}x${decoded.height} '
          'to ${resized.width}x${resized.height}',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Image resize failed, uploading original: $e');
    }

    // Start background upload immediately
    context.read<UploadCubit>().startUpload(imageFile);
    // Confirm upload immediately since user selected it from gallery
    context.read<UploadCubit>().confirm();

    if (!mounted) return;
    if (widget.fromColorPicker) {
      context.pushReplacement(
        AppRoutes.imageColorPicker,
        extra: {
          'imageFile': imageFile,
          'image_id': context.read<UploadCubit>().state.imageId,
          'originalImage': widget.originalImage,
        },
      );
    } else {
      context.pushReplacement(
        AppRoutes.imageUploadPreview,
        extra: {
          'imageFile': imageFile,
          'image_category': "Uploaded Image",
          'sub_category': "User Upload",
        },
      );
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
          // 📷 Camera Preview or Captured Image Preview
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: _bottomBarHeight,
            child: RepaintBoundary(
              child: _isImageTaken && _capturedFile != null
                  ? Container(
                      color: Colors.white,
                      child: Center(
                        child: Image.file(_capturedFile!, fit: BoxFit.contain),
                      ),
                    )
                  : GestureDetector(
                      onScaleStart: (details) {
                        _baseZoomLevel = _currentZoomLevel;
                      },
                      onScaleUpdate: (details) async {
                        if (_controller == null ||
                            !_controller!.value.isInitialized)
                          return;
                        double newZoom = _baseZoomLevel * details.scale;
                        newZoom = newZoom.clamp(_minZoomLevel, _maxZoomLevel);
                        if (newZoom != _currentZoomLevel) {
                          _currentZoomLevel = newZoom;
                          try {
                            await _controller!.setZoomLevel(newZoom);
                          } catch (e) {
                            debugPrint('Error setting zoom: $e');
                          }
                        }
                      },
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1 / _controller!.value.aspectRatio,
                          child: CameraPreview(_controller!),
                        ),
                      ),
                    ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: _bottomBarHeight,
            child: Container(color: Colors.white),
          ),

          // 🔘 Bottom controls — swap based on whether image is captured
          Positioned(
            bottom: (_bottomBarHeight / 2) - 36,
            left: 0,
            right: 0,
            child: Center(
              child: _isImageTaken ? _buildConfirmRow() : _buildCaptureRow(),
            ),
          ),

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
                if (!_isImageTaken)
                  IconButton(
                    icon: Icon(_getFlashIcon(), color: Colors.white),
                    onPressed: _toggleFlash,
                  ),
              ],
            ),
          ),

          if (!_isImageTaken)
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

          if (_isUploading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: CircularProgressIndicator(color: TColors.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Original: menu / capture / gallery
  Widget _buildCaptureRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        const SizedBox(width: 5),
        GestureDetector(
          onTap: () => Scaffold.of(context).openDrawer(),
          child: _circleButton(child: const Icon(Icons.menu, size: 24)),
        ),
        GestureDetector(
          onTap: _capture,
          child: _circleButton(
            size: 72,
            child: const Icon(Icons.camera_alt, size: 36),
          ),
        ),
        GestureDetector(
          onTap: _pickFromGallery,
          child: _circleButton(child: const Icon(Icons.file_upload_outlined)),
        ),
        const SizedBox(width: 5),
      ],
    );
  }

  // NEW: Retake / Use Photo confirmation row
  Widget _buildConfirmRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Retake
        GestureDetector(
          onTap: _retakePhoto,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: TColors.primary, width: 1.5),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, color: TColors.primary),
                SizedBox(width: 6),
                Text(
                  "Retake",
                  style: TextStyle(
                    color: TColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Use Photo (confirm)
        GestureDetector(
          onTap: _confirmPhoto,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: TColors.primary,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  "Use Photo",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _circleButton({double size = 50, required Widget child}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            blurRadius: 3,
            color: Color(0xFF646464),
            offset: Offset(0, 2),
          ),
        ],
        color: Colors.white,
      ),
      child: Center(child: child),
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
  _OverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withOpacity(0.6);

    // Centered overlay rect matching ratio of edit page
    final double rectWidth = size.width - 32.0;
    final double ratio = size.width / (size.height * 0.40);
    final double rectHeight = rectWidth / ratio;
    final double rectLeft = 16.0;
    final double rectTop = (size.height - rectHeight) / 2;

    final captureRect = Rect.fromLTWH(rectLeft, rectTop, rectWidth, rectHeight);

    // Draw dim rectangles around the capture area
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

    // White border with rounded corners around capture area
    canvas.drawRRect(
      RRect.fromRectAndRadius(captureRect, const Radius.circular(16)),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) => false;
}
