import 'package:equatable/equatable.dart';

class ImageEditState extends Equatable {
  final bool isCompareLoading;
  final bool isApplyLoading;
  final String? errorMessage;
  final String? successMessage;
  final String? editedImageFile;

  const ImageEditState({
    this.isCompareLoading = false,
    this.isApplyLoading = false,
    this.errorMessage,
    this.successMessage,
    this.editedImageFile,
  });

  ImageEditState copyWith({
    bool? isCompareLoading,
    bool? isApplyLoading,
    String? errorMessage,
    String? successMessage,
    String? editedImageFile,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ImageEditState(
      isCompareLoading: isCompareLoading ?? this.isCompareLoading,
      isApplyLoading: isApplyLoading ?? this.isApplyLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      editedImageFile: editedImageFile ?? this.editedImageFile,
    );
  }

  @override
  List<Object?> get props => [
        isCompareLoading,
        isApplyLoading,
        errorMessage,
        successMessage,
        editedImageFile,
      ];
}
