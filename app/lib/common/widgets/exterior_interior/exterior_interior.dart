import 'package:flutter/material.dart';

class ExteriorInteriorSwitchSlider extends StatelessWidget {
  const ExteriorInteriorSwitchSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 140, // smaller width to fit row
        height: 28, // smaller height
        padding: const EdgeInsets.all(0.2),
        decoration: BoxDecoration(
          color: const Color(0xFFCCCCCC), // background color
          borderRadius: BorderRadius.circular(14), // half height for pill
          border: Border.all(color: const Color(0xFFD9D9D9), width: 0),
        ),
        child: Stack(
          children: [
            // Inner outline and true soft inset shadow
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      // Base shadow (dark)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                      ),
                      // Light highlight on bottom
                      BoxShadow(
                        color: Colors.white.withOpacity(0.6),
                        spreadRadius: -1.0,
                        blurRadius: 3.0,
                        offset: const Offset(0, 2),
                      ),
                      // Center track background color that softens outwards
                      const BoxShadow(
                        color: Color(0xFFCCCCCC),
                        spreadRadius: -2.0,
                        blurRadius: 4.0,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFEEEEEE),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            // Sliding selected background
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 70, // half of container width
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            // Text labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'Interior',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: !value
                            ? const Color(0xFF898888)
                            : const Color(0xFF898888).withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Exterior',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: value
                            ? const Color(0xFF898888)
                            : const Color(0xFF898888).withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
