import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:gal/gal.dart';

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

  Future<void> _handleShare() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    
    try {
      final path = await _getLocalImagePath();
      if (path != null) {
        await Share.shareXFiles(
          [XFile(path)],
          text: 'Check out my design from Century Decor Studio!',
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

  Future<void> _handleSave() async {
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
        SnackBar(content: Text('Error saving image: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              'assets/icons/century_logo.png', // Assuming logo is available
              height: 32,
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
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            if (widget.usedLaminates.isNotEmpty)
                              SizedBox(
                                height: 120,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: widget.usedLaminates.length,
                                  separatorBuilder: (context, index) => const SizedBox(width: 16),
                                  itemBuilder: (context, index) {
                                    final lam = widget.usedLaminates[index];
                                    return _buildLaminateItem(lam);
                                  },
                                ),
                              )
                            else
                              const Text("No laminates applied", style: TextStyle(color: Colors.grey)),

                            const SizedBox(height: 24),
                            const Text(
                              "Created by",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // User Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Left side: User Info
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      children: [
                                        const CircleAvatar(
                                          radius: 24,
                                          backgroundColor: Colors.grey,
                                          backgroundImage: AssetImage('assets/images/placeholder_user.png'), // placeholder
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          "Rahul Ghosh",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const Text(
                                          "Contractor",
                                          style: TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                        const Text(
                                          "User Id:1234",
                                          style: TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Divider
                                  Container(
                                    height: 80,
                                    width: 1.5,
                                    color: Colors.red.shade400,
                                    margin: const EdgeInsets.symmetric(horizontal: 16),
                                  ),
                                  
                                  // Right side: Contact Info
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildContactRow(Icons.phone, "+91 7654321908"),
                                        const SizedBox(height: 12),
                                        _buildContactRow(Icons.email, "rahulG@email.com"),
                                        const SizedBox(height: 12),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleShare,
                          icon: const Icon(Icons.share, color: Colors.black),
                          label: const Text("Share", style: TextStyle(color: Colors.black)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleSave,
                          icon: const Icon(Icons.download, color: Colors.black),
                          label: const Text("Save", style: TextStyle(color: Colors.black)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
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
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildLaminateItem(Map<String, dynamic> lam) {
    final imagePath = lam['coverImage'] ?? '';
    final name = lam['name'] ?? 'Texture';
    final sku = lam['sku'] ?? '${lam['id'] ?? ''}';

    return SizedBox(
      width: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade200,
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
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.black87),
          ),
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
      );
    } else if (image is String) {
      imgWidget = image.startsWith('http')
          ? Image.network(
              image,
              fit: BoxFit.cover,
              width: double.infinity,
            )
          : Image.asset(
              image,
              fit: BoxFit.cover,
              width: double.infinity,
            );
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
