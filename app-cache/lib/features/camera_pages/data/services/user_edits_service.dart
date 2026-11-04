import 'dart:io';
import 'package:dio/dio.dart';
import 'package:century_ai/core/constants/api_constants.dart';
import 'package:century_ai/core/network/firebase_auth_interceptor.dart';
import '../models/edit_record.dart';
import '../../../../core/services/image_preprocessor.dart';

class UserEditsService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: TApiConstants.baseUrl,
      connectTimeout: null,
      receiveTimeout: null,
    ),
  );

  UserEditsService() {
    // The backend identifies the user from the Firebase ID token.
    _dio.interceptors.add(FirebaseAuthInterceptor(_dio));
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print('USTAD_API: $obj'),
      ),
    );
  }

  /// Fetch the signed-in user's edits, optionally filtered by furnitureId
  Future<List<EditRecord>> getEdits({String? furnitureId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (furnitureId != null) {
        queryParams['furnitureId'] = furnitureId;
      }
      final response = await _dio.get(
        '/me/edits',
        queryParameters: queryParams,
      );
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
  }) async {
    try {
      final processedFile = await ImagePreprocessor.preprocessImage(editedFile);
      final formData = FormData.fromMap({
        'edited_file': await MultipartFile.fromFile(
          processedFile.path,
          filename: processedFile.path.split('/').last,
        ),
        'id': furnitureId,
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
