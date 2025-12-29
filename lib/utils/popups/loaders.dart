import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../constants/colors.dart';
import '../helpers/helper_functions.dart';

class TLoaders {
  static hideSnackBar(BuildContext context) => ScaffoldMessenger.of(context).hideCurrentSnackBar();

  static customToast({required BuildContext context, required message}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        width: 500,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.transparent,
        content: Container(
          padding: const EdgeInsets.all(12.0),
          margin: const EdgeInsets.symmetric(horizontal: 30),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: THelperFunctions.isDarkMode(context) ? TColors.darkerGrey.withOpacity(0.9) : TColors.grey.withOpacity(0.9),
          ),
          child: Center(child: Text(message, style: Theme.of(context).textTheme.labelLarge)),
        ),
      ),
    );
  }

  static successSnackBar({required BuildContext context, required title, message = '', duration = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Iconsax.check, color: TColors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: TColors.white, fontWeight: FontWeight.bold)),
                  if (message.isNotEmpty) Text(message, style: const TextStyle(color: TColors.white)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: TColors.primary,
        duration: Duration(seconds: duration),
        margin: const EdgeInsets.all(10),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static warningSnackBar({required BuildContext context, required title, message = ''}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Iconsax.warning_2, color: TColors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: TColors.white, fontWeight: FontWeight.bold)),
                  if (message.isNotEmpty) Text(message, style: const TextStyle(color: TColors.white)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(20),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static errorSnackBar({required BuildContext context, required title, message = ''}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Iconsax.warning_2, color: TColors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: TColors.white, fontWeight: FontWeight.bold)),
                  if (message.isNotEmpty) Text(message, style: const TextStyle(color: TColors.white)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(20),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
