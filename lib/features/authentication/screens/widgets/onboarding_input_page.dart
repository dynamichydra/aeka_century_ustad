import 'package:century_ai/features/home/screens/home.dart';
import 'package:century_ai/utils/constants/colors.dart';
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
    return Padding(
      padding: const EdgeInsets.all(TSizes.defaultSpace),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Image(
                width: THelperFunctions.screenWidth(context) * 0.8,
                height: THelperFunctions.screenHeight(context) * 0.5,
                image: AssetImage(widget.image)),
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(
              height: TSizes.spaceBtwItems,
            ),
            Text(
              widget.subTitle,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TSizes.spaceBtwSections),
            
            // Toggle between Mobile Number and OTP Input
            if (!_showOtpInput) ...[
              TextFormField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Iconsax.call),
                  labelText: 'Mobile Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ] else ...[
              TextFormField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Iconsax.password_check),
                  labelText: 'Enter OTP',
                  border: OutlineInputBorder(),
                ),
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
                    // Navigate to Home Page
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const HomeScreen()),
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
