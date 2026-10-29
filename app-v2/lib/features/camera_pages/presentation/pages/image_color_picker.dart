import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get_storage/get_storage.dart';
import 'package:century_ai/features/camera_pages/presentation/widgets/camera_tips_bottom_sheet.dart';
import 'package:century_ai/router/app_routes.dart';

class ImageColorPickerPage extends StatefulWidget {
  final File imageFile;
  final File? originalImage;

  const ImageColorPickerPage({
    super.key,
    required this.imageFile,
    this.originalImage,
  });

  @override
  State<ImageColorPickerPage> createState() => _ImageColorPickerPageState();
}

class _ImageColorPickerPageState extends State<ImageColorPickerPage> {
  GlobalKey _imageKey = GlobalKey();
  Offset _touchPos = Offset.zero;
  Color _primaryColor = const Color(0xFFE5E5E5);
  Color _complimentaryColor1 = const Color(0xFFE5E5E5);
  Color _complimentaryColor2 = const Color(0xFFCDCDCD);

  ui.Image? _cachedImage;
  ByteData? _pixelData;
  late File _currentImage;
  final ImagePicker _picker = ImagePicker();
  bool _isCapturing = false;

  double? _imageAspectRatio;
  double _dragX = 0.0;
  double _dragY = 0.0;

