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
      message = 'Contact your BSM for help restoring login access.',
      role = 'BSM',
      name = SampleBsmContact.name,
      phone = SampleBsmContact.phone,
      email = SampleBsmContact.email;

  const LoginSupportPage.noAccount({super.key})
    : title = 'No account found',
      message = 'Contact your admin to set up your account before logging in.',
      role = 'admin',
      name = 'Ravi Mehta',
      phone = '+1 202 555 0143',
      email = 'admin@example.com';

  final String title;
  final String message;
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
    return Scaffold(
      body: AuthDecoratedBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CenturyLogo(),
                    const SizedBox(height: 44),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: TColors.pureWhite,
                        border: Border.all(color: const Color(0xFFE3E3E3)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sample $role contact', style: theme.bodyMedium),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: theme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(height: 24),
                          _ContactLine(
                            icon: Icons.phone_outlined,
                            value: phone,
                          ),
                          const SizedBox(height: 12),
                          _ContactLine(icon: Icons.mail_outline, value: email),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    AuthPrimaryButton(
                      label: 'Call $role',
                      onPressed: () => _openDialer(context),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
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
        Icon(icon, size: 20, color: TColors.vividRed),
        const SizedBox(width: 12),
        Expanded(child: SelectableText(value)),
      ],
    );
  }
}
