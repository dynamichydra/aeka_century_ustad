import 'package:century_ai/features/camera_pages/demo_overlay/overlay_layer_model.dart';

class OverlayEditState {
  final String baseRoomImage;
  final List<OverlayLayer> overlays;
  final bool isGenerating;
  final bool isExporting;
  final String? errorMessage;
  final String? successMessage;
  final String? exportedImagePath;

  OverlayEditState({
    required this.baseRoomImage,
    required this.overlays,
    this.isGenerating = false,
    this.isExporting = false,
    this.errorMessage,
    this.successMessage,
    this.exportedImagePath,
  });

  OverlayEditState copyWith({
    String? baseRoomImage,
    List<OverlayLayer>? overlays,
    bool? isGenerating,
    bool? isExporting,
    String? errorMessage,
    String? successMessage,
    String? exportedImagePath,
  }) {
    return OverlayEditState(
      baseRoomImage: baseRoomImage ?? this.baseRoomImage,
      overlays: overlays ?? this.overlays,
      isGenerating: isGenerating ?? this.isGenerating,
      isExporting: isExporting ?? this.isExporting,
      errorMessage: errorMessage, // We pass null explicitly when resetting errors
      successMessage: successMessage,
      exportedImagePath: exportedImagePath ?? this.exportedImagePath,
    );
  }
}
