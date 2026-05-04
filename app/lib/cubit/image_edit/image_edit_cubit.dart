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

  Future<void> compareImageSelected(ProductImageModel image) async {
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

  Future<void> applyTextureSelected({
    required File roomImage,
    required String textureUrl,
    required Map<String, dynamic> coordinate,
    required bool isShortTap,
    required bool isLongTap,
  }) async {
    emit(state.copyWith(
      isApplyLoading: true,
      clearError: true,
      clearSuccess: true,
    ));

    try {
      // 1. Download pattern image to a temporary file
      debugPrint('🎨 AI_TRYON_LOG: Starting applyTextureSelected');
      debugPrint('🖼️ AI_TRYON_LOG: Room Image Path: ${roomImage.path}');
      debugPrint('🧪 AI_TRYON_LOG: Texture URL: $textureUrl');

      
      final tempDir = await Directory.systemTemp.createTemp();
      final patternFile = File('${tempDir.path}/pattern_image.png');
      await Dio().download(textureUrl, patternFile.path);
      debugPrint('✅ AI_TRYON_LOG: Pattern downloaded to: ${patternFile.path}');

      // 2. Call the AI service
      final resultFile = await _imageEditService.tryOnFurniture(
        roomImage: roomImage,
        patternImage: patternFile,
        x: (coordinate['x'] as num).toInt(),
        y: (coordinate['y'] as num).toInt(),
      );

      debugPrint('✨ AI_TRYON_LOG: Result received: ${resultFile.path}');

      emit(state.copyWith(
        isApplyLoading: false,
        successMessage: "Texture applied successfully.",
        editedImageFile: resultFile.path,
      ));
    } catch (e) {
      debugPrint("Apply Texture API Error: $e");
      emit(state.copyWith(
        isApplyLoading: false,
        errorMessage: "Failed to apply texture: $e",
      ));
    }
  }
}
