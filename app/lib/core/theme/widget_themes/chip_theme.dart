import 'package:flutter/material.dart';
import '../../constants/colors.dart';

class TChipTheme {
  TChipTheme._();

  static ChipThemeData lightChipTheme = ChipThemeData(
    checkmarkColor: TColors.pureWhite,
    selectedColor: TColors.dangerRed,
    disabledColor: TColors.lightGray.withOpacity(0.4),
    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
    labelStyle: const TextStyle(color: TColors.nearBlack, fontFamily: 'Urbanist'),
  );

  static ChipThemeData darkChipTheme = const ChipThemeData(
    checkmarkColor: TColors.pureWhite,
    selectedColor: TColors.dangerRed,
    disabledColor: TColors.darkGray,
    padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
    labelStyle: TextStyle(color: TColors.pureWhite, fontFamily: 'Urbanist'),
  );
}
