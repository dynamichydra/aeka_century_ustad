import 'dart:io';

import 'package:century_ai/features/camera_pages/presentation/pages/image_edit_page.dart';
import 'package:flutter/material.dart';

class ImageEditScrollPage extends StatelessWidget {
  final File imageFile;
  final Color? pickedColor;

  const ImageEditScrollPage({
    super.key,
    required this.imageFile,
    this.pickedColor,
  });

  @override
  Widget build(BuildContext context) {
    return ImageEditPage(
      imageFile: imageFile,
      pickedColor: pickedColor,
      scrollableEditSection: true,
      showTextureDetailOnTap: false,
      textureListHeight: 110,
      textureThumbWidth: 120,
      textureThumbHeight: 80,
    );
  }
}
