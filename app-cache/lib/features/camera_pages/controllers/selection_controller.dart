import 'dart:ui';
import 'dart:math' as math;
import 'package:century_ai/features/camera_pages/models/selection_models.dart';

class SelectionController {
  const SelectionController();

  SelectionMode hitTestHandles({
    required SelectionRect? selection,
    required Offset localPosition,
    double touchRadius = 36.0,
    double zoomScale = 1.0,
  }) {
    if (selection == null) return SelectionMode.none;

    // Scale touch radius inversely with zoom so handles stay easy to grab
    // at any zoom level. Minimum effective radius of 20px.
    final double effectiveRadius = math.max(20.0, touchRadius / zoomScale);

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
    if ((localPosition - topLeft).distance <= effectiveRadius) {
      return SelectionMode.resizeTopLeft;
    }
    if ((localPosition - topRight).distance <= effectiveRadius) {
      return SelectionMode.resizeTopRight;
    }
    if ((localPosition - bottomLeft).distance <= effectiveRadius) {
      return SelectionMode.resizeBottomLeft;
    }
    if ((localPosition - bottomRight).distance <= effectiveRadius) {
      return SelectionMode.resizeBottomRight;
    }

    // 2. Check middle handles (high priority)
    final double midX = left + width / 2;
    final double midY = top + height / 2;
    final Offset midLeft = Offset(left, midY);
    final Offset midRight = Offset(right, midY);
    final Offset midTop = Offset(midX, top);
    final Offset midBottom = Offset(midX, bottom);

    if ((localPosition - midLeft).distance <= effectiveRadius) {
      return SelectionMode.resizeLeft;
    }
    if ((localPosition - midRight).distance <= effectiveRadius) {
      return SelectionMode.resizeRight;
    }
    if ((localPosition - midTop).distance <= effectiveRadius) {
      return SelectionMode.resizeTop;
    }
    if ((localPosition - midBottom).distance <= effectiveRadius) {
      return SelectionMode.resizeBottom;
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

    // 3. Check if inside the selection rect first — prioritize moving
    // over edge resize for interior taps to prevent accidental resize
    final bool isInside = localPosition.dx >= left &&
        localPosition.dx <= right &&
        localPosition.dy >= top &&
        localPosition.dy <= bottom;

    if (isInside) {
      // Distance from each edge
      final double dLeft = (localPosition.dx - left).abs();
      final double dRight = (right - localPosition.dx).abs();
      final double dTop = (localPosition.dy - top).abs();
      final double dBottom = (bottom - localPosition.dy).abs();
      final double minEdgeDist = math.min(
        math.min(dLeft, dRight),
        math.min(dTop, dBottom),
      );

      // If the touch is well inside (far from all edges), always move
      // Use a tighter threshold (40% of effectiveRadius) for edge resize
      // inside the selection to avoid accidental resize while dragging
      final double edgeResizeThreshold = effectiveRadius * 0.4;

      if (minEdgeDist > edgeResizeThreshold) {
        return SelectionMode.moving;
      }

      // Close to an edge but still inside — check which edge
      if (dLeft <= edgeResizeThreshold) {
        return SelectionMode.resizeLeft;
      }
      if (dRight <= edgeResizeThreshold) {
        return SelectionMode.resizeRight;
      }
      if (dTop <= edgeResizeThreshold) {
        return SelectionMode.resizeTop;
      }
      if (dBottom <= edgeResizeThreshold) {
        return SelectionMode.resizeBottom;
      }

      // Fallback: still inside, move
      return SelectionMode.moving;
    }

    // 2. Outside the selection — check edges for resize (from outside)
    if (distToVert(localPosition, left, top, bottom) <= effectiveRadius) {
      return SelectionMode.resizeLeft;
    }
    if (distToVert(localPosition, right, top, bottom) <= effectiveRadius) {
      return SelectionMode.resizeRight;
    }
    if (distToHoriz(localPosition, top, left, right) <= effectiveRadius) {
      return SelectionMode.resizeTop;
    }
    if (distToHoriz(localPosition, bottom, left, right) <= effectiveRadius) {
      return SelectionMode.resizeBottom;
    }

    return SelectionMode.none;
  }

  bool isPointInHorizontalOverlay({
    required SelectionRect? selection,
    required Offset localPos,
    required Rect imageRect,
    Size? viewSize,
  }) {
    if (selection == null) return false;

    // Use viewport for clamping if available, otherwise fall back to imageRect
    final double clampRight = viewSize != null ? viewSize.width : imageRect.right;
    final double clampBottom = viewSize != null ? viewSize.height : imageRect.bottom;

    final double spaceBelow =
        clampBottom - (selection.top + selection.height);
    final double spaceAbove = selection.top;
    final bool showHorizontalArrowAtTop =
        spaceBelow < 50.0 && spaceAbove > spaceBelow;

    final double top = showHorizontalArrowAtTop
        ? selection.top - 42
        : selection.top + selection.height + 22;

    double left = selection.left + (selection.width - 150) / 2;
    left = left.clamp(0.0, clampRight - 154);

    // Expanded hit zone with 12px padding on all sides
    final double hitLeft = left - 12;
    final double hitRight = left + 150 + 12;
    final double hitTop = top - 12;
    final double hitBottom = top + 40 + 12;
    return localPos.dx >= hitLeft &&
        localPos.dx <= hitRight &&
        localPos.dy >= hitTop &&
        localPos.dy <= hitBottom;
  }

  bool isPointInVerticalOverlay({
    required SelectionRect? selection,
    required Offset localPos,
    required Rect imageRect,
    Size? viewSize,
  }) {
    if (selection == null) return false;

    // Use viewport for clamping if available, otherwise fall back to imageRect
    final double clampRight = viewSize != null ? viewSize.width : imageRect.right;

    final double spaceRight =
        clampRight - (selection.left + selection.width);
    final double spaceLeft = selection.left;
    final bool showVerticalArrowAtLeft =
        spaceRight < 120.0 && spaceLeft > spaceRight;

    final double top = selection.top + (selection.height - 40) / 2;

    double left = showVerticalArrowAtLeft
        ? selection.left - 70
        : selection.left + selection.width + 22;

    left = left.clamp(0.0, clampRight - 75);

    // Expanded hit zone with 12px padding on all sides
    final double hitLeft = left - 12;
    final double hitRight = left + 120 + 12;
    final double hitTop = top - 12;
    final double hitBottom = top + 40 + 12;
    return localPos.dx >= hitLeft &&
        localPos.dx <= hitRight &&
        localPos.dy >= hitTop &&
        localPos.dy <= hitBottom;
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
