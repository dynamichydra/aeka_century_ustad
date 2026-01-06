import 'package:century_ai/common/widgets/inputs/text_field.dart';
import 'package:century_ai/features/home/screens/widgets/home_drawer.dart';
import 'package:century_ai/utils/constants/colors.dart';
import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:century_ai/utils/constants/sizes.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class ProductExplorerScreen extends StatefulWidget {
  final ProductImageModel selectedProduct;

  const ProductExplorerScreen({super.key, required this.selectedProduct});

  @override
  State<ProductExplorerScreen> createState() => _ProductExplorerScreenState();
}

class _ProductExplorerScreenState extends State<ProductExplorerScreen> {
  late ProductImageModel _currentProduct;
  int _crossAxisCount = 2;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.selectedProduct;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: TSizes.md),
            child: Image.asset(TImages.smallLogo, width: 35, height: 35),
          ),
        ],
      ),
      drawer: const HomeDrawer(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(TSizes.defaultSpace),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              const TTextField(
                labelText: 'Search',
                prefixIcon: Icon(Iconsax.search_normal),
                fillColor: Colors.white,
                suffixIcon: Image(
                  image: AssetImage(TImages.homeInputRightIcon),
                  fit: BoxFit.cover,
                ),
                isCircularIcon: true,
              ),
              const SizedBox(height: TSizes.spaceBtwSections),

              // Horizontal Category/Product List
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5, // 3 images + 1 See More
                  itemBuilder: (context, index) {
                    if (index == 4) {
                      return Padding(
                        padding: const EdgeInsets.only(right: TSizes.spaceBtwItems),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: TColors.inputBackground,
                              ),
                              child: IconButton(
                                onPressed: () {},
                                icon: const Icon(Iconsax.arrow_right_3, color: Colors.black),
                              ),
                            ),
                            const SizedBox(height: TSizes.spaceBtwItems / 2),
                            Text(
                              "See more",
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      );
                    }

                    final product = TProductImages.productImages[index];
                    final isSelected = _currentProduct.id == product.id;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentProduct = product;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: TSizes.spaceBtwItems),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? TColors.productSelectedColor : Colors.transparent,
                                  width: 4,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(4), // Hollow ring gap
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                  ),
                                  child: CircleAvatar(
                                    radius: 30,
                                    backgroundImage: AssetImage(product.image),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: TSizes.spaceBtwItems / 2),
                            Text(
                              product.name,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: TSizes.spaceBtwSections),

              // Grid View or List View of related images
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _crossAxisCount,
                  crossAxisSpacing: TSizes.spaceBtwItems,
                  mainAxisSpacing: TSizes.spaceBtwItems,
                  childAspectRatio: 1,
                ),
                itemCount: 8, // Representative number
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(TSizes.md),
                    child: Image.asset(
                      _currentProduct.image, // In a real app, these might be different sub-images
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(TSizes.defaultSpace),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Menu Button (Left)
            Builder(
              builder: (context) => Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Iconsax.menu_1, color: Colors.black),
                ),
              ),
            ),
            const SizedBox(width: TSizes.spaceBtwSections),
            // Change View Button (Right)
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
