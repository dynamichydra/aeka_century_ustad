import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A reusable service to preprocess images before they are uploaded to the backend.
/// Normalizes the file format, orientation, metadata, and handles resizing.
///
/// NOTE ON COLOR SPACE CONVERSION:
/// The Dart 'image' package decodes images into a standard raw RGB/RGBA pixel buffer
/// and encodes them back without true ICC profile parsing or conversion (e.g., converting
/// Display P3 color spaces directly to sRGB). The comments and code reflect that we
/// decode the image to raw pixels and re-encode to a standard JPEG file format.
class ImagePreprocessor {
  const ImagePreprocessor._();

  /// Preprocesses the given image [inputImage].
  ///
  /// Normalizes the image into:
  /// - JPEG format
  /// - 8-bit color depth (via standard JPEG encoding)
  /// - EXIF orientation baked into the pixels
  /// - EXIF metadata removed (as a side effect of re-encoding)
  /// - Flattened transparency (alpha channel) onto a white background (if present)
  /// - JPEG quality 90
  /// - Resized if the longest side is larger than 2048px (preserving aspect ratio)
  ///
  /// If any error occurs (including decoding/encoding errors or out-of-memory conditions),
  /// logs the error and returns the original image.
  static Future<File> preprocessImage(File inputImage) async {
    final stopwatch = Stopwatch()..start();
    int originalLength = 0;

    try {
      if (!await inputImage.exists()) {
        debugPrint('⚠️ ImagePreprocessor: Input image does not exist: ${inputImage.path}');
        return inputImage;
      }

      originalLength = await inputImage.length();
      debugPrint('📸 ImagePreprocessor: Processing image: ${inputImage.path} ($originalLength bytes)');
      
      final bytes = await inputImage.readAsBytes();
      
      // Run the heavy image manipulation tasks on a background isolate
      final Map<String, dynamic> result = await compute(_preprocessIsolate, bytes);

      final Uint8List processedBytes = result['jpegBytes'] as Uint8List;
      final int originalWidth = result['originalWidth'] as int;
      final int originalHeight = result['originalHeight'] as int;
      final int processedWidth = result['processedWidth'] as int;
      final int processedHeight = result['processedHeight'] as int;
      final bool transparencyFlattened = result['transparencyFlattened'] as bool;

      // Generate a collision-safe temporary filename using timestamp and a secure random number
      final tempDir = Directory.systemTemp;
      final randomSuffix = Random.secure().nextInt(1000000);
      final tempFile = File(
        '${tempDir.path}/preprocessed_${DateTime.now().microsecondsSinceEpoch}_$randomSuffix.jpg',
      );

      await tempFile.writeAsBytes(processedBytes);
      final processedLength = await tempFile.length();
      stopwatch.stop();

      debugPrint(
        '✅ ImagePreprocessor Success:\n'
        '  - Path: ${tempFile.path}\n'
        '  - Original Dimensions: ${originalWidth}x$originalHeight\n'
        '  - Processed Dimensions: ${processedWidth}x$processedHeight\n'
        '  - Original Size: $originalLength bytes\n'
        '  - Processed Size: $processedLength bytes\n'
        '  - Transparency Flattened: $transparencyFlattened\n'
        '  - Duration: ${stopwatch.elapsedMilliseconds}ms'
      );

      return tempFile;
    } catch (e, stackTrace) {
      stopwatch.stop();
      debugPrint(
        '❌ ImagePreprocessor Error:\n'
        '  - Failed to preprocess image: $e\n'
        '  - Duration: ${stopwatch.elapsedMilliseconds}ms\n'
        '  - StackTrace: $stackTrace'
      );
      // Fallback to original image
      return inputImage;
    }
  }
}

/// Helper function to perform image preprocessing in a background isolate.
/// Returns a map containing the processed JPEG bytes and image metadata.
Map<String, dynamic> _preprocessIsolate(Uint8List bytes) {
  // 1. Decode image bytes
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (e) {
    throw Exception('Failed to decode image: $e');
  }

  if (decoded == null) {
    throw Exception('Decoded image is null.');
  }

  final int originalWidth = decoded.width;
  final int originalHeight = decoded.height;

  // 2. Apply EXIF orientation
  decoded = img.bakeOrientation(decoded);

  // 3. Convert image to RGB (flatten transparency onto a white background) only if needed
  bool transparencyFlattened = false;
  img.Image workingImage = decoded;

  if (decoded.numChannels > 3) {
    bool hasTransparency = false;
    for (final pixel in decoded) {
      if (pixel.a < 255) {
        hasTransparency = true;
        break;
      }
    }

    if (hasTransparency) {
      // Create a solid white background of the same size
      final whiteBg = img.Image(
        width: decoded.width,
        height: decoded.height,
        numChannels: 3,
      );
      img.fill(whiteBg, color: img.ColorRgb8(255, 255, 255));
      
      // Composite the transparent image onto the white background
      img.compositeImage(whiteBg, decoded);
      workingImage = whiteBg;
      transparencyFlattened = true;
    }
  }

  // 4. Resize if the longest side exceeds 2048px
  final width = workingImage.width;
  final height = workingImage.height;
  int longestSide = width > height ? width : height;
  img.Image finalImage = workingImage;

  if (longestSide > 2048) {
    double scale = 2048.0 / longestSide;
    int newWidth = (width * scale).round();
    int newHeight = (height * scale).round();
    
    // Use high quality cubic interpolation for resizing
    finalImage = img.copyResize(
      workingImage,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.cubic,
    );
  }

  // 5. Encode to JPEG with quality 90
  Uint8List encoded;
  try {
    encoded = Uint8List.fromList(img.encodeJpg(finalImage, quality: 90));
  } catch (e) {
    throw Exception('Failed to encode image to JPEG: $e');
  }

  return {
    'jpegBytes': encoded,
    'originalWidth': originalWidth,
    'originalHeight': originalHeight,
    'processedWidth': finalImage.width,
    'processedHeight': finalImage.height,
    'transparencyFlattened': transparencyFlattened,
  };
}
