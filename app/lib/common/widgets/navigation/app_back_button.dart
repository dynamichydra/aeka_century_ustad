import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

class AppBackButton extends StatelessWidget {
  final Color? iconColor;
  final double size;

  const AppBackButton({super.key, this.iconColor, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Iconsax.arrow_left_2,
        size: size,
        color: iconColor ?? Colors.black,
      ),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          Navigator.of(context).maybePop();
        }
      },
    );
  }
}
