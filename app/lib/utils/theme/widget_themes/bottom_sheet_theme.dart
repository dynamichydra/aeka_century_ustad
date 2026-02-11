import 'package:flutter/material.dart';
import '../../constants/colors.dart';

class TBottomSheetTheme {
  TBottomSheetTheme._();

  static BottomSheetThemeData lightBottomSheetTheme = BottomSheetThemeData(
    showDragHandle: true,
    backgroundColor: TColors.pureWhite,
    modalBackgroundColor: TColors.pureWhite,
    constraints: const BoxConstraints(minWidth: double.infinity),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );

  static BottomSheetThemeData darkBottomSheetTheme = BottomSheetThemeData(
    showDragHandle: true,
    backgroundColor: TColors.nearBlack,
    modalBackgroundColor: TColors.nearBlack,
    constraints: const BoxConstraints(minWidth: double.infinity),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
}
