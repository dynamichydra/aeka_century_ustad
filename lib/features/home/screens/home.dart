import 'package:century_ai/common/widgets/inputs/text_field.dart';
import 'package:century_ai/features/home/screens/widgets/before_after_slider.dart';
import 'package:century_ai/features/home/screens/widgets/home_drawer.dart';
import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:century_ai/utils/constants/sizes.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      drawer: const HomeDrawer(),
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
                  Text(
                    "Let’s explore",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(height: TSizes.spaceBtwItems),

              // Search Input
              const TTextField(
                labelText: 'Search for images...',
                prefixIcon: Icon(Iconsax.search_normal),
                fillColor: Colors.white,
              ),
              const SizedBox(height: TSizes.spaceBtwSections),

              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: TSizes.spaceBtwItems),
                  itemBuilder: (context, index) {
                    if (index == 4) {
                      // See More Button at end of row (5th element)
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
                              icon: const Icon(Iconsax.arrow_right_3),
                            ),
                          ),
                          const SizedBox(height: TSizes.spaceBtwItems / 2),
                          Text(
                            "See more",
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      );
                    }
                    final product = TProductImages.productImages[index];
                    return GestureDetector(
                      onTap: () => context.go('/product-explorer', extra: product),
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            padding: const EdgeInsets.all(TSizes.xs),
                            decoration: BoxDecoration(shape: BoxShape.circle),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: Image(
                                image: AssetImage(product.image),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: TSizes.spaceBtwItems / 2),
                          Text(
                            product.name,
                            style: Theme.of(context).textTheme.labelMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // const SizedBox(height: TSizes.spaceBtwSections),

              // "Popular image list" Section
              // Row(
              //    mainAxisAlignment: MainAxisAlignment.start,
              //    children: [
              //      // "left side see more button"
              //      TextButton(
              //        onPressed: (){},
              //        child: const Row(
              //          children: [
              //            Text("See More"),
              //            SizedBox(width: 4),
              //            Icon(Iconsax.arrow_right_3, size: 16),
              //          ],
              //        )
              //      ),
              //    ],
              // ),
              // const SizedBox(height: TSizes.spaceBtwItems),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    spacing: 3,
                    children: [
                      Icon(
                        Icons.local_fire_department_sharp,
                        color: Color(0xFFF29D38),
                      ),
                      Text("POPULAR"),
                    ],
                  ),
                  Text("See all"),
                ],
              ),
              const SizedBox(height: TSizes.spaceBtwItems),
              // Popular Image List (Vertical for now)
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: TProductImages.productImages.length - 1,
                separatorBuilder: (_, __) =>
                const SizedBox(height: TSizes.spaceBtwItems),
                itemBuilder: (context, index) {
                  return BeforeAfterSlider(
                    beforeImage: TProductImages.productImages[index].image,
                    afterImage: TProductImages.productImages[index + 1].image,
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
