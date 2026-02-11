import 'package:century_ai/common/widgets/layout/grid_view_toggle_bar.dart';
import 'package:century_ai/common/widgets/section/section_header.dart';
import 'package:century_ai/common/widgets/section/section_list.dart';
import 'package:century_ai/features/home/presentation/widgets/home_drawer.dart';
import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/core/constants/sizes.dart';
import 'package:century_ai/data/repositories/product_repository.dart';
import 'package:century_ai/data/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final ProductRepository _productRepository;
  List<ProductImageModel> _favorites = ProductImages.productImages.take(4).toList();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _productRepository = ProductRepository(ApiService());
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await _productRepository.getFavoriteProducts(limit: 8);
    if (!mounted) return;
    setState(() {
      _favorites = favorites;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(TSizes.defaultSpace),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                SectionList(
                  items: _favorites.take(1).toList(),
                  headerBuilder: (context, category) {
                    return SectionHeader(
                      leading: sectionTitleText(context, "My Collection"),
                      trailing: TextButton(
                        onPressed: () {},
                        child: const Text(
                          'view all',
                          style: TextStyle(color: TColors.mediumDarkGray),
                        ),
                      ),
                    );
                  },
                  itemBuilder: (context, category) {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(TSizes.defaultSpace),
        child: Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.6,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: TColors.dangerRed,
                side: const BorderSide(color: TColors.dangerRed),
              ),
              child: const Text("+ Create a new Collection"),
            ),
          ),
        ),
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
