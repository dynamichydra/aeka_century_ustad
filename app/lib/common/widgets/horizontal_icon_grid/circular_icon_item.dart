import 'package:flutter/material.dart';
import '../../../core/constants/sizes.dart';

class CircularIconItem extends StatelessWidget {
  final Widget child;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;
  final Color? selectedBorderColor;
  final double selectedBorderWidth;

  const CircularIconItem({
    super.key,
    required this.child,
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.selectedBorderColor,
    this.selectedBorderWidth = 6,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? (selectedBorderColor ?? Colors.black)
                    : Colors.transparent,
                width: selectedBorderWidth,
              ),
            ),
            child: Padding(padding: const EdgeInsets.all(2), child: child),
          ),
          const SizedBox(height: TSizes.spaceBtwItems / 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
