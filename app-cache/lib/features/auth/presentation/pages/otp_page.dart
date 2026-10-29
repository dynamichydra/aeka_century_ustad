import 'dart:async';

import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/cubit/auth/auth_cubit.dart';
import 'package:century_ai/cubit/auth/auth_state.dart';
import 'package:century_ai/data/repositories/auth_repository.dart';
import 'package:century_ai/features/auth/data/auth_storage.dart';
import 'package:century_ai/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:century_ai/router/app_routes.dart';
import 'package:century_ai/utils/popups/loaders.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

class OtpPage extends StatefulWidget {
  final String phone;

  const OtpPage({super.key, required this.phone});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  // Firebase sends 6-digit codes.
  static const _otpLength = 6;
  bool _signedIn = false;

  final _otpController = TextEditingController();
  final _otpFocus = FocusNode();

  StreamSubscription<String>? _autoCodeSub;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(() => setState(() {}));
    // Android: show the code Firebase read from the SMS; it signs in by itself.
    _autoCodeSub = context.read<AuthRepository>().autoCodes.listen((code) {
      if (mounted) _otpController.text = code;
    });
    // Focus straight away so iOS shows the "From Messages" code suggestion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocus.requestFocus();
    });
  }

  void _changeNumber() {
    context.read<AuthCubit>().resetStatus();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  Future<void> _resendOtp() async {
    final cubit = context.read<AuthCubit>();
    if (cubit.state.status == AuthStatus.loading) return;
    _otpController.clear();
    await cubit.requestOtp(widget.phone);
    if (!mounted) return;
    if (cubit.state.status == AuthStatus.otpSent) {
      TLoaders.customToast(context: context, message: 'OTP sent again');
    } else if (cubit.state.status == AuthStatus.error) {
      TLoaders.errorSnackBar(
        context: context,
        title: 'Could not send OTP',
        message: cubit.state.errorMessage ?? '',
      );
    }
  }

  Future<void> _verify() async {
    final otp = _otpController.text;
    if (otp.length != _otpLength) {
      TLoaders.errorSnackBar(
        context: context,
        title: 'Incomplete OTP',
        message: 'Enter the $_otpLength-digit OTP.',
      );
      return;
    }
    FocusScope.of(context).unfocus();

    final cubit = context.read<AuthCubit>();
    await cubit.verifyOtp(phone: widget.phone, otp: otp);
    if (!mounted) return;
    if (cubit.state.status == AuthStatus.error) {
      TLoaders.errorSnackBar(
        context: context,
        title: 'Verification failed',
        message: cubit.state.errorMessage ?? '',
      );
    }
  }

  /// Handles both a typed code and Android's automatic SMS verification.
  Future<void> _onAuthenticated(AuthState state) async {
    if (_signedIn || state.session == null) return;
    _signedIn = true;
    await AuthStorage.saveSession(state.session!);
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  void dispose() {
    _autoCodeSub?.cancel();
    _otpController.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.select<AuthCubit, bool>(
      (c) => c.state.status == AuthStatus.loading,
    );

    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (prev, curr) =>
          curr.status == AuthStatus.authenticated && prev.status != curr.status,
      listener: (context, state) => _onAuthenticated(state),
      child: Scaffold(
        body: AuthFormLayout(
          form: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SentToLine(phone: widget.phone, onEdit: _changeNumber),
              const SizedBox(height: 18),
              _OtpBoxes(
                controller: _otpController,
                focusNode: _otpFocus,
                length: _otpLength,
                onCompleted: _verify,
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: loading ? null : _resendOtp,
                style: TextButton.styleFrom(
                  foregroundColor: TColors.pureBlack,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Resend OTP?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                ),
              ),
            ],
          ),
          button: AuthPrimaryButton(
            label: 'Verify',
            loading: loading,
            onPressed: _verify,
          ),
        ),
      ),
    );
  }
}

class _SentToLine extends StatelessWidget {
  final String phone;
  final VoidCallback onEdit;

  const _SentToLine({required this.phone, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text.rich(
            TextSpan(
              text: 'Enter Your OTP sent to ',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555555),
              ),
              children: [
                TextSpan(
                  text: '+91 $phone',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: TColors.pureBlack,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 6),
        InkResponse(
          onTap: onEdit,
          radius: 18,
          child: const Icon(Iconsax.edit, size: 18, color: TColors.vividRed),
        ),
      ],
    );
  }
}

/// Four underlined digit slots backed by one hidden text field, so paste
/// and iOS one-time-code autofill keep working.
class _OtpBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final VoidCallback onCompleted;

  const _OtpBoxes({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final text = controller.text;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: focusNode.requestFocus,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(length, (i) {
              return Container(
                width: 34,
                height: 46,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF555555), width: 1.5),
                  ),
                ),
                child: Text(
                  i < text.length ? text[i] : '',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: TColors.pureBlack,
                  ),
                ),
              );
            }),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(length),
                ],
                showCursor: false,
                enableInteractiveSelection: false,
                scrollPadding: const EdgeInsets.only(bottom: 160),
                onChanged: (value) {
                  if (value.length == length) onCompleted();
                },
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  counterText: '',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
