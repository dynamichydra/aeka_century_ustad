import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class PreviewService {
  final Dio _dio = Dio();

  Future<void> logPreviewDetails({
    required String imageCategory,
    required String subCategory,
    required String interiorFurniture,
    required bool isTrending,
    required bool isLiked,
  }) async {
    print("--- PreviewService: Sending Request ---");
    final params = {
      "image_category": imageCategory,
      "sub_category": subCategory,
      "interior_furniture": interiorFurniture,
      "is_trending": isTrending,
      "is_liked": isLiked,
    };

    print("Request Parameters: $params");
    
    // try {
    //   final response = await _dio.post(
    //     'my api endpoint', // Dummy endpoint
    //     data: params,
    //   );
    // } catch (e) {
    //   debugPrint("API Call skipped/failed (Expected for dummy): $e");
    // }
    
    debugPrint("-----------------------------------");
  }
}
