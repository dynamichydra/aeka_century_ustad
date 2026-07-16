import 'package:century_ai/core/network/api_client.dart';
import 'package:century_ai/data/services/api_service.dart';
import 'dart:io';

class ImageEditService {
  final ApiClient api = ApiClient();
  final ApiService _apiService = ApiService();

  /// Post Compare Image Details
  Future<dynamic> postCompareImageDetails({
    required String imageCategory,
    required String subCategory,
    required String nestedSubCategory,
    required String interiorFurniture,
    required bool isTrending,
    required bool isLiked,
  }) async {
    // Replace with actual endpoint once available
    print("--- ImageEditService: Sending Request ---");
    final params = {
      "image_category": imageCategory,
      "sub_category": subCategory,
      "nested_sub_category": nestedSubCategory,
      "interior_furniture": interiorFurniture,
      "is_trending": isTrending,
      "is_liked": isLiked,
    };

    print("Request Parameters: $params");
    // var res = await api.post(
    //   "/compare-image-details",
    //   {
    //     "image_category": imageCategory,
    //     "sub_category": subCategory,
    //     "interior_furniture": interiorFurniture,
    //     "is_trending": isTrending,
    //     "is_liked": isLiked,
    //   },
    // );
    // return res;
  }

  /// Post Apply Texture
  Future<dynamic> postApplyTexture({
    required String selectedId,
    required Map<String, dynamic> coordinate,
    required bool isShortTap,
    required bool isLongTap,
    required String selectedTexturePatterns,
  }) async {
    // Replace with actual endpoint once available

    print("--- ImageEditService: Sending Request ---");
    final params = {
      "selected_id": selectedId,
      "coordinate": coordinate,
      "is_short_tap": isShortTap,
      "is_long_tap": isLongTap,
      "selected_texture_patterns": selectedTexturePatterns,
    };

    print("Request Parameters: $params");

    // var res = await api.post(
    //   "/apply-texture",
    //   {
    //     "selected_id": selectedId,
    //     "coordinate": coordinate,
    //     "is_short_tap": isShortTap,
    //     "is_long_tap": isLongTap,
    //     "selected_texture_patterns": selectedTexturePatterns,
    //   },
    // );
    // return res;
  }

  Future<File> tryOnFurniture({
    required File roomImage,
    required File patternImage,
    required int left,
    required int top,
    required int right,
    required int bottom,
  }) async {
    final bytes = await _apiService.tryOnFurniture(
      roomImage: roomImage,
      patternImage: patternImage,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );

    // Save bytes to a temporary file
    final tempDir = await Directory.systemTemp.createTemp();
    final file = File('${tempDir.path}/tryon_result.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<Map<String, dynamic>> tryOnFurnitureV2({
    required File roomImage,
    required File patternImage,
    required int left,
    required int top,
    required int right,
    required int bottom,
  }) async {
    return await _apiService.tryOnFurnitureV2(
      roomImage: roomImage,
      patternImage: patternImage,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
  }

  Future<File> tryOnFurnitureV4({
    required File roomImage,
    required File patternImage,
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    double? objW,
    double? objH,
  }) async {
    final bytes = await _apiService.tryOnFurnitureV4(
      roomImage: roomImage,
      patternImage: patternImage,
      left: x1,
      top: y1,
      right: x2,
      bottom: y2,
      objW: objW,
      objH: objH,
    );

    // Save bytes to a temporary file
    final tempDir = await Directory.systemTemp.createTemp();
    final file = File('${tempDir.path}/tryon_v4_result_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<Map<String, dynamic>> submitTryOnFeedback({
    required String originalImageUrl,
    required String originalImageId,
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    required double objW,
    required double objH,
    required String feedback,
    required String ownerId,
  }) async {
    return await _apiService.submitTryOnFeedback(
      originalImageUrl: originalImageUrl,
      originalImageId: originalImageId,
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      objW: objW,
      objH: objH,
      feedback: feedback,
      ownerId: ownerId,
    );
  }

  Future<void> uploadEditedImage({
    required String uploadUrl,
    required File imageFile,
  }) async {
    await _apiService.uploadEditedImage(
      uploadUrl: uploadUrl,
      imageFile: imageFile,
    );
  }
}
