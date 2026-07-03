import 'dart:ui';
import 'dart:math' as math;
import 'package:century_ai/features/camera_pages/models/selection_models.dart';

class SelectionController {
  const SelectionController();

  SelectionMode hitTestHandles({
    required SelectionRect? selection,
    required Offset localPosition,
    double touchRadius = 30.0,
  }) {
    if (selection == null) return SelectionMode.none;

    final double left = selection.left;
    final double top = selection.top;
    final double right = selection.left + selection.width;
    final double bottom = selection.top + selection.height;
    final double width = selection.width;
    final double height = selection.height;

    final Offset topLeft = Offset(left, top);
    final Offset topRight = Offset(right, top);
    final Offset bottomLeft = Offset(left, bottom);
    final Offset bottomRight = Offset(right, bottom);

    // 1. Check corners first (high priority)
    if ((localPosition - topLeft).distance <= touchRadius) {
      return SelectionMode.resizeTopLeft;
    }
    if ((localPosition - topRight).distance <= touchRadius) {
      return SelectionMode.resizeTopRight;
    }
    if ((localPosition - bottomLeft).distance <= touchRadius) {
      return SelectionMode.resizeBottomLeft;
    }
    if ((localPosition - bottomRight).distance <= touchRadius) {
      return SelectionMode.resizeBottomRight;
    }

    // Helper to calculate distance from point to vertical segment
    double distToVert(Offset p, double targetX, double startY, double endY) {
      final double clampedY = p.dy.clamp(startY, endY);
      return (p - Offset(targetX, clampedY)).distance;
    }

    // Helper to calculate distance from point to horizontal segment
    double distToHoriz(Offset p, double targetY, double startX, double endX) {
      final double clampedX = p.dx.clamp(startX, endX);
      return (p - Offset(clampedX, targetY)).distance;
    }

    // 2. Check edges (next priority)
    if (distToVert(localPosition, left, top, bottom) <= touchRadius) {
      return SelectionMode.resizeLeft;
    }
    if (distToVert(localPosition, right, top, bottom) <= touchRadius) {
      return SelectionMode.resizeRight;
    }
    if (distToHoriz(localPosition, top, left, right) <= touchRadius) {
      return SelectionMode.resizeTop;
    }
    if (distToHoriz(localPosition, bottom, left, right) <= touchRadius) {
      return SelectionMode.resizeBottom;
    }

    // 3. Check middle area for moving/dragging
    final bool isInside = localPosition.dx >= left &&
        localPosition.dx <= right &&
        localPosition.dy >= top &&
        localPosition.dy <= bottom;

    if (isInside) {
      final double centerX = left + width / 2;
      final double centerY = top + height / 2;

      final bool isNearCenter = (localPosition.dx - centerX).abs() <= 16.0 &&
                                (localPosition.dy - centerY).abs() <= 16.0;

      final bool isFarFromEdges = (localPosition.dx - left) > touchRadius &&
                                  (right - localPosition.dx) > touchRadius &&
                                  (localPosition.dy - top) > touchRadius &&
                                  (bottom - localPosition.dy) > touchRadius;

      if (isFarFromEdges || isNearCenter) {
        return SelectionMode.moving;
      }
    }

    return SelectionMode.none;
  }

  bool isPointInHorizontalOverlay({
    required SelectionRect? selection,
    required Offset localPos,
    required Rect imageRect,
  }) {
    if (selection == null) return false;
    final double spaceBelow =
        imageRect.bottom - (selection.top + selection.height);
    final double spaceAbove = selection.top - imageRect.top;
    final bool showHorizontalArrowAtTop =
        spaceBelow < 50.0 && spaceAbove > spaceBelow;

    final double top = showHorizontalArrowAtTop
        ? selection.top - 42
        : selection.top + selection.height + 22;

    double left = selection.left + (selection.width - 150) / 2;
    left = left.clamp(imageRect.left + 4, imageRect.right - 154);

    final double right = left + 150;
    final double bottom = top + 40;
    return localPos.dx >= left &&
        localPos.dx <= right &&
        localPos.dy >= top &&
        localPos.dy <= bottom;
  }

