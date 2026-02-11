import 'package:century_ai/common/widgets/layout/grid_view_toggle_bar.dart';
import 'package:century_ai/common/widgets/section/section_header.dart';
import 'package:century_ai/common/widgets/section/section_list.dart';
import 'package:century_ai/features/home/presentation/widgets/home_drawer.dart';
import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/core/constants/sizes.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

class ProductLibraryScreen extends StatefulWidget {
  const ProductLibraryScreen({super.key});

  @override
  State<ProductLibraryScreen> createState() => _ProductLibraryScreenState();
}

class _ProductLibraryScreenState extends State<ProductLibraryScreen> {
  int _crossAxisCount = 2;

  @override
  Widget build(BuildContext context) {
    // Get all category products from the data source
    final allCategories = ProductImages.productImages;

    return Scaffold(
      drawer: const HomeDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(TSizes.defaultSpace),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Back Button and Title
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Iconsax.arrow_left),
                    ),
                    const SizedBox(width: TSizes.spaceBtwItems),
                    Text(
                      'Laibery',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
                const SizedBox(height: TSizes.spaceBtwSections),

               SectionList(
                  items: allCategories,
                  headerBuilder: (context, category) {
                    return SectionHeader(
                      leading: sectionTitleText(context, category.name),
                      trailing: TextButton(
                        onPressed: () {},
                        child: const Text(
                          'view all',
                          style: TextStyle(color: TColors.mediumDarkGray),
                        ),
                      ),
                    );
                  },

                  /// CONTENT
                  itemBuilder: (context, category) {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _crossAxisCount,
                        crossAxisSpacing: TSizes.spaceBtwItems,
                        mainAxisSpacing: TSizes.spaceBtwItems,
                        childAspectRatio: 1,
                      ),
                      itemCount: 4,
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
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: GridViewToggleBar(
        isGridView: _crossAxisCount == 2,
        onMenuTap: () => Scaffold.of(context).openDrawer(),
        onToggleView: () {
          setState(() {
            _crossAxisCount = _crossAxisCount == 2 ? 4 : 2;
          });
        },
      ),
    );
  }
}

Widget sectionTitleText(BuildContext context, String text) {
  return Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
      color: const Color(0xFFA39F9F),
    ),
    overflow: TextOverflow.ellipsis,
  );
}
