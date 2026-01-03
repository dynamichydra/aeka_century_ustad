import 'package:century_ai/features/authentication/controllers/onboarding/onboarding_cubit.dart';
import 'package:century_ai/common/widgets/inputs/text_field.dart';
import 'package:century_ai/utils/constants/colors.dart';
import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:century_ai/utils/constants/sizes.dart';
import 'package:century_ai/utils/helpers/helper_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

class OnboardingInputPage extends StatefulWidget {
  const OnboardingInputPage({
    super.key,
    required this.image,
    this.image2,
    required this.title,
    required this.subTitle,
  });

  final String image, title, subTitle;
  final String? image2;

  @override
  State<OnboardingInputPage> createState() => _OnboardingInputPageState();
}

class _OnboardingInputPageState extends State<OnboardingInputPage> {
  @override
  Widget build(BuildContext context) {
    final dark = THelperFunctions.isDarkMode(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TSizes.defaultSpace),
      child: SingleChildScrollView(
        child: BlocBuilder<OnboardingCubit, OnboardingState>(
          builder: (context, state) {
            final isOtpStage = state.isOtpStage;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 62.01),
                Image(
                  width: THelperFunctions.screenWidth(context) * 0.4,
                  height: 70,
                  image: AssetImage(
                    dark ? TImages.lightAppLogo : TImages.darkAppLogo,
                  ),
                ),
                Image(
                  width: THelperFunctions.screenWidth(context) * 0.8,
                  image: AssetImage(TImages.onBoardingImageUssad),
                ),
                const Divider(color: TColors.primary, thickness: 2, height: 2),
                Align(
                  alignment: Alignment.centerRight,

                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    margin: EdgeInsets.only(right: 10),
                    color: TColors.primary,
                    child: Text(

                      "APKA APNA DESIGN GUIDE",
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: TColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: TSizes.spaceBtwSections),
                Container(
                  width: THelperFunctions.screenWidth(context) * 0.5,
                  height: THelperFunctions.screenWidth(context) * 0.5,
                  decoration: BoxDecoration(
                    color: TColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: TColors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Image(
                        width: THelperFunctions.screenWidth(context) * 0.7,
                        height: THelperFunctions.screenWidth(context) * 0.7,
                        fit: BoxFit.contain,
                        image: AssetImage(widget.image),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: TSizes.spaceBtwItems),
                Text(
                  "LAMINATES IDEA IN ONE TAP",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: TColors.black,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: TSizes.spaceBtwSections),
                if (!isOtpStage) ...[
                  const TTextField(
                    labelText: 'Mobile Number',
                    prefixIcon: Icon(Iconsax.call, color: TColors.black),
                    isCircularIcon: true,
                    keyboardType: TextInputType.phone,
                  ),
                ] else ...[
                  const TTextField(
                    labelText: 'Enter OTP',
                    prefixIcon: Icon(Iconsax.password_check, color: TColors.black),
                    isCircularIcon: true,
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: TSizes.spaceBtwItems),
                // Button
                SizedBox(
                  width: THelperFunctions.screenWidth(context) * 0.6,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!isOtpStage) {
                        context.read<OnboardingCubit>().setOtpStage(true);
                      } else {
                        context.go('/');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TColors.primary,
                      side: const BorderSide(color: TColors.primary),
                    ),
                    child: Text(isOtpStage ? 'Send' : 'Get OTP'),
                  ),
                ),
                if (isOtpStage) ...[
                  const SizedBox(height: TSizes.spaceBtwItems),
                  TextButton(
                    onPressed: () {
                      // Handle Resend OTP logic
                    },
                    child: Text(
                      'Resend OTP',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: TColors.black,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

