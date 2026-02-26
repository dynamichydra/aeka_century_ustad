import 'package:flutter/material.dart';

class ProductContainers extends StatelessWidget {
  final String imagePath;
  final bool isTrending;

  const ProductContainers({
    super.key,
    required this.imagePath,
    required this.isTrending,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 200, // 👈 set your container height
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12), // optional
        child: Stack(
          fit: StackFit.expand, // 👈 image fills whole container
          children: [
            Image.asset(imagePath, fit: BoxFit.cover),

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
