import 'package:century_ai/core/services/image_composite_service.dart';
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
  final List<Map<String, dynamic>> generatedHistory;
  final Map<String, dynamic>? selectedPattern;
  final Map<String, dynamic>? selectedArea;
  final bool isGenerating;
  final bool hasPatternChanged;
  final bool hasAreaChanged;
  final String? furnitureId;
  final String? ownerId;
  final String? sessionId;
  final List<LayerPair> appliedLayers; // Accumulated mask and warped patterns

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
    this.hasPatternChanged = false,
    this.hasAreaChanged = false,
    this.furnitureId,
    this.ownerId,
    this.sessionId,
    this.appliedLayers = const [],
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
    Map<String, dynamic>? selectedPattern,
    Map<String, dynamic>? selectedArea,
    bool? isGenerating,
    bool? hasPatternChanged,
    bool? hasAreaChanged,
    String? furnitureId,
    String? ownerId,
    String? sessionId,
    List<LayerPair>? appliedLayers,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ImageEditState(
      isCompareLoading: isCompareLoading ?? this.isCompareLoading,
      isApplyLoading: isApplyLoading ?? this.isApplyLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
      editedImageFile: editedImageFile ?? this.editedImageFile,
      originalImage: originalImage ?? this.originalImage,
      currentGeneratedImage:
          currentGeneratedImage ?? this.currentGeneratedImage,
      generatedHistory: generatedHistory ?? this.generatedHistory,
      selectedPattern: selectedPattern ?? this.selectedPattern,
      selectedArea: selectedArea ?? this.selectedArea,
      isGenerating: isGenerating ?? this.isGenerating,
      hasPatternChanged: hasPatternChanged ?? this.hasPatternChanged,
      hasAreaChanged: hasAreaChanged ?? this.hasAreaChanged,
      furnitureId: furnitureId ?? this.furnitureId,
      ownerId: ownerId ?? this.ownerId,
      sessionId: sessionId ?? this.sessionId,
      appliedLayers: appliedLayers ?? this.appliedLayers,
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
    hasPatternChanged,
    hasAreaChanged,
    furnitureId,
    ownerId,
    sessionId,
    appliedLayers,
  ];
}
