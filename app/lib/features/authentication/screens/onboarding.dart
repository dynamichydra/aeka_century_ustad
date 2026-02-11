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
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({Key? key}) : super(key: key);

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  late final OnboardingCubit controller;
  late final PageController pageController;

  @override
  void initState() {
    super.initState();
    controller = OnboardingCubit();
    pageController = PageController();
  }

  @override
  void dispose() {
    controller.close();
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => controller,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: TColors.paleGray,
        body: Stack(
          children: [
            // Horizontal Scrollable Page
            BlocListener<OnboardingCubit, OnboardingState>(
              listener: (context, state) {
                if (pageController.hasClients) {
                  final currentPage = pageController.page?.round() ?? 0;
                  if (currentPage != state.pageIndex) {
                    pageController.animateToPage(
                      state.pageIndex,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                }
              },
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
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
                      image: TImages.onBoardingImage4,
                      title: TTexts.onBoardingTitle2,
                      subTitle: TTexts.onBoardingSubTitle2,
                    ),
                    OnboardingInputPage(
                      image: TImages.onBoardingImage6,
                      title: TTexts.onBoardingTitle3,
                      subTitle: TTexts.onBoardingSubTitle3,
                    ),
                  ],
                ),
              ),
            ),

            // Skip Button
            const OnBoardingSkip(),

            // Top Left Image
            Positioned(
              top: TDeviceUtils.getAppBarHeight() - 20,
              left: 0,
              child: const Image(
                image: AssetImage(TImages.onBoardingImageTopLeft),
              ),
            ),

            Positioned(
              bottom: 0,
              right: 0,
              child: const Image(
                image: AssetImage(TImages.onBoardingImageBottomRight),
              ),
            ),

            // Dot Navigation SmoothPageIndicator
            OnBoardingDotNavigation(pageController: pageController),
          ],
        ),
      ),
    );
  }
}

class OnBoardingSkip extends StatelessWidget {
  const OnBoardingSkip({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 36,
      right: TSizes.defaultSpace,
      child: BlocBuilder<OnboardingCubit, OnboardingState>(
        builder: (context, state) {
          // Hide Skip button on the last page
          if (state.pageIndex == 2) return const SizedBox.shrink();

          return TextButton(
            onPressed: () => context.read<OnboardingCubit>().skipPage(),
            child: Text(
              'Skip',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: TColors.nearBlack,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }
}

class OnBoardingDotNavigation extends StatelessWidget {
  const OnBoardingDotNavigation({super.key, required this.pageController});

  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    final dark = THelperFunctions.isDarkMode(context);

    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        if (state.isOtpStage) return const SizedBox.shrink();

        return Positioned(
          bottom: TDeviceUtils.getBottomNavigationBarHeight() * 0.3,
          left: TSizes.defaultSpace,
          right: TSizes.defaultSpace,
          child: Column(
            children: [
              Center(
                child: SmoothPageIndicator(
                  controller: pageController,
                  onDotClicked: (index) =>
                      context.read<OnboardingCubit>().dotNavigationClick(index),
                  count: 3,
                  effect: WormEffect(
                    activeDotColor: dark
                        ? TColors.snowWhite
                        : TColors.coolGray,
                    dotHeight: 12,
                    dotWidth: 12,
                  ),
                ),
              ),
              const SizedBox(height: TSizes.spaceBtwItems),
              Center(
                child: BlocBuilder<OnboardingCubit, OnboardingState>(
                  builder: (context, state) {
                    // Strictly hide Next button on the final page
                    if (state.pageIndex == 2) return const SizedBox.shrink();

                    return TextButton(
                      onPressed: () {
                        context.read<OnboardingCubit>().nextPage();
                      },
                      child: Text(
                        'Next',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: TColors.nearBlack,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
