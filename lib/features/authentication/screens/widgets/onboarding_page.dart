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
      padding: const EdgeInsets.symmetric(horizontal: TSizes.defaultSpace),
      child: Column(
        children: [
          SizedBox(height: 62.01),
          Image(
            width: THelperFunctions.screenWidth(context) * 0.4,
            image: AssetImage(
              dark ? TImages.lightAppLogo : TImages.darkAppLogo,
            ),
          ),
          const SizedBox(height: TSizes.spaceBtwItems),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: TSizes.spaceBtwItems),
          Text(
            subTitle,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: TSizes.spaceBtwItems),
          Image(
            width: THelperFunctions.screenWidth(context),
            height: THelperFunctions.screenWidth(context),
            image: AssetImage(image),
          ),
        ],
      ),
    );
  }
}
