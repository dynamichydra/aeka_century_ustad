import 'dart:math' as math;

import 'package:century_ai/core/constants/colors.dart';
import 'package:flutter/material.dart';

abstract final class AuthAssets {
  static const logo = 'assets/logos/CenturyDecoratives_Logo.png';
  static const starLogo = 'assets/auth/logo.png';
  static const topStars = 'assets/auth/top-stars.png';
  static const bottomStars = 'assets/auth/bottom-stars.png';
  static const mascot = 'assets/auth/banner-man.png';
  static const carpenterMascot = 'assets/auth/carpenter-mascot.png';
  static const onboarding1 = 'assets/auth/onbaording-1.png';
  static const onboarding2Dark = 'assets/auth/onboarding-2-dark.png';
  static const onboarding2Light = 'assets/auth/onboarding-2-light.png';
}

/// White page with the silver star decorations in the top-left and
/// bottom-right corners, used behind onboarding, login and OTP.
class AuthDecoratedBackground extends StatelessWidget {
  final Widget child;
  final bool showBottomStars;

  const AuthDecoratedBackground({
    super.key,
    required this.child,
    this.showBottomStars = true,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TColors.pureWhite,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: Image.asset(AuthAssets.topStars, width: 146),
          ),
          if (showBottomStars)
            Positioned(
              right: 0,
              bottom: 0,
              child: Image.asset(AuthAssets.bottomStars, width: 59),
            ),
          // Keep the form and its text input connection when the stars hide.
          Positioned.fill(key: const ValueKey('auth-content'), child: child),
        ],
      ),
    );
  }
}

class CenturyLogo extends StatelessWidget {
  final double width;

  const CenturyLogo({super.key, this.width = 168});

  @override
  Widget build(BuildContext context) {
    return Image.asset(AuthAssets.logo, width: width, fit: BoxFit.contain);
  }
}

/// White circle with the "Century / Decor Studio" wordmark.
class DecorStudioBadge extends StatelessWidget {
  final double size;

  const DecorStudioBadge({super.key, this.size = 160});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: TColors.pureWhite,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFF2F2F2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Century',
              style: TextStyle(
                fontSize: size * 0.125,
                fontWeight: FontWeight.w700,
                color: TColors.vividRed,
                height: 1.2,
              ),
            ),
            Text(
              'Decor Studio',
              style: TextStyle(
                fontSize: size * 0.125,
                fontWeight: FontWeight.w700,
                color: TColors.pureBlack,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 146,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: TColors.vividRed,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: loading ? null : onPressed,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TColors.pureWhite,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: TColors.pureWhite,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Shared layout of the login and OTP screens: logo, studio badge, tagline,
/// a screen-specific [form], the mascot and the [button]. Scrolls when the
/// screen is short or the keyboard is open.
class AuthFormLayout extends StatelessWidget {
  final Widget form;
  final Widget button;

  final Widget? belowButton;

  const AuthFormLayout({
    super.key,
    required this.form,
    required this.button,
    this.belowButton,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildForViewport);
  }

  Widget _buildForViewport(BuildContext context, BoxConstraints _) {
    // The scaffold resizes its body and removes the keyboard inset from it.
    final keyboardOpen = View.of(context).viewInsets.bottom > 0;
    // Keep the design scale stable while the keyboard resizes the scroll view.
    final k = (MediaQuery.sizeOf(context).height / 812).clamp(0.7, 1.15);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final footerPadding = belowButton == null ? 56 * k : 8.0;
    final bottomGap = math.max(
      bottomInset,
      keyboardOpen ? 24.0 : footerPadding,
    );

    return AuthDecoratedBackground(
      showBottomStars: !keyboardOpen,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      SizedBox(height: 40 * k),
                      CenturyLogo(width: k < 0.85 ? 140 : 168),
                      SizedBox(height: 40 * k),
                      DecorStudioBadge(size: 160 * k.clamp(0.8, 1.0)),
                      SizedBox(height: 48 * k),
                      const Text(
                        'Lets Design Furnitures with Century Decor',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF555555),
                        ),
                      ),
                      SizedBox(height: 44 * k),
                      form,
                    ],
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: (keyboardOpen ? 52 : 12) * k,
                      bottom: bottomGap,
                    ),
                    child: Column(
                      mainAxisAlignment: keyboardOpen
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.end,
                      children: [
                        if (!keyboardOpen) ...[
                          Image.asset(
                            AuthAssets.mascot,
                            height: 115 * k.clamp(0.8, 1.0),
                            excludeFromSemantics: true,
                          ),
                          SizedBox(height: 28 * k),
                        ],
                        button,
                        if (belowButton != null) ...[
                          const SizedBox(height: 4),
                          belowButton!,
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
