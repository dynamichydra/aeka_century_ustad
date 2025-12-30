import 'package:century_ai/utils/constants/colors.dart';
import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:century_ai/utils/constants/sizes.dart';
import 'package:century_ai/utils/helpers/helper_functions.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const Drawer(),
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
             child: const Image(image: AssetImage(TImages.toyIcon), width: 30, height: 30),
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
                      "John Doe",
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
              
              // Search Input
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  borderRadius: BorderRadius.circular(TSizes.inputFieldRadius),
                ),
                child: TextFormField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Iconsax.search_normal),
                    labelText: 'Search for images...',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: TSizes.spaceBtwSections),

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
              Row(
                 mainAxisAlignment: MainAxisAlignment.start,
                 children: [
                   // "left side see more button"
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: TSizes.defaultSpace, vertical: TSizes.sm),
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
              _buildNavItem(Iconsax.image, 0),
              _buildNavItem(Iconsax.camera, 1),
              _buildNavItem(Iconsax.heart, 2),
              _buildNavItem(Iconsax.magic_star, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
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
          ]
        ),
        child: Icon(
          icon, 
          color: isSelected ? Colors.white : TColors.darkGrey,
        ),
      ),
    );
  }
}
