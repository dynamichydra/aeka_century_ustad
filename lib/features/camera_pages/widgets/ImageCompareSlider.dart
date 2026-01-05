import 'dart:io';
import 'package:flutter/material.dart';

class ImageCompareSlider extends StatefulWidget {
  final File before;
  final File after;
  final double height;

  const ImageCompareSlider({
    super.key,
    required this.before,
    required this.after,
    this.height = 360,
  });

  @override
  State<ImageCompareSlider> createState() => _ImageCompareSliderState();
}

class _ImageCompareSliderState extends State<ImageCompareSlider> {
  double _pos = 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;

        return GestureDetector(
          onHorizontalDragUpdate: (d) {
            setState(() {
              _pos += d.delta.dx / width;
              _pos = _pos.clamp(0.0, 1.0);
            });
          },
          child: SizedBox(
            height: widget.height,
            child: Stack(
              children: [
                /// AFTER image (background)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    widget.after,
                    width: width,
                    height: widget.height,
                    fit: BoxFit.contain,
                  ),
                ),

                /// BEFORE image (clipped)
                ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: _pos,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        widget.before,
                        width: width,
                        height: widget.height,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                /// DASHED DIVIDER
                Positioned(
                  left: width * _pos - 1,
                  top: 0,
                  bottom: 0,
                  child: CustomPaint(
                    size: Size(2, widget.height),
                    painter: DashedLinePainter(),
                  ),
                ),

                /// HANDLE
                Positioned(
                  left: width * _pos - 18,
                  top: widget.height / 2 - 18,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0x7DFFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                            )
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_back_ios, size: 8),
                            Icon(Icons.arrow_forward_ios, size: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashHeight;
  final double dashGap;

  DashedLinePainter({
    this.color = Colors.white,
    this.dashHeight = 6,
    this.dashGap = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;

    double y = 0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(0, y),
        Offset(0, y + dashHeight),
        paint,
      );
      y += dashHeight + dashGap;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
