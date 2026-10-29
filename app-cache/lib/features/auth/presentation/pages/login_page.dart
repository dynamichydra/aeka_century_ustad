import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/cubit/auth/auth_cubit.dart';
import 'package:century_ai/cubit/auth/auth_state.dart';
import 'package:century_ai/features/auth/data/auth_storage.dart';
import 'package:century_ai/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:century_ai/router/app_routes.dart';
import 'package:century_ai/utils/popups/loaders.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _phoneController.text = context.read<AuthCubit>().state.phone;
  }

  Future<void> _requestOtp() async {
    FocusScope.of(context).unfocus();
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      TLoaders.errorSnackBar(
        context: context,
        title: 'Invalid number',
        message: 'Enter a valid 10-digit mobile number.',
      );
      return;
    }

    final cubit = context.read<AuthCubit>();
    await cubit.requestOtp(phone);
    if (!mounted) return;
    final state = cubit.state;
    if (state.status == AuthStatus.authenticated && state.session != null) {
      // Android verified the number instantly, without an SMS code.
      await AuthStorage.saveSession(state.session!);
      if (mounted) context.go(AppRoutes.home);
    } else if (state.status == AuthStatus.otpSent) {
      context.push(AppRoutes.otp, extra: phone);
    } else if (state.status == AuthStatus.error) {
      TLoaders.errorSnackBar(
        context: context,
        title: 'Could not send OTP',
        message: state.errorMessage ?? '',
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.select<AuthCubit, bool>(
      (c) => c.state.status == AuthStatus.loading,
    );

    return Scaffold(
      body: AuthFormLayout(
        form: _PhoneField(
          controller: _phoneController,
          onSubmitted: (_) => _requestOtp(),
        ),
        button: AuthPrimaryButton(
          label: 'Get OTP',
          loading: loading,
          onPressed: _requestOtp,
        ),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  const _PhoneField({required this.controller, required this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Container(
        height: 58,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: TColors.pureWhite,
          borderRadius: BorderRadius.circular(29),
          border: Border.all(color: const Color(0xFFE6E6E6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: TColors.pureWhite,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Iconsax.call,
                size: 22,
                color: Color(0xFF555555),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onSubmitted: onSubmitted,
                textAlign: TextAlign.center,
                scrollPadding: const EdgeInsets.only(bottom: 120),
                style: const TextStyle(
                  fontSize: 15,
                  color: TColors.pureBlack,
                  letterSpacing: 0.5,
                ),
                decoration: const InputDecoration(
                  hintText: 'Enter Your Mobile Number',
                  hintStyle: TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF6B6B6B),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
