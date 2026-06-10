import 'package:century_ai/features/camera_pages/data/services/image_edit_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'image_edit_state.dart';
import 'package:century_ai/core/constants/image_strings.dart'; // For ProductImageModel
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:century_ai/db/repositories/edit_history_repository.dart';
import 'package:century_ai/db/models/edit_history_data.dart';
import 'dart:typed_data';
import 'package:century_ai/core/services/image_composite_service.dart';

class ImageEditCubit extends Cubit<ImageEditState> {
  final ImageEditService _imageEditService = ImageEditService();

  ImageEditCubit() : super(const ImageEditState());

  void initOriginalImage(
    String imagePath, {
    String? furnitureId,
    String? ownerId,
    String? sessionId,
  }) {
    // Emit a completely fresh state so nothing from the previous session
    // (selected laminate, generated images, success/error messages) leaks in.
    emit(
      ImageEditState(
        originalImage: imagePath,
        furnitureId: furnitureId,
        ownerId: ownerId,
        sessionId: sessionId,
        appliedLayers: const [],
      ),
    );
  }

  void selectPattern(Map<String, dynamic> pattern) {
    emit(state.copyWith(selectedPattern: pattern, hasPatternChanged: true));
    _checkAndGenerate();
  }

  void selectArea(Map<String, dynamic> area) {
    emit(state.copyWith(selectedArea: area, hasAreaChanged: true));
    _checkAndGenerate();
  }

  void clearSelection() {
    emit(
      ImageEditState(
        originalImage: state.originalImage,
        currentGeneratedImage: state.currentGeneratedImage,
        generatedHistory: state.generatedHistory,
        furnitureId: state.furnitureId,
        ownerId: state.ownerId,
        sessionId: state.sessionId,
        selectedPattern: null,
        selectedArea: null,
        isGenerating: false,
        hasPatternChanged: false,
        hasAreaChanged: false,
        appliedLayers: state
            .appliedLayers, // Retain applied layers, just clear the pending selection
      ),
    );
  }

  void _checkAndGenerate() {
    final bool isFirstTime = state.generatedHistory.isEmpty;
    final bool bothSelected =
        state.selectedPattern != null && state.selectedArea != null;
    final bool bothChanged = state.hasPatternChanged && state.hasAreaChanged;

    if (bothSelected && !state.isGenerating) {
      if (isFirstTime || bothChanged) {
        generateAIImage();
      }
    }
  }

