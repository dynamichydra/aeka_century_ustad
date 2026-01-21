import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

class ImageColorPickerPage extends StatefulWidget {
  final File imageFile;
  final File? originalImage;

  const ImageColorPickerPage({super.key, required this.imageFile, this.originalImage});

  @override
  State<ImageColorPickerPage> createState() => _ImageColorPickerPageState();
}

class _ImageColorPickerPageState extends State<ImageColorPickerPage> {
  final GlobalKey _imageKey = GlobalKey();
  Offset _touchPos = Offset.zero;
  Color _primaryColor = const Color(0xFFE5E5E5);
  Color _complimentaryColor1 = const Color(0xFFE5E5E5);
  Color _complimentaryColor2 = const Color(0xFFCDCDCD);
  
  ui.Image? _cachedImage;
  ByteData? _pixelData;

  @override
  void initState() {
    super.initState();
    // Initialize touch position to the center of the image area
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      setState(() {
        _touchPos = Offset(size.width / 2, size.height * 0.3);
        _pickColor(_touchPos);
      });
    });
  }

  Future<void> _pickColor(Offset localPos) async {
    try {
      if (_cachedImage == null) {
        RenderRepaintBoundary? boundary = _imageKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) return;
        _cachedImage = await boundary.toImage(pixelRatio: 1.0);
        _pixelData = await _cachedImage!.toByteData(format: ui.ImageByteFormat.rawRgba);
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
        _complimentaryColor1 = Color.fromARGB(a, (255 - r).clamp(0, 255), (255 - g).clamp(0, 255), (255 - b).clamp(0, 255));
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
            child: Stack(
              children: [
                // Image with RepaintBoundary
                RepaintBoundary(
                  key: _imageKey,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _touchPos = details.localPosition;
                      });
                      _pickColor(details.localPosition);
                    },
                    onTapDown: (details) {
                      setState(() {
                        _touchPos = details.localPosition;
                      });
                      _pickColor(details.localPosition);
                    },
                    child: Image.file(
                      widget.imageFile,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
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
            ),
          ),

          // Bottom Panel
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                                      style: TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                    const Text(
                                      "8A660",
                                      style: TextStyle(fontSize: 10, color: Colors.grey),
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
                                      style: TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                    const Text(
                                      "8A660",
                                      style: TextStyle(fontSize: 10, color: Colors.grey),
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
                        icon: const Icon(Icons.camera_alt_outlined),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
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
                      context.push("/image_edit_page", extra: {
                        'imageFile': widget.originalImage ?? widget.imageFile,
                        'pickedColor': _primaryColor,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
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

