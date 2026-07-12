import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(
    BaseOptions(
      baseUrl: "https://designnavigator.centuryply.com/api/",
      headers: {
        "Authorization": "Bearer JYKcj98luq3W0FFtKBFpU1QHGkI8J6CEQkah2Y-BAEA",
        "Content-Type": "application/json",
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        print("RESOLVED FULL URL: ${options.uri}");
        return handler.next(options);
      },
    ),
  );

  try {
    print("Testing with leading slash '/api/findByCategory/paginated':");
    await dio.post("/api/findByCategory/paginated", data: {});
  } catch (e) {}

  try {
    print("\nTesting with relative 'findByCategory/paginated':");
    await dio.post("findByCategory/paginated", data: {
      "category": "Solid",
      "subcategory": false,
      "itemType": "Laminates",
    });
  } catch (e) {}
}
