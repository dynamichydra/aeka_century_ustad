import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/constants/sizes.dart';

class GridViewToggleBar extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onToggleView;
  final bool isGridView;

  const GridViewToggleBar({
    super.key,
    required this.onMenuTap,
    required this.onToggleView,
    required this.isGridView,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TSizes.defaultSpace),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          /// MENU
          Builder(
            builder: (context) => Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: onMenuTap,
                icon: const Icon(Iconsax.menu_1, color: Colors.black),
              ),
            ),
          ),

          const SizedBox(width: TSizes.spaceBtwSections),

          /// GRID / LIST TOGGLE
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: onToggleView,
              icon: Icon(
                isGridView ? Icons.grid_view : Icons.view_list,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
