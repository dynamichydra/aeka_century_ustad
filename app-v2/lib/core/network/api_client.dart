import 'package:dio/dio.dart';

class ApiClient {
  static const String baseUrl = "https://designnavigator.centuryply.com/api/";

  static const String token = "JYKcj98luq3W0FFtKBFpU1QHGkI8J6CEQkah2Y-BAEA";

  late Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: null,
        receiveTimeout: null,
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

  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    final response = await dio.post(endpoint, data: data);
    return response.data;
  }
}
