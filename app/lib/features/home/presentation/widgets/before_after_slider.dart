import 'package:flutter/material.dart';

class BeforeAfterSlider extends StatefulWidget {
  final String beforeImage;
  final String afterImage;
  final double height;

  const BeforeAfterSlider({
    super.key,
    required this.beforeImage,
    required this.afterImage,
    this.height = 360,
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _sliderPosition = 0.5; // 50%

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _sliderPosition += details.delta.dx / width;
              _sliderPosition = _sliderPosition.clamp(0.0, 1.0);
            });
          },
          child: Stack(
            children: [
              // AFTER image (background)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  widget.afterImage,
                  width: width,
                  height: widget.height,
                  fit: BoxFit.cover,
                ),
              ),

              // BEFORE image (clipped)
              ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: _sliderPosition,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      widget.beforeImage,
                      width: width,
                      height: widget.height,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              // Divider line
              Positioned(
                left: width * _sliderPosition - 1,
                top: 0,
                bottom: 0,
                child: CustomPaint(
                  size: Size(2, widget.height),
                  painter: DashedLinePainter(),
                )
              ),

              // Handle
              Positioned(
                left: width * _sliderPosition - 18,
                top: widget.height / 2 - 14,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.arrow_back_ios,
                            size: 8,
                          ),const Icon(
                            Icons.arrow_forward_ios,
                            size: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

