import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:century_ai/cubit/upload/upload_state.dart';
import 'package:century_ai/data/repositories/upload_repository.dart';
import 'package:century_ai/db/models/selected_image_data.dart';
import 'package:century_ai/db/repositories/selected_images_repository.dart';

class UploadCubit extends Cubit<UploadState> {
  final UploadRepository _uploadRepository;
  String? _currentSessionToken;

  UploadCubit(this._uploadRepository) : super(const UploadState());

  Future<void> startUpload(File croppedFile) async {
    final sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
    _currentSessionToken = sessionToken;

    emit(UploadState(
      uploadInProgress: true,
      croppedFile: croppedFile,
    ));

    try {
      // Step 1: POST /upload/init
      final initData = await _uploadRepository.initUpload();
      if (_currentSessionToken != sessionToken) return; // Stale session, ignore!

      final uploadId = initData['uploadId'] as String;
      final uploadUrl = initData['uploadUrl'] as String;
      final storagePath = initData['storagePath'] as String;

      emit(state.copyWith(
        uploadId: uploadId,
        storagePath: storagePath,
      ));

      // Step 2: Upload binary image to uploadUrl
      await _uploadRepository.uploadBinary(uploadUrl, croppedFile);
      if (_currentSessionToken != sessionToken) return;

      // Step 3: Call POST /upload/{uploadId}/complete
      final completeData = await _uploadRepository.completeUpload(uploadId, storagePath);
      if (_currentSessionToken != sessionToken) return;

      final imageId = completeData['imageId']?.toString();
      final applicationType = completeData['applicationType']?.toString();

      emit(state.copyWith(
        uploadInProgress: false,
        uploadCompleted: true,
        imageId: imageId,
        applicationType: applicationType,
      ));

      // If user has already clicked "Use Photo" (confirm), save to SQLite
      if (state.isConfirmed && imageId != null) {
        await _saveToSQLite(imageId, croppedFile, applicationType);
      }
    } catch (e) {
      debugPrint('❌ UPLOAD_CUBIT ERROR: $e');
      if (_currentSessionToken == sessionToken) {
        emit(state.copyWith(
          uploadInProgress: false,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  Future<void> confirm() async {
    emit(state.copyWith(isConfirmed: true));
    // If upload is already completed, save to SQLite now
    if (state.uploadCompleted && state.imageId != null && state.croppedFile != null) {
      await _saveToSQLite(state.imageId!, state.croppedFile!, state.applicationType);
    }
  }

  Future<void> _saveToSQLite(String imageId, File file, String? applicationType) async {
    try {
      final imageBytes = await compute(
        (File f) => f.readAsBytesSync(),
        file,
      );
      await SelectedImagesRepository.saveImage(
        SelectedImageData(
          id: imageId,
          imageData: imageBytes,
          imagePath: file.path,
          category: 'Uploaded Image',
          subcategory: 'User Upload',
          selectedAt: DateTime.now(),
          applicationType: applicationType,
        ),
      );
      debugPrint('💾 UPLOAD_CUBIT: Saved image $imageId to SQLite');
    } catch (e) {
      debugPrint('❌ UPLOAD_CUBIT SQLITE SAVE ERROR: $e');
    }
  }

  void reset() {
    _currentSessionToken = null;
    emit(const UploadState());
  }
}
