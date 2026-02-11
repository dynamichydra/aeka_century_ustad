import 'package:flutter/material.dart';
import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/core/constants/sizes.dart';

class SectionHeader extends StatelessWidget {
  /// Left side (text / avatar / custom)
  final Widget leading;

  /// Right side action (View all / icon / custom)
  final Widget? trailing;

  const SectionHeader({super.key, required this.leading, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: leading),
        if (trailing != null) trailing!,
      ],
    );
  }
}
