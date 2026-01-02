import 'package:century_ai/features/home/screens/widgets/home_drawer.dart';
import 'package:century_ai/utils/constants/colors.dart';
import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:century_ai/utils/constants/sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

class NavWrapper extends StatelessWidget {
  final Widget child;

  const NavWrapper({super.key, required this.child});

  static const List<String> _routes = [
    "/",
    "/camera",
    "/heart",
    "/star",
  ];

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;

    int currentIndex = _routes.indexWhere((r) => r == location);
    if (currentIndex == -1) currentIndex = 0;

    return Scaffold(
      // backgroundColor: Colors.white,
      drawer: const HomeDrawer(),

      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Iconsax.menu_1, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: TSizes.defaultSpace),
            child: Image(
              image: AssetImage(TImages.smallLogo),
              width: 30,
              height: 30,
            ),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      /// 🔥 Current routed screen
      body: child,

      /// 🔥 Custom Bottom Navigation (same UI as HomeScreen)
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TSizes.defaultSpace,
          vertical: TSizes.sm,
        ),
        child: Container(
          padding: const EdgeInsets.all(TSizes.sm),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(TSizes.inputFieldRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                offset: const Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavItem(
                icon: Iconsax.image,
                isSelected: currentIndex == 0,
                onTap: () => context.go(_routes[0]),
              ),
              _NavItem(
                icon: Iconsax.camera,
                isSelected: currentIndex == 1,
                onTap: () => context.go(_routes[1]),
              ),
              _NavItem(
                icon: Iconsax.heart,
                isSelected: currentIndex == 2,
                onTap: () => context.go(_routes[2]),
              ),
              _NavItem(
                icon: Iconsax.magic_star,
                isSelected: currentIndex == 3,
                onTap: () => context.go(_routes[3]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? TColors.primary : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : TColors.darkGrey,
        ),
      ),
    );
  }
}
