import 'package:century_ai/features/authentication/controllers/onboarding/onboarding_cubit.dart';
import 'package:century_ai/features/authentication/screens/widgets/onboarding_input_page.dart';
import 'package:century_ai/features/authentication/screens/widgets/onboarding_page.dart';
import 'package:century_ai/utils/constants/colors.dart';
import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:century_ai/utils/constants/sizes.dart';
import 'package:century_ai/utils/constants/text_strings.dart';
import 'package:century_ai/utils/device/device_utility.dart';
import 'package:century_ai/utils/helpers/helper_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class Onboarding extends StatelessWidget {
  const Onboarding({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = OnboardingCubit();
    // PageController to handle swiping
    final pageController = PageController();

    return BlocProvider(
      create: (_) => controller,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Horizontal Scrollable Page
            BlocListener<OnboardingCubit, int>(
              listener: (context, state) {
                // Animate to the page when state changes (e.g. from dot click or skip)
                 if (pageController.hasClients && pageController.page != state.toDouble()) {
                  pageController.animateToPage(
                    state,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: PageView(
                  controller: pageController,
                  onPageChanged: controller.updatePageIndicator,
                  children: const [
                    OnboardingPage(
                      image: TImages.onBoardingImage1,
                      title: TTexts.onBoardingTitle1,
                      subTitle: TTexts.onBoardingSubTitle1,
                    ),
                    OnboardingPage(
                      image: TImages.onBoardingImage2,
                      title: TTexts.onBoardingTitle2,
                      subTitle: TTexts.onBoardingSubTitle2,
                    ),
                    OnboardingInputPage(
                      image: TImages.onBoardingImage3,
                      title: TTexts.onBoardingTitle3,
                      subTitle: TTexts.onBoardingSubTitle3,
                    ),
                  ],
                ),
              ),
            ),

            // Skip Button
            const OnBoardingSkip(),

            // Dot Navigation SmoothPageIndicator
            OnBoardingDotNavigation(pageController: pageController),

            // NEXT Button (Circular) - Optional, but keeping standard structure. 
            // Since the last page is input, we might want to hide this on the last page.
            // OnBoardingNextButton(pageController: pageController),
          ],
        ),
      ),
    );
  }
}

class OnBoardingSkip extends StatelessWidget {
  const OnBoardingSkip({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: TDeviceUtils.getAppBarHeight(),
      right: TSizes.defaultSpace,
      child: BlocBuilder<OnboardingCubit, int>(
        builder: (context, state) {
          // Hide Skip button on the last page
          if (state == 2) return const SizedBox.shrink();
          
          return TextButton(
            onPressed: () => context.read<OnboardingCubit>().skipPage(),
            child: const Text('Skip'),
          );
        },
      ),
    );
  }
}

class OnBoardingDotNavigation extends StatelessWidget {
  const OnBoardingDotNavigation({
    super.key,
    required this.pageController,
  });

  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    final dark = THelperFunctions.isDarkMode(context);

    return Positioned(
      bottom: TDeviceUtils.getBottomNavigationBarHeight(),
      left: 0,
      right: 0,
      child: Center(
        child: SmoothPageIndicator(
          controller: pageController,
          onDotClicked: (index) => context.read<OnboardingCubit>().dotNavigationClick(index),
          count: 3,
          effect: WormEffect(
              activeDotColor: dark ? TColors.light : TColors.dark,
              dotHeight: 12, // Increased size for circle
              dotWidth: 12,
          ),
        ),
      ),
    );
  }
}

class OnBoardingNextButton extends StatelessWidget {
  const OnBoardingNextButton({
    super.key,
    required this.pageController,
  });

  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    final dark = THelperFunctions.isDarkMode(context);
    
    return Positioned(
      right: 0,
      left: 0,
      bottom: TDeviceUtils.getBottomNavigationBarHeight(),
      child: BlocBuilder<OnboardingCubit, int>(
        builder: (context, state) {
           // Hide Next button on the last page because we have "Get OTP"
           if (state == 2) return const SizedBox.shrink();

           return ElevatedButton(
            onPressed: () => context.read<OnboardingCubit>().nextPage(),
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor: dark ? TColors.primary : Colors.black,
            ),
            child: const Icon(Iconsax.arrow_right_3),
          );
        },
      ),
    );
  }
}
