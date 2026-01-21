import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:share_plus/share_plus.dart';
import 'package:century_ai/features/home/screens/widgets/home_drawer.dart';
import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:century_ai/utils/constants/sizes.dart';

class ImageFinalizePage extends StatelessWidget {
  final File editedImage;
  final Map<String, dynamic> selectedColor;
  final Map<String, dynamic> selectedLamination;

  const ImageFinalizePage({
    super.key,
    required this.editedImage,
    required this.selectedColor,
    required this.selectedLamination,
  });

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      drawer: const HomeDrawer(),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              /// ---------------- IMAGE AREA ----------------
              SafeArea(
                bottom: false,
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: Image.file(
                    editedImage,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),

              /// ---------------- BOTTOM PANEL ----------------
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Design",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                        ),
                      ),
                      const Text(
                        "AI Based Color & Pattern Search",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Selected Color Section
                      Text(
                        "Selected Color : ${selectedColor['name']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildColorCircle(_parseHex(selectedColor['hex'])),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Variant Section
                      Text(
                        "Variant: ${selectedColor['id']} SL",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Pattern & Texture Section
                      const Text(
                        "Pattern & Texture",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildTextureItem(
                            selectedLamination['name'],
                            "${selectedLamination['id']} SL",
                            selectedLamination['image'],
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(Icons.bookmark_outline, () {}),
                          _buildActionButton(Icons.delete_outline, () => context.pop()),
                          _buildActionButton(Icons.share_outlined, () {
                            Share.shareXFiles([XFile(editedImage.path)], text: 'Check out my design!');
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Custom Header (Menu & Logo)
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Iconsax.menu_1, color: Colors.black),
                  onPressed: () => scaffoldKey.currentState?.openDrawer(),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: TSizes.defaultSpace),
                  child: Image(
                    image: AssetImage(TImages.smallLogo),
                    width: 30,
                    height: 30,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorCircle(Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
    );
  }

  Color _parseHex(String hex) {
    hex = hex.replaceAll("#", "");
    return Color(int.parse("FF$hex", radix: 16));
  }

  Widget _buildTextureItem(String name, String code, String imagePath) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          height: 45,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F1F1),
            borderRadius: BorderRadius.circular(4),
            image: DecorationImage(
              image: AssetImage(imagePath),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
        ),
        Text(
          code,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 4,
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 24, color: Colors.black),
      ),
    );
  }
}
