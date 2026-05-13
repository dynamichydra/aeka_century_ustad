import 'dart:io';
import 'package:image_picker/image_picker.dart';

final ImagePicker _picker = ImagePicker();

/// Pick image from gallery
Future<File?> pickFromGallery() async {
  final XFile? picked =
  await _picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 90,
  );

  if (picked == null) return null;
  return File(picked.path);
}

/// Capture image from camera
Future<File?> pickFromCamera() async {
  final XFile? picked =
  await _picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 90,
  );

  if (picked == null) return null;
  return File(picked.path);
}
