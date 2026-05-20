import 'package:century_ai/core/constants/image_strings.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';

class ImageFinalizePage extends StatefulWidget {
  final dynamic editedImage;
  final List<Map<String, dynamic>> usedLaminates;

  const ImageFinalizePage({
    super.key,
    required this.editedImage,
    this.usedLaminates = const [],
  });

  @override
  State<ImageFinalizePage> createState() => _ImageFinalizePageState();
}

class _ImageFinalizePageState extends State<ImageFinalizePage> {
  bool _isProcessing = false;
  final GlobalKey _shareKey = GlobalKey();

  Future<String?> _getLocalImagePath() async {
    final image = widget.editedImage;
    if (image is File) {
      return image.path;
    } else if (image is String) {
      if (image.startsWith('http')) {
        try {
          final tempDir = await getTemporaryDirectory();
          final tempPath = p.join(
            tempDir.path,
            'century_decor_studio_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await Dio().download(image, tempPath);
          return tempPath;
        } catch (e) {
          debugPrint("Error downloading image: $e");
          return null;
        }
      } else {
        // Check if it is a local absolute path
        if (await File(image).exists()) {
          return image;
        }
        // Otherwise, it's probably an asset path, which requires extraction if we want to save it.
        return null;
      }
    }
    return null;
  }

  Future<void> _handleShare(BuildContext context) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    
    try {
      final RenderRepaintBoundary? boundary = 
          _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary != null) {
        // Capture screenshot of the whole page inside RepaintBoundary
        final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        
        if (byteData != null) {
          final Uint8List pngBytes = byteData.buffer.asUint8List();
          final tempDir = await getTemporaryDirectory();
          final sharePath = p.join(
            tempDir.path,
            'century_decor_studio_design_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          
          final File shareFile = File(sharePath);
          await shareFile.writeAsBytes(pngBytes, flush: true);
          
          final RenderBox? box = context.findRenderObject() as RenderBox?;
          final Rect? rect = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;
 
          await Share.shareXFiles(
            [XFile(sharePath)],
            text: 'Check out my design from Century Decor Studio!',
            sharePositionOrigin: rect,
          );
        } else {
          throw Exception("Failed to convert captured page to bytes");
        }
      } else {
        throw Exception("Failed to locate page render object");
      }
    } catch (e) {
      debugPrint("Error capturing page, falling back to raw image: $e");
      // Fallback: Share only the edited image if the repaint boundary screenshot fails
      try {
        final path = await _getLocalImagePath();
        if (path != null) {
          final RenderBox? box = context.findRenderObject() as RenderBox?;
          final Rect? rect = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;
 
          await Share.shareXFiles(
            [XFile(path)],
            text: 'Check out my design from Century Decor Studio!',
            sharePositionOrigin: rect,
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to prepare image for sharing')),
            );
          }
        }
      } catch (fallbackError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sharing design: $fallbackError')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }


  Future<Directory> _resolveDirectory(String folderLocation) async {
    String cleanPath = folderLocation.trim();
    if (cleanPath.startsWith("Device Storage/")) {
      final subPath = cleanPath.substring("Device Storage/".length);
      final baseDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(p.join(baseDir.path, subPath));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      return targetDir;
    }
    if (cleanPath == "Device Storage") {
      return await getApplicationDocumentsDirectory();
    }
    if (cleanPath.startsWith('/') || cleanPath.contains(':\\') || cleanPath.contains('storage/emulated')) {
      final targetDir = Directory(cleanPath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      return targetDir;
    }
    final baseDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(baseDir.path, cleanPath));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }

  Future<void> _saveWithDetails({
    required String imageName,
    required String folderLocation,
  }) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final path = await _getLocalImagePath();
      if (path != null) {
        final File sourceFile = File(path);
        final bytes = await sourceFile.readAsBytes();
        final Directory targetDir = await _resolveDirectory(folderLocation);
        String finalName = imageName.trim();
        if (finalName.isEmpty) {
          finalName = 'century_design_${DateTime.now().millisecondsSinceEpoch}';
        }
        if (!finalName.toLowerCase().endsWith('.jpg') && 
            !finalName.toLowerCase().endsWith('.jpeg') && 
            !finalName.toLowerCase().endsWith('.png')) {
          finalName = '$finalName.jpg';
        }
        final String targetFilePath = p.join(targetDir.path, finalName);
        final File targetFile = File(targetFilePath);
        await targetFile.writeAsBytes(bytes, flush: true);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image saved successfully to: $targetFilePath'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to prepare image for saving')),
          );
        }
      }
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showSaveDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController(
      text: 'century_design_${DateTime.now().millisecondsSinceEpoch}',
    );
    String locationText = 'Device Storage/Decor Studio/';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              elevation: 12,
              backgroundColor: Colors.white,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 26.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header ──────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Choose where to Save',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              letterSpacing: -0.2,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── File Name Row ─────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.insert_drive_file_outlined,
                              size: 20,
                              color: Colors.black87,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: nameController,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  hintText: 'File name',
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Save Location Row ──────────────────────────────────
                      GestureDetector(
                        onTap: () async {
                          final String? selectedDirectory =
                              await FilePicker.platform.getDirectoryPath(
                            dialogTitle: 'Select Save Folder',
                          );
                          if (selectedDirectory != null) {
                            setDialogState(() {
                              locationText = selectedDirectory;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.folder_rounded,
                                size: 20,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  locationText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Actions ───────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final String name =
                                    nameController.text.trim();
                                Navigator.pop(dialogContext);
                                _saveWithDetails(
                                  imageName: name,
                                  folderLocation: locationText,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade100,
                                foregroundColor: Colors.black87,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Download',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: RepaintBoundary(
                    key: _shareKey,
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Image
                          _buildFinalImage(context),
                          
                          // Content Below Image
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Laminates used",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.normal,
                                    color: Color(0xFF5D5D5D),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                if (widget.usedLaminates.isNotEmpty)
                                  SizedBox(
                                    height: 105,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: widget.usedLaminates.length,
                                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                                      itemBuilder: (context, index) {
                                        final lam = widget.usedLaminates[index];
                                        return _buildLaminateItem(lam);
                                      },
                                    ),
                                  )
                                else
                                  const Text("No laminates applied", style: TextStyle(color: Colors.grey)),

                                const SizedBox(height: 10),
                                const Text(
                                  "Created by",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.normal,
                                    color: Color(0xFF5D5D5D),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // User Card
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Color(0xFFD9D9D9), width: 1),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.14),
                                        blurRadius: 3,
                                        offset: const Offset(3, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Left side: User Info
                                      Expanded(
                                        flex: 4,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const CircleAvatar(
                                              radius: 28,
                                              backgroundColor: Colors.grey,
                                              backgroundImage: AssetImage(TImages.user), // placeholder
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              "Rahul Ghosh",
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12.5,
                                                color: Colors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            const Text(
                                              "Contractor",
                                              style: TextStyle(color: Color(0xFF5D5D5D), fontSize: 10.5),
                                            ),
                                            const SizedBox(height: 2),
                                            const Text(
                                              "User Id:1234",
                                              style: TextStyle(color: Color(0xFF5D5D5D), fontSize: 10.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Divider
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                                        child: Container(
                                          height: 96,
                                          width: 1.0,
                                          color: Colors.red.shade400,
                                          margin: const EdgeInsets.symmetric(horizontal: 8),
                                        ),
                                      ),
                                      
                                      // Right side: Contact Info
                                      Expanded(
                                        flex: 6,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildContactRow(Icons.phone, "+91 7654321908"),
                                            const SizedBox(height: 15),
                                            _buildContactRow(Icons.email, "rahulG@email.com"),
                                            const SizedBox(height: 15),
                                            _buildContactRow(Icons.location_on, "123 Street, Kolkata, West Bengal"),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 10),
                                const Center(
                                  child: Text(
                                    "Century Decor Studio",
                                    style: TextStyle(
                                      color: Color(0xFFFF383C),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Bottom Actions
              Container(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          iconPath: 'assets/icons/app_icons/share.png',
                          label: "Share",
                          onTap: () => _handleShare(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionButton(
                          iconPath: 'assets/icons/app_icons/save.png',
                          label: "Save",
                          onTap: () => _showSaveDialog(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.red),
              ),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.black87),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11, 
              color: Colors.black87,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String iconPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 3,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(0),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  iconPath,
                  width: 20,
                  height: 20,
                  color: Colors.black,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    label == "Share" ? Icons.share : Icons.download,
                    size: 20,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLaminateItem(Map<String, dynamic> lam) {
    final imagePath = lam['coverImage'] ?? lam['imageUrl'] ?? lam['image'] ?? lam['cover_image'] ?? '';
    final name = lam['name'] ?? 'Texture';
    final sku = lam['sku'] ?? lam['code'] ?? '${lam['id'] ?? ''}';

    return SizedBox(
      width: 75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade100,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              image: imagePath.isNotEmpty
                  ? DecorationImage(
                      image: imagePath.startsWith('http')
                          ? NetworkImage(imagePath) as ImageProvider
                          : AssetImage(imagePath),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 2),
          Text(
            sku,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalImage(BuildContext context) {
    final image = widget.editedImage;
    Widget imgWidget;

    if (image is File) {
      imgWidget = Image.file(
        image,
        fit: BoxFit.cover,
        width: double.infinity,
        cacheWidth: 600,
      );
    } else if (image is String) {
      if (image.startsWith('http')) {
        imgWidget = Image.network(
          image,
          fit: BoxFit.cover,
          width: double.infinity,
          cacheWidth: 600,
        );
      } else if (image.startsWith('/') || image.contains('data/user') || image.contains('emulator') || image.contains('storage/emulated')) {
        imgWidget = Image.file(
          File(image),
          fit: BoxFit.cover,
          width: double.infinity,
          cacheWidth: 600,
        );
      } else {
        imgWidget = Image.asset(
          image,
          fit: BoxFit.cover,
          width: double.infinity,
          cacheWidth: 600,
        );
      }
    } else {
      imgWidget = const Center(child: Icon(Icons.image_not_supported));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.40,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(child: imgWidget),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/logos/small_logo.png',
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
