import 'package:equatable/equatable.dart';

class ImageEditState extends Equatable {
  final bool isCompareLoading;
  final bool isApplyLoading;
  final String? errorMessage;
  final String? successMessage;
  final String? editedImageFile;

  // New fields for AI generation flow
  final String? originalImage;
  final String? currentGeneratedImage;
  final List<Map<String, String>> generatedHistory;
  final Map<String, dynamic>? selectedPattern;
  final Map<String, dynamic>? selectedArea;
  final bool isGenerating;

  const ImageEditState({
    this.isCompareLoading = false,
    this.isApplyLoading = false,
    this.errorMessage,
    this.successMessage,
    this.editedImageFile,
    this.originalImage,
    this.currentGeneratedImage,
    this.generatedHistory = const [],
    this.selectedPattern,
    this.selectedArea,
    this.isGenerating = false,
  });

  ImageEditState copyWith({
    bool? isCompareLoading,
    bool? isApplyLoading,
    String? errorMessage,
    String? successMessage,
    String? editedImageFile,
    String? originalImage,
    String? currentGeneratedImage,
    List<Map<String, String>>? generatedHistory,
    Map<String, dynamic>? selectedPattern,
    Map<String, dynamic>? selectedArea,
    bool? isGenerating,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ImageEditState(
      isCompareLoading: isCompareLoading ?? this.isCompareLoading,
      isApplyLoading: isApplyLoading ?? this.isApplyLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
      editedImageFile: editedImageFile ?? this.editedImageFile,
      originalImage: originalImage ?? this.originalImage,
      currentGeneratedImage:
          currentGeneratedImage ?? this.currentGeneratedImage,
      generatedHistory: generatedHistory ?? this.generatedHistory,
      selectedPattern: selectedPattern ?? this.selectedPattern,
      selectedArea: selectedArea ?? this.selectedArea,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }

  @override
  List<Object?> get props => [
        isCompareLoading,
        isApplyLoading,
        errorMessage,
        successMessage,
        editedImageFile,
        originalImage,
        currentGeneratedImage,
        generatedHistory,
        selectedPattern,
        selectedArea,
        isGenerating,
      ];
}