  void _resolveImageSize() {
    final ImageProvider imageProvider = FileImage(_currentImage);
    final ImageStream stream = imageProvider.resolve(
      const ImageConfiguration(),
    );
    ImageStreamListener? listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (mounted) {
          setState(() {
            _imageAspectRatio = info.image.width / info.image.height;
            _dragX = 0.0;
            _dragY = 0.0;
          });
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          stream.removeListener(listener!);
        });
      },
      onError: (exception, stackTrace) {
        debugPrint("Error loading image size: $exception");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          stream.removeListener(listener!);
        });
      },
    );
    stream.addListener(listener);
  }

  @override
  void initState() {
    super.initState();
    _currentImage = widget.imageFile;
    _resolveImageSize();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      setState(() {
        _touchPos = Offset(size.width / 2, size.height * 0.3);
      });
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _pickColor(_touchPos);
        }
      });
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final box = GetStorage();
      final bool dontShow = box.read<bool>('dont_show_camera_tips') ?? false;
      if (!dontShow) {
        await CameraTipsBottomSheet.show(context);
      }
    }
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _currentImage = File(pickedFile.path);
          _cachedImage = null; // Force repaint
          _pixelData = null;
          _imageKey = GlobalKey(); // Force new RepaintBoundary
        });
        _resolveImageSize();

        // Reset touch pos and pick new color after image has time to render
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              final size = MediaQuery.of(context).size;
              setState(() {
                _touchPos = Offset(size.width / 2, size.height * 0.3);
                _cachedImage = null;
                _pixelData = null;
              });
              _pickColor(_touchPos);
            }
          });
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _pickColor(Offset localPos) async {
    try {
      if (_cachedImage == null) {
        if (_isCapturing) return;
        _isCapturing = true;
        try {
          RenderRepaintBoundary? boundary =
              _imageKey.currentContext?.findRenderObject()
                  as RenderRepaintBoundary?;
          if (boundary == null) return;
          _cachedImage = await boundary.toImage(pixelRatio: 1.0);
          _pixelData = await _cachedImage!.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
        } finally {
          _isCapturing = false;
        }
      }

      if (_pixelData == null || _cachedImage == null) return;

      final int x = localPos.dx.toInt().clamp(0, _cachedImage!.width - 1);
      final int y = localPos.dy.toInt().clamp(0, _cachedImage!.height - 1);

      final int byteOffset = (y * _cachedImage!.width + x) * 4;

      if (byteOffset + 3 >= _pixelData!.lengthInBytes) return;

      final int r = _pixelData!.getUint8(byteOffset);
      final int g = _pixelData!.getUint8(byteOffset + 1);
      final int b = _pixelData!.getUint8(byteOffset + 2);
      final int a = _pixelData!.getUint8(byteOffset + 3);

      setState(() {
        _primaryColor = Color.fromARGB(a, r, g, b);
        // Simple complimentary logic for demonstration
        _complimentaryColor1 = Color.fromARGB(
          a,
          (255 - r).clamp(0, 255),
          (255 - g).clamp(0, 255),
          (255 - b).clamp(0, 255),
        );
        _complimentaryColor2 = _primaryColor.withOpacity(0.7);
      });
    } catch (e) {
      debugPrint("Error picking color: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2C),
      body: Column(
        children: [
          // Top Image Area
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewportWidth = constraints.maxWidth;
                final viewportHeight = constraints.maxHeight;

                if (_imageAspectRatio == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final viewportRatio = viewportWidth / viewportHeight;
                final isLandscape = _imageAspectRatio! > viewportRatio;

                double maxDragX = 0.0;
                double maxDragY = 0.0;
                double scaledWidth = viewportWidth;
                double scaledHeight = viewportHeight;

                if (isLandscape) {
                  scaledWidth = viewportHeight * _imageAspectRatio!;
                  scaledHeight = viewportHeight;
                  maxDragX = (scaledWidth - viewportWidth) / 2.0;
                } else {
                  scaledWidth = viewportWidth;
                  scaledHeight = viewportWidth / _imageAspectRatio!;
                  maxDragY = (scaledHeight - viewportHeight) / 2.0;
                }

                _dragX = _dragX.clamp(-maxDragX, maxDragX);
                _dragY = _dragY.clamp(-maxDragY, maxDragY);

                bool isDraggingTarget = false;

                return Stack(
                  children: [
                    RepaintBoundary(
                      key: _imageKey,
                      child: GestureDetector(
                        onPanStart: (details) {
                          _cachedImage = null;
                          _pixelData = null;
                          final distance =
                              (details.localPosition - _touchPos).distance;
                          if (distance < 40.0) {
                            isDraggingTarget = true;
                          } else {
                            isDraggingTarget = false;
                          }
                        },
                        onPanUpdate: (details) {
                          if (isDraggingTarget) {
                            setState(() {
                              _touchPos = details.localPosition;
                            });
                            _pickColor(details.localPosition);
                          } else {
                            setState(() {
                              if (isLandscape) {
                                _dragX = (_dragX + details.delta.dx).clamp(
                                  -maxDragX,
                                  maxDragX,
                                );
                              } else {
                                _dragY = (_dragY + details.delta.dy).clamp(
                                  -maxDragY,
                                  maxDragY,
                                );
                              }
                            });
                            _pickColor(_touchPos);
                          }
                        },
                        onTapDown: (details) {
                          _cachedImage = null;
                          _pixelData = null;
                          setState(() {
                            _touchPos = details.localPosition;
                          });
                          _pickColor(details.localPosition);
                        },
                        child: Container(
                          width: viewportWidth,
                          height: viewportHeight,
                          color: Colors.black,
                          child: ClipRect(
                            child: OverflowBox(
                              minWidth: scaledWidth,
                              maxWidth: scaledWidth,
                              minHeight: scaledHeight,
                              maxHeight: scaledHeight,
                              child: Transform.translate(
                                offset: Offset(_dragX, _dragY),
                                child: Image.file(
                                  _currentImage,
                                  width: scaledWidth,
                                  height: scaledHeight,
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Color Picker Target Icon
                    Positioned(
                      left: _touchPos.dx - 20,
                      top: _touchPos.dy - 20,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.gps_fixed,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Bottom Panel
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Primary Color
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Primary",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: _primaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Grand Forrester",
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          const Text(
                            "8A660",
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Complimentary Colors
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Complimentary",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: _complimentaryColor1,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(4),
                                          bottomLeft: Radius.circular(4),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      "Calming Touch",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const Text(
                                      "8A660",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: _complimentaryColor2,
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(4),
                                          bottomRight: Radius.circular(4),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      "Full Boom",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const Text(
                                      "8A660",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Buttons
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: IconButton(
                        onPressed: () {
                          context.push(
                            AppRoutes.camera,
                            extra: {
                              'fromColorPicker': true,
                              'originalImage': widget.originalImage ?? widget.imageFile,
                            },
                          );
                        },
                        icon: const Icon(Icons.camera_alt_outlined),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: IconButton(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context, _primaryColor);
                        },
                        icon: const Icon(Icons.gps_fixed),
                        label: const Text("Load Color"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, _primaryColor);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      side: BorderSide.none,
                    ),
                    child: const Text("Done"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
