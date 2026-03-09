import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class HomeService {
  final Dio _dio = Dio();

  Future<void> filterProducts({
    required String query,
    required bool isExterior,
    required bool isTrending,
    required bool isLiked,
    required String category,
  }) async {
    print("--- HomeService: Sending Request ---");
    final params = {
      'query': query,
      'mode': isExterior ? 'Exterior' : 'Interior',
      'trending': isTrending,
      'liked': isLiked,
      'category': category,
    };
    

    print("Request Parameters: $params");
    // try {
    //   final response = await _dio.get(
    //     'my api', // Dummy endpoint
    //     queryParameters: params,
    //   );
    // } catch (e) {
    //   debugPrint("API Call skipped/failed (Expected for dummy): $e");
    // }
    debugPrint("-----------------------------------");
  }
}
