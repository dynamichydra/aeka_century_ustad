import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/core/constants/sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter/cupertino.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // Force Light Mode colors setup just in case, though app is forced light.

    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.white),
            accountName: Text(
              "Ramesh",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            accountEmail: Text(
              "Ramesh.doe@example.com",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundImage: AssetImage(TImages.user),
            ),
          ),

          // Menu Items
          ListTile(
            leading: const Icon(Iconsax.home),
            title: const Text("home 1"),
            onTap: () {
              context.go("/");
              Scaffold.of(context).closeDrawer();
            },
          ),
          
          ListTile(
            leading: const Icon(Iconsax.home),
            title: const Text("home 2"),
            onTap: () {
              context.go("/home_2");
              Scaffold.of(context).closeDrawer();
            },
          ),
          ListTile(
            leading: const Icon(Iconsax.home),
            title: const Text("home 3"),
            onTap: () {
              context.go("/home_3");
              Scaffold.of(context).closeDrawer();
            },
          ),
          ListTile(
            leading: const Icon(Iconsax.user),
            title: const Text("Profile"),
            onTap: () => {},
          ),

          ExpansionTile(
            leading: const Icon(Iconsax.folder),
            title: const Text("My Project"),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(left: TSizes.xl),
                leading: const Icon(Iconsax.personalcard),
                title: const Text("Business card"),
                onTap: () => {},
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: TSizes.xl),
                leading: const Icon(Iconsax.briefcase),
                title: const Text("My Work"),
                onTap: () => {},
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: TSizes.xl),
                leading: const Icon(Iconsax.document),
                title: const Text("Quotation"),
                onTap: () => {},
              ),
            ],
          ),

          ExpansionTile(
            leading: const Icon(Iconsax.lamp_on),
            title: const Text("Inspiration Wall"),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(left: TSizes.xl),
                leading: const Icon(
                  CupertinoIcons.plus_square_fill_on_square_fill,
                ),
                title: const Text("Art Gallery"),
                onTap: () => {},
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: TSizes.xl),
                leading: const Icon(
                  CupertinoIcons.plus_square_fill_on_square_fill,
                ),
                title: const Text("Color Horoscope"),
                onTap: () => {},
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: TSizes.xl),
                leading: const Icon(
                  CupertinoIcons.plus_square_fill_on_square_fill,
                ),
                title: const Text("Blogs"),
                onTap: () => {},
              ),
            ],
          ),
          ListTile(
            leading: const Icon(Iconsax.info_circle),
            title: const Text("Tips"),
            onTap: () => {},
          ),
          ListTile(
            leading: const Icon(Iconsax.heart),
            title: const Text("Fav."),
            onTap: () => {},
          ),
          ListTile(
            leading: const Icon(Iconsax.security_safe),
            title: const Text("Tams & Condition"),
            onTap: () => {},
          ),
          ListTile(
            leading: const Icon(Iconsax.call),
            title: const Text("Contact us"),
            onTap: () => {},
          ),
          ListTile(
            leading: const Icon(Iconsax.star),
            title: const Text("Rate Our App"),
            onTap: () {
              // Rate App Logic
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Iconsax.share),
            title: const Text("Share The App"),
            onTap: () {
              // Share App Logic
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Iconsax.info_circle),
            title: const Text("About Us"),
            onTap: () => {},
          ),
        ],
      ),
    );
  }
}
