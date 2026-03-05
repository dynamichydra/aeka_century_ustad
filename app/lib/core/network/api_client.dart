import 'package:dio/dio.dart';

class ApiClient {

  static const String baseUrl =
      "https://dummynavigator.centuryply.com/api";

  static const String token =
      "h+jN0UoxQfElOH2ZvP1srXJWm29EjpQgTCbCpiu3O84=";

  late Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print("REQUEST → ${options.path}");
          print("BODY → ${options.data}");
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print("RESPONSE → ${response.data}");
          return handler.next(response);
        },
        onError: (error, handler) {
          print("ERROR → ${error.message}");
          return handler.next(error);
        },
      ),
    );
  }

  Future<dynamic> post(
      String endpoint,
      Map<String, dynamic> data,
      ) async {
    final response = await dio.post(endpoint, data: data);
    return response.data;
  }
}