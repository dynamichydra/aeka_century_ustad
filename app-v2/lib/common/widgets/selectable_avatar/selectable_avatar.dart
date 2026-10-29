import 'package:flutter/material.dart';

class SelectableAvatar extends StatelessWidget {
  final String imageUrl;
  final String name;
  final bool isSelected;
  final double avatarSize;
  final double borderWidth;
  final VoidCallback? onTap;

  const SelectableAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    this.isSelected = false,
    this.avatarSize = 56,
    this.borderWidth = 3,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double totalSize = avatarSize + borderWidth * 2;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            width: totalSize,
            height: totalSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isSelected)
                  Container(
                    width: totalSize,
                    height: totalSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: borderWidth,
                      ),
                    ),
                  ),
                CircleAvatar(
                  radius: avatarSize / 2,
                  backgroundImage: NetworkImage(imageUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
