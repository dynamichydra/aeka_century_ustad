import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_layer_model.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_image_cache_service.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_composition_engine.dart';

/// Native-resolution pixel compositing export service.
///
/// ARCHITECTURE NOTE:
///   Uses [OverlayCompositionEngine] for all drawing — the SAME engine as
///   [OverlayRendererWidget]. This guarantees preview == exported image.
///
///   Uses [OverlayImageCacheService] for all overlay layer decoding —
///   NO duplicate codec allocations between renderer and exporter.
///
/// This service does NOT depend on:
///   - Current UI viewport size or widget tree
///   - Zoom / pan transformation state
///   - Device pixel ratio or screen density
///   - RepaintBoundary screenshots
///
/// Always exports at the ORIGINAL base image pixel resolution.
class OverlayExportService {
  final OverlayImageCacheService _cache;

  OverlayExportService({OverlayImageCacheService? cacheService})
      : _cache = cacheService ?? OverlayImageCacheService.instance;

  /// Composites [layers] over the base image at native resolution.
  ///
  /// Returns the absolute path of the saved PNG, or null on failure.
  Future<String?> exportComposite({
    required String baseImagePath,
    required List<OverlayLayer> layers,
  }) async {
    try {
      // 1. Load and decode base image bytes (not shared-cached: one-time, full-res).
      final Uint8List baseBytes = await _loadFileBytes(baseImagePath);
      final ui.Image baseUiImage = await _decodePng(baseBytes);
      final int canvasWidth = baseUiImage.width;
      final int canvasHeight = baseUiImage.height;

      debugPrint(
        '🖼️  OverlayExportService: base decoded at $canvasWidth×${canvasHeight}px '
        '| ${layers.length} layer(s)',
      );

      // 2. Pre-decode all visible layer images via shared cache.
      //    Layers already decoded by the renderer are served from cache
      //    instantly — zero duplicate codec allocations.
      final Map<String, ui.Image> imageSnapshot = {};
      for (final layer in layers) {
        if (!layer.visible || !layer.hasBytesLoaded) continue;
        try {
          final ui.Image img = await _cache.getDecodedImage(
            layer.id,
            layer.warpedOverlayBytes,
          );
          imageSnapshot[layer.id] = img;
        } catch (e) {
          debugPrint(
            '⚠️  OverlayExportService: decode failed for layer '
            '"${layer.id}" — $e (layer skipped)',
          );
        }
      }

      // 3. Set up PictureRecorder at native resolution.
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()),
      );

      // 4. Draw base image.
      canvas.drawImage(baseUiImage, Offset.zero, Paint());
      baseUiImage.dispose(); // Base image is not cached; dispose immediately.

      // 5. Composite overlays via OverlayCompositionEngine.
      //    baseImageSize=null → export fills full canvas (no letterboxing).
      //    This is the SAME draw path as the viewport painter — parity guaranteed.
      OverlayCompositionEngine.compositeLayersOntoCanvas(
        canvas: canvas,
        canvasSize: Size(canvasWidth.toDouble(), canvasHeight.toDouble()),
        baseImageSize: null,
        layers: layers,
        imageCache: imageSnapshot,
      );

      // 6. Rasterize to PNG.
      final ui.Picture picture = recorder.endRecording();
      final ui.Image composited =
          await picture.toImage(canvasWidth, canvasHeight);
      final ByteData? byteData = await composited.toByteData(
        format: ui.ImageByteFormat.png,
      );
      composited.dispose();
      picture.dispose();

      if (byteData == null) {
        debugPrint('❌ OverlayExportService: ByteData was null after rasterize.');
        return null;
      }

      // 7. Save to temporary directory.
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath =
          '${tempDir.path}/overlay_export_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(filePath).writeAsBytes(pngBytes);

      debugPrint('✅ OverlayExportService: Export saved to $filePath');
      return filePath;
    } catch (e) {
      debugPrint('❌ OverlayExportService: Export failed — $e');
      return null;
    }
  }

  Future<Uint8List> _loadFileBytes(String path) async {
    if (path.startsWith('http')) {
      throw UnsupportedError(
        'Network base images must be downloaded to a local path before export.',
      );
    }
    return File(path).readAsBytes();
  }

  Future<ui.Image> _decodePng(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
