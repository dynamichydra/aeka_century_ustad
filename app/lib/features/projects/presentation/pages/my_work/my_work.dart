import 'package:century_ai/features/home/presentation/widgets/home_drawer.dart';
import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/core/constants/sizes.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

class MyWorkScreen extends StatefulWidget {
  const MyWorkScreen({super.key});

  @override
  State<MyWorkScreen> createState() => _MyWorkScreenState();
}

class _MyWorkScreenState extends State<MyWorkScreen> {
  int _crossAxisCount = 2;

  @override
  Widget build(BuildContext context) {
    // Get all category products from the data source
    final allCategories = ProductImages.productImages;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Work'),
        automaticallyImplyLeading: false, 
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      drawer: HomeDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric( horizontal:TSizes.defaultSpace),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Collection',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.lock, size: 14),
                    SizedBox(width: 4),
                    Text('Private · 209 items', style: TextStyle(fontSize: 12)),
                  ],
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: allCategories.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: TSizes.spaceBtwSections),
                  itemBuilder: (context, index) {
                    final category = allCategories[index];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Header: Title and View All
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                category.name.toUpperCase(),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                      color: Color(0xFFA39F9F),
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: const Text(
                                "view all",
                                style: TextStyle(color: TColors.mediumDarkGray),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: TSizes.spaceBtwItems),

                        // Grid showing the SAME image 4 times
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _crossAxisCount,
                                crossAxisSpacing: TSizes.spaceBtwItems,
                                mainAxisSpacing: TSizes.spaceBtwItems,
                                childAspectRatio: 1,
                              ),
                          itemCount: 4, // Always show 4 images (repeated)
                          itemBuilder: (context, _) {
                            return GestureDetector(
                              onTap: () => context.push(
                                '/product-explorer',
                                extra: category,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  TSizes.borderRadiusLg,
                                ),
                                child: Image.asset(
                                  category.image,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TSizes.defaultSpace,
          vertical: TSizes.md,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Menu Button
            Builder(
              builder: (context) => Container(
                decoration: BoxDecoration(
                  border: Border.all(color: TColors.lightGray),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Iconsax.menu_1, color: Colors.black),
                ),
              ),
            ),
            const SizedBox(width: TSizes.spaceBtwSections),
            // toggle between 2 and 4 images in a row
            Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _crossAxisCount = (_crossAxisCount == 2) ? 4 : 2;
                  });
                },
                icon: Icon(
                  _crossAxisCount == 2 ? Icons.grid_view : Icons.view_list,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
