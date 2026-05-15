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
    emit(ImageEditState(
      originalImage: imagePath,
      furnitureId: furnitureId,
      ownerId: ownerId,
      sessionId: sessionId,
    ));
  }

  void selectPattern(Map<String, dynamic> pattern) {
    emit(state.copyWith(selectedPattern: pattern, hasPatternChanged: true));
    _checkAndGenerate();
  }

  void selectArea(Map<String, dynamic> area) {
    emit(state.copyWith(selectedArea: area, hasAreaChanged: true));
    _checkAndGenerate();
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
        isApplyLoading: true, // Keep for backward compatibility if needed
        clearError: true,
        clearSuccess: true,
      ),
    );

    try {
      File roomFile;
      final String baseImageToUse = state.currentGeneratedImage ?? state.originalImage!;
      if (baseImageToUse.startsWith('http')) {
        // DOWNLOAD NETWORK IMAGE TO TEMP FILE
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

      debugPrint('🎨 AI_GEN: Starting generation');

      // Download pattern
      final tempDir = await Directory.systemTemp.createTemp();
      final patternFile = File('${tempDir.path}/pattern_image.png');
      await Dio().download(textureUrl, patternFile.path);

      // AI Service
      final resultFile = await _imageEditService.tryOnFurniture(
        roomImage: roomFile,
        patternImage: patternFile,
        x: (coordinate['x'] as num).toInt(),
        y: (coordinate['y'] as num).toInt(),
      );

      final newGeneratedImage = resultFile.path;

      // PERSISTENT STORAGE: Copy from temp to documents directory
      String persistentPath = newGeneratedImage;
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        final editDir = Directory(p.join(appDocDir.path, 'edits'));
        if (!await editDir.exists()) {
          await editDir.create(recursive: true);
        }

        final fileName = 'edit_${DateTime.now().millisecondsSinceEpoch}.png';
        final savedFile = await resultFile.copy(p.join(editDir.path, fileName));
        persistentPath = savedFile.path;
        debugPrint(
          '💾 Saved edited image to permanent storage: $persistentPath',
        );
      } catch (e) {
        debugPrint('❌ Failed to save to permanent storage, using temp: $e');
      }

      final updatedHistory = List<Map<String, dynamic>>.from(
        state.generatedHistory,
      );
      updatedHistory.add({
        'original': state.originalImage!,
        'generated': persistentPath,
        'laminate': state.selectedPattern, // STORE LAMINATE DETAILS
      });

      emit(
        state.copyWith(
          isGenerating: false,
          isApplyLoading: false,
          currentGeneratedImage: persistentPath,
          editedImageFile: persistentPath, // Keep for backward compatibility
          originalImage: persistentPath, // UPDATE BASE FOR STACKING
          generatedHistory: updatedHistory,
          hasPatternChanged: false,
          hasAreaChanged: false,
          successMessage: "AI design applied successfully.",
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
  }) async {
    if (state.furnitureId == null) return;

    try {
      final editData = EditHistoryData(
        id: const Uuid().v4(),
        furnitureId: state.furnitureId!,
        sessionId: state.sessionId ?? "default_session",
        originalImagePath: state.originalImage!,
        editedImagePath: imgPath,
        editedAt: DateTime.now(),
        ownerId: state.ownerId ?? "anisasru1@gmail.com",
        usedLaminates: laminate != null ? jsonEncode(laminate) : null,
        laminateName: laminate?['name']?.toString(),
        laminateSku: laminate?['sku']?.toString(),
      );

      await EditHistoryRepository.saveEdit(editData);
      debugPrint('✅ Edit saved to SQLite with laminates: ${laminate?['name']}');
    } catch (e) {
      debugPrint('❌ Error saving to SQLite: $e');
    }
  }
}
