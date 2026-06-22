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
        imageHistory: [imagePath],
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
        imageHistory: state.imageHistory,
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

  /// The current image to use as the base for the next API call.
  /// If we have an edited image, use that; otherwise use the original.
  String? get _currentBaseImage =>
      state.currentGeneratedImage ?? state.originalImage;

  Future<void> generateAIImage() async {
    if (_currentBaseImage == null ||
        state.selectedPattern == null ||
        state.selectedArea == null)
      return;

    emit(
      state.copyWith(
        isGenerating: true,
        isApplyLoading: true,
        clearError: true,
        clearSuccess: true,
      ),
    );

    try {
      File roomFile;
      final String baseImageToUse = _currentBaseImage!;
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

      debugPrint('🎨 AI_GEN: Starting generation via V4 (direct image)');

      // Download pattern
      final tempDir = await Directory.systemTemp.createTemp();
      final patternFile = File('${tempDir.path}/pattern_image.png');
      await Dio().download(textureUrl, patternFile.path);

      // Call V4 API — returns the final edited image directly
      final resultFile = await _imageEditService.tryOnFurnitureV4(
        roomImage: roomFile,
        patternImage: patternFile,
        x1: (coordinate['left'] as num?)?.toInt() ?? (coordinate['x'] as num?)?.toInt() ?? 0,
        y1: (coordinate['top'] as num?)?.toInt() ?? (coordinate['y'] as num?)?.toInt() ?? 0,
        x2: (coordinate['right'] as num?)?.toInt() ?? (coordinate['x'] as num?)?.toInt() ?? 0,
        y2: (coordinate['bottom'] as num?)?.toInt() ?? (coordinate['y'] as num?)?.toInt() ?? 0,
      );

      final newImagePath = resultFile.path;
      debugPrint('✅ V4 edited image saved to: $newImagePath');

      final updatedGenHistory = List<Map<String, dynamic>>.from(state.generatedHistory)..add({
        'original': state.originalImage!,
        'generated': newImagePath,
        'laminate': state.selectedPattern,
      });

      emit(
        ImageEditState(
          originalImage: state.originalImage,
          currentGeneratedImage: newImagePath,
          editedImageFile: newImagePath,
          generatedHistory: updatedGenHistory,
          redoHistory: const [],
          furnitureId: state.furnitureId,
          ownerId: state.ownerId,
          sessionId: state.sessionId,
          selectedPattern: null,
          selectedArea: null,

          isGenerating: false,
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

  /// Undo: pop the last image from history and restore the previous one.
  void undoLastEdit() {
    if (state.generatedHistory.isEmpty) {
      debugPrint('↩️ Nothing to undo — already at original image');
      return;
    }

    final updatedGenHistory = List<Map<String, dynamic>>.from(state.generatedHistory);
    final poppedItem = updatedGenHistory.removeLast();

    final updatedRedoHistory = List<Map<String, dynamic>>.from(state.redoHistory);
    updatedRedoHistory.add(poppedItem);

    final previousImage = updatedGenHistory.isEmpty 
        ? null 
        : updatedGenHistory.last['generated'] as String?;

    emit(
      ImageEditState(
        originalImage: state.originalImage,
        currentGeneratedImage: previousImage,
        editedImageFile: previousImage,
        generatedHistory: updatedGenHistory,
        redoHistory: updatedRedoHistory,
        furnitureId: state.furnitureId,
        ownerId: state.ownerId,
        sessionId: state.sessionId,
        selectedPattern: null,
        selectedArea: null,
        isGenerating: false,
        hasPatternChanged: false,
        hasAreaChanged: false,
      ),
    );
    debugPrint('↩️ Undo successful! History depth: ${updatedGenHistory.length}');
  }

  /// Redo: pop the last image from redoHistory and restore it.
  void redoLastEdit() {
    if (state.redoHistory.isEmpty) {
      debugPrint('↪️ Nothing to redo');
      return;
    }

    final updatedRedoHistory = List<Map<String, dynamic>>.from(state.redoHistory);
    final poppedItem = updatedRedoHistory.removeLast();

    final updatedGenHistory = List<Map<String, dynamic>>.from(state.generatedHistory);
    updatedGenHistory.add(poppedItem);

    final currentImage = poppedItem['generated'] as String?;

    emit(
      ImageEditState(
        originalImage: state.originalImage,
        currentGeneratedImage: currentImage,
        editedImageFile: currentImage,
        generatedHistory: updatedGenHistory,
        redoHistory: updatedRedoHistory,
        furnitureId: state.furnitureId,
        ownerId: state.ownerId,
        sessionId: state.sessionId,
        selectedPattern: null,
        selectedArea: null,
        isGenerating: false,
        hasPatternChanged: false,
        hasAreaChanged: false,
      ),
    );
    debugPrint('↪️ Redo successful! History depth: ${updatedGenHistory.length}');
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
    double? systemArea,
    double? userArea,
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
        systemArea: systemArea,
        userArea: userArea,
      );

      await EditHistoryRepository.saveEdit(editData);
      debugPrint(
        '✅ Edit saved to SQLite | laminates: ${sessionLaminates.length} | parentEditId: $parentEditId | systemArea: $systemArea | userArea: $userArea',
      );
    } catch (e) {
      debugPrint('❌ Error saving to SQLite: $e');
    }
  }
}
