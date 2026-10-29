import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:century_ai/core/services/image_composite_service.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_layer_model.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_edit_state.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_dummy_service.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_repository.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_session_model.dart';

/// UI state manager for the non-destructive overlay editor.
///
/// ARCHITECTURE RULES:
///   - ONLY manages UI state and user interactions.
///   - NEVER decodes or stores GPU objects (ui.Image).
///   - NEVER performs I/O directly — all I/O goes through [OverlayRepository].
///   - The base room image path is SET ONCE and is IMMUTABLE.
///     Use [clearOverlaysOnly] to start a new session — base image never changes.
///
/// COMPOSITING:
///   [applyOverlay] runs the full Python/OpenCV-equivalent pipeline via
///   [ImageCompositeService]:
///     1. Load warped pattern bytes (from [OverlayDummyService])
///     2. Load mask bytes          (from [OverlayDummyService.loadMaskBytes])
///     3. Load base image bytes    (via rootBundle or File)
///     4. Run [ImageCompositeService.compositeImages()]
///     5. Store result in [OverlayLayer.compositedResultBytes]
///   The renderer then displays it via Image.memory() — no GPU canvas needed.
///
/// DEPENDENCY GRAPH:
///   OverlayEditCubit
///     ├── ImageCompositeService    (Python/OpenCV pixel math — CPU path)
///     ├── OverlayDummyService      (loads demo warped pattern + mask bytes)
///     └── OverlayRepository        (export, session save/load, cache sync)
///           ├── OverlayExportService  (PictureRecorder compositing — GPU path)
///           │     └── OverlayCompositionEngine  (shared draw logic)
///           ├── OverlayImageCacheService  (LRU ui.Image cache)
///           └── Session JSON persistence
class OverlayEditCubit extends Cubit<OverlayEditState> {
  final OverlayDummyService _dummyService;
  final OverlayRepository _repository;

  OverlayEditCubit({
    required String baseRoomImage,
    OverlayDummyService? dummyService,
    OverlayRepository? repository,
  })  : _dummyService = dummyService ?? OverlayDummyService(),
        _repository = repository ?? OverlayRepository(),
        super(OverlayEditState(baseRoomImage: baseRoomImage, overlays: []));

  // ─── Overlay Management ──────────────────────────────────────────────────

  /// Loads demo warped pattern + mask bytes, runs the Python/OpenCV-equivalent
  /// compositing pipeline, builds a new [OverlayLayer] with the computed
  /// composite, and appends it to the overlay stack.
  ///
  /// The base room image is NEVER touched — the composite is stored only in
  /// [OverlayLayer.compositedResultBytes] and rendered via Image.memory().
  Future<void> applyOverlay({
    required Map<String, dynamic> coordinate,
    required Map<String, dynamic> texture,
  }) async {
    emit(state.copyWith(isGenerating: true));

    try {
      // ── Step 1: Load warped pattern bytes ─────────────────────────────────
      final Uint8List warpedBytes = await _dummyService.loadWarpedPatternBytes();

      // ── Step 2: Load mask bytes ───────────────────────────────────────────
      final Uint8List maskBytes = await _dummyService.loadMaskBytes();

      // ── Step 3: Load base image bytes ─────────────────────────────────────
      // Try rootBundle first (bundled assets), fall back to File for local paths.
      final Uint8List baseBytes = await _loadBaseImageBytes(state.baseRoomImage);

      // ── Step 4: Run Python/OpenCV-equivalent compositing pipeline ─────────
      // Matches: relighted = texture * lighting_map
      //          composite = bitwise_and(bg, inv_mask) + bitwise_and(fg, mask)
      final Uint8List compositedPng = await ImageCompositeService.compositeImages(
        baseImageBytes: baseBytes,
        layers: [
          LayerPair(
            maskBytes: maskBytes,
            warpedPatternBytes: warpedBytes,
          ),
        ],
      );

      // ── Step 5: Build and push new overlay layer ──────────────────────────
      final OverlayLayer newLayer = OverlayLayer(
        id: 'layer_${DateTime.now().millisecondsSinceEpoch}'
            '_${texture['id'] ?? 'unknown'}',
        warpedOverlayBytes: warpedBytes,           // kept for GPU canvas fallback
        compositedResultBytes: compositedPng,      // ← pre-computed OpenCV composite
        laminateName: texture['name'] as String? ?? 'Demo Laminate',
        laminateSku: texture['sku'] as String? ?? 'SKU-0000',
        createdAt: DateTime.now(),
        coordinate: coordinate,
        visible: true,
        opacity: 1.0,
        zIndex: state.overlays.length, // stack on top
      );

      final List<OverlayLayer> updatedList =
          List<OverlayLayer>.from(state.overlays)..add(newLayer);

      // Sync cache: keep only active layer textures.
      _repository.syncCache(updatedList);

      emit(state.copyWith(
        overlays: updatedList,
        isGenerating: false,
        successMessage: 'Overlay applied!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isGenerating: false,
        errorMessage: 'Error applying overlay: $e',
      ));
    }
  }

