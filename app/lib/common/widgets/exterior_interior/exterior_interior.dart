import 'package:flutter/material.dart';

class ExteriorInteriorSwitchSlider extends StatefulWidget {
  const ExteriorInteriorSwitchSlider({super.key});

  @override
  State<ExteriorInteriorSwitchSlider> createState() =>
      _ExteriorInteriorSwitchSliderState();
}

class _ExteriorInteriorSwitchSliderState
    extends State<ExteriorInteriorSwitchSlider> {
  bool isExterior = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          isExterior = !isExterior;
        });
      },
      child: Container(
        width: 100, // smaller width to fit row
        height: 28, // smaller height
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0xFFD9D9D9), // background color
          borderRadius: BorderRadius.circular(14), // half height for pill
          border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
        ),
        child: Stack(
          children: [
            // Sliding selected background
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: isExterior
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Container(
                width: 48, // half of container width
                height: 24,
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
                      'Exterior',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isExterior
                            ? const Color(0xFF898888)
                            : const Color(0xFF898888).withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Interior',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: !isExterior
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
