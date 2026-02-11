import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/sizes.dart';

/* -- Light & Dark Elevated Button Themes -- */
class TElevatedButtonTheme {
  TElevatedButtonTheme._(); //To avoid creating instances


  /* -- Light Theme -- */
  static final lightElevatedButtonTheme  = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 8,
      shadowColor: TColors.dangerRed.withOpacity(0.5),
      foregroundColor: TColors.snowWhite,
      backgroundColor: TColors.dangerRed,
      disabledForegroundColor: TColors.mediumGray,
      disabledBackgroundColor: TColors.cloudGray,
      side: const BorderSide(color: TColors.dangerRed),
      padding: const EdgeInsets.symmetric(vertical: TSizes.buttonHeight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TSizes.buttonRadius)),
      textStyle: const TextStyle(fontSize: 16, color: TColors.pureWhite, fontWeight: FontWeight.w500, fontFamily: 'Urbanist'),
    ),
  );

  /* -- Dark Theme -- */
  static final darkElevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 8,
      shadowColor: TColors.dangerRed.withOpacity(0.5),
      foregroundColor: TColors.snowWhite,
      backgroundColor: TColors.dangerRed,
      disabledForegroundColor: TColors.mediumGray,
      disabledBackgroundColor: TColors.darkGray,
      side: const BorderSide(color: TColors.dangerRed),
      padding: const EdgeInsets.symmetric(vertical: TSizes.buttonHeight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TSizes.buttonRadius)),
      textStyle: const TextStyle(fontSize: 16, color: TColors.pureWhite, fontWeight: FontWeight.w600, fontFamily: 'Urbanist'),
    ),
  );
}
