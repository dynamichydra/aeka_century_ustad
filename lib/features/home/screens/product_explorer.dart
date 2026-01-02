import 'package:century_ai/common/widgets/inputs/text_field.dart';
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
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.selectedProduct;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentProduct.name),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Iconsax.more)),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(TSizes.defaultSpace),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              const TTextField(
                labelText: 'Search for images...',
                prefixIcon: Icon(Iconsax.search_normal),
                fillColor: Color(0xFFF9F9F9),
              ),
              const SizedBox(height: TSizes.spaceBtwSections),

              // Horizontal Category/Product List
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: TProductImages.productImages.length,
                  itemBuilder: (context, index) {
                    final product = TProductImages.productImages[index];
                    final isSelected = _currentProduct.id == product.id;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentProduct = product;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: TSizes.spaceBtwItems),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.orange : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundImage: AssetImage(product.image),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: TSizes.spaceBtwSections),

              // Grid View or List View of related images
              _isGridView
                  ? GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
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
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 8,
                      separatorBuilder: (_, __) => const SizedBox(height: TSizes.spaceBtwItems),
                      itemBuilder: (context, index) {
                         return ClipRRect(
                          borderRadius: BorderRadius.circular(TSizes.md),
                          child: Image.asset(
                            _currentProduct.image,
                            height: 200,
                            width: double.infinity,
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: TSizes.sm, horizontal: TSizes.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(TSizes.inputFieldRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Menu Button (Left)
              IconButton(
                onPressed: () {},
                icon: const Icon(Iconsax.menu_1, color: Colors.black),
              ),
              // Change View Button (Right)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isGridView = !_isGridView;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: TSizes.md, vertical: TSizes.sm),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(TSizes.buttonRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isGridView ? Iconsax.row_vertical : Iconsax.grid_1,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: TSizes.sm),
                      Text(
                        _isGridView ? "List View" : "Grid View",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