  Future<void> generateAIImage() async {
    if (state.originalImage == null ||
        state.selectedPattern == null ||
        state.selectedArea == null)
      return;

    emit(
      state.copyWith(
        isGenerating: true,
        isApplyLoading: true,
        clearError: true,
        clearSuccess: true,
        clearPendingPreview:
            true, // Clear any stale preview from a previous attempt
      ),
    );

    try {
      File roomFile;
      final String baseImageToUse = state.originalImage!;
      if (baseImageToUse.startsWith('http')) {
        final dio = Dio();
        final tempDir = await getTemporaryDirectory();
        final tempPath = p.join(
          tempDir.path,
          "temp_edit_${DateTime.now().millisecondsSinceEpoch}.png",
        );
        await dio.download(baseImageToUse, tempPath);
        roomFile = File(tempPath);
        debugPrint('🌐 Downloaded network image for editing: $tempPath');
      } else {
        roomFile = File(baseImageToUse);
      }

      final textureUrl = state.selectedPattern!["coverImage"]?.toString() ?? "";
      final coordinate = state.selectedArea!;

      debugPrint('🎨 AI_GEN: Starting generation via V2 (preview mode)');

      // Download pattern
      final tempDir = await Directory.systemTemp.createTemp();
      final patternFile = File('${tempDir.path}/pattern_image.png');
      await Dio().download(textureUrl, patternFile.path);

      // AI Service (V2)
      final responseJson = await _imageEditService.tryOnFurnitureV2(
        roomImage: roomFile,
        patternImage: patternFile,
        left: (coordinate['left'] as num).toInt(),
        top: (coordinate['top'] as num).toInt(),
        right: (coordinate['right'] as num).toInt(),
        bottom: (coordinate['bottom'] as num).toInt(),
      );

      final maskBase64 = responseJson['mask'] as String;
      final warpedPatternBase64 = responseJson['warped_pattern'] as String;

      final maskBytes = base64Decode(maskBase64);
      final warpedPatternBytes = base64Decode(warpedPatternBase64);

      // Stack the layers locally for the preview composited result
      final newLayer = LayerPair(
        maskBytes: maskBytes,
        warpedPatternBytes: warpedPatternBytes,
      );

      final previewLayers = List<LayerPair>.from(state.appliedLayers)
        ..add(newLayer);

      // Composite locally
      final Uint8List roomBytes = await roomFile.readAsBytes();
      final Uint8List previewBytes =
          await ImageCompositeService.compositeImages(
            baseImageBytes: roomBytes,
            layers: previewLayers,
          );

      // Save to temp directory only
      final sysTemp = await getTemporaryDirectory();
      final previewFile = File(
        p.join(
          sysTemp.path,
          'preview_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await previewFile.writeAsBytes(previewBytes);
      debugPrint('👁️ Preview written to temp: ${previewFile.path}');

      // Emit PREVIEW state — no composite saved permanently, no SQLite yet
      emit(
        state.copyWith(
          isGenerating: false,
          isApplyLoading: false,
          showSelectionPreview: true,
          pendingMaskBytes: maskBytes,
          pendingWarpedBytes: warpedPatternBytes,
          tempCompositedImagePath: previewFile.path,
          hasPatternChanged: false,
          hasAreaChanged: false,
        ),
      );
    } catch (e) {
      debugPrint("AI Generation Error: $e");
      emit(
        state.copyWith(
          isGenerating: false,
          isApplyLoading: false,
          errorMessage: "Failed to generate AI design: $e",
        ),
      );
    }
  }

  Future<void> compareImageSelected(ProductImageModel image) async {
    // ... existing implementation ...
    emit(
      state.copyWith(
        isCompareLoading: true,
        clearError: true,
        clearSuccess: true,
      ),
    );

    try {
      final response = await _imageEditService.postCompareImageDetails(
        imageCategory: image.category ?? "Interiors",
        subCategory: image.subcategory ?? "",
        nestedSubCategory: image.nestedSubcategory ?? "",
        interiorFurniture: image.name,
        isTrending: image.isTrending,
        isLiked: false,
      );

      debugPrint("Compare Image Details API Response: $response");

      emit(
        state.copyWith(
          isCompareLoading: false,
          successMessage: "Compare image selected details sent.",
        ),
      );
    } catch (e) {
      debugPrint("Compare Image Details API Error: $e");
      emit(
        state.copyWith(
          isCompareLoading: false,
          errorMessage: "Failed to send compare image details: $e",
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2A: Accept — composite permanently but do NOT write SQLite or trigger success message yet
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> acceptPendingDesign({
    String? customSessionId,
    String? parentEditId,
  }) async {
    if (!state.showSelectionPreview ||
        state.pendingMaskBytes == null ||
        state.pendingWarpedBytes == null ||
        state.originalImage == null) {
      debugPrint('⚠️ acceptPendingDesign: no pending preview to accept');
      return;
    }

    emit(state.copyWith(isApplyLoading: true, clearError: true));

    try {
      // ── Stack the accepted layer
      final newLayer = LayerPair(
        maskBytes: state.pendingMaskBytes!,
        warpedPatternBytes: state.pendingWarpedBytes!,
      );
      final updatedLayers = List<LayerPair>.from(state.appliedLayers)
        ..add(newLayer);

      // Promote the temp preview file as the new current image
      final String? acceptedImagePath = state.tempCompositedImagePath;
      debugPrint(
        '✅ Layer accepted — stacked ${updatedLayers.length} layer(s). Preview: $acceptedImagePath',
      );

      final updatedHistory =
          List<Map<String, dynamic>>.from(state.generatedHistory)..add({
            'original': state.originalImage!,
            'generated': acceptedImagePath,
            'laminate': state.selectedPattern,
          });

      emit(
        ImageEditState(
          originalImage: state.originalImage,
          currentGeneratedImage: acceptedImagePath,
          editedImageFile: acceptedImagePath,
          generatedHistory: updatedHistory,
          furnitureId: state.furnitureId,
          ownerId: state.ownerId,
          sessionId: state.sessionId,
          selectedPattern: null,
          selectedArea: null,
          isGenerating: false,
          hasPatternChanged: false,
          hasAreaChanged: false,
          appliedLayers: updatedLayers,
          showSelectionPreview: false,
          pendingMaskBytes: null,
          pendingWarpedBytes: null,
          tempCompositedImagePath: null,
        ),
      );
    } catch (e) {
      debugPrint('❌ acceptPendingDesign error: $e');
      emit(
        state.copyWith(
          isApplyLoading: false,
          errorMessage: 'Failed to accept design: $e',
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2B: Cancel — discard everything, no file write, no SQLite
  // ─────────────────────────────────────────────────────────────────────────
  void rejectPendingDesign() {
    final previewPath = state.tempCompositedImagePath;
    if (previewPath != null) {
      File(previewPath).delete().catchError((_) => File(previewPath));
    }
    emit(
      ImageEditState(
        originalImage: state.originalImage,
        currentGeneratedImage: state.currentGeneratedImage,
        generatedHistory: state.generatedHistory,
        furnitureId: state.furnitureId,
        ownerId: state.ownerId,
        sessionId: state.sessionId,
        selectedPattern: null,
        selectedArea: null,
        isGenerating: false,
        hasPatternChanged: false,
        hasAreaChanged: false,
        appliedLayers: state.appliedLayers,
        showSelectionPreview: false,
        pendingMaskBytes: null,
        pendingWarpedBytes: null,
        tempCompositedImagePath: null,
      ),
    );
    debugPrint('🚫 Pending design rejected — nothing saved.');
  }

  // Deprecated in favor of selectPattern + selectArea automatic flow
  Future<void> applyTextureSelected({
    required File roomImage,
    required String textureUrl,
    required Map<String, dynamic> coordinate,
    required bool isShortTap,
    required bool isLongTap,
  }) async {
    // Forward to new logic for compatibility if needed,
    // but better to use selectPattern/selectArea
    emit(
      state.copyWith(
        selectedPattern: {"coverImage": textureUrl},
        selectedArea: coordinate,
      ),
    );
    await generateAIImage();
  }

  /// Save a specific generated edit to SQLite
  Future<void> saveToDatabase({
    required String imgPath,
    Map<String, dynamic>? laminate,
    String? customSessionId,
    String? parentEditId,
  }) async {
    if (state.furnitureId == null) return;

    try {
      final List<Map<String, dynamic>> sessionLaminates = [];
      for (var hist in state.generatedHistory) {
        if (hist['laminate'] != null) {
          final lam = hist['laminate'] as Map<String, dynamic>;
          if (!sessionLaminates.any((element) => element['id'] == lam['id'])) {
            sessionLaminates.add(lam);
          }
        }
        if (hist['generated'] == imgPath) {
          break;
        }
      }
      if (sessionLaminates.isEmpty && laminate != null) {
        sessionLaminates.add(laminate);
      }

      final editData = EditHistoryData(
        id: customSessionId ?? const Uuid().v4(),
        furnitureId: state.furnitureId!,
        sessionId: customSessionId ?? state.sessionId ?? "default_session",
        originalImagePath: state.originalImage!,
        editedImagePath: imgPath,
        editedAt: DateTime.now(),
        ownerId: state.ownerId ?? "user13@gmail.com",
        usedLaminates: sessionLaminates.isNotEmpty
            ? jsonEncode(sessionLaminates)
            : null,
        laminateName: laminate?['name']?.toString(),
        laminateSku: laminate?['sku']?.toString(),
        parentEditId: parentEditId,
      );

      await EditHistoryRepository.saveEdit(editData);
      debugPrint(
        '✅ Edit saved to SQLite | laminates: ${sessionLaminates.length} | parentEditId: $parentEditId',
      );
    } catch (e) {
      debugPrint('❌ Error saving to SQLite: $e');
    }
  }
}
