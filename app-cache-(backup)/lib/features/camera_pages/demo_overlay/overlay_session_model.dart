import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_layer_model.dart';

// ─── LayerTransformData ───────────────────────────────────────────────────────

/// Pure-data, serializable representation of a per-layer spatial transform.
///
/// REPLACES [Matrix4] in [OverlayLayer]:
///   - No dart:ui or rendering engine dependencies.
///   - Fully serializable to/from JSON.
///   - Safe to store in Cubit state and persist to disk.
///
/// All values default to the identity transform (no-op).
/// Coordinates are in ORIGINAL IMAGE PIXEL SPACE.
@immutable
class LayerTransformData {
  /// Horizontal translation in image pixel space.
  final double translateX;

  /// Vertical translation in image pixel space.
  final double translateY;

  /// Uniform scale factor. 1.0 = original size.
  final double scale;

  /// Rotation in radians. 0.0 = no rotation.
  final double rotation;

  const LayerTransformData({
    this.translateX = 0.0,
    this.translateY = 0.0,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  /// Identity transform — no translation, scale, or rotation.
  static const LayerTransformData identity = LayerTransformData();

  /// Returns true if this transform is effectively a no-op.
  bool get isIdentity =>
      translateX == 0.0 &&
      translateY == 0.0 &&
      scale == 1.0 &&
      rotation == 0.0;

  LayerTransformData copyWith({
    double? translateX,
    double? translateY,
    double? scale,
    double? rotation,
  }) {
    return LayerTransformData(
      translateX: translateX ?? this.translateX,
      translateY: translateY ?? this.translateY,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  Map<String, dynamic> toJson() => {
        'translateX': translateX,
        'translateY': translateY,
        'scale': scale,
        'rotation': rotation,
      };

  factory LayerTransformData.fromJson(Map<String, dynamic> json) {
    return LayerTransformData(
      translateX: (json['translateX'] as num?)?.toDouble() ?? 0.0,
      translateY: (json['translateY'] as num?)?.toDouble() ?? 0.0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayerTransformData &&
          translateX == other.translateX &&
          translateY == other.translateY &&
          scale == other.scale &&
          rotation == other.rotation;

  @override
  int get hashCode => Object.hash(translateX, translateY, scale, rotation);

  @override
  String toString() =>
      'LayerTransformData(tx: $translateX, ty: $translateY, '
      'scale: $scale, rot: $rotation)';
}

// ─── OverlaySession ──────────────────────────────────────────────────────────

/// Represents a complete, serializable editing session.
///
/// ARCHITECTURE NOTE:
///   The session is the PRIMARY editing state — flattened PNG exports
///   are DERIVED OUTPUT from the session, not the source of truth.
///
/// PERSISTENCE:
///   [warpedOverlayBytes] is NOT serialized (too large for JSON).
///   [toJson] saves layer metadata only (SKU, name, opacity, transform, etc.).
///   On restore, bytes must be re-fetched from the AI/asset service.
///   Check [OverlayLayer.hasBytesLoaded] to know if bytes need re-fetching.
@immutable
class OverlaySession {
  final String sessionId;
  final String baseImagePath;
  final List<OverlayLayer> layers;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OverlaySession({
    required this.sessionId,
    required this.baseImagePath,
    required this.layers,
    required this.createdAt,
    required this.updatedAt,
  });

  OverlaySession copyWith({
    String? sessionId,
    String? baseImagePath,
    List<OverlayLayer>? layers,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OverlaySession(
      sessionId: sessionId ?? this.sessionId,
      baseImagePath: baseImagePath ?? this.baseImagePath,
      layers: layers ?? this.layers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Serializes session metadata to JSON.
  ///
  /// WARNING: [warpedOverlayBytes] is intentionally excluded.
  /// On restore, bytes must be re-fetched using [laminateSku] / [laminateName].
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'baseImagePath': baseImagePath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'layers': layers.map(_layerToJson).toList(),
    };
  }

  /// Reconstructs a session from JSON.
  ///
  /// Layers will have [hasBytesLoaded] == false until bytes are re-fetched.
  factory OverlaySession.fromJson(Map<String, dynamic> json) {
    final rawLayers = json['layers'] as List<dynamic>? ?? [];
    return OverlaySession(
      sessionId: json['sessionId'] as String,
      baseImagePath: json['baseImagePath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      layers: rawLayers
          .map((e) => _layerFromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Map<String, dynamic> _layerToJson(OverlayLayer layer) {
    return {
      'id': layer.id,
      'laminateName': layer.laminateName,
      'laminateSku': layer.laminateSku,
      'zIndex': layer.zIndex,
      'blendMode': layer.blendMode.index,
      'visible': layer.visible,
      'opacity': layer.opacity,
      'coordinate': layer.coordinate,
      'transform': layer.transform?.toJson(),
      'overlayBounds': layer.overlayBounds != null
          ? {
              'left': layer.overlayBounds!.left,
              'top': layer.overlayBounds!.top,
              'width': layer.overlayBounds!.width,
              'height': layer.overlayBounds!.height,
            }
          : null,
    };
  }

  static OverlayLayer _layerFromJson(Map<String, dynamic> json) {
    final boundsJson = json['overlayBounds'] as Map<String, dynamic>?;
    return OverlayLayer(
      id: json['id'] as String,
      // Bytes are intentionally empty on restore — must be re-fetched.
      warpedOverlayBytes: Uint8List(0),
      laminateName: json['laminateName'] as String? ?? '',
      laminateSku: json['laminateSku'] as String?,
      zIndex: json['zIndex'] as int? ?? 0,
      blendMode: BlendMode.values[json['blendMode'] as int? ?? BlendMode.srcOver.index],
      visible: json['visible'] as bool? ?? true,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      createdAt: DateTime.now(),
      coordinate: (json['coordinate'] as Map<String, dynamic>?),
      transform: json['transform'] != null
          ? LayerTransformData.fromJson(
              json['transform'] as Map<String, dynamic>,
            )
          : null,
      overlayBounds: boundsJson != null
          ? Rect.fromLTWH(
              (boundsJson['left'] as num).toDouble(),
              (boundsJson['top'] as num).toDouble(),
              (boundsJson['width'] as num).toDouble(),
              (boundsJson['height'] as num).toDouble(),
            )
          : null,
    );
  }
}
