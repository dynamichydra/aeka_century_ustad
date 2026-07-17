import 'package:equatable/equatable.dart';

class ImageEditState extends Equatable {
  final bool isCompareLoading;
  final bool isApplyLoading;
  final String? errorMessage;
  final String? successMessage;
  final String? editedImageFile;

  // AI generation flow
  final String? originalImage;
  final String? currentGeneratedImage;
  final List<Map<String, dynamic>> generatedHistory;
  final List<Map<String, dynamic>> redoHistory;
  final Map<String, dynamic>? selectedPattern;
  final Map<String, dynamic>? selectedArea;
  final bool isGenerating;
  final bool hasPatternChanged;
  final bool hasAreaChanged;
  final String? furnitureId;
  final String? ownerId;
  final String? sessionId;
  final String? originalImageUrl;
  final String? imageUrl;

  /// Stack of image paths: [original, edit1, edit2, ...].
  /// The last element is the current image displayed.
  /// Undo pops the last element to restore the previous image.
  final List<String> imageHistory;

  const ImageEditState({
    this.isCompareLoading = false,
    this.isApplyLoading = false,
    this.errorMessage,
    this.successMessage,
    this.editedImageFile,
    this.originalImage,
    this.currentGeneratedImage,
    this.generatedHistory = const [],
    this.redoHistory = const [],
    this.selectedPattern,
    this.selectedArea,
    this.isGenerating = false,
    this.hasPatternChanged = false,
    this.hasAreaChanged = false,
    this.furnitureId,
    this.ownerId,
    this.sessionId,
    this.originalImageUrl,
    this.imageUrl,
    this.imageHistory = const [],
  });

  ImageEditState copyWith({
    bool? isCompareLoading,
    bool? isApplyLoading,
    String? errorMessage,
    String? successMessage,
    String? editedImageFile,
    String? originalImage,
    String? currentGeneratedImage,
    List<Map<String, dynamic>>? generatedHistory,
    List<Map<String, dynamic>>? redoHistory,
    Map<String, dynamic>? selectedPattern,
    Map<String, dynamic>? selectedArea,
    bool? isGenerating,
    bool? hasPatternChanged,
    bool? hasAreaChanged,
    String? furnitureId,
    String? ownerId,
    String? sessionId,
    String? originalImageUrl,
    String? imageUrl,
    List<String>? imageHistory,
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
      redoHistory: redoHistory ?? this.redoHistory,
      selectedPattern: selectedPattern ?? this.selectedPattern,
      selectedArea: selectedArea ?? this.selectedArea,
      isGenerating: isGenerating ?? this.isGenerating,
      hasPatternChanged: hasPatternChanged ?? this.hasPatternChanged,
      hasAreaChanged: hasAreaChanged ?? this.hasAreaChanged,
      furnitureId: furnitureId ?? this.furnitureId,
      ownerId: ownerId ?? this.ownerId,
      sessionId: sessionId ?? this.sessionId,
      originalImageUrl: originalImageUrl ?? this.originalImageUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      imageHistory: imageHistory ?? this.imageHistory,
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
    redoHistory,
    selectedPattern,
    selectedArea,
    isGenerating,
    hasPatternChanged,
    hasAreaChanged,
    furnitureId,
    ownerId,
    sessionId,
    originalImageUrl,
    imageUrl,
    imageHistory,
  ];
}
