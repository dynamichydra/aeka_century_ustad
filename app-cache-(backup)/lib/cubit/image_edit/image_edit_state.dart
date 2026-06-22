import 'dart:typed_data';
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

  // Preview / approval flow (transient — never persisted)
  /// True while the user is reviewing a pending laminate application.
  final bool showSelectionPreview;

  /// Raw mask PNG bytes returned by the API (used to draw the selection outline).
  final Uint8List? pendingMaskBytes;

  /// Raw warped-pattern PNG bytes returned by the API.
  final Uint8List? pendingWarpedBytes;

  /// Path to the temporary composited PNG written during preview.
  /// Copied to /edits/ on Accept; deleted on Cancel.
  final String? tempCompositedImagePath;

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
    // Preview fields
    this.showSelectionPreview = false,
    this.pendingMaskBytes,
    this.pendingWarpedBytes,
    this.tempCompositedImagePath,
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
    // Preview fields
    bool? showSelectionPreview,
    Uint8List? pendingMaskBytes,
    Uint8List? pendingWarpedBytes,
    String? tempCompositedImagePath,
    // Convenience flags
    bool clearError = false,
    bool clearSuccess = false,
    /// When true, nullifies all four transient preview fields at once.
    bool clearPendingPreview = false,
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
      hasPatternChanged: hasPatternChanged ?? this.hasPatternChanged,
      hasAreaChanged: hasAreaChanged ?? this.hasAreaChanged,
      furnitureId: furnitureId ?? this.furnitureId,
      ownerId: ownerId ?? this.ownerId,
      sessionId: sessionId ?? this.sessionId,
      appliedLayers: appliedLayers ?? this.appliedLayers,
      // Preview — cleared wholesale with clearPendingPreview
      showSelectionPreview: clearPendingPreview
          ? false
          : (showSelectionPreview ?? this.showSelectionPreview),
      pendingMaskBytes:
          clearPendingPreview ? null : (pendingMaskBytes ?? this.pendingMaskBytes),
      pendingWarpedBytes: clearPendingPreview
          ? null
          : (pendingWarpedBytes ?? this.pendingWarpedBytes),
      tempCompositedImagePath: clearPendingPreview
          ? null
          : (tempCompositedImagePath ?? this.tempCompositedImagePath),
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
    showSelectionPreview,
    pendingMaskBytes,
    pendingWarpedBytes,
    tempCompositedImagePath,
  ];
}
