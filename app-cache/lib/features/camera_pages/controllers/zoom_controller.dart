import 'package:flutter/material.dart';

class ZoomController {
  const ZoomController();

  static Matrix4 calculateZoomIn({
    required Matrix4 currentMatrix,
    required double minZoomLimit,
    required double maxScale,
    required double viewportWidth,
    required double viewportHeight,
    required double? originalImageWidth,
    required double? originalImageHeight,
    required double displayScale,
  }) {
    final double currentScale = currentMatrix.getMaxScaleOnAxis();
    final double newScale = (currentScale + 0.5).clamp(minZoomLimit, maxScale);

    final double imgDisplayW = originalImageWidth != null ? originalImageWidth * displayScale : viewportWidth;
    final double imgDisplayH = originalImageHeight != null ? originalImageHeight * displayScale : viewportHeight;
    final double imgLeft = (viewportWidth - imgDisplayW) / 2.0;
    final double imgTop = (viewportHeight - imgDisplayH) / 2.0;

    final double currentTx = currentMatrix.storage[12];
    final double currentTy = currentMatrix.storage[13];
    final double ratio = newScale / currentScale;
    double newTx = (viewportWidth / 2.0) - (viewportWidth / 2.0 - currentTx) * ratio;
    double newTy = (viewportHeight / 2.0) - (viewportHeight / 2.0 - currentTy) * ratio;

    final double minTx = viewportWidth - newScale * (imgLeft + imgDisplayW);
    final double maxTx = -newScale * imgLeft;
    final double minBoundX = minTx.compareTo(maxTx) > 0 ? maxTx : minTx;
    final double maxBoundX = minTx.compareTo(maxTx) > 0 ? minTx : maxTx;
    newTx = newTx.clamp(minBoundX, maxBoundX);

    final double minTy = viewportHeight - newScale * (imgTop + imgDisplayH);
    final double maxTy = -newScale * imgTop;
    final double minBoundY = minTy.compareTo(maxTy) > 0 ? maxTy : minTy;
    final double maxBoundY = minTy.compareTo(maxTy) > 0 ? minTy : maxTy;
    newTy = newTy.clamp(minBoundY, maxBoundY);

    return Matrix4.identity()
      ..translate(newTx, newTy)
      ..scale(newScale);
  }

  static Matrix4 calculateZoomOut({
    required Matrix4 currentMatrix,
    required double minZoomLimit,
    required double maxScale,
    required double viewportWidth,
    required double viewportHeight,
    required double? originalImageWidth,
    required double? originalImageHeight,
    required double displayScale,
  }) {
    final double currentScale = currentMatrix.getMaxScaleOnAxis();
    final double newScale = (currentScale - 0.5).clamp(minZoomLimit, maxScale);

    final double imgDisplayW = originalImageWidth != null ? originalImageWidth * displayScale : viewportWidth;
    final double imgDisplayH = originalImageHeight != null ? originalImageHeight * displayScale : viewportHeight;
    final double imgLeft = (viewportWidth - imgDisplayW) / 2.0;
    final double imgTop = (viewportHeight - imgDisplayH) / 2.0;

    final double currentTx = currentMatrix.storage[12];
    final double currentTy = currentMatrix.storage[13];
    final double ratio = newScale / currentScale;
    double newTx = (viewportWidth / 2.0) - (viewportWidth / 2.0 - currentTx) * ratio;
    double newTy = (viewportHeight / 2.0) - (viewportHeight / 2.0 - currentTy) * ratio;

    final double minTx = viewportWidth - newScale * (imgLeft + imgDisplayW);
    final double maxTx = -newScale * imgLeft;
    final double minBoundX = minTx.compareTo(maxTx) > 0 ? maxTx : minTx;
    final double maxBoundX = minTx.compareTo(maxTx) > 0 ? minTx : maxTx;
    newTx = newTx.clamp(minBoundX, maxBoundX);

    final double minTy = viewportHeight - newScale * (imgTop + imgDisplayH);
    final double maxTy = -newScale * imgTop;
    final double minBoundY = minTy.compareTo(maxTy) > 0 ? maxTy : minTy;
    final double maxBoundY = minTy.compareTo(maxTy) > 0 ? minTy : maxTy;
    newTy = newTy.clamp(minBoundY, maxBoundY);

    return Matrix4.identity()
      ..translate(newTx, newTy)
      ..scale(newScale);
  }

  static Matrix4 calculatePinchPan({
    required Matrix4 currentMatrix,
    required Map<int, Offset> activePointers,
    required Offset eventPosition,
    required Offset oldPos,
    required Size viewSize,
    required double? originalImageWidth,
    required double? originalImageHeight,
    required double displayScale,
    required double initialPointerDistance,
    required double initialScale,
    required double minZoomLimit,
    required double maxScale,
  }) {
    final Matrix4 matrix = currentMatrix.clone();
    final double oldScale = matrix.getMaxScaleOnAxis();

    double targetScale = oldScale;
    double scaleRatio = 1.0;

    if (activePointers.length >= 2) {
      final keys = activePointers.keys.toList();
      final p1 = activePointers[keys[0]]!;
      final p2 = activePointers[keys[1]]!;
      final double currentDistance = (p1 - p2).distance;

      if (initialPointerDistance > 1.0) {
        final double scaleFactor = currentDistance / initialPointerDistance;
        targetScale = (initialScale * scaleFactor).clamp(minZoomLimit, maxScale);
        scaleRatio = targetScale / oldScale;
      }
    }

    Offset sumNew = Offset.zero;
    for (final pos in activePointers.values) {
      sumNew += pos;
    }
    final Offset newCentroid = sumNew / activePointers.length.toDouble();

    final Offset sumOld = sumNew - eventPosition + oldPos;
    final Offset oldCentroid = sumOld / activePointers.length.toDouble();

    final double oldTx = matrix.storage[12];
    final double oldTy = matrix.storage[13];

    double newTx = newCentroid.dx - (oldCentroid.dx - oldTx) * scaleRatio;
    double newTy = newCentroid.dy - (oldCentroid.dy - oldTy) * scaleRatio;

    final double imgDisplayW = originalImageWidth != null ? originalImageWidth * displayScale : viewSize.width;
    final double imgDisplayH = originalImageHeight != null ? originalImageHeight * displayScale : viewSize.height;
    final double imgLeft = (viewSize.width - imgDisplayW) / 2.0;
    final double imgTop = (viewSize.height - imgDisplayH) / 2.0;

    final double minTx = viewSize.width - targetScale * (imgLeft + imgDisplayW);
    final double maxTx = -targetScale * imgLeft;
    final double minTy = viewSize.height - targetScale * (imgTop + imgDisplayH);
    final double maxTy = -targetScale * imgTop;

    final double minBoundX = minTx.compareTo(maxTx) > 0 ? maxTx : minTx;
    final double maxBoundX = minTx.compareTo(maxTx) > 0 ? minTx : maxTx;
    newTx = newTx.clamp(minBoundX, maxBoundX);

    final double minBoundY = minTy.compareTo(maxTy) > 0 ? maxTy : minTy;
    final double maxBoundY = minTy.compareTo(maxTy) > 0 ? minTy : maxTy;
    newTy = newTy.clamp(minBoundY, maxBoundY);

    return Matrix4.identity()
      ..translate(newTx, newTy)
      ..scale(targetScale);
  }
}
