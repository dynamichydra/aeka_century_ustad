import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
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
    final file = await _resolveToLocalFile(
      imagePath: product.image,
      isNetworkImage: product.isNetworkImage,
    );
    final imageBytes = await file.readAsBytes();
    final category = product.category ?? fallbackCategory;
    final subcategory = product.subcategory ?? fallbackSubcategory;

    await SelectedImagesRepository.saveImage(
      SelectedImageData(
        id: product.id,
        imageData: imageBytes,
        imagePath: file.path,
        category: category,
        subcategory: subcategory,
        selectedAt: DateTime.now(),
      ),
    );

    return PreparedProductImage(
      file: file,
      imageId: product.id,
      category: category,
      subcategory: subcategory,
    );
  }

  Future<File> _resolveToLocalFile({
    required String imagePath,
    required bool isNetworkImage,
  }) async {
    if (isNetworkImage) {
      final response = await http.get(Uri.parse(imagePath));
      if (response.statusCode != 200) {
        throw Exception('Failed to download image: ${response.statusCode}');
      }

      final tempDir = await getTemporaryDirectory();
      final fileName =
          'downloaded_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      return file;
    }

    final byteData = await rootBundle.load(imagePath);
    final imageBytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    final tempDir = await getTemporaryDirectory();
    final fileName = imagePath.replaceAll('/', '_');
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(imageBytes);
    return file;
  }
}
