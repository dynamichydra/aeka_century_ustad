import 'dart:io';
import 'package:flutter/material.dart';

class ImageCompareSlider extends StatelessWidget {
  final File before;
  final File after;
  final double height;
  final double position;
  final ValueChanged<double> onChanged;

  const ImageCompareSlider({
    super.key,
    required this.before,
    required this.after,
    required this.position,
    required this.onChanged,
    this.height = 360,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            final newPos = (position + details.delta.dx / width).clamp(0.0, 1.0);
            onChanged(newPos);
          },
          child: Stack(
            children: [
              /// AFTER image (background)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  after,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                ),
              ),

              /// BEFORE image (clipped)
              ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: position,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      before,
                      width: width,
                      height: height,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              /// DIVIDER
              Positioned(
                left: width * position - 1,
                top: 0,
                bottom: 0,
                child: CustomPaint(
                  size: Size(2, height),
                  painter: DashedLinePainter(),
                ),
              ),

              /// HANDLE
              Positioned(
                left: width * position - 18,
                top: height / 2 - 18,
                child: const _SliderHandle(),
              ),
            ],
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

class _SliderHandle extends StatelessWidget {
  const _SliderHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0x7DFFFFFF), // semi-transparent white
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.arrow_back_ios,
                size: 8,
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
