import 'package:century_ai/common/widgets/section/section_header.dart';
import 'package:century_ai/common/widgets/section/section_list.dart';
import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/core/constants/sizes.dart';
import 'package:century_ai/core/theme/widget_themes/text_theme.dart';
import 'package:century_ai/data/repositories/product_repository.dart';
import 'package:century_ai/data/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ArtGallery extends StatefulWidget {
  const ArtGallery({super.key});

  @override
  State<ArtGallery> createState() => _ArtGalleryState();
}

class _ArtGalleryState extends State<ArtGallery> {
  late final ProductRepository _productRepository;
  List<ProductImageModel> _categories = ProductImages.productImages;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _productRepository = ProductRepository(ApiService());
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await _productRepository.getProducts(limit: 18);
    if (!mounted) return;
    setState(() {
      _categories = products;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Art Gallery')),
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
                  items: _categories,
                  headerBuilder: (context, category) {
                    return SectionHeader(
                      leading: sectionAvatarTitle(
                        image: const AssetImage(TImages.user),
                        title: 'Jaison Fernandes',
                      ),
                      trailing: TextButton(
                        onPressed: () {},
                        child: const Text(
                          'View all',
                          style: TextStyle(
                            color: TColors.mediumDarkGray,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                  itemBuilder: (context, category) {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                            child: Image.asset(category.image, fit: BoxFit.cover),
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
    );
  }
}

Widget sectionAvatarTitle({
  required ImageProvider<Object> image,
  required String title,
}) {
  return Row(
    children: [
      CircleAvatar(radius: 18, backgroundImage: image),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: TTextTheme.lightTextTheme.headlineSmall,
        ),
      ),
    ],
  );
}
