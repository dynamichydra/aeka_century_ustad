import 'package:flutter/material.dart';

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
                          ? (selectedBorderColor ?? const Color(0xFFD9D9D9))
                          : Colors.transparent,
                      width: 6,
                    ),
                  )
                : null,
            child: Padding(padding: const EdgeInsets.all(0), child: child),
          ),
          // const SizedBox(height: TSizes.spaceBtwItems / 2),
          SizedBox(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.normal,
                height: 1.5,
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
            ),
          ),
          if (useUnderline)
            SizedBox(
              width: 40,
              height: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFE30613)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
