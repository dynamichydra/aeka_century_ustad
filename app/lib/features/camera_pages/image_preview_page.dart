import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

class ImagePreviewPage extends StatefulWidget {
  final File imageFile;

  const ImagePreviewPage({super.key, required this.imageFile});

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Image Section with Overlays
                Stack(
                  children: [
                    Image.file(
                      widget.imageFile,
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.55,
                      fit: BoxFit.cover,
                    ),
                    // -- Overlays based on screenshot --
                    // Visual bounding boxes (simulated with CustomPaint or Containers)
                    _buildBoundingBox(top: 50, left: 30, width: 120, height: 150),
                    _buildBoundingBox(top: 140, left: 210, width: 150, height: 80),
                    _buildBoundingBox(top: 250, left: 10, width: 120, height: 180),
                    _buildBoundingBox(top: 350, left: 150, width: 200, height: 100),
                    
                    // Center Instruction
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.35),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.touch_app_outlined, color: Colors.white, size: 40),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                    ),
                  ],
                ),
                
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Text(
                    "More Beds to Explore",
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: exploreImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
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
                          child: Icon(Icons.local_fire_department, color: Colors.red, size: 16),
                        ),
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: Icon(Icons.favorite_border, color: Colors.white70, size: 16),
                        ),
                      ],
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
                child: FloatingActionButton.extended(
                  onPressed: () => context.push("/image_edit_page", extra: widget.imageFile),
                  backgroundColor: Colors.white,
                  elevation: 0,
                  highlightElevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  icon: const Icon(Icons.edit_outlined, color: Colors.black, size: 20),
                  label: const Text(
                    "Edit",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoundingBox({required double top, required double left, required double width, required double height}) {
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
      path.lineTo(i + dashWidth > size.width ? size.width : i + dashWidth, size.height);
    }
    
    // Left line
    for (double i = 0; i < size.height; i += dashWidth + dashSpace) {
      path.moveTo(0, i);
      path.lineTo(0, i + dashWidth > size.height ? size.height : i + dashWidth);
    }
    
    // Right line
    for (double i = 0; i < size.height; i += dashWidth + dashSpace) {
      path.moveTo(size.width, i);
      path.lineTo(size.width, i + dashWidth > size.height ? size.height : i + dashWidth);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
