import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/sizes.dart';

class TAppBarTheme{
  TAppBarTheme._();

  static const lightAppBarTheme = AppBarTheme(
    elevation: 0,
    centerTitle: false,
    scrolledUnderElevation: 0,
    backgroundColor: TColors.warmGray,
    surfaceTintColor: Colors.white,
    iconTheme: IconThemeData(color: TColors.coolGray, size: TSizes.iconMd),
    actionsIconTheme: IconThemeData(color: TColors.coolGray, size: TSizes.iconMd),
    titleTextStyle: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, color: TColors.nearBlack, fontFamily: 'Helvetica'),
  );
  static const darkAppBarTheme = AppBarTheme(
    elevation: 0,
    centerTitle: false,
    scrolledUnderElevation: 0,
    backgroundColor: TColors.pureBlack,
    surfaceTintColor: TColors.pureBlack,
    iconTheme: IconThemeData(color: TColors.nearBlack, size: TSizes.iconMd),
    actionsIconTheme: IconThemeData(color: TColors.pureWhite, size: TSizes.iconMd),
    titleTextStyle: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, color: TColors.pureWhite, fontFamily: 'Helvetica'),
  );
}