import 'dart:ui';
import 'dart:math' as math;
import 'package:century_ai/features/camera_pages/models/selection_models.dart';

class SelectionController {
  const SelectionController();

  SelectionMode hitTestHandles({
    required SelectionRect? selection,
    required Offset localPosition,
    required Rect imageRect,
    double touchRadius = 36.0,
    double zoomScale = 1.0,
  }) {
    if (selection == null) return SelectionMode.none;

    final double left = selection.left;
    final double top = selection.top;
    final double right = selection.left + selection.width;
    final double bottom = selection.top + selection.height;
    final double width = selection.width;
    final double height = selection.height;

    // Convert dimensions to physical screen pixels
    final double screenWidth = width * zoomScale;
    final double screenHeight = height * zoomScale;

    final Offset topLeft = Offset(left, top);
    final Offset topRight = Offset(right, top);
    final Offset bottomLeft = Offset(left, bottom);
    final Offset bottomRight = Offset(right, bottom);

    final double midX = left + width / 2;
    final double midY = top + height / 2;
    final Offset midLeft = Offset(left, midY);
    final Offset midRight = Offset(right, midY);
    final Offset midTop = Offset(midX, top);
    final Offset midBottom = Offset(midX, bottom);

    // List of handle targets: (position, mode)
    final List<MapEntry<Offset, SelectionMode>> handles = [
      MapEntry(topLeft, SelectionMode.resizeTopLeft),
      MapEntry(topRight, SelectionMode.resizeTopRight),
      MapEntry(bottomLeft, SelectionMode.resizeBottomLeft),
      MapEntry(bottomRight, SelectionMode.resizeBottomRight),
      MapEntry(midLeft, SelectionMode.resizeLeft),
      MapEntry(midRight, SelectionMode.resizeRight),
      MapEntry(midTop, SelectionMode.resizeTop),
      MapEntry(midBottom, SelectionMode.resizeBottom),
    ];

    // Check if inside the selection rect
    final bool isInside = localPosition.dx >= left &&
        localPosition.dx <= right &&
        localPosition.dy >= top &&
        localPosition.dy <= bottom;

    final double imgL = imageRect.left;
    final double imgR = imageRect.right;
    final double imgT = imageRect.top;
    final double imgB = imageRect.bottom;

    if (isInside) {
      // Find the closest handle and its physical screen distance
      double minScreenDist = double.infinity;
      SelectionMode? closestHandleMode;
      Offset? closestHandlePos;

      for (final entry in handles) {
        // Physical screen distance to the handle
        final double screenDist = (localPosition - entry.key).distance * zoomScale;
        if (screenDist < minScreenDist) {
          minScreenDist = screenDist;
          closestHandleMode = entry.value;
          closestHandlePos = entry.key;
        }
      }

      // Check if the closest handle is near any image/screen edge in screen pixels.
      // If a handle is near the edge, the user cannot grab it from the outside.
      bool isHandleNearEdge = false;
      if (closestHandlePos != null) {
        final double screenDistToLeft = (closestHandlePos.dx - imgL).abs() * zoomScale;
        final double screenDistToRight = (closestHandlePos.dx - imgR).abs() * zoomScale;
        final double screenDistToTop = (closestHandlePos.dy - imgT).abs() * zoomScale;
        final double screenDistToBottom = (closestHandlePos.dy - imgB).abs() * zoomScale;
        isHandleNearEdge = screenDistToLeft < 16.0 ||
            screenDistToRight < 16.0 ||
            screenDistToTop < 16.0 ||
            screenDistToBottom < 16.0;
      }

      // Dynamic inner threshold in screen pixels:
      // Be much more generous if the handle is up against the image boundary
      final double screenThreshold = isHandleNearEdge
          ? math.min(30.0, math.min(screenWidth, screenHeight) * 0.45)
          : math.min(16.0, math.min(screenWidth, screenHeight) * 0.35);

      // If the touch is within the screen threshold of the closest handle, resize
      if (closestHandleMode != null && minScreenDist <= screenThreshold) {
        return closestHandleMode;
      }

      // Otherwise, dragging from the middle (moving)
      return SelectionMode.moving;
    }

    // Outside the selection — check handles with full screen touch radius (36.0 dp)
    double minScreenDist = double.infinity;
    SelectionMode? closestHandleMode;

    for (final entry in handles) {
      final double screenDist = (localPosition - entry.key).distance * zoomScale;
      if (screenDist < minScreenDist) {
        minScreenDist = screenDist;
        closestHandleMode = entry.value;
      }
    }

    if (closestHandleMode != null && minScreenDist <= 36.0) {
      return closestHandleMode;
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

    // Outside the selection — check edges for resize (from outside) in screen pixels
    final List<MapEntry<double, SelectionMode>> outsideEdges = [
      MapEntry(distToVert(localPosition, left, top, bottom) * zoomScale, SelectionMode.resizeLeft),
      MapEntry(distToVert(localPosition, right, top, bottom) * zoomScale, SelectionMode.resizeRight),
      MapEntry(distToHoriz(localPosition, top, left, right) * zoomScale, SelectionMode.resizeTop),
      MapEntry(distToHoriz(localPosition, bottom, left, right) * zoomScale, SelectionMode.resizeBottom),
    ];

    double minOutsideEdgeDist = double.infinity;
    SelectionMode? closestOutsideEdgeMode;
    for (final entry in outsideEdges) {
      if (entry.key < minOutsideEdgeDist) {
        minOutsideEdgeDist = entry.key;
        closestOutsideEdgeMode = entry.value;
      }
    }

    if (closestOutsideEdgeMode != null && minOutsideEdgeDist <= 36.0) {
      return closestOutsideEdgeMode;
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
