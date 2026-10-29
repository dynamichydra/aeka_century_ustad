import 'dart:io';

import 'package:century_ai/features/camera_pages/presentation/pages/image_edit_page.dart';
import 'package:flutter/material.dart';

class ImageEditScrollPage extends StatelessWidget {
  final File imageFile;
  final Color? pickedColor;
  final String? image_id;
  final String? originalImageUrl;
  final String? imageUrl;
  final bool isExterior;

  const ImageEditScrollPage({
    super.key,
    required this.imageFile,
    this.pickedColor,
    this.image_id,
    this.originalImageUrl,
    this.imageUrl,
    this.isExterior = false,
  });

  @override
  Widget build(BuildContext context) {
    return ImageEditPage(
      imageFile: imageFile,
      pickedColor: pickedColor,
      image_id: image_id,
      originalImageUrl: originalImageUrl,
      imageUrl: imageUrl,
      isExterior: isExterior,
      scrollableEditSection: true,
      showTextureDetailOnTap: true,
      textureListHeight: 110,
      textureThumbWidth: 120,
      textureThumbHeight: 80,
    );
  }
}
