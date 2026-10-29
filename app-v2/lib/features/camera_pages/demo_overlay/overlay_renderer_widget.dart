import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_layer_model.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_image_cache_service.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_composition_engine.dart';

/// Widget shell for the non-destructive overlay editor canvas.
///
/// RENDERING STRATEGY (priority order):
///   1. If the topmost visible layer has [OverlayLayer.compositedResultBytes],
///      display it as a full-canvas Image.memory() — this is the result of
///      the Python/OpenCV-equivalent [ImageCompositeService] pipeline.
///      No GPU CustomPainter pass is needed for this path.
///
///   2. Fallback: GPU canvas path via [OverlayCompositionEngine] / CustomPainter.
///      Used when compositedResultBytes is null (bytes not yet computed or
///      a restored session layer with empty bytes).
///
/// RESPONSIBILITIES (this widget):
///   - Render the immutable base room image (BoxFit.contain).
///   - Trigger image decode/cache via [OverlayImageCacheService.instance].
///   - Pass decoded image snapshot to [_OverlayCanvasPainter].
///   - No GPU object ownership — cache service manages lifecycle.
///
/// RESPONSIBILITIES (delegated):
///   - Image decode + cache: [OverlayImageCacheService]
///   - Compositing draw logic: [OverlayCompositionEngine]
///   - Layer model: [OverlayLayer] (pure data, no ui.Image)
///
/// CACHE NOTE:
///   This widget calls [OverlayImageCacheService.getDecodedImage] but does NOT
///   own or dispose any [ui.Image] objects. The cache singleton manages
///   all GPU texture lifetimes, LRU eviction, and disposal.
class OverlayRendererWidget extends StatefulWidget {
  /// The immutable base room image path. Never changes after widget construction.
  final String baseImagePath;

  /// Current ordered overlay layer list from Cubit state.
  final List<OverlayLayer> layers;

  /// Height of the viewport container in logical pixels.
  final double containerHeight;

  /// Optional original image dimensions for accurate BoxFit.contain alignment.
  ///
  /// When provided, [OverlayCompositionEngine] computes the correct contain-rect
  /// so overlays are precisely letterboxed to match the base image position.
  /// When null, overlays fill the full canvas (legacy behavior, visually fine
  /// for images that fill the viewport without significant letterboxing).
  final Size? baseImageSize;

  const OverlayRendererWidget({
    super.key,
    required this.baseImagePath,
    required this.layers,
    required this.containerHeight,
    this.baseImageSize,
  });

  @override
  State<OverlayRendererWidget> createState() => _OverlayRendererWidgetState();
}

class _OverlayRendererWidgetState extends State<OverlayRendererWidget> {
  final OverlayImageCacheService _cache = OverlayImageCacheService.instance;

  /// Local snapshot of decoded images for the current frame.
  /// References into the shared cache — we do NOT own these [ui.Image] objects.
  Map<String, ui.Image> _decodedImages = {};

  /// Whether at least one sync has completed (prevents flickering on first load)
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _syncImages(widget.layers);
  }

  @override
  void didUpdateWidget(OverlayRendererWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layers != widget.layers) {
      _syncImages(widget.layers);
    }
  }

  @override
  void dispose() {
    // Do NOT dispose images — they belong to the shared OverlayImageCacheService.
    // Cache eviction is managed by OverlayRepository.syncCache().
    super.dispose();
  }

  /// Builds a decoded-image snapshot for all visible layers via the shared cache.
  ///
  /// Only pre-decodes visible layers that need the GPU canvas path
  /// (i.e., no pre-computed compositedResultBytes).
  Future<void> _syncImages(List<OverlayLayer> layers) async {
    final Map<String, ui.Image> snapshot = {};

    for (final layer in layers) {
      if (!layer.visible) continue;
      // Skip GPU decode for layers that already have a composited result —
      // those are rendered directly via Image.memory().
      if (layer.hasCompositeResult) continue;
      if (!layer.hasBytesLoaded) continue; // Skip shell layers (needs re-fetch)

      try {
        final ui.Image img = await _cache.getDecodedImage(
          layer.id,
          layer.warpedOverlayBytes,
        );
        snapshot[layer.id] = img;
      } catch (e) {
        debugPrint(
          '⚠️  OverlayRenderer: decode failed for layer "${layer.id}" — $e',
        );
      }
    }

    if (mounted) {
      setState(() {
        _decodedImages = snapshot;
        _isReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Determine rendering path ──────────────────────────────────────────────
    // Find the topmost visible layer that has a pre-computed composite.
    // We display the LAST (topmost by zIndex) composite result, as it
    // already incorporates all previous layers via sequential compositing.
    final OverlayLayer? topCompositeLayer = widget.layers
        .where((l) => l.visible && l.hasCompositeResult)
        .fold<OverlayLayer?>(
          null,
          (prev, l) => (prev == null || l.zIndex >= prev.zIndex) ? l : prev,
        );

    final bool hasGpuLayers =
        _isReady && widget.layers.any((l) => l.visible && l.hasBytesLoaded && !l.hasCompositeResult);

    return SizedBox(
      width: double.infinity,
      height: widget.containerHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── PATH 1: OpenCV-style composite (Image.memory) ──────────────────
          // When the top layer has a pre-computed composite, display it
          // as a full replacement for the base image — same pattern as
          // the reference main.dart implementation.
          if (topCompositeLayer != null)
            Image.memory(
              topCompositeLayer.compositedResultBytes!,
              width: double.infinity,
              height: widget.containerHeight,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true, // prevents flash between updates
            )
          else ...[
            // ── PATH 2: GPU canvas fallback ──────────────────────────────────
            // No composited result available yet — show base image + GPU overlay.

            // 2a. Immutable base room image — always rendered, never replaced.
            _buildBaseImage(),

            // 2b. GPU overlay compositor — rendered once images are decoded.
            if (hasGpuLayers)
              Positioned.fill(
                child: CustomPaint(
                  painter: _OverlayCanvasPainter(
                    layers: widget.layers,
                    decodedImages: _decodedImages,
                    baseImageSize: widget.baseImageSize,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildBaseImage() {
    final String path = widget.baseImagePath;
    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: double.infinity,
        height: widget.containerHeight,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        cacheWidth: 800,
      );
    }
    return Image.file(
      File(path),
      width: double.infinity,
      height: widget.containerHeight,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      cacheWidth: 800,
    );
  }
}

/// CustomPainter shell — delegates ALL draw logic to [OverlayCompositionEngine].
///
/// No drawing logic lives here. This class exists only to bridge the
/// Flutter CustomPainter API with the composition engine.
/// Only used when a layer lacks [OverlayLayer.compositedResultBytes].
class _OverlayCanvasPainter extends CustomPainter {
  final List<OverlayLayer> layers;
  final Map<String, ui.Image> decodedImages;
  final Size? baseImageSize;

  const _OverlayCanvasPainter({
    required this.layers,
    required this.decodedImages,
    this.baseImageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    OverlayCompositionEngine.compositeLayersOntoCanvas(
      canvas: canvas,
      canvasSize: size,
      baseImageSize: baseImageSize,
      layers: layers,
      imageCache: decodedImages,
    );
  }

  @override
  bool shouldRepaint(_OverlayCanvasPainter oldDelegate) {
    return oldDelegate.layers != layers ||
        oldDelegate.decodedImages != decodedImages ||
        oldDelegate.baseImageSize != baseImageSize;
  }
}
