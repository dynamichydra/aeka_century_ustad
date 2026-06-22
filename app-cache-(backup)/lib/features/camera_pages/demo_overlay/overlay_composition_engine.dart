import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_layer_model.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_session_model.dart';

/// The SINGLE rendering authority for the overlay compositing engine.
///
/// ARCHITECTURE RULE:
///   Both [OverlayRendererWidget] (viewport preview) and [OverlayExportService]
///   (native-resolution export) MUST delegate ALL drawing calls to this class.
///   This guarantees pixel-perfect parity: preview == exported image.
///
/// STATELESS DESIGN:
///   All methods are static. No GPU objects, no state, no lifecycle.
///   All required inputs are parameters.
///
/// COORDINATE SYSTEMS:
///   - [imageRect]: The rect occupied by the base image in canvas space.
///     * For viewport: the BoxFit.contain rect (may be letterboxed).
///     * For export: Rect(0, 0, canvasW, canvasH) — no letterboxing.
///   - [LayerTransformData]: coordinates in image pixel space, pivoting
///     around the center of [imageRect].
///   - [OverlayLayer.overlayBounds]: normalized [0, 1] × [0, 1] bounds
///     relative to the image rect. null = full image rect.
class OverlayCompositionEngine {
  // Private constructor — pure static utility class.
  const OverlayCompositionEngine._();

  /// Composites all visible [layers] onto [canvas] within [imageRect].
  ///
  /// Parameters:
  /// - [canvas]: The target canvas (from CustomPainter or PictureRecorder).
  /// - [canvasSize]: The total size of the canvas (for contain-rect computation).
  /// - [baseImageSize]: Optional original image dimensions. When provided,
  ///   [imageRect] is computed via BoxFit.contain. When null, [imageRect]
  ///   defaults to full [canvasSize] (no letterboxing — used for export).
  /// - [layers]: Ordered overlay stack from Cubit state.
  /// - [imageCache]: Pre-decoded [ui.Image] objects, keyed by layer ID.
  ///   Layers with missing cache entries are silently skipped (still loading).
  static void compositeLayersOntoCanvas({
    required Canvas canvas,
    required Size canvasSize,
    Size? baseImageSize,
    required List<OverlayLayer> layers,
    required Map<String, ui.Image> imageCache,
  }) {
    // Compute the image rect: where the base image lives in canvas space.
    final Rect imageRect = baseImageSize != null
        ? _computeContainRect(canvasSize, baseImageSize)
        : Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);

    // Sort by zIndex: lowest drawn first, highest on top.
    final List<OverlayLayer> sorted = List<OverlayLayer>.from(layers)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    for (final layer in sorted) {
      if (!layer.visible) continue;

      final ui.Image? img = imageCache[layer.id];
      if (img == null) continue; // Still decoding — skip this frame.

      _compositeLayer(canvas, imageRect, layer, img);
    }
  }

  // ─── Private Helpers ───────────────────────────────────────────────────────

  /// Draws a single [layer] onto [canvas] within [imageRect].
  static void _compositeLayer(
    Canvas canvas,
    Rect imageRect,
    OverlayLayer layer,
    ui.Image img,
  ) {
    // Compute destination rect:
    // If overlayBounds is set (normalized coords), scale to imageRect.
    // null → full imageRect.
    final Rect dstRect = layer.overlayBounds != null
        ? _scaleNormalizedBounds(layer.overlayBounds!, imageRect)
        : imageRect;

    final Rect srcRect = Rect.fromLTWH(
      0, 0, img.width.toDouble(), img.height.toDouble(),
    );

    final Paint paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, layer.opacity.clamp(0.0, 1.0))
      ..blendMode = layer.blendMode;

    final LayerTransformData? t = layer.transform;

    if (t == null || t.isIdentity) {
      // ── Fast path: identity transform, no canvas save/restore overhead. ──
      canvas.drawImageRect(img, srcRect, dstRect, paint);
    } else {
      // ── Transformed path: pivot around the center of dstRect. ──
      final double cx = dstRect.center.dx;
      final double cy = dstRect.center.dy;

      canvas.save();
      // 1. Move pivot to center of destination rect, apply user translation.
      canvas.translate(cx + t.translateX, cy + t.translateY);
      // 2. Rotate around pivot.
      canvas.rotate(t.rotation);
      // 3. Scale around pivot.
      canvas.scale(t.scale, t.scale);
      // 4. Draw centered at the pivoted origin.
      final Rect centeredDst = Rect.fromLTWH(
        -dstRect.width / 2,
        -dstRect.height / 2,
        dstRect.width,
        dstRect.height,
      );
      canvas.drawImageRect(img, srcRect, centeredDst, paint);
      canvas.restore();
    }
  }

  /// Computes the BoxFit.contain rect for [imageSize] inside [canvasSize].
  ///
  /// The image is centered, maintaining aspect ratio, never cropped.
  static Rect _computeContainRect(Size canvasSize, Size imageSize) {
    if (imageSize.width <= 0 || imageSize.height <= 0) {
      return Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);
    }
    final double scaleW = canvasSize.width / imageSize.width;
    final double scaleH = canvasSize.height / imageSize.height;
    final double scale = math.min(scaleW, scaleH);
    final double w = imageSize.width * scale;
    final double h = imageSize.height * scale;
    final double x = (canvasSize.width - w) / 2;
    final double y = (canvasSize.height - h) / 2;
    return Rect.fromLTWH(x, y, w, h);
  }

  /// Converts normalized [bounds] (values in [0, 1]) to canvas-space rect
  /// relative to [imageRect].
  ///
  /// Example: bounds = Rect(0.1, 0.2, 0.8, 0.6) on a 400×300 imageRect
  ///   → canvas rect = (40, 60, 320, 180).
  static Rect _scaleNormalizedBounds(Rect bounds, Rect imageRect) {
    return Rect.fromLTWH(
      imageRect.left + bounds.left * imageRect.width,
      imageRect.top + bounds.top * imageRect.height,
      bounds.width * imageRect.width,
      bounds.height * imageRect.height,
    );
  }
}
