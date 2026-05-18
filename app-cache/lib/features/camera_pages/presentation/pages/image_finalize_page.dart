import 'package:century_ai/core/constants/image_strings.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:gal/gal.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to prepare image for sharing')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveToGallery() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    
    try {
      // Check and request permission if needed
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission is required to save images.')),
          );
          return;
        }
      }

      final path = await _getLocalImagePath();
      if (path != null) {
        await Gal.putImage(path, album: 'Century Deco Studio');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image saved to gallery in "Century Deco Studio" album!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to prepare image for saving')),
        );
      }
    } catch (e) {
      debugPrint('Save error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving image to gallery: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveToFiles(BuildContext context) async {
    if (_isProcessing) return;
    
    try {
      final path = await _getLocalImagePath();
      if (path != null) {
        // Open native directory picker dialogue
        final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
        
        if (selectedDirectory != null) {
          setState(() => _isProcessing = true);
          
          final String newFileName = 'century_decor_studio_design_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final File sourceFile = File(path);
          final String destinationPath = p.join(selectedDirectory, newFileName);
          
          await sourceFile.copy(destinationPath);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image saved successfully to selected folder!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to prepare image for saving')),
        );
      }
    } catch (e) {
      debugPrint('Save to files error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving image to files: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSaveOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pull Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Save Options",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Choose where you want to save your design.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              _buildSaveOptionCard(
                icon: Icons.photo_library_outlined,
                title: "Save to Photo Gallery",
                description: "Instantly add the image to your system's Photos app.",
                onTap: () {
                  Navigator.pop(sheetContext);
                  _saveToGallery();
                },
              ),
              const SizedBox(height: 12),
              _buildSaveOptionCard(
                icon: Icons.folder_open_outlined,
                title: "Save to Device Files",
                description: "Save to Downloads, local folders, or cloud storage.",
                onTap: () {
                  Navigator.pop(sheetContext);
                  _saveToFiles(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSaveOptionCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.red, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
            child: Image.asset(
              'assets/icons/century_logo.png', // Assuming logo is available
              height: 36,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          )
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Image
                      _buildFinalImage(context),
                      
                      // Content Below Image
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Laminates used",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            if (widget.usedLaminates.isNotEmpty)
                              SizedBox(
                                height: 130,
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

                            const SizedBox(height: 20),
                            const Text(
                              "Created by",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // User Card
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.14),
                                    blurRadius: 3,
                                    offset: const Offset(2, 2),
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
                                            fontWeight: FontWeight.bold, 
                                            fontSize: 13.5,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          "Contractor",
                                          style: TextStyle(color: Colors.grey, fontSize: 10.5),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          "User Id:1234",
                                          style: TextStyle(color: Colors.grey, fontSize: 10.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Divider
                                  Container(
                                    height: 84,
                                    width: 1.0,
                                    color: Colors.red.shade400,
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  
                                  // Right side: Contact Info
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildContactRow(Icons.phone, "+91 7654321908"),
                                        const SizedBox(height: 10),
                                        _buildContactRow(Icons.email, "rahulG@email.com"),
                                        const SizedBox(height: 10),
                                        _buildContactRow(Icons.location_on, "123 Street, Kolkata, West Bengal"),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            const Center(
                              child: Text(
                                "Century Decor Studio",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
                          onTap: () => _showSaveOptionsBottomSheet(context),
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
          borderRadius: BorderRadius.circular(30),
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
      width: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
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

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.45,
      width: double.infinity,
      child: imgWidget,
    );
  }
}
