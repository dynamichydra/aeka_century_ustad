import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/db/models/selected_image_data.dart';
import 'package:century_ai/db/repositories/selected_images_repository.dart';

class PreparedProductImage {
  final File file;
  final String imageId;
  final String category;
  final String? subcategory;

  const PreparedProductImage({
    required this.file,
    required this.imageId,
    required this.category,
    this.subcategory,
  });
}

class ImagePreparationService {
  const ImagePreparationService();

  Future<PreparedProductImage> prepareProductImage({
    required ProductImageModel product,
    required String fallbackCategory,
    String? fallbackSubcategory,
  }) async {
    final category = product.category ?? fallbackCategory;
    final subcategory = product.subcategory ?? fallbackSubcategory;

    // 1. Check if image already exists in database
    final existingData = await SelectedImagesRepository.getImage(product.id);
    if (existingData != null) {
      final existingFile = File(existingData.imagePath);
      if (await existingFile.exists()) {
        return PreparedProductImage(
          file: existingFile,
          imageId: product.itemId ?? product.furnitureId ?? product.id,
          category: category,
          subcategory: subcategory,
        );
      }
      
      // If DB record exists but file is gone, we'll proceed to re-resolve it
      // but we can potentially reconstruct it from existingData.imageData if needed.
    }

    // 2. Resolve image to a local file (using cache for network images)
    final file = await _resolveToLocalFile(
      imagePath: product.image,
      isNetworkImage: product.isNetworkImage,
      productId: product.id,
    );

    // 3. Save to database if it didn't exist
    if (existingData == null) {
      final imageBytes = await file.readAsBytes();
      await SelectedImagesRepository.saveImage(
        SelectedImageData(
          id: product.id,
          imageData: imageBytes,
          imagePath: product.image.startsWith('http') ? product.image : file.path,
          category: category,
          subcategory: subcategory,
          selectedAt: DateTime.now(),
          applicationType: product.applicationType,
          originalImageUrl: product.originalImageUrl,
        ),
      );
    }

    return PreparedProductImage(
      file: file,
      imageId: product.itemId ?? product.furnitureId ?? product.id,
      category: category,
      subcategory: subcategory,
    );
  }

  Future<File> _resolveToLocalFile({
    required String imagePath,
    required bool isNetworkImage,
    required String productId,
  }) async {
    if (isNetworkImage) {
      // Use flutter_cache_manager to get the file (returns instantly if cached)
      final fileInfo = await DefaultCacheManager().getSingleFile(imagePath);
      return fileInfo;
    }

    // For assets, we still need to load and save to temp
    final byteData = await rootBundle.load(imagePath);
    final imageBytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    
    final tempDir = await getTemporaryDirectory();
    // Use a stable filename based on productId to avoid duplicates
    final fileName = 'asset_${productId}_${imagePath.split('/').last}';
    final file = File('${tempDir.path}/$fileName');
    
    if (!(await file.exists())) {
      await file.writeAsBytes(imageBytes);
    }
    
    return file;
  }

  /// Helper to check if an image is already available locally (cache or DB)
  Future<bool> isImageAvailableLocally(String productId, String imagePath, bool isNetwork) async {
    // Check DB
    if (await SelectedImagesRepository.imageExists(productId)) {
      return true;
    }
    
    // Check Network Cache
    if (isNetwork) {
      final fileInfo = await DefaultCacheManager().getFileFromCache(imagePath);
      return fileInfo != null;
    }
    
    return false;
  }
}
