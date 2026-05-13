import 'dart:io';
import 'package:flutter/material.dart';

class ImageCompareSlider extends StatefulWidget {
  final dynamic before;
  final dynamic after;
  final double height;
  final double position;
  final ValueChanged<double> onChanged;
  final bool isAfterNetwork;

  const ImageCompareSlider({
    super.key,
    required this.before,
    required this.after,
    required this.position,
    required this.onChanged,
    this.height = 360,
    this.isAfterNetwork = false,
  });

  @override
  State<ImageCompareSlider> createState() => _ImageCompareSliderState();
}

class _ImageCompareSliderState extends State<ImageCompareSlider> {
  late ValueNotifier<double> _positionNotifier;

  @override
  void initState() {
    super.initState();
    _positionNotifier = ValueNotifier(widget.position);
  }

  @override
  void didUpdateWidget(ImageCompareSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) {
      _positionNotifier.value = widget.position;
    }
  }

  @override
  void dispose() {
    _positionNotifier.dispose();
    super.dispose();
  }

  Widget _buildImage(dynamic source, double width, double height, {bool forceNetwork = false}) {
    if (source is File) {
      return Image.file(source, width: width, height: height, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (source is String) {
      if (forceNetwork || source.startsWith('http')) {
        return Image.network(
          source,
          width: width,
          height: height,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey[200],
            child: const Icon(Icons.error_outline),
          ),
        );
      }
      return Image.asset(source, width: width, height: height, fit: BoxFit.cover, gaplessPlayback: true);
    }
    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final actualHeight = (widget.height != 360) ? widget.height : constraints.maxHeight;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            if (width == 0) return;
            final newPos = (_positionNotifier.value + details.delta.dx / width).clamp(0.0, 1.0);
            _positionNotifier.value = newPos;
            widget.onChanged(newPos);
          },
          child: Stack(
            children: [
              /// AFTER image (background)
              RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: _buildImage(widget.after, width, actualHeight, forceNetwork: widget.isAfterNetwork),
                ),
              ),

              ValueListenableBuilder<double>(
                valueListenable: _positionNotifier,
                builder: (context, position, child) {
                  return SizedBox(
                    width: width,
                    height: actualHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        /// BEFORE image (clipped)
                        ClipRect(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: position,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(0),
                              child: _buildImage(
                                widget.before,
                                width,
                                actualHeight,
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
                            size: Size(2, actualHeight),
                            painter: DashedLinePainter(),
                          ),
                        ),

                        /// HANDLE
                        Positioned(
                          left: width * position - 18,
                          top: actualHeight / 2 - 18,
                          child: const _SliderHandle(),
                        ),
                      ],
                    ),
                  );
                },
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
                Icons.chevron_left,
                size: 14,
              ),
              Icon(
                Icons.chevron_right,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
