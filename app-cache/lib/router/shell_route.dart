import 'package:century_ai/features/auth/presentation/widgets/user_avatar.dart';
import 'package:century_ai/features/home/presentation/widgets/home_drawer.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/core/constants/sizes.dart';
import 'package:flutter/material.dart';

class NavWrapper extends StatelessWidget {
  final Widget child;

  const NavWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const HomeDrawer(),
      drawerScrimColor: const Color(0x4D000000),

      appBar: AppBar(
        leadingWidth: 2 * TSizes.defaultSpace + 30,
        leading: Builder(
          builder: (context) => IconButton(
            // The user's own profile photo (default avatar until they add one).
            tooltip: 'Open navigation menu',
            icon: const UserAvatar(size: 30),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          "Century Decor Studio",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsetsDirectional.only(end: TSizes.defaultSpace),
            child: Image(
              image: AssetImage(TImages.smallLogo),
              width: 30,
              height: 30,
            ),
          ),
        ],
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),

      body: child,
    );
  }
}
