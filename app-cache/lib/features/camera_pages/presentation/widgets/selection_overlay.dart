import 'package:flutter/material.dart';
import 'package:century_ai/features/camera_pages/models/selection_models.dart';

class SelectionOverlay extends StatelessWidget {
  final SelectionRect selection;
  final Rect imageRect;
  final Size viewSize;
  final bool editingWidth;
  final bool editingHeight;
  final TextEditingController widthEditController;
  final TextEditingController heightEditController;
  final double customWidthInches;
  final double customHeightInches;
  final VoidCallback onWidthSave;
  final VoidCallback onHeightSave;
  final VoidCallback onWidthTap;
  final VoidCallback onHeightTap;

  const SelectionOverlay({
    super.key,
    required this.selection,
    required this.imageRect,
    required this.viewSize,
    required this.editingWidth,
    required this.editingHeight,
    required this.widthEditController,
    required this.heightEditController,
    required this.customWidthInches,
    required this.customHeightInches,
    required this.onWidthSave,
    required this.onHeightSave,
    required this.onWidthTap,
    required this.onHeightTap,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate available space on each side
    final double spaceBelow =
        imageRect.bottom - (selection.top + selection.height);
    final double spaceAbove = selection.top - imageRect.top;
    final double spaceRight =
        imageRect.right - (selection.left + selection.width);
    final double spaceLeft = selection.left - imageRect.left;

    // Decide which side to display the horizontal indicator
    bool showHorizontalArrowAtTop = false;
    if (selection.top - imageRect.top < 45.0) {
      showHorizontalArrowAtTop = false;
    } else if (imageRect.bottom - (selection.top + selection.height) < 45.0) {
      showHorizontalArrowAtTop = true;
    } else {
      showHorizontalArrowAtTop = spaceBelow < 50.0 && spaceAbove > spaceBelow;
    }

    // Decide which side to display the vertical indicator
    bool showVerticalArrowAtLeft = false;
    if (selection.left - imageRect.left < 125.0) {
      showVerticalArrowAtLeft = false;
    } else if (imageRect.right - (selection.left + selection.width) < 125.0) {
      showVerticalArrowAtLeft = true;
    } else {
      showVerticalArrowAtLeft = spaceRight < 120.0 && spaceLeft > spaceRight;
    }

    final double horizontalArrowTop = showHorizontalArrowAtTop
        ? selection.top - 18
        : selection.top + selection.height + 8;

    final double horizontalLabelTop = showHorizontalArrowAtTop
        ? selection.top - 42
        : selection.top + selection.height + 22;

    double verticalArrowLeft = showVerticalArrowAtLeft
        ? selection.left - 18
        : selection.left + selection.width + 8;

    double verticalLabelLeft = showVerticalArrowAtLeft
        ? selection.left - (editingHeight ? 128.0 : 80.0)
        : selection.left + selection.width + 22;

    // Clamp coordinates to prevent clipping off screen/image edges
    final double screenW = viewSize.width;
    verticalArrowLeft = verticalArrowLeft.clamp(
      imageRect.left + 2,
      imageRect.right - 12,
    );
    verticalLabelLeft = verticalLabelLeft.clamp(
      8.0,
      screenW - 128.0,
    );

    double horizontalLabelLeft =
        selection.left + (selection.width - 150) / 2;
    horizontalLabelLeft = horizontalLabelLeft.clamp(
      8.0,
      screenW - 158.0,
    );

    final double horizontalLabelTopClamped = horizontalLabelTop.clamp(8.0, viewSize.height - 48.0);
    final double verticalLabelTopClamped = (selection.top + (selection.height - 40) / 2).clamp(8.0, viewSize.height - 48.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Horizontal double arrow line
        Positioned(
          left: selection.left,
          top: horizontalArrowTop,
          width: selection.width,
          height: 10,
          child: CustomPaint(
            painter: _LocalDashedLinePainter(axis: Axis.horizontal),
          ),
        ),
        // Vertical double arrow line
        Positioned(
          left: verticalArrowLeft,
          top: selection.top,
          width: 10,
          height: selection.height,
          child: CustomPaint(
            painter: _LocalDashedLinePainter(axis: Axis.vertical),
          ),
        ),
        // Horizontal dimension label / inline editor
        Positioned(
          left: horizontalLabelLeft,
          top: horizontalLabelTopClamped,
          width: 150,
          child: Center(
            child: editingWidth
                ? _buildInlineEditor(
                    controller: widthEditController,
                    onSave: onWidthSave,
                  )
                : _buildDisplayLabel(
                    value: customWidthInches,
                    onTap: onWidthTap,
                  ),
          ),
        ),
        // Vertical dimension label / inline editor
        Positioned(
          left: verticalLabelLeft,
          top: verticalLabelTopClamped,
          child: Center(
            child: editingHeight
                ? _buildInlineEditor(
                    controller: heightEditController,
                    onSave: onHeightSave,
                  )
                : _buildDisplayLabel(
                    value: customHeightInches,
                    onTap: onHeightTap,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisplayLabel({
    required double value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${value.round()} in",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.7),
                    offset: const Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit,
              color: Colors.white,
              size: 11,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.7),
                  offset: const Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineEditor({
    required TextEditingController controller,
    required VoidCallback onSave,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300, width: 0.8),
            ),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.zero,
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            "in",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSave,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalDashedLinePainter extends CustomPainter {
  final Axis axis;
  _LocalDashedLinePainter({required this.axis});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final double dashWidth = 4.0;
    final double dashSpace = 4.0;

    final path = Path();
    if (axis == Axis.horizontal) {
      path.moveTo(6, size.height / 2 - 4);
      path.lineTo(0, size.height / 2);
      path.lineTo(6, size.height / 2 + 4);

      path.moveTo(size.width - 6, size.height / 2 - 4);
      path.lineTo(size.width, size.height / 2);
      path.lineTo(size.width - 6, size.height / 2 + 4);

      for (double i = 6; i < size.width - 6; i += dashWidth + dashSpace) {
        path.moveTo(i, size.height / 2);
        path.lineTo(
          i + dashWidth > size.width - 6 ? size.width - 6 : i + dashWidth,
          size.height / 2,
        );
      }
    } else {
      path.moveTo(size.width / 2 - 4, 6);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width / 2 + 4, 6);

      path.moveTo(size.width / 2 - 4, size.height - 6);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width / 2 + 4, size.height - 6);

      for (double i = 6; i < size.height - 6; i += dashWidth + dashSpace) {
        path.moveTo(size.width / 2, i);
        path.lineTo(
          size.width / 2,
          i + dashWidth > size.height - 6 ? size.height - 6 : i + dashWidth,
        );
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
