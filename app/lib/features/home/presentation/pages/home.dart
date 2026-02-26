import 'package:century_ai/common/widgets/exterior_interior/exterior_interior.dart';
import 'package:century_ai/common/widgets/horizontal_icon_grid/circular_icon_item.dart';
import 'package:century_ai/common/widgets/horizontal_icon_grid/horizontal_icon_grid.dart';
import 'package:century_ai/common/widgets/profile/profile.dart';
import 'package:century_ai/common/widgets/search_input/search_input.dart';
import 'package:century_ai/cubit/products/products_cubit.dart';
import 'package:century_ai/cubit/products/products_state.dart';
import 'package:century_ai/features/home/presentation/widgets/home_drawer.dart';
import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/core/constants/sizes.dart';
import 'package:century_ai/features/home/widgets/product_containers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isGridView = false;

  @override
  Widget build(BuildContext context) {
    final ProductsState productsState = context.watch<ProductsCubit>().state;
    final products = productsState.products.isEmpty
        ? ProductImages.productImages
        : productsState.products;
    final quickProducts = products.take(4).toList();
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const HomeDrawer(),
      body: RefreshIndicator(
        onRefresh: () => context.read<ProductsCubit>().refreshProducts(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: ExteriorInteriorSwitchSlider()),
                const SizedBox(height: TSizes.spaceBtwItems),
                // SearchInput(),
                TextField(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            spreadRadius: 2,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(
                          "assets/icons/app_icons/ai_search.png",
                          width: 20,
                          height: 20,
                        ),
                      ),
                    ),
                    hintText: "Ai based furniture idea search",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                // const SizedBox(height: TSizes.spaceBtwSections),
                // if (productsState.isLoading)
                //   const Padding(
                //     padding: EdgeInsets.symmetric(vertical: 16),
                //     child: Center(child: CircularProgressIndicator()),
                //   ),
                // SizedBox(
                //   height: 120,
                //   child: HorizontalIconGrid(
                //     itemCount: quickProducts.length + 1,
                //     itemBuilder: (context, index) {
                //       if (index == quickProducts.length) {
                //         return CircularIconItem(
                //           label: 'See more',
                //           onTap: () => context.push('/product-library'),
                //           child: Container(
                //             decoration: const BoxDecoration(
                //               shape: BoxShape.circle,
                //               color: TColors.lightGray,
                //             ),
                //             child: IconButton(
                //               onPressed: () => context.push('/product-library'),
                //               icon: const Icon(Iconsax.arrow_right_3, size: 22),
                //               padding: EdgeInsets.zero,
                //               constraints: const BoxConstraints(),
                //             ),
                //           ),
                //         );
                //       }
                //
                //       final product = quickProducts[index];
                //
                //       return CircularIconItem(
                //         label: product.name,
                //         onTap: () =>
                //             context.go('/product-explorer', extra: product),
                //         child: ClipOval(
                //           child: Image.asset(product.image, fit: BoxFit.cover),
                //         ),
                //       );
                //     },
                //   ),
                // ),
                SizedBox(height: 20,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            "Interior",
                            style: TextStyle(
                              color: Colors.black,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            "Furniture",
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        InkWell(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 3,
                                  spreadRadius: 2,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child:  Image.asset(
                                "assets/icons/app_icons/trendng2.png",
                                width: 20,
                                height: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        InkWell(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 3,
                                  spreadRadius: 2,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.favorite,
                                size: 18,
                                color: Color(0xFF898888),
                              ),
                            ),
                          ),
                        ),
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
                              crossAxisCount: 2, // 👈 4 images per row
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1, // square images
                            ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];

                          return GestureDetector(
                            onTap: () {
                              // open product
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ProductContainers(
                                imagePath: product.image,
                                isTrending: product.isTrending,
                              ),
                            ),
                          );
                        },
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final product = products[index];

                          return GestureDetector(
                            onTap: () {
                              // open product
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ProductContainers(
                                imagePath: product.image,
                                isTrending: product.isTrending,
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
