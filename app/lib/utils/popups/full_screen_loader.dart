import 'package:flutter/material.dart';
import '../../common/widgets/loaders/animation_loader.dart';
import '../../common/widgets/loaders/circular_loader.dart';
import '../constants/colors.dart';
import '../helpers/helper_functions.dart';

/// A utility class for managing a full-screen loading dialog.
class TFullScreenLoader {
  /// Open a full-screen loading dialog with a given text and animation.
  /// This method doesn't return anything.
  ///
  /// Parameters:
  ///   - context: The build context.
  ///   - text: The text to be displayed in the loading dialog.
  ///   - animation: The Lottie animation to be shown.
  static void openLoadingDialog(BuildContext context, String text, String animation) {
    showDialog(
      context: context, 
      barrierDismissible: false, // The dialog can't be dismissed by tapping outside it
      builder: (_) => PopScope(
        canPop: false, // Disable popping with the back button
        child: Container(
          color: THelperFunctions.isDarkMode(context) ? TColors.pureBlack : TColors.pureWhite,
          width: double.infinity,
          height: double.infinity,
          child: Column(
            children: [
              const SizedBox(height: 250), // Adjust the spacing as needed
              TAnimationLoaderWidget(text: text, animation: animation),
            ],
          ),
        ),
      ),
    );
  }

  static void popUpCircular(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: TCircularLoader()),
    );
  }

  /// Stop the currently open loading dialog.
  /// This method doesn't return anything.
  static stopLoading(BuildContext context) {
    Navigator.of(context).pop(); // Close the dialog using the Navigator
  }
}
