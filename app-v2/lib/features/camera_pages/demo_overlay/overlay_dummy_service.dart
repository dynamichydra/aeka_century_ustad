import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

/// Simulates AI try-on responses by loading static demo assets.
///
/// Provides both the warped pattern bytes AND the corresponding mask bytes.
/// Both are required by [ImageCompositeService] to run the Python-equivalent
/// lighting + bitwise-mask compositing pipeline.
///
/// DATA SOURCES:
///   - warped_pattern : loaded from 'assets/tryon-resposne.json' (base64 field)
///   - mask           : loaded from 'assets/mask_1.png' via rootBundle
///
/// RULES:
///   - All assets are loaded via [rootBundle] — never via dart:io File().
///   - No ui.Image decoding here — that belongs to [OverlayImageCacheService].
class OverlayDummyService {
  /// Loads the warped pattern bytes from the bundled demo JSON.
  ///
  /// The JSON file contains a 'warped_pattern' field with base64-encoded PNG bytes.
  Future<Uint8List> loadWarpedPatternBytes() async {
    try {
      final String jsonStr =
          await rootBundle.loadString('assets/tryon-resposne.json');
      final Map<String, dynamic> data = json.decode(jsonStr);
      final String warpedPatternBase64 = data['warped_pattern'] as String;
      return base64Decode(warpedPatternBase64);
    } catch (e) {
      throw Exception('OverlayDummyService: Failed to load warped pattern — $e');
    }
  }

  /// Loads the grayscale mask bytes for the demo overlay.
  ///
  /// First attempts to read a 'mask' field from 'assets/tryon-resposne.json'.
  /// Falls back to loading 'assets/mask_1.png' directly via rootBundle.
  ///
  /// The mask is a grayscale PNG where:
  ///   white (255) = texture region (foreground)
  ///   black (0)   = preserved background
  Future<Uint8List> loadMaskBytes() async {
    // 1. Try JSON 'mask' field first (for future API compatibility)
    try {
      final String jsonStr =
          await rootBundle.loadString('assets/tryon-resposne.json');
      final Map<String, dynamic> data = json.decode(jsonStr);
      if (data.containsKey('mask') && data['mask'] is String) {
        final String maskBase64 = data['mask'] as String;
        if (maskBase64.isNotEmpty) {
          return base64Decode(maskBase64);
        }
      }
    } catch (_) {
      // Fall through to asset fallback
    }

    // 2. Fallback: load bundled mask PNG asset
    try {
      final ByteData byteData = await rootBundle.load('assets/mask_1.png');
      return byteData.buffer.asUint8List();
    } catch (e) {
      throw Exception('OverlayDummyService: Failed to load mask bytes — $e');
    }
  }
}
