import 'package:century_ai/features/content/screens/inspiration_wall/inspiration_wall.dart';
import 'package:century_ai/features/content/screens/tips/tips.dart';
import 'package:century_ai/features/personalization/screens/profile/profile.dart';
import 'package:century_ai/features/projects/screens/my_work/my_work.dart';
import 'package:century_ai/features/projects/screens/quotation/quotation.dart';
import 'package:century_ai/features/shop/screens/favorites/favorites.dart';
import 'package:century_ai/features/support/screens/about_us/about_us.dart';
import 'package:century_ai/features/support/screens/contact_us/contact_us.dart';
import 'package:century_ai/features/support/screens/terms_conditions/terms_conditions.dart';
import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:century_ai/utils/constants/sizes.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

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
            accountName: Text("John Doe", style: Theme.of(context).textTheme.titleLarge),
            accountEmail: Text("john.doe@example.com", style: Theme.of(context).textTheme.bodyMedium),
            currentAccountPicture: const CircleAvatar(
              backgroundImage: AssetImage(TImages.user),
            ),
          ),

          // Menu Items
          ListTile(
            leading: const Icon(Iconsax.user),
            title: const Text("Profile"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          
          ExpansionTile(
            leading: const Icon(Iconsax.folder),
            title: const Text("My Project"),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(left: TSizes.xl),
                leading: const Icon(Iconsax.briefcase),
                title: const Text("My Work"),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyWorkScreen())),
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: TSizes.xl),
                leading: const Icon(Iconsax.document),
                title: const Text("Quotation"),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuotationScreen())),
              ),
            ],
          ),

          ListTile(
            leading: const Icon(Iconsax.lamp_on),
            title: const Text("Inspiration Wall"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InspirationWallScreen())),
          ),
          ListTile(
            leading: const Icon(Iconsax.info_circle),
            title: const Text("Tips"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TipsScreen())),
          ),
          ListTile(
            leading: const Icon(Iconsax.heart),
            title: const Text("Fav."),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen())),
          ),
          ListTile(
            leading: const Icon(Iconsax.security_safe),
            title: const Text("Tams & Condition"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
          ),
          ListTile(
            leading: const Icon(Iconsax.call),
            title: const Text("Contact us"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactUsScreen())),
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutUsScreen())),
          ),
        ],
      ),
    );
  }
}
