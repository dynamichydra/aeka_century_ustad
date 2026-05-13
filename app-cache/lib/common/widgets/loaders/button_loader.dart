import 'package:century_ai/core/constants/colors.dart';
import 'package:flutter/material.dart';

/// A premium button loader widget using a white circular indicator.
class TButtonLoader extends StatelessWidget {
  const TButtonLoader({
    super.key,
    this.size = 20,
    this.color = TColors.pureWhite,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: size,
        width: size,
        child: CircularProgressIndicator(
          color: color,
          strokeWidth: 3,
        ),
      ),
    );
  }
}
