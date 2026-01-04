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
    required this.title,
    required this.subTitle,
  });

  final String image, title, subTitle;

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
                  height: 100,
                  image: AssetImage(
                    dark ? TImages.lightAppLogo : TImages.darkAppLogo,
                  ),
                ),
                SizedBox(
                  width: THelperFunctions.screenWidth(context) * 0.6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image(
                        image: AssetImage(TImages.onBoardingImageUssad),
                        width: THelperFunctions.screenWidth(context) * 0.5,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 8),
                      const Divider(
                        color: TColors.primary,
                        thickness: 2,
                        height: 2,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          color: TColors.primary,
                          child: Text(
                            "APKA APNA DESIGN GUIDE",
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: TColors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: TSizes.spaceBtwItems),

                SizedBox(
                  width: THelperFunctions.screenWidth(context),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // White Circular Background
                      Container(
                        width: THelperFunctions.screenWidth(context) * 0.7,
                        height: THelperFunctions.screenWidth(context) * 0.7,
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
                      ),
                      // Overflowing Image with Bottom Clipping
                      ClipPath(
                        clipper: TImagePopOutClipper(),
                        child: Image(
                          width: THelperFunctions.screenWidth(context) * 0.8,
                          height: THelperFunctions.screenWidth(context) * 0.8,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          image: AssetImage(widget.image),
                        ),
                      ),
                    ],
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
                    prefixIcon: Icon(
                      Iconsax.password_check,
                      color: TColors.black,
                    ),
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

class TImagePopOutClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    // Circle diameter is 0.7/0.8 of the image width
    final circleRadius = size.width * (0.7 / 0.8) / 2;
    // The center should be at height - radius to match bottomCenter alignment
    final centerY = size.height - circleRadius;

    // Top Rectangle (Full width) - starts from top and goes to the midline of the circle
    path.addRect(Rect.fromLTWH(0, 0, size.width, centerY));

    // Bottom Circle (Diameter matching background)
    path.addOval(
      Rect.fromCircle(
        center: Offset(size.width / 2, centerY),
        radius: circleRadius,
      ),
    );
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}
