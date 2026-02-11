import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/core/constants/sizes.dart';
import 'package:century_ai/cubit/products/products_cubit.dart';
import 'package:century_ai/features/home/presentation/widgets/home_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

class MyWorkScreen extends StatefulWidget {
  const MyWorkScreen({super.key});

  @override
  State<MyWorkScreen> createState() => _MyWorkScreenState();
}

class _MyWorkScreenState extends State<MyWorkScreen> {
  int _crossAxisCount = 2;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProductsCubit>().state;
    final allCategories = state.products.isEmpty
        ? ProductImages.productImages
        : state.products;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Work'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      drawer: const HomeDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: TSizes.defaultSpace),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Collection',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                const Row(
                  children: [
                    Icon(Icons.lock, size: 14),
                    SizedBox(width: 4),
                    Text('Private - 209 items', style: TextStyle(fontSize: 12)),
                  ],
                ),
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
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
                                      color: const Color(0xFFA39F9F),
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
                        GridView.builder(
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
