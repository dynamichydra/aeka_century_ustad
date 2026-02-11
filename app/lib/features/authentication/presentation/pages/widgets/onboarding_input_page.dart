import 'package:century_ai/features/authentication/controllers/onboarding/onboarding_cubit.dart';
import 'package:century_ai/common/widgets/inputs/text_field.dart';
import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/core/constants/sizes.dart';
import 'package:century_ai/data/repositories/auth_repository.dart';
import 'package:century_ai/data/services/api_service.dart';
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
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  late final AuthRepository _authRepository;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _authRepository = AuthRepository(ApiService());
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleAction(BuildContext context, bool isOtpStage) async {
    if (_isSubmitting) return;

    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      if (!isOtpStage) {
        if (phone.isEmpty) throw Exception('Please enter mobile number.');
        await _authRepository.requestOtp(phone);
        if (!mounted) return;
        context.read<OnboardingCubit>().setOtpStage(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dummy OTP sent. Use 1234 to continue.')),
        );
      } else {
        if (otp.isEmpty) throw Exception('Please enter OTP.');
        await _authRepository.verifyOtp(phone: phone, otp: otp);
        if (!mounted) return;
        context.go('/');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 0,
                        ),
                        color: TColors.dangerRed,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            "USTAAD",
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 32,
                                  color: Colors.white,
                                  fontFamily: "Helvatica",
                                  height: 1,
                                ),
                          ),
                        ),
                      ),
                      SizedBox(height: 3),
                      const Divider(
                        color: TColors.dangerRed,
                        thickness: 2,
                        height: 2,
                      ),
                      Align(
                        alignment: Alignment.centerRight,

                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          margin: EdgeInsets.only(right: 8),
                          color: TColors.dangerRed,
                          child: Text(
                            "APKA APNA DESIGN GUIDE",
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: TColors.pureWhite,
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
                        width: THelperFunctions.screenWidth(context) * 0.5,
                        height: THelperFunctions.screenWidth(context) * 0.5,
                        decoration: BoxDecoration(
                          color: TColors.pureWhite,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: TColors.nearBlack.withValues(alpha: 0.1),
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
                          width: THelperFunctions.screenWidth(context) * 0.55,
                          height: THelperFunctions.screenWidth(context) * 0.55,
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
                  "Design furniture. Made easy.",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: TColors.nearBlack,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: TSizes.spaceBtwSections),
                if (!isOtpStage) ...[
                  TTextField(
                    labelText: 'Mobile Number',
                    controller: _phoneController,
                    prefixIcon: Icon(Iconsax.call, color: TColors.nearBlack),
                    isCircularIcon: true,
                    keyboardType: TextInputType.phone,
                  ),
                ] else ...[
                  TTextField(
                    labelText: 'Enter OTP',
                    controller: _otpController,
                    prefixIcon: Icon(
                      Icons.more_horiz_rounded,
                      color: TColors.nearBlack,
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
                    onPressed: _isSubmitting
                        ? null
                        : () => _handleAction(context, isOtpStage),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TColors.dangerRed,
                      side: const BorderSide(color: TColors.dangerRed),
                    ),
                    child: Text(
                      _isSubmitting
                          ? 'Please wait...'
                          : (isOtpStage ? 'Send' : 'Get OTP'),
                    ),
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
                        color: TColors.nearBlack,
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
    final circleRadius = size.width * (0.5 / 0.6) / 2;
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
