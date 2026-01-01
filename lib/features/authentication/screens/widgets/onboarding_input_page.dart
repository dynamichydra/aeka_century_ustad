import 'package:century_ai/common/widgets/inputs/text_field.dart';
import 'package:century_ai/utils/constants/colors.dart';
import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:century_ai/utils/constants/sizes.dart';
import 'package:century_ai/utils/helpers/helper_functions.dart';
import 'package:flutter/material.dart';
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
  bool _showOtpInput = false;

  @override
  Widget build(BuildContext context) {
    final dark = THelperFunctions.isDarkMode(context);

    return Padding(
      padding: const EdgeInsets.all(TSizes.defaultSpace),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Image(
              width: THelperFunctions.screenWidth(context) * 0.4,
              height: THelperFunctions.screenHeight(context) * 0.15,
              image: AssetImage(
                dark ? TImages.lightAppLogo : TImages.darkAppLogo,
              ),
            ),
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TSizes.spaceBtwItems),
            Text(
              widget.subTitle,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            Image(
              width: THelperFunctions.screenWidth(context) * 0.5,
              height: THelperFunctions.screenHeight(context) * 0.3,
              image: AssetImage(widget.image),
            ),

            const SizedBox(height: TSizes.spaceBtwSections),

            // Toggle between Mobile Number and OTP Input
            if (!_showOtpInput) ...[
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
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (!_showOtpInput) {
                    setState(() {
                      _showOtpInput = true;
                    });
                  } else {

                    context.go('/');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: TColors.primary,
                  side: const BorderSide(color: TColors.primary),
                ),
                child: Text(_showOtpInput ? 'Send' : 'Get OTP'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
