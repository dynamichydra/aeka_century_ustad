import 'package:century_ai/features/home/presentation/widgets/home_drawer.dart';
import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/core/constants/sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

class NavWrapper extends StatelessWidget {
  final Widget child;

  const NavWrapper({super.key, required this.child});

  static const List<String> _routes = [
    "/",
    "/camera",
    "/upload",
    "/heart",
    "/people",
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
            icon: const Icon(Icons.person, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text("Lets design Furniture with Century Decor", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),),
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
        backgroundColor: Colors.white,
        elevation: 0,
      ),

      /// 🔥 Current routed screen
      body: child,

      /// 🔥 Custom Bottom Navigation (same UI as HomeScreen)
      // bottomNavigationBar: Padding(
      //   padding: const EdgeInsets.symmetric(
      //     horizontal: TSizes.defaultSpace,
      //     vertical: TSizes.sm,
      //   ),
      //   child: Container(
      //     padding: const EdgeInsets.all(TSizes.sm),
      //     decoration: BoxDecoration(
      //       color: Colors.white,
      //       borderRadius: BorderRadius.circular(TSizes.inputFieldRadius),
      //       boxShadow: [
      //         BoxShadow(
      //           color: Colors.grey.withOpacity(0.3),
      //           offset: const Offset(0, 4),
      //           blurRadius: 10,
      //         ),
      //       ],
      //     ),
      //     child: Row(
      //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //       children: [
      //         _NavItem(
      //           icon: Icon(
      //             Icons.image,
      //             color: TColors.nearBlack,
      //           ),
      //           isSelected: currentIndex == 0,
      //           onTap: () => context.go(_routes[0]),
      //         ),
      //         _NavItem(
      //           icon: Icon(
      //             Icons.camera_alt,
      //             color: TColors.nearBlack,
      //           ),
      //           isSelected: currentIndex == 1,
      //           onTap: () => context.push(_routes[1]),
      //         ),
      //
      //         _NavItem(
      //           icon: Image.asset(
      //             "assets/icons/app_icons/upload.png",
      //             height: 24,
      //             width: 24,
      //           ),
      //           isSelected: currentIndex == 2,
      //           onTap: () => context.go(_routes[2]),
      //         ),
      //
      //         _NavItem(
      //           icon: Icon(
      //             Icons.favorite,
      //             color: TColors.nearBlack,
      //           ),
      //           isSelected: currentIndex == 3,
      //           onTap: () => context.go(_routes[3]),
      //         ),
      //
      //         _NavItem(
      //           icon: SvgPicture.asset(
      //             "assets/icons/app_icons/person.svg",
      //             height: 24,
      //             width: 24,
      //             colorFilter: const ColorFilter.mode(
      //               Colors.black,
      //               BlendMode.srcIn,
      //             ),
      //           ),
      //           isSelected: currentIndex == 4,
      //           onTap: () => context.go(_routes[4]),
      //         ),
      //       ],
      //     ),
      //   ),
      // ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final Widget icon;
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
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: icon,
      ),
    );
  }
}

