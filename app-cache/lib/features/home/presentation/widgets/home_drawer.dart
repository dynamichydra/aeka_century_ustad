import 'package:century_ai/core/constants/colors.dart';
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

  static const _iconColor = Color(0xFF555555);

  void _close(BuildContext context) => Scaffold.of(context).closeDrawer();

  void _go(BuildContext context, String route) {
    _close(context);
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.78,
      backgroundColor: TColors.pureWhite,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 12),
                child: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 30,
                    color: TColors.pureBlack,
                  ),
                  onPressed: () => _close(context),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 4),
                children: [
                  _DrawerItem(
                    icon: const Icon(Iconsax.home_2, color: _iconColor),
                    label: 'Home',
                    onTap: () => _go(context, AppRoutes.home),
                  ),
                  // _DrawerItem(
                  //   icon: const Icon(Iconsax.home_2, color: _iconColor),
                  //   label: 'Home 2',
                  //   onTap: () => _go(context, AppRoutes.home2),
                  // ),
                  _DrawerItem(
                    icon: const UserAvatar(size: 24),
                    label: 'Profile',
                    labelColor: TColors.vividRed,
                    onTap: () {
                      _close(context);
                      context.push(AppRoutes.profile);
                    },
                  ),
                  _ExpandableDrawerItem(
                    icon: const Icon(
                      Icons.photo_library_outlined,
                      color: _iconColor,
                    ),
                    label: 'My Project',
                    children: [
                      _DrawerSubItem(label: 'Business Card', onTap: () {}),
                      _DrawerSubItem(label: 'My Work', onTap: () {}),
                      _DrawerSubItem(label: 'Quotation', onTap: () {}),
                    ],
                  ),
                  _DrawerItem(
                    icon: const Icon(Icons.tips_and_updates, color: _iconColor),
                    label: 'Tips',
                    onTap: () => _close(context),
                  ),
                  _DrawerItem(
                    icon: const Icon(Icons.favorite, color: _iconColor),
                    label: 'Favorite',
                    onTap: () => _close(context),
                  ),
                  _DrawerItem(
                    icon: const Icon(Icons.shortcut, color: _iconColor),
                    label: 'Share The App',
                    onTap: () => _close(context),
                  ),
                  _DrawerItem(
                    icon: const Icon(Icons.info_outline, color: _iconColor),
                    label: 'About Us',
                    onTap: () => _close(context),
                  ),
                ],
              ),
            ),
            _DrawerItem(
              icon: const Icon(Iconsax.logout, color: TColors.vividRed),
              label: 'Logout',
              labelColor: TColors.vividRed,
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

/// One drawer row: icon in a fixed-width slot, bold label, optional trailing.
class _DrawerItem extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;
  final Widget? trailing;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor = TColors.pureBlack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 13, 20, 13),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 26,
              child: IconTheme(
                data: const IconThemeData(size: 26),
                child: Center(child: icon),
              ),
            ),
            const SizedBox(width: 30),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Drawer row with a chevron that opens its sub-items below it.
class _ExpandableDrawerItem extends StatefulWidget {
  final Widget icon;
  final String label;
  final List<Widget> children;

  const _ExpandableDrawerItem({
    required this.icon,
    required this.label,
    required this.children,
  });

  @override
  State<_ExpandableDrawerItem> createState() => _ExpandableDrawerItemState();
}

class _ExpandableDrawerItemState extends State<_ExpandableDrawerItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DrawerItem(
          icon: widget.icon,
          label: widget.label,
          onTap: () => setState(() => _open = !_open),
          trailing: AnimatedRotation(
            turns: _open ? 0.25 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(
              Icons.chevron_right_rounded,
              size: 28,
              color: TColors.pureBlack,
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: _open
              ? Column(children: widget.children)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _DrawerSubItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DrawerSubItem({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        // Lines up with the parent's label.
        padding: const EdgeInsets.fromLTRB(90, 10, 20, 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
          ),
        ),
      ),
    );
  }
}
