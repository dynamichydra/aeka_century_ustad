import 'package:flutter/material.dart';
import '../../constants/colors.dart';

/// Custom Class for Light & Dark Text Themes
class TTextTheme {
  TTextTheme._(); // To avoid creating instances

  /// Customizable Light Text Theme
  static TextTheme lightTextTheme = TextTheme(
    headlineLarge: const TextStyle().copyWith(fontSize: 32.0, fontWeight: FontWeight.bold, color: TColors.pureBlack),
    headlineMedium: const TextStyle().copyWith(fontSize: 24.0, fontWeight: FontWeight.bold, color: TColors.pureBlack),
    headlineSmall: const TextStyle().copyWith(fontSize: 16.0, fontWeight: FontWeight.bold, color: TColors.pureBlack),

    titleLarge: const TextStyle().copyWith(fontSize: 24.0, fontWeight: FontWeight.normal, color: TColors.pureBlack),
    titleMedium: const TextStyle().copyWith(fontSize: 16.0, fontWeight: FontWeight.w600, color: TColors.mediumDarkGray),
    titleSmall: const TextStyle().copyWith(fontSize: 12.0, fontWeight: FontWeight.w400, color: TColors.mediumDarkGray),

    bodyLarge: const TextStyle().copyWith(fontSize: 14.0, fontWeight: FontWeight.w600, color: TColors.pureBlack),
    bodyMedium: const TextStyle().copyWith(fontSize: 14.0, fontWeight: FontWeight.normal, color: TColors.pureBlack),
    bodySmall: const TextStyle().copyWith(fontSize: 14.0, fontWeight: FontWeight.normal, color: TColors.mediumDarkGray),

    labelLarge: const TextStyle().copyWith(fontSize: 12.0, fontWeight: FontWeight.normal, color: TColors.pureBlack),
    labelMedium: const TextStyle().copyWith(fontSize: 12.0, fontWeight: FontWeight.normal, color: TColors.mediumDarkGray),
  );

  /// Customizable Dark Text Theme
  static TextTheme darkTextTheme = TextTheme(
    headlineLarge: const TextStyle().copyWith(fontSize: 24.0, fontWeight: FontWeight.bold, color: TColors.snowWhite),
    headlineMedium: const TextStyle().copyWith(fontSize: 18.0, fontWeight: FontWeight.bold, color: TColors.snowWhite),
    headlineSmall: const TextStyle().copyWith(fontSize: 16.0, fontWeight: FontWeight.w600, color: TColors.snowWhite),

    titleLarge: const TextStyle().copyWith(fontSize: 16.0, fontWeight: FontWeight.bold, color: TColors.snowWhite),
    titleMedium: const TextStyle().copyWith(fontSize: 16.0, fontWeight: FontWeight.w600, color: TColors.snowWhite),
    titleSmall: const TextStyle().copyWith(fontSize: 16.0, fontWeight: FontWeight.w400, color: TColors.snowWhite),

    bodyLarge: const TextStyle().copyWith(fontSize: 14.0, fontWeight: FontWeight.w600, color: TColors.snowWhite),
    bodyMedium: const TextStyle().copyWith(fontSize: 14.0, fontWeight: FontWeight.normal, color: TColors.snowWhite),
    bodySmall: const TextStyle().copyWith(fontSize: 14.0, fontWeight: FontWeight.w400, color: TColors.snowWhite.withOpacity(0.5)),

    labelLarge: const TextStyle().copyWith(fontSize: 12.0, fontWeight: FontWeight.normal, color: TColors.snowWhite),
    labelMedium: const TextStyle().copyWith(fontSize: 12.0, fontWeight: FontWeight.normal, color: TColors.snowWhite.withOpacity(0.5)),
  );
}
