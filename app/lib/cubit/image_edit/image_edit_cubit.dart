import 'package:century_ai/features/camera_pages/data/services/image_edit_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'image_edit_state.dart';
import 'package:century_ai/core/constants/image_strings.dart'; // For ProductImageModel
import 'dart:io';
import 'package:dio/dio.dart';

class ImageEditCubit extends Cubit<ImageEditState> {
  final ImageEditService _imageEditService = ImageEditService();

  ImageEditCubit() : super(const ImageEditState());

  void initOriginalImage(String imagePath) {
    emit(state.copyWith(originalImage: imagePath));
  }

  void selectPattern(Map<String, dynamic> pattern) {
    emit(state.copyWith(selectedPattern: pattern));
    _checkAndGenerate();
  }

  void selectArea(Map<String, dynamic> area) {
    emit(state.copyWith(selectedArea: area));
    _checkAndGenerate();
  }

  void _checkAndGenerate() {
    if (state.selectedPattern != null &&
        state.selectedArea != null &&
        !state.isGenerating) {
      generateAIImage();
    }
  }

  Future<void> generateAIImage() async {
    if (state.originalImage == null ||
        state.selectedPattern == null ||
        state.selectedArea == null) return;

    emit(state.copyWith(
      isGenerating: true,
      isApplyLoading: true, // Keep for backward compatibility if needed
      clearError: true,
      clearSuccess: true,
    ));

    try {
      final roomImage = File(state.originalImage!);
      final textureUrl =
          state.selectedPattern!["coverImage"]?.toString() ?? "";
      final coordinate = state.selectedArea!;

      debugPrint('🎨 AI_GEN: Starting generation');
      
      // Download pattern
      final tempDir = await Directory.systemTemp.createTemp();
      final patternFile = File('${tempDir.path}/pattern_image.png');
      await Dio().download(textureUrl, patternFile.path);

      // AI Service
      final resultFile = await _imageEditService.tryOnFurniture(
        roomImage: roomImage,
        patternImage: patternFile,
        x: (coordinate['x'] as num).toInt(),
        y: (coordinate['y'] as num).toInt(),
      );

      final newGeneratedImage = resultFile.path;
      final updatedHistory = List<Map<String, String>>.from(state.generatedHistory);
      updatedHistory.add({
        'original': state.originalImage!,
        'generated': newGeneratedImage,
      });

      emit(state.copyWith(
        isGenerating: false,
        isApplyLoading: false,
        currentGeneratedImage: newGeneratedImage,
        editedImageFile: newGeneratedImage, // Keep for backward compatibility
        generatedHistory: updatedHistory,
        successMessage: "AI design applied successfully.",
      ));
    } catch (e) {
      debugPrint("AI Generation Error: $e");
      emit(state.copyWith(
        isGenerating: false,
        isApplyLoading: false,
        errorMessage: "Failed to generate AI design: $e",
      ));
    }
  }

  Future<void> compareImageSelected(ProductImageModel image) async {
    // ... existing implementation ...
    emit(state.copyWith(
      isCompareLoading: true,
      clearError: true,
      clearSuccess: true,
    ));

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
      
      emit(state.copyWith(
        isCompareLoading: false,
        successMessage: "Compare image selected details sent.",
      ));
    } catch (e) {
      debugPrint("Compare Image Details API Error: $e");
      emit(state.copyWith(
        isCompareLoading: false,
        errorMessage: "Failed to send compare image details: $e",
      ));
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
    emit(state.copyWith(
      selectedPattern: {"coverImage": textureUrl},
      selectedArea: coordinate,
    ));
    await generateAIImage();
  }
}
