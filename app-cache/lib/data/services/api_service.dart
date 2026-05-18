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
        connectTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 2),
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

  Future<List<dynamic>> getFeaturedFurniture({
    String? ownerId,
    int limit = 10,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{'limit': limit, 'offset': offset};
    if (ownerId != null) queryParams['ownerId'] = ownerId;
    debugPrint('🛒 FETCH_PRODUCT: ${TApiConstants.baseUrl}${TApiConstants.featuredBrowse} | Params: $queryParams');
    final response = await _dio.get(
      TApiConstants.featuredBrowse,
      queryParameters: queryParams,
    );
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getInteriorFurniture({
    String? ownerId,
    int limit = 10,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{'limit': limit, 'offset': offset};
    if (ownerId != null) queryParams['ownerId'] = ownerId;
    debugPrint('🛒 FETCH_PRODUCT: ${TApiConstants.baseUrl}${TApiConstants.interiorBrowse} | Params: $queryParams');
    final response = await _dio.get(
      TApiConstants.interiorBrowse,
      queryParameters: queryParams,
    );
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getExteriorFurniture({
    String? ownerId,
    int limit = 10,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{'limit': limit, 'offset': offset};
    if (ownerId != null) queryParams['ownerId'] = ownerId;
    debugPrint('🛒 FETCH_PRODUCT: ${TApiConstants.baseUrl}${TApiConstants.exteriorBrowse} | Params: $queryParams');
    final response = await _dio.get(
      TApiConstants.exteriorBrowse,
      queryParameters: queryParams,
    );
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getFurnitureByRoom(
    String room, {
    String? ownerId,
    int limit = 20,
    int offset = 0,
  }) async {
    final url = '${TApiConstants.roomBrowse}/$room';
    final queryParams = <String, dynamic>{'limit': limit, 'offset': offset};
    if (ownerId != null) queryParams['ownerId'] = ownerId;
    debugPrint('🛒 FETCH_PRODUCT: ${TApiConstants.baseUrl}$url | Params: $queryParams');
    final response = await _dio.get(
      url,
      queryParameters: queryParams,
    );
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getFurnitureByGroup(
    String group, {
    String? ownerId,
    int limit = 20,
    int offset = 0,
  }) async {
    final url = '${TApiConstants.groupBrowse}/$group';
    final queryParams = <String, dynamic>{'limit': limit, 'offset': offset};
    if (ownerId != null) queryParams['ownerId'] = ownerId;
    debugPrint('🛒 FETCH_PRODUCT: ${TApiConstants.baseUrl}$url | Params: $queryParams');
    final response = await _dio.get(
      url,
      queryParameters: queryParams,
    );
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getFurnitureByProduct(
    String product, {
    String? subCategory,
    String? ownerId,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{'limit': limit, 'offset': offset};
    if (subCategory != null && subCategory != 'All' && subCategory.isNotEmpty) {
      queryParams['subCategory'] = subCategory;
    }
    if (ownerId != null) queryParams['ownerId'] = ownerId;
    final url = '${TApiConstants.productBrowse}/$product';
    debugPrint('🛒 FETCH_PRODUCT: ${TApiConstants.baseUrl}$url | Params: $queryParams');
    final response = await _dio.get(
      url,
      queryParameters: queryParams,
    );
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getSimilarProducts(
    String id, {
    String? ownerId,
    int limit = 20,
    int offset = 0,
  }) async {
    final url = '${TApiConstants.similarProducts}/$id';
    final queryParams = <String, dynamic>{'limit': limit, 'offset': offset};
    if (ownerId != null) queryParams['ownerId'] = ownerId;
    debugPrint(
      '🛒 FETCH_PRODUCT: ${TApiConstants.baseUrl}$url | Params: $queryParams',
    );
    final response = await _dio.get(url, queryParameters: queryParams);
    return response.data as List<dynamic>;
  }
  
  Future<List<dynamic>> getTrendingProducts({
    String? ownerId,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (ownerId != null) queryParams['ownerId'] = ownerId;
    debugPrint('🛒 FETCH_TRENDING: ${TApiConstants.baseUrl}${TApiConstants.trendingProducts} | Params: $queryParams');
    final response = await _dio.get(
      TApiConstants.trendingProducts,
      queryParameters: queryParams,
    );
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getFavoriteProducts({
    required String ownerId,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{
      'ownerId': ownerId,
      'limit': limit,
      'offset': offset,
    };
    debugPrint('🛒 FETCH_FAVORITES: ${TApiConstants.baseUrl}${TApiConstants.favorites} | Params: $queryParams');
    final response = await _dio.get(
      TApiConstants.favorites,
      queryParameters: queryParams,
    );
    return response.data as List<dynamic>;
  }

  Future<dynamic> toggleFavorite({
    required String itemId,
    required String ownerId,
    String type = "FURNITURE",
  }) async {
    final data = {
      "itemId": itemId,
      "ownerId": ownerId,
      "itemType": type,
    };
    debugPrint('🛒 TOGGLE_FAVORITE: ${TApiConstants.baseUrl}${TApiConstants.favorites} | Data: $data');
    final response = await _dio.post(
      TApiConstants.favorites,
      data: data,
    );
    return response.data;
  }

  Future<dynamic> removeFavorite({
    required String itemId,
    required String ownerId,
  }) async {
    final url = '${TApiConstants.favorites}/$itemId';
    final queryParams = {'ownerId': ownerId};
    debugPrint('🛒 REMOVE_FAVORITE: ${TApiConstants.baseUrl}$url | Params: $queryParams');
    final response = await _dio.delete(
      url,
      queryParameters: queryParams,
    );
    return response.data;
  }

  Future<dynamic> uploadFurniture(File file) async {
    String fileName = file.path.split('/').last;
    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(file.path, filename: fileName),
    });

    debugPrint('🛒 FETCH_PRODUCT: ${TApiConstants.baseUrl}${TApiConstants.upload} | POST multipart/form-data (File: $fileName)');
    final response = await _dio.post(TApiConstants.upload, data: formData);

    return response.data;
  }


  Future<List<dynamic>> searchFurnitureByText(
    String query, {
    String? product,
    String? furnitureCategory,
    String? interiorCategory,
    String? subCategory,
    String? applicationType,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{'q': query, 'limit': limit, 'offset': offset};
    if (product != null) queryParams['product'] = product;
    if (furnitureCategory != null) queryParams['furnitureCategory'] = furnitureCategory;
    if (interiorCategory != null) queryParams['interiorCategory'] = interiorCategory;
    if (subCategory != null) queryParams['subCategory'] = subCategory;
    if (applicationType != null) queryParams['applicationType'] = applicationType;
    debugPrint('🛒 FETCH_PRODUCT: ${TApiConstants.baseUrl}${TApiConstants.searchText} | Params: $queryParams');
    final response = await _dio.get(
      TApiConstants.searchText,
      queryParameters: queryParams,
    );
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> searchFurnitureBySimilarImage(
    File file, {
    String? product,
    String? furnitureCategory,
    String? interiorCategory,
    String? subCategory,
    String? applicationType,
  }) async {
    String fileName = file.path.split('/').last;
    final map = <String, dynamic>{
      "file": await MultipartFile.fromFile(file.path, filename: fileName),
    };
    if (product != null) map['product'] = product;
    if (furnitureCategory != null) map['furnitureCategory'] = furnitureCategory;
    if (interiorCategory != null) map['interiorCategory'] = interiorCategory;
    if (subCategory != null) map['subCategory'] = subCategory;
    if (applicationType != null) map['applicationType'] = applicationType;
    
    FormData formData = FormData.fromMap(map);

    debugPrint('🛒 FETCH_PRODUCT: ${TApiConstants.baseUrl}${TApiConstants.searchSimilar} | POST multipart/form-data');
    final response = await _dio.post(
      TApiConstants.searchSimilar,
      data: formData,
    );
    return response.data as List<dynamic>;
  }

  Future<List<int>> tryOnFurniture({
    required File roomImage,
    required File patternImage,
    required int x,
    required int y,
  }) async {
    // Ensure files exist before proceeding
    if (!await roomImage.exists()) {
      throw Exception('Room image file does not exist at path: ${roomImage.path}');
    }
    if (!await patternImage.exists()) {
      throw Exception('Pattern image file does not exist at path: ${patternImage.path}');
    }

    String roomFileName = roomImage.path.split('/').last;
    String patternFileName = patternImage.path.split('/').last;

    FormData formData = FormData.fromMap({
      "room_image": await MultipartFile.fromFile(
        roomImage.path,
        filename: roomFileName,
      ),
      "pattern_image": await MultipartFile.fromFile(
        patternImage.path,
        filename: patternFileName,
      ),
      "x": x.toString(),
      "y": y.toString(),
    });

    debugPrint('🛒 FETCH_PRODUCT: ${TApiConstants.tryOn} | POST Try-On (Room: $roomFileName, Pattern: $patternFileName, X: $x, Y: $y)');

    final response = await _dio.post(
      TApiConstants.tryOn,
      data: formData,
      options: Options(
        responseType: ResponseType.bytes,
        contentType: 'multipart/form-data',
      ),
    );

    debugPrint('✅ API_LOG: Response Status: ${response.statusCode}');
    debugPrint('📄 API_LOG: Response size: ${response.data.length} bytes');

    return response.data as List<int>;
  }

  Future<List<dynamic>> getMyUploads({
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = {'limit': limit, 'offset': offset};
    debugPrint('🛒 FETCH_UPLOADS: ${TApiConstants.baseUrl}/me/uploads | Params: $queryParams');
    final response = await _dio.get(
      '/me/uploads',
      queryParameters: queryParams,
    );
    return response.data as List<dynamic>;
  }

  Future<dynamic> deleteMyUpload({
    required String id,
  }) async {
    final url = '/me/uploads/$id';
    debugPrint('🛒 DELETE_UPLOAD: ${TApiConstants.baseUrl}$url');
    final response = await _dio.delete(url);
    return response.data;
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
    final response = await _dio.put(
      '${TApiConstants.users}/$id',
      data: payload,
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<List<dynamic>> getProducts({
    int limit = 20,
    int skip = 0,
    int? page,
  }) async {
    final queryParams = {'limit': limit, 'skip': skip};
    debugPrint('🛒 FETCH_PRODUCT (Legacy): ${TApiConstants.baseUrl}${TApiConstants.products} | Params: $queryParams');
    final response = await _dio.get(
      TApiConstants.products,
      queryParameters: queryParams,
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
    final queryParams = {'limit': limit, 'skip': effectiveSkip};
    debugPrint('🛒 FETCH_PRODUCT (Legacy): ${TApiConstants.baseUrl}${TApiConstants.products} | Params: $queryParams');
    final response = await _dio.get(
      TApiConstants.products,
      queryParameters: queryParams,
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<List<dynamic>> getProductsByPage({
    int limit = 20,
    int page = 1,
  }) async {
    final queryParams = {'limit': limit, 'skip': (page - 1) * limit};
    debugPrint('🛒 FETCH_PRODUCT (Legacy): ${TApiConstants.baseUrl}${TApiConstants.products} | Params: $queryParams');
    final response = await _dio.get(
      TApiConstants.products,
      queryParameters: queryParams,
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
