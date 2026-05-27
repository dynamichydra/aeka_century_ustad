// ignore_for_file: avoid_print
// lib/core/services/image_composite_service.dart
//
// Reproduces the Python/OpenCV compositing pipeline as closely as possible.
//
// Python reference:
//   lighting   = gray / 255.0
//   lighting  *= 1.2
//   lighting   = clamp(0, 1)
//   relighted  = texture * lighting          (multiply blend)
//   inv_mask   = bitwise_not(mask)
//   background = bitwise_and(composite, composite, mask=inv_mask)
//   foreground = bitwise_and(relighted,  relighted,  mask=mask)
//   composite  = add(background, foreground)

import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Holds one (mask, warpedPattern) pair — matches one Python layer_pair entry.
class LayerPair {
  final Uint8List maskBytes;
  final Uint8List warpedPatternBytes;

  const LayerPair({required this.maskBytes, required this.warpedPatternBytes});
}

/// Pure Dart port of the Python/OpenCV multi-layer texture compositing pipeline.
///
/// PIPELINE (per layer):
///   1. Extract luminance from the ORIGINAL base image → lighting map [0..1]
///   2. Multiply warped texture pixels by lighting map  → relighted texture
///   3. Apply bitwise mask gate                          → background + foreground
///   4. Saturating add background + foreground           → updated composite
///
/// OUTPUT: PNG bytes (lossless — no JPEG edge softening).
class ImageCompositeService {
  // Private constructor — pure static utility class.
  const ImageCompositeService._();

