import 'dart:io';
import 'package:camera/camera.dart';
import 'package:century_ai/features/home/screens/widgets/home_drawer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CameraPagesIndex extends StatefulWidget {
  const CameraPagesIndex({super.key});

  @override
  State<CameraPagesIndex> createState() => _CameraPagesIndexState();
}

class _CameraPagesIndexState extends State<CameraPagesIndex> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  CameraController? _controller;
  bool _isReady = false;
  final double _bottomBarHeight = 140;

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

    // Navigate to edit page (example)
    context.push(
      "/image_edit_page",
      extra: File(file.path),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(
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
          // 📷 Camera Preview (full screen)
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),

          // 🟦 Capture Area Overlay (stays above camera)
          const _CaptureOverlay(),

          // ⬜ WHITE BOTTOM PANEL
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: _bottomBarHeight,
            child: Container(
              color: Colors.white,
            ),
          ),

          // 🔘 Capture Button (inside white area)
          Positioned(
            bottom: (_bottomBarHeight / 2) - 36,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(width: 10,),
                  GestureDetector(
                    onTap: (){_scaffoldKey.currentState?.openDrawer();
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
                          BoxShadow(blurRadius: 3, color: Color(0xFF646464), offset: const Offset(0, 2), )
                        ],
                        color: Colors.white,
                      ),
                      child: const Center(
                        child: Icon(Icons.menu, size: 24,),
                      ),
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
                          BoxShadow(blurRadius: 3, color: Color(0xFF646464), offset: const Offset(0, 4), )
                        ],
                        color: Colors.white,
                      ),
                      child: const Center(
                        child: Icon(Icons.camera_alt, size: 24,),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: (){},
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
                          BoxShadow(blurRadius: 3, color: Color(0xFF646464), offset: const Offset(0, 2), )
                        ],
                        color: Colors.white,
                      ),
                      child: const Center(
                        child: Icon(Icons.file_upload_outlined, size: 24,),
                      ),
                    ),
                  ),
                  SizedBox(width: 10,),
                ],
              ),
            ),
          ),

          // ❌ Close Button
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => context.go("/"),
            ),
          ),
        ],
      ),
    );
    ;
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

    // Dim background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      dimPaint,
    );

    // Clear capture area
    canvas.saveLayer(Rect.largest, Paint());
    canvas.drawRect(captureRect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

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
