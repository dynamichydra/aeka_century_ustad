import 'package:century_ai/features/home/screens/widgets/home_drawer.dart';
import 'package:century_ai/utils/constants/colors.dart';
import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:century_ai/utils/constants/sizes.dart';
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
      drawer: const HomeDrawer(),
      // appBar: AppBar(
      //   leading: Builder(
      //     builder: (context) => IconButton(
      //       icon: const Icon(Iconsax.menu_1, color: Colors.black),
      //       onPressed: () => Scaffold.of(context).openDrawer(),
      //     ),
      //   ),
      //   actions: [
      //      Padding(
      //        padding: const EdgeInsets.only(right: TSizes.defaultSpace),
      //        child: const Image(image: AssetImage(TImages.toyIcon), width: 30, height: 30),
      //      ),
      //   ],
      //   backgroundColor: Colors.transparent,
      //   elevation: 0,
      // ),
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
                  itemCount: TProductImages.productImages.length,
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
                            child: Image(
                              image: AssetImage(
                                TProductImages.productImages[index],
                              ), // Placeholder
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
                itemCount: TProductImages.productImages.length,
                separatorBuilder: (_, __) => const SizedBox(height: TSizes.spaceBtwItems),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(TSizes.cardRadiusLg),
                    child: Image(
                      image: AssetImage(TProductImages.productImages[index]), 
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
    );
  }
}
