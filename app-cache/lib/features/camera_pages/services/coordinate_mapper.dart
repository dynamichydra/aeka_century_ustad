import 'dart:ui';
import 'dart:math' as math;

class CoordinateMapper {
  const CoordinateMapper();

  static Size getViewSize(double screenWidth, double screenHeight) {
    return Size(
      screenWidth,
      screenHeight * 0.40,
    );
  }

  static Rect getImageRect({
    required Size viewSize,
    required double? originalImageWidth,
    required double? originalImageHeight,
    required double currentDisplayScale,
  }) {
    final double imgW = originalImageWidth != null
        ? originalImageWidth * currentDisplayScale
        : viewSize.width;
    final double imgH = originalImageHeight != null
        ? originalImageHeight * currentDisplayScale
        : viewSize.height;
    final double imgL = (viewSize.width - imgW) / 2.0;
    final double imgT = (viewSize.height - imgH) / 2.0;
    return Rect.fromLTWH(imgL, imgT, imgW, imgH);
  }

  static Offset mapLocalToOriginal({
    required Offset localPos,
    required Size viewSize,
    required double? originalImageWidth,
    required double? originalImageHeight,
    required double currentDisplayScale,
  }) {
    if (originalImageWidth == null || originalImageHeight == null) {
      return localPos;
    }

    final double imageWidth = originalImageWidth;
    final double imageHeight = originalImageHeight;
    final double viewWidth = viewSize.width;
    final double viewHeight = viewSize.height;

    final double scale = currentDisplayScale;

    final double scaledWidth = imageWidth * scale;
    final double scaledHeight = imageHeight * scale;

    final double offsetX = (viewWidth - scaledWidth) / 2;
    final double offsetY = (viewHeight - scaledHeight) / 2;

    final double mappedX = (localPos.dx - offsetX) / scale;
    final double mappedY = (localPos.dy - offsetY) / scale;

    return Offset(mappedX.clamp(0, imageWidth), mappedY.clamp(0, imageHeight));
  }
}
