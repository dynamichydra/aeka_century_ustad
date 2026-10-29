import 'dart:math' as math;

import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/features/auth/data/auth_storage.dart';
import 'package:century_ai/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:century_ai/features/home/presentation/widgets/before_after_slider.dart';
import 'package:century_ai/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _pageCount = 2;

  final _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  void _finish() {
    if (_finishing) return;
    _finishing = true;
    context.go(AuthStorage.isLoggedIn ? AppRoutes.home : AppRoutes.login);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 700;

    return Scaffold(
      body: AuthDecoratedBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(
                    foregroundColor: TColors.pureBlack,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
                  ),
                ),
              ),
              SizedBox(height: compact ? 4 : 12),
              CenturyLogo(width: compact ? 140 : 168),
              Expanded(
                // Swiping past the last page finishes onboarding.
                // Covers both clamping (Android) and bouncing (iOS) physics.
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.depth != 0 || n.metrics.axis != Axis.horizontal) {
                      return false;
                    }
                    final pastEnd = n is OverscrollNotification
                        ? n.overscroll > 0
                        : n.metrics.pixels > n.metrics.maxScrollExtent + 48;
                    if (_page == _pageCount - 1 && pastEnd) _finish();
                    return false;
                  },
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      _OnboardingSlide(
                        title: 'Design Smarter.\nWork Easier.',
                        subtitle:
                            'Century Decor Studio\nhelps you visualise laminates on furniture.',
                        compact: compact,
                        image: LayoutBuilder(
                          builder: (context, c) {
                            final side = math.min(
                              math.min(c.maxWidth, c.maxHeight) * 0.82,
                              300.0,
                            );
                            return Image.asset(
                              AuthAssets.onboarding1,
                              width: side,
                              height: side,
                              fit: BoxFit.contain,
                            );
                          },
                        ),
                      ),
                      _OnboardingSlide(
                        title: 'Show Clients in\nReal Time',
                        subtitle:
                            'Apply laminates, compare finishes,\nand help your client decide instantly.',
                        compact: compact,
                        image: LayoutBuilder(
                          builder: (context, c) {
                            final width = math.min(c.maxWidth, 340.0);
                            return SizedBox(
                              width: width,
                              child: BeforeAfterSlider(
                                beforeImage: AuthAssets.onboarding2Dark,
                                afterImage: AuthAssets.onboarding2Light,
                                height: width * 210 / 374,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _PageDots(count: _pageCount, current: _page),
              SizedBox(height: compact ? 24 : 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget image;
  final bool compact;

  const _OnboardingSlide({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SizedBox(height: compact ? 24 : 48),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 19 : 21,
              fontWeight: FontWeight.w700,
              color: TColors.pureBlack,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 12.5 : 13.5,
              fontWeight: FontWeight.w400,
              color: TColors.pureBlack,
              height: 1.4,
            ),
          ),
          SizedBox(height: compact ? 16 : 32),
          Expanded(
            child: Align(alignment: const Alignment(0, -0.4), child: image),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int current;

  const _PageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 7),
          width: active ? 24 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: active ? TColors.vividRed : const Color(0xFFEDEDED),
            borderRadius: BorderRadius.circular(6),
            boxShadow: active
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
          ),
        );
      }),
    );
  }
}
