import 'package:century_ai/features/camera_pages/services/image_edit_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'image_edit_state.dart';
import 'package:century_ai/core/constants/image_strings.dart'; // For ProductImageModel

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
        imageCategory: image.imageCategory ?? "Interiors",
        subCategory: image.subCategory ?? "",
        interiorFurniture: image.name,
        isTrending: image.isTrending ?? false,
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

  Future<void> applyTextureSelected(
    String textureId, 
    String textureUrl,
    Map<String, dynamic> coordinate,
    bool isShortTap,
    bool isLongTap,
  ) async {
    emit(state.copyWith(
      isApplyLoading: true,
      clearError: true,
      clearSuccess: true,
    ));

    try {
      final response = await _imageEditService.postApplyTexture(
        selectedId: textureId,
        coordinate: coordinate,
        isShortTap: isShortTap,
        isLongTap: isLongTap,
        selectedTexturePatterns: textureUrl,
      );
      
      debugPrint("Apply Texture API Response: $response");
      
      emit(state.copyWith(
        isApplyLoading: false,
        successMessage: "Texture applied successfully.",
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
