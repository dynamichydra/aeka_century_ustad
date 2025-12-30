import 'package:century_ai/utils/constants/colors.dart';
import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:century_ai/utils/constants/sizes.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const Drawer(), // Basic Drawer with hamburger icon implied by Scaffold
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Iconsax.menu_1, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
           Padding(
             padding: const EdgeInsets.only(right: TSizes.defaultSpace),
             child: const Image(image: AssetImage(TImages.toyIcon), width: 30, height: 30), // Example Image Icon
           ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(TSizes.defaultSpace),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Section
              Center(
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundImage: AssetImage(TImages.user),
                    ),
                    const SizedBox(height: TSizes.spaceBtwItems),
                    Text(
                      "John Doe", // Placeholder name
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TSizes.spaceBtwSections),

              // "Let’s explore" Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Let’s explore", style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: TSizes.spaceBtwItems),
              
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 6, // 5 images + 1 "See more"
                  separatorBuilder: (_, __) => const SizedBox(width: TSizes.spaceBtwItems),
                  itemBuilder: (context, index) {
                    if (index == 5) {
                      // See More Button at end of row
                      return Column(
                        children: [
                           Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade200,
                            ),
                            child: IconButton(
                              onPressed: () {}, 
                              icon: const Icon(Iconsax.arrow_right_3)
                            ),
                          ),
                          const SizedBox(height: TSizes.spaceBtwItems / 2),
                          Text("See more", style: Theme.of(context).textTheme.labelMedium),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          padding: const EdgeInsets.all(TSizes.xs),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: TColors.primary),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: const Image(
                              image: AssetImage(TImages.clothIcon), // Placeholder
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: TSizes.spaceBtwSections),

              // "Popular image list" Section
              // "bottom of the row show popular image list and left side see more button"
              // Interpreting as a header row with "See more" on the left? Or list with button on left?
              // Standard UX: Title Left, See More Right.
              // Request: "left side see more button".
              Row(
                 mainAxisAlignment: MainAxisAlignment.start,
                 children: [
                   TextButton(
                     onPressed: (){}, 
                     child: const Row(
                       children: [
                         Text("See More"),
                         SizedBox(width: 4),
                         Icon(Iconsax.arrow_right_3, size: 16),
                       ],
                     )
                   ),
                   const Spacer(), // To push text to left if needed, or keep it compact
                   // If text is Popular Images?
                   // Text("Popular Images", style: Theme.of(context).textTheme.headlineSmall),
                 ],
              ),
              const SizedBox(height: TSizes.spaceBtwItems),
              
              // Popular Image List (Vertical for now)
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(height: TSizes.spaceBtwItems),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(TSizes.cardRadiusLg),
                    child: const Image(
                      image: AssetImage(TImages.promoBanner1), 
                      height: 150, 
                      width: double.infinity, 
                      fit: BoxFit.cover
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {},
        destinations: const [
          NavigationDestination(icon: Icon(Iconsax.image), label: 'Image'),
          NavigationDestination(icon: Icon(Iconsax.camera), label: 'Camera'),
          NavigationDestination(icon: Icon(Iconsax.heart), label: 'Favorite'),
          NavigationDestination(icon: Icon(Iconsax.magic_star), label: 'AI'), // Using Magic Star for AI
        ],
      ),
    );
  }
}
