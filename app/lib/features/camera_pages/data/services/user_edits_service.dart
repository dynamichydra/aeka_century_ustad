import 'dart:io';
import 'package:dio/dio.dart';
import '../models/edit_record.dart';

class UserEditsService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://century-ustad-api-507497848998.asia-south1.run.app',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  UserEditsService() {
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('USTAD_API: $obj'),
    ));
  }

  /// Fetch all edits for a specific owner
  Future<List<EditRecord>> getEdits(String email) async {
    try {
      final response = await _dio.get('/me/edits', queryParameters: {'owner': email});
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((e) => EditRecord.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching edits: $e');
      return [];
    }
  }

  /// Log a new before/after image edit pair
  Future<EditRecord?> postEdit({
    required File editedFile,
    required String furnitureId,
    required String email,
  }) async {
    try {
      final formData = FormData.fromMap({
        'edited_file': await MultipartFile.fromFile(
          editedFile.path,
          filename: editedFile.path.split('/').last,
        ),
        'id': furnitureId,
        'owner': email,
      });

      final response = await _dio.post('/me/edits', data: formData);
      if (response.statusCode == 201) {
        return EditRecord.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error posting edit: $e');
      return null;
    }
  }
}