  bool isPointInVerticalOverlay({
    required SelectionRect? selection,
    required Offset localPos,
    required Rect imageRect,
  }) {
    if (selection == null) return false;
    final double spaceRight =
        imageRect.right - (selection.left + selection.width);
    final double spaceLeft = selection.left - imageRect.left;
    final bool showVerticalArrowAtLeft =
        spaceRight < 120.0 && spaceLeft > spaceRight;

    final double top = selection.top + (selection.height - 40) / 2;

    double left = showVerticalArrowAtLeft
        ? selection.left - 70
        : selection.left + selection.width + 22;

    left = left.clamp(imageRect.left + 2, imageRect.right - 75);

    final double right = left + 120;
    final double bottom = top + 40;
    return localPos.dx >= left &&
        localPos.dx <= right &&
        localPos.dy >= top &&
        localPos.dy <= bottom;
  }

  SelectionRect createSelection({
    required Offset dragStart,
    required Offset currentPos,
    required Rect imageRect,
  }) {
    final double imgL = imageRect.left;
    final double imgR = imageRect.right;
    final double imgT = imageRect.top;
    final double imgB = imageRect.bottom;

    double snap(double val, double minBound, double maxBound) {
      return val.clamp(minBound, maxBound);
    }

    final double currentX = snap(currentPos.dx, imgL, imgR);
    final double currentY = snap(currentPos.dy, imgT, imgB);

    final double left = math.min(dragStart.dx, currentX);
    final double top = math.min(dragStart.dy, currentY);
    final double width = (currentX - dragStart.dx).abs();
    final double height = (currentY - dragStart.dy).abs();

    return SelectionRect(
      left: left,
      top: top,
      width: width,
      height: height,
    );
  }

  SelectionRect moveSelection({
    required SelectionRect selection,
    required Offset delta,
    required Rect imageRect,
  }) {
    final double imgL = imageRect.left;
    final double imgR = imageRect.right;
    final double imgT = imageRect.top;
    final double imgB = imageRect.bottom;

    double newLeft = selection.left + delta.dx;
    double newTop = selection.top + delta.dy;

    newLeft = math.max(
      imgL,
      math.min(imgR - selection.width, newLeft),
    );
    newTop = math.max(
      imgT,
      math.min(imgB - selection.height, newTop),
    );

    return SelectionRect(
      left: newLeft,
      top: newTop,
      width: selection.width,
      height: selection.height,
    );
  }

  SelectionRect resizeSelection({
    required SelectionRect selection,
    required SelectionMode mode,
    required Offset localPos,
    required Rect imageRect,
  }) {
    final double imgL = imageRect.left;
    final double imgR = imageRect.right;
    final double imgT = imageRect.top;
    final double imgB = imageRect.bottom;

    double left = selection.left;
    double top = selection.top;
    double right = selection.left + selection.width;
    double bottom = selection.top + selection.height;

    double snap(double val, double minBound, double maxBound) {
      return val.clamp(minBound, maxBound);
    }

    final double localX = snap(localPos.dx, imgL, imgR);
    final double localY = snap(localPos.dy, imgT, imgB);

    switch (mode) {
      case SelectionMode.resizeTopLeft:
        left = math.max(imgL, math.min(right - 10.0, localX));
        top = math.max(imgT, math.min(bottom - 10.0, localY));
        break;
      case SelectionMode.resizeTopRight:
        right = math.min(imgR, math.max(left + 10.0, localX));
        top = math.max(imgT, math.min(bottom - 10.0, localY));
        break;
      case SelectionMode.resizeBottomLeft:
        left = math.max(imgL, math.min(right - 10.0, localX));
        bottom = math.min(imgB, math.max(top + 10.0, localY));
        break;
      case SelectionMode.resizeBottomRight:
        right = math.min(imgR, math.max(left + 10.0, localX));
        bottom = math.min(imgB, math.max(top + 10.0, localY));
        break;
      case SelectionMode.resizeLeft:
        left = math.max(imgL, math.min(right - 10.0, localX));
        break;
      case SelectionMode.resizeRight:
        right = math.min(imgR, math.max(left + 10.0, localX));
        break;
      case SelectionMode.resizeTop:
        top = math.max(imgT, math.min(bottom - 10.0, localY));
        break;
      case SelectionMode.resizeBottom:
        bottom = math.min(imgB, math.max(top + 10.0, localY));
        break;
      default:
        break;
    }

    return SelectionRect(
      left: left,
      top: top,
      width: right - left,
      height: bottom - top,
    );
  }
}
