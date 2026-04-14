import 'dart:io';
import 'package:dio/dio.dart';
import 'package:century_ai/core/constants/api_constants.dart';
import 'package:flutter/widgets.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: TApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Enhanced logging for API interactions
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: false,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (object) => debugPrint('📡 API_LOG: $object'),
      ),
    );
  }

  // --- Furniture API ---

  Future<List<dynamic>> getFeaturedFurniture() async {
    final response = await _dio.get(TApiConstants.featuredBrowse);
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getFurnitureByRoom(String room) async {
    final response = await _dio.get('${TApiConstants.roomBrowse}/$room');
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getFurnitureByGroup(String group) async {
    final response = await _dio.get('${TApiConstants.groupBrowse}/$group');
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getFurnitureByProduct(String product, {String? subCategory}) async {
    final queryParams = <String, dynamic>{};
    if (subCategory != null && subCategory != 'All' && subCategory.isNotEmpty) {
      queryParams['subCategory'] = subCategory;
    }
    final response = await _dio.get(
      '${TApiConstants.productBrowse}/$product',
      queryParameters: queryParams,
    );
    return response.data as List<dynamic>;
  }

  Future<dynamic> uploadFurniture(File file) async {
    String fileName = file.path.split('/').last;
    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(file.path, filename: fileName),
    });

    final response = await _dio.post(
      TApiConstants.upload,
      data: formData,
    );
    return response.data;
  }

  Future<List<dynamic>> searchFurnitureByText(String query) async {
    final response = await _dio.get(
      TApiConstants.searchText,
      queryParameters: {'q': query},
    );
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> searchFurnitureBySimilarImage(File file) async {
    String fileName = file.path.split('/').last;
    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(file.path, filename: fileName),
    });

    final response = await _dio.post(
      TApiConstants.searchSimilar,
      data: formData,
    );
    return response.data as List<dynamic>;
  }

  // --- Legacy / Dummy API (from dummyjson.com) ---
  // Note: These might fail if TApiConstants.baseUrl is set to the new furniture API.

  Future<Map<String, dynamic>> requestOtp(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return {
      'success': true,
      'phone': phone,
      'otp': '1234',
      'message': 'Dummy OTP sent',
    };
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (otp.trim() != '1234') {
      throw Exception('Invalid OTP. Use 1234 for dummy flow.');
    }

    return {
      'token': 'dummy-token-${DateTime.now().millisecondsSinceEpoch}',
      'refreshToken': 'dummy-refresh-token',
      'userId': 1,
      'phone': phone,
    };
  }

  Future<Map<String, dynamic>> getUserById(int id) async {
    final response = await _dio.get('${TApiConstants.users}/$id');
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> updateUserById(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put('${TApiConstants.users}/$id', data: payload);
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<List<dynamic>> getProducts({
    int limit = 20,
    int skip = 0,
    int? page,
  }) async {
    final response = await _dio.get(
      TApiConstants.products,
      queryParameters: {'limit': limit, 'skip': skip},
    );
    final data = (response.data as Map).cast<String, dynamic>();
    return (data['products'] as List?) ?? <dynamic>[];
  }

  Future<Map<String, dynamic>> getProductsPage({
    int limit = 20,
    int skip = 0,
    int? page,
  }) async {
    // dummyjson uses skip+limit pagination, not page directly.
    final effectiveSkip = page != null && page > 0 ? (page - 1) * limit : skip;
    final response = await _dio.get(
      TApiConstants.products,
      queryParameters: {'limit': limit, 'skip': effectiveSkip},
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<List<dynamic>> getProductsByPage({
    int limit = 20,
    int page = 1,
  }) async {
    final response = await _dio.get(
      TApiConstants.products,
      queryParameters: {'limit': limit, 'skip': (page - 1) * limit},
    );
    final data = (response.data as Map).cast<String, dynamic>();
    return (data['products'] as List?) ?? <dynamic>[];
  }

  Future<List<dynamic>> getPosts({int limit = 10}) async {
    final response = await _dio.get(
      TApiConstants.posts,
      queryParameters: {'limit': limit},
    );
    final data = (response.data as Map).cast<String, dynamic>();
    return (data['posts'] as List?) ?? <dynamic>[];
  }

  // Legacy method for old repository usage.
  Future<List<dynamic>> fetchPeople() async {
    return getProducts(limit: 20, skip: 0);
  }
}
