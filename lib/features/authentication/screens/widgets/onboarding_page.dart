import 'package:century_ai/features/authentication/controllers/onboarding/onboarding_cubit.dart';
import 'package:century_ai/utils/constants/colors.dart';
import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:century_ai/utils/device/device_utility.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_functions.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.image,
    this.image2,
    required this.title,
    required this.subTitle,
  });

  final String image, title, subTitle;
  final String? image2;

  @override
  Widget build(BuildContext context) {
    final dark = THelperFunctions.isDarkMode(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TSizes.defaultSpace),
      child: Column(
        children: [
          const Spacer(flex: 2), // Top flexible space
          Image(
            width: THelperFunctions.screenWidth(context) * 0.4,
            height: 70,
            image: AssetImage(
              dark ? TImages.lightAppLogo : TImages.darkAppLogo,
            ),
          ),
          const Spacer(flex: 1), // Space between logo and text
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
          const Spacer(flex: 1), // Space between text and image
          Flexible(
            flex: 8, // Main image takes most of the remaining space
            child: BlocBuilder<OnboardingCubit, OnboardingState>(
              builder: (context, state) {
                final showSecondImage = state.isSecondImage && image2 != null;
                return Image(
                  width: THelperFunctions.screenWidth(context),
                  height: THelperFunctions.screenWidth(context),
                  fit: BoxFit.contain, // Ensure image fits responsibly
                  image: AssetImage(showSecondImage ? image2! : image),
                );
              },
            ),
          ),
          const Spacer(flex: 4), // Space for bottom navigation area
        ],
      ),
    );
  }
}


