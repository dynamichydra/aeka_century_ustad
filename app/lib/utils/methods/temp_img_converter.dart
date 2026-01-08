import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<File> assetImageToTempFile(String assetPath) async {
  // Load asset as bytes
  final byteData = await rootBundle.load(assetPath);
  final Uint8List bytes = byteData.buffer.asUint8List();

  // Get temp directory
  final tempDir = await getTemporaryDirectory();

  // Create a file path
  final fileName = p.basename(assetPath);
  final file = File('${tempDir.path}/$fileName');

  // Write bytes to file
  await file.writeAsBytes(bytes, flush: true);

  return file;
}
