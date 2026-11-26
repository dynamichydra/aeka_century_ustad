import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/core/constants/sample_bsm_contact.dart';
import 'package:century_ai/cubit/auth/auth_cubit.dart';
import 'package:century_ai/db/repositories/local_user_profile_repository.dart';
import 'package:century_ai/features/auth/data/auth_storage.dart';
import 'package:century_ai/features/auth/presentation/widgets/user_avatar.dart';
import 'package:century_ai/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  static const _mutedColor = Color(0xFF5C5C5C);

  void _close(BuildContext context) => Scaffold.of(context).closeDrawer();

  void _go(BuildContext context, String route) {
    _close(context);
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final activePath = GoRouterState.of(context).uri.path;

    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.78,
      backgroundColor: TColors.pureWhite,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 12),
                children: [
                  Stack(
                    children: [
                      const Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(36, 10, 60, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your BSM',
                              style: TextStyle(
                                fontSize: 14,
                                color: _mutedColor,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              SampleBsmContact.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: TColors.pureBlack,
                              ),
                            ),
                            SizedBox(height: 8),
                            _BsmContactLine(
                              icon: Icons.call,
                              text: SampleBsmContact.phone,
                            ),
                            SizedBox(height: 8),
                            _BsmContactLine(
                              icon: Icons.email,
                              text: SampleBsmContact.email,
                            ),
                          ],
                        ),
                      ),
                      PositionedDirectional(
                        top: 0,
                        end: 0,
                        child: IconButton(
                          tooltip: 'Close navigation menu',
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 25,
                            color: TColors.pureBlack,
                          ),
                          onPressed: () => _close(context),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsetsDirectional.only(start: 33, end: 13),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: TColors.silverGray,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _DrawerItem(
                    icon: const Icon(Iconsax.home_2),
                    label: 'Home',
                    selected:
                        activePath == AppRoutes.home ||
                        activePath == AppRoutes.home2 ||
                        activePath == AppRoutes.heart,
                    onTap: () => _go(context, AppRoutes.home),
                  ),
                  _DrawerItem(
                    icon: const UserAvatar(size: 24),
                    label: 'Profile',
                    selected: activePath == AppRoutes.profile,
                    onTap: () {
                      _close(context);
                      context.push(AppRoutes.profile);
                    },
                  ),
                  _DrawerItem(
                    icon: const Icon(Icons.tips_and_updates),
                    label: 'Tips',
                    selected: activePath == AppRoutes.tips,
                    onTap: () => _go(context, AppRoutes.tips),
                  ),
                  _DrawerItem(
                    icon: const Icon(
                      Icons.reply_rounded,
                      textDirection: TextDirection.rtl,
                    ),
                    label: 'Share The App',
                    onTap: () => _close(context),
                  ),
                ],
              ),
            ),
            _DrawerItem(
              icon: const Icon(Icons.logout_rounded),
              label: 'Logout',
              onTap: () => _confirmLogout(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              "Logout",
              style: TextStyle(color: TColors.vividRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await context.read<AuthCubit>().logout();
    await AuthStorage.clearSession();
    LocalUserProfileRepository.clearCurrent();
    if (context.mounted) context.go(AppRoutes.login);
  }
}

class _BsmContactLine extends StatelessWidget {
  const _BsmContactLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: TColors.pureBlack),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: HomeDrawer._mutedColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(33, 14, 13, 14),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 26,
                child: IconTheme(
                  data: IconThemeData(
                    size: 24,
                    color: selected ? TColors.vividRed : HomeDrawer._mutedColor,
                  ),
                  child: Center(child: icon),
                ),
              ),
              const SizedBox(width: 27),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected ? TColors.vividRed : TColors.pureBlack,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
