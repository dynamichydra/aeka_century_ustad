import 'dart:io';
import 'package:century_ai/data/services/api_service.dart';

class UploadRepository {
  final ApiService _apiService;

  UploadRepository(this._apiService);

  Future<Map<String, dynamic>> initUpload() async {
    return await _apiService.initUpload();
  }

  Future<void> uploadBinary(String uploadUrl, File file) async {
    await _apiService.uploadBinary(uploadUrl, file);
  }

  Future<Map<String, dynamic>> completeUpload(String uploadId, String storagePath) async {
    return await _apiService.completeUpload(uploadId, storagePath);
  }
}
