import 'package:flutter/material.dart';
import '../../../core/constants/sizes.dart';

class CircularIconItem extends StatelessWidget {
  final Widget child;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;
  final Color? selectedBorderColor;
  final double selectedBorderWidth;
  final double size;
  final bool useUnderline;
  final bool isCircular;

  const CircularIconItem({
    super.key,
    required this.child,
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.selectedBorderColor,
    this.selectedBorderWidth = 2,
    this.size = 60,
    this.useUnderline = false,
    this.isCircular = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: isCircular
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? (selectedBorderColor ?? const Color(0xFFEEEEEE))
                          : Colors.transparent,
                      width: selectedBorderWidth,
                    ),
                  )
                : null,
            child: Padding(padding: const EdgeInsets.all(2), child: child),
          ),
          const SizedBox(height: TSizes.spaceBtwItems / 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (isSelected && useUnderline)
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 40,
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFFE30613), // Brand Red
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
        ],
      ),
    );
  }
}