  // ─── Overlay Management ──────────────────────────────────────────────────

  /// Removes the overlay layer with the given [id] from the stack.
  void removeOverlay(String id) {
    final List<OverlayLayer> updated =
        state.overlays.where((l) => l.id != id).toList();
    _repository.syncCache(updated); // Dispose evicted texture from GPU cache.
    emit(state.copyWith(overlays: updated));
  }

  /// Removes the most recently added overlay layer (Undo).
  void undo() {
    if (state.overlays.isNotEmpty) {
      final List<OverlayLayer> updated =
          List<OverlayLayer>.from(state.overlays)..removeLast();
      _repository.syncCache(updated); // Dispose evicted texture from GPU cache.
      emit(state.copyWith(overlays: updated));
    }
  }

  /// Toggles the visibility flag for layer [id].
  void toggleVisibility(String id) {
    final updated = state.overlays
        .map((l) => l.id == id ? l.copyWith(visible: !l.visible) : l)
        .toList();
    emit(state.copyWith(overlays: updated));
  }

  /// Updates the opacity of layer [id] (clamped 0.0–1.0).
  void updateOpacity(String id, double opacity) {
    final updated = state.overlays
        .map((l) => l.id == id
            ? l.copyWith(opacity: opacity.clamp(0.0, 1.0))
            : l)
        .toList();
    emit(state.copyWith(overlays: updated));
  }

  /// Updates the transform of layer [id].
  void updateTransform(String id, LayerTransformData transform) {
    final updated = state.overlays
        .map((l) => l.id == id ? l.copyWith(transform: transform) : l)
        .toList();
    emit(state.copyWith(overlays: updated));
  }

  // ─── Export ───────────────────────────────────────────────────────────────

  /// Exports the composited image at native resolution via [OverlayRepository].
  ///
  /// Uses [OverlayCompositionEngine] through the repository — same draw path
  /// as the viewport renderer, guaranteeing preview == export parity.
  Future<void> exportAndSave(String baseImagePath) async {
    emit(state.copyWith(isExporting: true));

    try {
      final OverlaySession session = OverlaySession(
        sessionId: 'export_${DateTime.now().millisecondsSinceEpoch}',
        baseImagePath: baseImagePath,
        layers: state.overlays,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final String? path = await _repository.exportSession(session);

      if (path != null) {
        emit(state.copyWith(isExporting: false, exportedImagePath: path));
      } else {
        emit(state.copyWith(
          isExporting: false,
          errorMessage: 'Export failed: compositor returned null.',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isExporting: false,
        errorMessage: 'Export error: $e',
      ));
    }
  }

  /// Saves the current editing session metadata to disk via [OverlayRepository].
  ///
  /// Note: [warpedOverlayBytes] and [compositedResultBytes] are NOT persisted.
  /// Laminate SKU/metadata is saved so bytes can be re-fetched on restore.
  Future<void> saveSession(String baseImagePath, String sessionId) async {
    final OverlaySession session = OverlaySession(
      sessionId: sessionId,
      baseImagePath: baseImagePath,
      layers: state.overlays,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _repository.saveSession(session);
  }

  // ─── State Management ────────────────────────────────────────────────────

  /// Clears ONLY the overlay stack.
  ///
  /// The base room image remains IMMUTABLE — this is intentional.
  /// Use this to start a new session without changing the editing base.
  void clearOverlaysOnly() {
    _repository.syncCache([]); // Dispose all cached layer textures.
    emit(OverlayEditState(
      baseRoomImage: state.baseRoomImage,
      overlays: const [],
      isGenerating: false,
      isExporting: false,
    ));
  }

  /// Resets transient notification fields (errors, success, exported path).
  ///
  /// Call this after consuming a message from a [BlocListener] to prevent
  /// duplicate triggers.
  void clearMessages() {
    emit(OverlayEditState(
      baseRoomImage: state.baseRoomImage,
      overlays: state.overlays,
      isGenerating: state.isGenerating,
      isExporting: state.isExporting,
    ));
  }

  // ─── Private Helpers ─────────────────────────────────────────────────────

  /// Loads base image bytes from a path — tries rootBundle first for bundled
  /// assets, falls back to File I/O for local file system paths.
  Future<Uint8List> _loadBaseImageBytes(String path) async {
    // Bundled asset paths start with 'assets/'
    if (!path.startsWith('/') && !path.startsWith('http')) {
      try {
        final ByteData data = await rootBundle.load(path);
        return data.buffer.asUint8List();
      } catch (_) {
        // Not a bundled asset — try as a file path
      }
    }

    // Local file path
    final File file = File(path);
    if (await file.exists()) {
      return await file.readAsBytes();
    }

    throw Exception(
      'OverlayEditCubit: Cannot load base image from "$path" — '
      'not a valid asset path or existing file.',
    );
  }
}
