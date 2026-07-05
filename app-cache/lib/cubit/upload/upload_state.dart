import 'dart:io';

class UploadState {
  final bool uploadInProgress;
  final bool uploadCompleted;
  final String? imageId;
  final String? applicationType;
  final String? uploadId;
  final String? storagePath;
  final bool isConfirmed;
  final String? errorMessage;
  final File? croppedFile;

  const UploadState({
    this.uploadInProgress = false,
    this.uploadCompleted = false,
    this.imageId,
    this.applicationType,
    this.uploadId,
    this.storagePath,
    this.isConfirmed = false,
    this.errorMessage,
    this.croppedFile,
  });

  UploadState copyWith({
    bool? uploadInProgress,
    bool? uploadCompleted,
    String? imageId,
    String? applicationType,
    String? uploadId,
    String? storagePath,
    bool? isConfirmed,
    String? errorMessage,
    File? croppedFile,
  }) {
    return UploadState(
      uploadInProgress: uploadInProgress ?? this.uploadInProgress,
      uploadCompleted: uploadCompleted ?? this.uploadCompleted,
      imageId: imageId ?? this.imageId,
      applicationType: applicationType ?? this.applicationType,
      uploadId: uploadId ?? this.uploadId,
      storagePath: storagePath ?? this.storagePath,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      errorMessage: errorMessage ?? this.errorMessage,
      croppedFile: croppedFile ?? this.croppedFile,
    );
  }
}
