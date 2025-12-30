import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:flutter/material.dart';

import 'package:century_ai/utils/device/device_utility.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_functions.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.image,
    required this.title,
    required this.subTitle,
  });

  final String image, title, subTitle;

  @override
  Widget build(BuildContext context) {
    final dark = THelperFunctions.isDarkMode(context);
    return Padding(
      padding: const EdgeInsets.all(TSizes.defaultSpace),
      child: Column(
        children: [
          SizedBox(height: TDeviceUtils.getAppBarHeight()),
          Image(
            width: THelperFunctions.screenWidth(context) * 0.4,
            height: THelperFunctions.screenHeight(context) * 0.15,
            image: AssetImage(dark ? TImages.lightAppLogo : TImages.darkAppLogo),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: TSizes.spaceBtwItems),
          Text(
            subTitle,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: TSizes.spaceBtwSections),
          Image(
              width: THelperFunctions.screenWidth(context) * 0.8,
              height: THelperFunctions.screenHeight(context) * 0.4,
              image: AssetImage(image)),
        ],
      ),
    );
  }
}
