import 'package:century_ai/core/network/api_client.dart';

class ImageEditService {
  final ApiClient api = ApiClient();

  /// Post Compare Image Details
  Future<dynamic> postCompareImageDetails({
    required String imageCategory,
    required String subCategory,
    required String interiorFurniture,
    required bool isTrending,
    required bool isLiked,
  }) async {
    // Replace with actual endpoint once available
    print("--- ImageEditService: Sending Request ---");
    final params = {
      "image_category": imageCategory,
      "sub_category": subCategory,
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
}
