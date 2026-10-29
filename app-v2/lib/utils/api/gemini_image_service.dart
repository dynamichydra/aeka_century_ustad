// import 'dart:convert';
// import 'dart:io';
// import 'package:http/http.dart' as http;
// import 'package:image/image.dart' as img;
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:path_provider/path_provider.dart';
//
// /// ------------------------------------------------------------
// /// Resize image to SDXL compatible size (MANDATORY)
// /// ------------------------------------------------------------
// File resizeForSDXL(File file) {
//   final bytes = file.readAsBytesSync();
//   final image = img.decodeImage(bytes)!;
//
//   const int targetWidth = 1024;
//   const int targetHeight = 1024;
//
//   final resized = img.copyResize(
//     image,
//     width: targetWidth,
//     height: targetHeight,
//     interpolation: img.Interpolation.cubic,
//   );
//
//   final outFile = File("${file.path}_sdxl.jpg")
//     ..writeAsBytesSync(img.encodeJpg(resized, quality: 95));
//
//   return outFile;
// }
//
// /// ------------------------------------------------------------
// /// IMAGE GENERATION SERVICE (SDXL)
// /// ------------------------------------------------------------
// class GeminiImageService {
//   /// ⚠️ DO NOT hardcode keys in production
//   static const String _apiKey = "sk-Fmi8YgRzHlBrFERjYuWVJJ9U5rlMU6cw3BqENntgv4KVcji3";
//
// //   static Future<File> editImage({
// //     required File image,
// //     required File lamination, // prompt reference only
// //     required String prompt,
// //   }) async {
// //     final uri = Uri.parse(
// //       "https://api.stability.ai/v1/generation/"
// //           "stable-diffusion-xl-1024-v1-0/image-to-image",
// //     );
// //
// //     /// ✅ Resize image BEFORE upload
// //     final resizedImage = resizeForSDXL(image);
// //
// //     final request = http.MultipartRequest("POST", uri)
// //       ..headers.addAll({
// //         "Authorization": "Bearer $_apiKey",
// //         "Accept": "application/json",
// //       })
// //
// //     /// BASE IMAGE (REQUIRED)
// //       ..files.add(
// //         await http.MultipartFile.fromPath(
// //           "init_image",
// //           resizedImage.path,
// //         ),
// //       )
// //
// //     /// MAIN PROMPT
// //       ..fields["text_prompts[0][text]"] = prompt
// //       ..fields["text_prompts[0][weight]"] = "1"
// //
// //     /// LAMINATION GUIDANCE (TEXT ONLY — SDXL LIMITATION)
// //       ..fields["text_prompts[1][text]"] =
// //           "Apply a realistic wood lamination texture similar to ${lamination.path.split('/').last}"
// //       ..fields["text_prompts[1][weight]"] = "0.6"
// //
// //     /// IMAGE STRENGTH
// //       ..fields["image_strength"] = "0.45"
// //
// //     /// QUALITY SETTINGS
// //       ..fields["cfg_scale"] = "7"
// //       ..fields["samples"] = "1"
// //       ..fields["steps"] = "30";
// //
// //     final streamed = await request.send();
// //     final response = await http.Response.fromStream(streamed);
// //
// //     if (response.statusCode != 200) {
// //       throw Exception("SDXL failed: ${response.body}");
// //     }
// //
// //     final data = jsonDecode(response.body);
// //     final base64Image = data["artifacts"][0]["base64"];
// //
// //     final bytes = base64Decode(base64Image);
// //     final output = File("${image.path}_ai.jpg");
// //     await output.writeAsBytes(bytes);
// //
// //     return output;
// //   }
// // }
//
//
//   static Future<File> editImage({
//     required File image,
//     required File lamination, // unused for now
//     required String prompt,   // unused for now
//   }) async {
//
//     /// ⏳ Simulate AI processing delay
//     await Future.delayed(const Duration(milliseconds: 1500));
//
//     /// 🖼️ Return mock edited image from assets
//     /// (replace with your actual asset path)
//     final mockImage = await assetToTempFile(
//       'assets/images/sample_ai_result.jpg',
//       'mock_ai_result.jpg',
//     );
//
//     return mockImage;
//   }
//
//
// Future<File> assetToTempFile(String assetPath, String name) async {
//   final bytes = await rootBundle.load(assetPath);
//   final dir = await getTemporaryDirectory();
//   final file = File('${dir.path}/$name');
//
//   await file.writeAsBytes(
//     bytes.buffer.asUint8List(),
//     flush: true,
//   );
//
//   return file;
// }
//
//
//


import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class GeminiImageService {
  static Future<File> editImage({
    required File image,
    required File lamination, // unused for now
    required String prompt,   // unused for now
  }) async {

    /// ⏳ Simulate AI processing delay
    await Future.delayed(const Duration(milliseconds: 1500));

    /// 🖼️ Return mock edited image from assets
    final mockImage = await _assetToTempFile(
      'assets/images/furniture/page_13_r.jpg',
      'mock_ai_result.jpg',
    );

    return mockImage;
  }

  /// Convert asset image → temp File
  static Future<File> _assetToTempFile(
      String assetPath,
      String name,
      ) async {
    final bytes = await rootBundle.load(assetPath);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');

    await file.writeAsBytes(
      bytes.buffer.asUint8List(),
      flush: true,
    );

    return file; // ✅ IMPORTANT
  }
}
