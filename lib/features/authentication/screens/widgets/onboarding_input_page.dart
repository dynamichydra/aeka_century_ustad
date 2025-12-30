import 'package:century_ai/features/home/screens/home.dart';
import 'package:century_ai/utils/constants/colors.dart';
import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:century_ai/utils/constants/sizes.dart';
import 'package:century_ai/utils/helpers/helper_functions.dart';
import 'package:flutter/material.dart';
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
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  borderRadius: BorderRadius.circular(TSizes.inputFieldRadius),
                ),
                child: TextFormField(
                  decoration: InputDecoration(
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: TColors.white,
                        boxShadow: [
                          BoxShadow(
                            color: TColors.borderPrimary,
                            blurRadius: 12,
                            spreadRadius: 2,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(Iconsax.call, color: TColors.black),
                    ),
                    labelText: 'Mobile Number',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),
            ] else ...[
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  borderRadius: BorderRadius.circular(TSizes.inputFieldRadius),
                ),
                child: TextFormField(
                  decoration: InputDecoration(
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: TColors.white,
                        boxShadow: [
                          BoxShadow(
                            color: TColors.borderPrimary,
                            blurRadius: 12,
                            spreadRadius: 2,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Iconsax.password_check,
                        color: TColors.black,
                      ),
                    ),
                    labelText: 'Enter OTP',
                    filled: true,
                    fillColor: TColors.softGrey,
                  ),
                  keyboardType: TextInputType.number,
                ),
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
                    // Navigate to Home Page
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
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
