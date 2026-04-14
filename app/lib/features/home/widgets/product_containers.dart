import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ProductContainers extends StatelessWidget {
  final String imagePath;
  final bool isTrending;

  final bool isNetwork;
  final String? id;

  const ProductContainers({
    super.key,
    required this.imagePath,
    required this.isTrending,
    this.isNetwork = false,
    this.id,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12), // optional
        child: Stack(
          fit: StackFit.expand, // 👈 image fills whole container
          children: [
            isNetwork
                ? CachedNetworkImage(
                    imageUrl: imagePath,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  )
                : Image.asset(imagePath, fit: BoxFit.cover),

            // 🔹 Top Left Icon
            if (isTrending == true)
              Positioned(
                top: 13,
                left: 12,
                child: Image.asset(
                  "assets/icons/app_icons/trending.png",
                  width: 20,
                  height: 20,
                ),
              ),

            // 🔹 Top Right Icon
            Positioned(
              top: 0,
              right: 6,
              child: IconButton(
                onPressed: () {},
                icon: Icon(Icons.favorite_border, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
