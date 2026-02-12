import 'package:dio/dio.dart';
import 'package:century_ai/core/constants/api_constants.dart';

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

    // Optional: logging
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );
  }

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
    final pageData = await getProductsPage(limit: limit, skip: skip, page: page);
    return (pageData['products'] as List?) ?? <dynamic>[];
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
    final pageData = await getProductsPage(limit: limit, page: page);
    return (pageData['products'] as List?) ?? <dynamic>[];
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
