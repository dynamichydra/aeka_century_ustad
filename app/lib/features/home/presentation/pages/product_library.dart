import 'package:century_ai/common/widgets/layout/grid_view_toggle_bar.dart';
import 'package:century_ai/cubit/products/products_cubit.dart';
import 'package:century_ai/features/home/presentation/widgets/home_drawer.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/core/constants/sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

class ProductLibraryScreen extends StatefulWidget {
  const ProductLibraryScreen({super.key});

  @override
  State<ProductLibraryScreen> createState() => _ProductLibraryScreenState();
}

class _ProductLibraryScreenState extends State<ProductLibraryScreen> {
  int _crossAxisCount = 2;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      context.read<ProductsCubit>().loadMoreProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProductsCubit>().state;
    final categories = state.products.isEmpty
        ? ProductImages.productImages
        : state.products;
    return Scaffold(
      drawer: const HomeDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TSizes.defaultSpace),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Iconsax.arrow_left),
                  ),
                  const SizedBox(width: TSizes.spaceBtwItems),
                  Text(
                    'Library',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              const SizedBox(height: TSizes.spaceBtwSections),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => context.read<ProductsCubit>().refreshProducts(),
                  child: state.isLoading && categories.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : GridView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _crossAxisCount,
                            crossAxisSpacing: TSizes.spaceBtwItems,
                            mainAxisSpacing: TSizes.spaceBtwItems,
                            childAspectRatio: 1,
                          ),
                          itemCount: categories.length + (state.isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= categories.length) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final category = categories[index];
                            return GestureDetector(
                              onTap: () => context.push(
                                '/product-explorer',
                                extra: category,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(TSizes.borderRadiusLg),
                                child: Image.asset(category.image, fit: BoxFit.cover),
                              ),
                            );
                          },
                        ),
                ),
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
