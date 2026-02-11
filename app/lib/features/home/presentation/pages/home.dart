import 'package:century_ai/common/widgets/exterior_interior/exterior_interior.dart';
import 'package:century_ai/common/widgets/horizontal_icon_grid/circular_icon_item.dart';
import 'package:century_ai/common/widgets/horizontal_icon_grid/horizontal_icon_grid.dart';
import 'package:century_ai/common/widgets/profile/profile.dart';
import 'package:century_ai/common/widgets/search_input/search_input.dart';
import 'package:century_ai/features/home/presentation/widgets/home_drawer.dart';
import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/core/constants/sizes.dart';
import 'package:century_ai/data/repositories/product_repository.dart';
import 'package:century_ai/data/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isGridView = false;
  late final ProductRepository _productRepository;
  List<ProductImageModel> _products = ProductImages.productImages;
  bool _isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    _productRepository = ProductRepository(ApiService());
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final items = await _productRepository.getProducts(limit: 18);
    if (!mounted) return;
    setState(() {
      _products = items;
      _isLoadingProducts = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final quickProducts = _products.take(4).toList();
    return Scaffold(
      drawer: const HomeDrawer(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(TSizes.defaultSpace),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Profile(),
              const SizedBox(height: TSizes.spaceBtwSections),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "LET'S EXPLORE",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: TColors.warmTaupe,
                      letterSpacing: 2,
                    ),
                  ),
                  ExteriorInteriorSwitchSlider(),
                ],
              ),
              const SizedBox(height: TSizes.spaceBtwItems),
              SearchInput(),
              const SizedBox(height: TSizes.spaceBtwSections),
              if (_isLoadingProducts)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              SizedBox(
                height: 120,
                child: HorizontalIconGrid(
                  itemCount: quickProducts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == quickProducts.length) {
                      return CircularIconItem(
                        label: 'See more',
                        onTap: () => context.push('/product-library'),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: TColors.lightGray,
                          ),
                          child: IconButton(
                            onPressed: () => context.push('/product-library'),
                            icon: const Icon(Iconsax.arrow_right_3, size: 22),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      );
                    }

                    final product = quickProducts[index];

                    return CircularIconItem(
                      label: product.name,
                      onTap: () =>
                          context.go('/product-explorer', extra: product),
                      child: ClipOval(
                        child: Image.asset(product.image, fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.local_fire_department_sharp,
                        color: Color(0xFFF29D38),
                      ),
                      SizedBox(width: 4),
                      Text("POPULAR"),
                    ],
                  ),

                  Row(
                    children: [
                      const Text("See all"),
                      const SizedBox(width: 8),

                      /// 🔲 Layout toggle button
                      IconButton(
                        icon: Icon(
                          _isGridView ? Icons.view_list : Icons.grid_view,
                          size: 22,
                        ),
                        onPressed: () {
                          setState(() {
                            _isGridView = !_isGridView;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: TSizes.spaceBtwItems),
              // Popular Image List (Vertical for now)
              _isGridView
                  ? GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4, // 👈 4 images per row
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1, // square images
                          ),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];

                        return GestureDetector(
                          onTap: () {
                            // open product
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              product.image,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final product = _products[index];

                        return GestureDetector(
                          onTap: () {
                            // open product
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              product.image,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
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
