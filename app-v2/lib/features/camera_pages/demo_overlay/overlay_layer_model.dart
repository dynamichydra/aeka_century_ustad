import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_session_model.dart';

/// Represents a single non-destructive overlay layer in the overlay stack.
///
/// ARCHITECTURE RULES:
///   - Stores ONLY plain, serializable data: bytes, metadata, flags, hints.
///   - GPU objects (ui.Image) must NEVER be stored here.
///   - ui.Image decoding belongs exclusively in [OverlayImageCacheService].
///
/// COMPOSITING:
///   When [compositedResultBytes] is non-null it holds the pre-computed
///   OpenCV-style composite (base + this layer) produced by
///   [ImageCompositeService.compositeImages()].
///   The renderer displays this PNG directly via Image.memory() — no GPU
///   canvas pass required.
///
///   When [compositedResultBytes] is null, the renderer falls back to the
///   GPU canvas path using [warpedOverlayBytes] + [OverlayCompositionEngine].
///
/// LAYER ENGINE SUPPORT:
///   - [zIndex]: drawing order (higher = on top).
///   - [blendMode]: compositing blend mode.
///   - [transform]: pure-data per-layer transform (replaces Matrix4).
///   - [overlayBounds]: optional normalized crop bounds for future backend
///     optimization — null means full canvas, values in [0,1]×[0,1].
@immutable
class OverlayLayer {
  final String id;

  /// Pre-warped texture pattern bytes (transparent PNG).
  /// The PNG's alpha channel IS the stencil in the GPU canvas fallback path.
  /// May be empty (Uint8List(0)) for sessions restored from disk that
  /// have not yet re-fetched their bytes. Check [hasBytesLoaded].
  final Uint8List warpedOverlayBytes;

  /// Pre-computed OpenCV-style composite PNG bytes produced by
  /// [ImageCompositeService.compositeImages()].
  ///
  /// Non-null after [OverlayEditCubit.applyOverlay()] runs the pipeline.
  /// The renderer prefers this over the GPU canvas path when available.
  /// null = not yet composited (use GPU canvas fallback).
  final Uint8List? compositedResultBytes;

  final String laminateName;
  final String? laminateSku;

  /// Controls rendering order. Higher zIndex = drawn on top.
  final int zIndex;

  /// Compositing blend mode for this layer (GPU canvas path only).
  /// Defaults to [BlendMode.srcOver] (standard alpha compositing).
  final BlendMode blendMode;

  /// Optional per-layer spatial transform.
  ///
  /// Replaces Matrix4 — this is a pure data model with no rendering
  /// engine dependencies and is fully JSON-serializable.
  ///
  /// null = identity transform (no translation, scale, or rotation).
  /// [LayerTransformData.isIdentity] can also be checked for a no-op check.
  final LayerTransformData? transform;

  /// Optional normalized crop bounds in image space ([0,1] × [0,1]).
  ///
  /// FUTURE OPTIMIZATION: When the backend sends cropped overlay textures
  /// instead of full-canvas transparent PNGs, set this to the placement rect.
  ///
  /// null (default) = layer covers the full image rect.
  final Rect? overlayBounds;

  final bool visible;

  /// Opacity from 0.0 (fully transparent) to 1.0 (fully opaque).
  final double opacity;

  final DateTime createdAt;

  /// Tap coordinate in original image pixel space (from the editor gesture).
  final Map<String, dynamic>? coordinate;

  const OverlayLayer({
    required this.id,
    required this.warpedOverlayBytes,
    this.compositedResultBytes,
    required this.laminateName,
    this.laminateSku,
    this.zIndex = 0,
    this.blendMode = BlendMode.srcOver,
    this.transform,
    this.overlayBounds,
    this.visible = true,
    this.opacity = 1.0,
    required this.createdAt,
    this.coordinate,
  });

  /// True if warped bytes are loaded and ready for GPU canvas decoding.
  /// False for layers restored from a session JSON (bytes need re-fetching).
  bool get hasBytesLoaded => warpedOverlayBytes.isNotEmpty;

  /// True if the OpenCV-style composite has been computed and is ready to
  /// display via Image.memory() without GPU canvas overhead.
  bool get hasCompositeResult =>
      compositedResultBytes != null && compositedResultBytes!.isNotEmpty;

  OverlayLayer copyWith({
    String? id,
    Uint8List? warpedOverlayBytes,
    Uint8List? compositedResultBytes,
    String? laminateName,
    String? laminateSku,
    int? zIndex,
    BlendMode? blendMode,
    LayerTransformData? transform,
    Rect? overlayBounds,
    bool? visible,
    double? opacity,
    DateTime? createdAt,
    Map<String, dynamic>? coordinate,
  }) {
    return OverlayLayer(
      id: id ?? this.id,
      warpedOverlayBytes: warpedOverlayBytes ?? this.warpedOverlayBytes,
      compositedResultBytes: compositedResultBytes ?? this.compositedResultBytes,
      laminateName: laminateName ?? this.laminateName,
      laminateSku: laminateSku ?? this.laminateSku,
      zIndex: zIndex ?? this.zIndex,
      blendMode: blendMode ?? this.blendMode,
      transform: transform ?? this.transform,
      overlayBounds: overlayBounds ?? this.overlayBounds,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      createdAt: createdAt ?? this.createdAt,
      coordinate: coordinate ?? this.coordinate,
    );
  }
}
