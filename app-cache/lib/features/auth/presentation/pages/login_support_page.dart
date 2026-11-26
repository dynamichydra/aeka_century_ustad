import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/core/constants/sample_bsm_contact.dart';
import 'package:century_ai/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:century_ai/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginSupportPage extends StatelessWidget {
  const LoginSupportPage.loginLimit({super.key})
    : title = 'Login limit reached',
      role = 'BSM',
      name = SampleBsmContact.name,
      phone = SampleBsmContact.phone,
      email = SampleBsmContact.email;

  const LoginSupportPage.noAccount({super.key})
    : title = 'No account found',
      role = 'admin',
      name = 'Ravi Mehta',
      phone = '+1 202 555 0143',
      email = 'admin@example.com';

  final String title;
  final String role;
  final String name;
  final String phone;
  final String email;

  Future<void> _openDialer(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on PlatformException {
      // Some devices have no app that handles phone numbers.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open the phone dialer. Call $phone.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final scale = (MediaQuery.sizeOf(context).width / 390).clamp(0.8, 1.15);
    return Scaffold(
      body: AuthDecoratedBackground(
        child: Stack(
          children: [
            Positioned(
              left: 6,
              bottom: -10 * scale,
              child: Image.asset(
                AuthAssets.carpenterMascot,
                width: 96 * scale,
                excludeFromSemantics: true,
              ),
            ),
            Positioned.fill(
              bottom: 120 * scale,
              child: SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 45 * scale, bottom: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CenturyLogo(width: 174 * scale),
                              SizedBox(height: 42 * scale),
                              DecorStudioBadge(size: 166 * scale),
                              SizedBox(height: 46 * scale),
                              Semantics(
                                header: true,
                                label: title,
                                child: Text(
                                  'Contact $role to login',
                                  textAlign: TextAlign.center,
                                  style: theme.titleMedium?.copyWith(
                                    color: const Color(0xFF555555),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(height: 24 * scale),
                              SizedBox(
                                width: 210 * scale,
                                child: Container(
                                  padding: const EdgeInsets.all(11),
                                  decoration: BoxDecoration(
                                    color: TColors.pureWhite,
                                    border: Border.all(
                                      color: const Color(0xFFE8E8E8),
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        role == 'admin'
                                            ? 'Admin contact'
                                            : '$role contact',
                                        style: theme.bodySmall?.copyWith(
                                          color: const Color(0xFF666666),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        name,
                                        style: theme.titleMedium?.copyWith(
                                          color: TColors.pureBlack,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Divider(
                                        height: 20,
                                        color: Color(0xFFBDBDBD),
                                      ),
                                      _ContactLine(
                                        icon: Icons.phone,
                                        value: phone,
                                      ),
                                      const SizedBox(height: 8),
                                      _ContactLine(
                                        icon: Icons.email,
                                        value: email,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 24 * scale),
                              AuthPrimaryButton(
                                label: 'Call $role',
                                onPressed: () => _openDialer(context),
                              ),
                              SizedBox(height: 8 * scale),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: TColors.vividRed,
                                ),
                                onPressed: () => context.canPop()
                                    ? context.pop()
                                    : context.go(AppRoutes.login),
                                child: const Text('Back to login'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: TColors.pureBlack),
        const SizedBox(width: 9),
        Expanded(
          child: SelectableText(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF555555),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
