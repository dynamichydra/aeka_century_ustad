import 'package:century_ai/common/widgets/horizontal_icon_grid/circular_icon_item.dart';
import 'package:century_ai/common/widgets/horizontal_icon_grid/horizontal_icon_grid.dart';
import 'package:century_ai/common/widgets/layout/adaptive_grid_view.dart';
import 'package:century_ai/common/widgets/layout/grid_view_toggle_bar.dart';
import 'package:century_ai/common/widgets/search_input/search_input.dart';
import 'package:century_ai/cubit/products/products_cubit.dart';
import 'package:century_ai/features/home/presentation/widgets/home_drawer.dart';
import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/core/constants/sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

class ProductExplorerScreen extends StatefulWidget {
  final ProductImageModel selectedProduct;

  const ProductExplorerScreen({super.key, required this.selectedProduct});

  @override
  State<ProductExplorerScreen> createState() => _ProductExplorerScreenState();
}

class _ProductExplorerScreenState extends State<ProductExplorerScreen> {
  late ProductImageModel _currentProduct;
  List<ProductImageModel> _productsCache = ProductImages.productImages;
  int _crossAxisCount = 2;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.selectedProduct;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProductsCubit>().state;
    final products = state.products.isEmpty ? _productsCache : state.products;
    _productsCache = products;
    final selected = products.where((p) => p.id == _currentProduct.id);
    if (selected.isNotEmpty) _currentProduct = selected.first;
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
              SearchInput(),
              const SizedBox(height: TSizes.spaceBtwSections),
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              SizedBox(
                height: 100,
                child: HorizontalIconGrid(
                  itemCount: products.take(4).length + 1,
                  itemBuilder: (context, index) {
                    final quickProducts = products.take(4).toList();
                    if (index == quickProducts.length) {
                      return CircularIconItem(
                        label: 'See more',
                        onTap: () {},
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: TColors.lightGray,
                          ),
                          child: const Icon(
                            Iconsax.arrow_right_3,
                            size: 22,
                            color: Colors.black,
                          ),
                        ),
                      );
                    }
                    final product = quickProducts[index];
                    return CircularIconItem(
                      label: product.name,
                      isSelected: _currentProduct.id == product.id,
                      selectedBorderColor: TColors.warmBeige,
                      onTap: () {
                        setState(() {
                          _currentProduct = product;
                        });
                      },
                      child: ClipOval(
                        child: Image.asset(product.image, fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: TSizes.spaceBtwSections),
              AdaptiveGridView(
                crossAxisCount: _crossAxisCount,
                itemCount: 8,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(TSizes.md),
                    child: Image.asset(
                      _currentProduct.image,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ],
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