  /// Main entry point. Equivalent to the full Python compositing cell.
  ///
  /// [baseImageBytes] — the original room/furniture photo (JPG or PNG bytes).
  /// [layers]         — ordered list of (mask, warpedPattern) pairs.
  ///
  /// Returns PNG-encoded [Uint8List] of the final composite.
  static Future<Uint8List> compositeImages({
    required Uint8List baseImageBytes,
    required List<LayerPair> layers,
  }) async {
    // ── Step 1: Decode base image ────────────────────────────────────────────
    final img.Image? rawImage = img.decodeImage(baseImageBytes);
    if (rawImage == null) throw Exception('ImageCompositeService: Failed to decode base image');

    // ── Step 2: Extract lighting map ONCE from the original image ────────────
    // Python: gray_original = cv2.cvtColor(raw_image, cv2.COLOR_BGR2GRAY)
    //         lighting_map  = np.clip(gray_original / 255.0 * 1.2, 0, 1)
    final Float64List lightingMap = _extractLightingMap(rawImage);

    // ── Step 3: Start compositing canvas = copy of original ──────────────────
    img.Image composite = img.Image.from(rawImage);

    // ── Step 4: Sequential per-layer compositing loop ────────────────────────
    for (int i = 0; i < layers.length; i++) {
      final LayerPair layer = layers[i];

      final img.Image? maskImage   = img.decodeImage(layer.maskBytes);
      final img.Image? warpedImage = img.decodeImage(layer.warpedPatternBytes);

      if (maskImage == null || warpedImage == null) {
        print('ImageCompositeService: Pass ${i + 1} skipped (decode failed)');
        continue;
      }

      // Resize mask if needed — mask MUST match base dimensions.
      final img.Image mask =
          (maskImage.width == rawImage.width && maskImage.height == rawImage.height)
              ? maskImage
              : img.copyResize(
                  maskImage,
                  width: rawImage.width,
                  height: rawImage.height,
                  interpolation: img.Interpolation.linear,
                );

      // ONLY resize warped texture if dimensions differ.
      // Unnecessary resizing destroys perspective alignment and sharpness.
      final img.Image warpedTexture =
          (warpedImage.width == rawImage.width && warpedImage.height == rawImage.height)
              ? warpedImage
              : img.copyResize(
                  warpedImage,
                  width: rawImage.width,
                  height: rawImage.height,
                  interpolation: img.Interpolation.linear,
                );

      // Step 4a: Multiply-relight the warped texture.
      // Python: relighted_i = (warped_i.astype(float32) * lighting_3d).astype(uint8)
      final img.Image relighted = _multiplyLighting(warpedTexture, lightingMap);

      // Step 4b: Inverse-mask composite.
      // Python: background = bitwise_and(composite, composite, mask=inv_mask)
      //         foreground = bitwise_and(relighted, relighted, mask=mask)
      //         composite  = cv2.add(background, foreground)
      composite = _bitwiseMaskComposite(composite, relighted, mask);

      print('ImageCompositeService: Pass ${i + 1} applied');
    }

    // ── Step 5: Encode result as PNG (lossless — no JPEG edge softening) ─────
    return Uint8List.fromList(img.encodePng(composite));
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // LIGHTING MAP EXTRACTION
  // ─────────────────────────────────────────────────────────────────────────────
  // Python equivalent:
  //   gray_original = cv2.cvtColor(raw_image, cv2.COLOR_BGR2GRAY)
  //   lighting_map  = (gray_original.astype(np.float32) / 255.0) * 1.2
  //   lighting_map  = np.clip(lighting_map, 0, 1)
  //
  // Luminance formula: Y = 0.299*R + 0.587*G + 0.114*B
  // cv2.COLOR_BGR2GRAY uses the same weights (channel order differs in OpenCV's
  // BGR format but the numerical values are identical).
  static Float64List _extractLightingMap(img.Image image) {
    final Float64List map = Float64List(image.width * image.height);
    int idx = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final double gray = 0.299 * p.r.toDouble() +
                            0.587 * p.g.toDouble() +
                            0.114 * p.b.toDouble();
        map[idx++] = (gray / 255.0 * 1.2).clamp(0.0, 1.0);
      }
    }
    return map;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MULTIPLY LIGHTING ONTO WARPED TEXTURE
  // ─────────────────────────────────────────────────────────────────────────────
  // Python equivalent:
  //   relighted_i = (warped_pattern_i.astype(np.float32) * lighting_3d).astype(np.uint8)
  //
  // IMPORTANT: Python's .astype(np.uint8) TRUNCATES (floor), not rounds.
  // Use .toInt() in Dart — it also truncates — NOT .round().
  static img.Image _multiplyLighting(img.Image texture, Float64List lightMap) {
    final img.Image out = img.Image.from(texture);
    int idx = 0;
    for (int y = 0; y < texture.height; y++) {
      for (int x = 0; x < texture.width; x++) {
        final p = texture.getPixel(x, y);
        final double l = lightMap[idx++];
        // Truncate (not round) to match Python's .astype(np.uint8)
        out.setPixelRgb(
          x, y,
          (p.r.toDouble() * l).toInt().clamp(0, 255),
          (p.g.toDouble() * l).toInt().clamp(0, 255),
          (p.b.toDouble() * l).toInt().clamp(0, 255),
        );
      }
    }
    return out;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TRUE OpenCV BITWISE_AND + SATURATING ADD COMPOSITING
  // ─────────────────────────────────────────────────────────────────────────────
  // Python equivalent (exact):
  //   inv_mask        = cv2.bitwise_not(mask_i)            # 255 - mask (uint8)
  //   background_part = cv2.bitwise_and(composite,  composite,  mask=inv_mask)
  //   foreground_part = cv2.bitwise_and(relighted_i, relighted_i, mask=mask_i)
  //   composite       = cv2.add(background_part, foreground_part)
  //
  // How cv2.bitwise_and(img, img, mask=M) works:
  //   output[y,x] = img[y,x]   if M[y,x] != 0
  //   output[y,x] = (0, 0, 0)  if M[y,x] == 0
  //
  // cv2.add: saturating uint8 addition — clamp(a + b, 0, 255)
  //
  // The mask PNG is grayscale — package:image stores it as RGB with R=G=B=gray.
  // We read the .r channel as the mask byte.
  static img.Image _bitwiseMaskComposite(
    img.Image composite,
    img.Image relighted,
    img.Image mask,
  ) {
    final img.Image result = img.Image.from(composite);

    for (int y = 0; y < composite.height; y++) {
      for (int x = 0; x < composite.width; x++) {
        final maskPx = mask.getPixel(x, y);

        // Grayscale PNG: R == G == B == gray byte (0..255)
        final int maskByte = maskPx.r.toInt().clamp(0, 255);
        final int invByte  = 255 - maskByte; // cv2.bitwise_not

        final basePx = composite.getPixel(x, y);
        final relPx  = relighted.getPixel(x, y);

        // background_part: keep composite pixels where inv_mask != 0
        final int bgR = invByte != 0 ? basePx.r.toInt().clamp(0, 255) : 0;
        final int bgG = invByte != 0 ? basePx.g.toInt().clamp(0, 255) : 0;
        final int bgB = invByte != 0 ? basePx.b.toInt().clamp(0, 255) : 0;

        // foreground_part: keep relighted pixels where mask != 0
        final int fgR = maskByte != 0 ? relPx.r.toInt().clamp(0, 255) : 0;
        final int fgG = maskByte != 0 ? relPx.g.toInt().clamp(0, 255) : 0;
        final int fgB = maskByte != 0 ? relPx.b.toInt().clamp(0, 255) : 0;

        // cv2.add: saturating uint8 addition
        result.setPixelRgb(
          x, y,
          (bgR + fgR).clamp(0, 255),
          (bgG + fgG).clamp(0, 255),
          (bgB + fgB).clamp(0, 255),
        );
      }
    }

    return result;
  }
}
