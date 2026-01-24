import 'package:century_ai/common/widgets/layout/grid_view_toggle_bar.dart';
import 'package:century_ai/common/widgets/section/section_header.dart';
import 'package:century_ai/common/widgets/section/section_list.dart';
import 'package:century_ai/features/home/screens/widgets/home_drawer.dart';
import 'package:century_ai/utils/constants/colors.dart';
import 'package:century_ai/utils/constants/image_strings.dart';
import 'package:century_ai/utils/constants/sizes.dart';
import 'package:century_ai/utils/theme/widget_themes/text_theme.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

class ArtGallery extends StatefulWidget {
  const ArtGallery({super.key});

  @override
  State<ArtGallery> createState() => _ArtGalleryState();
}

class _ArtGalleryState extends State<ArtGallery> {

  @override
  Widget build(BuildContext context) {
    // Get all category products from the data source
    final allCategories = ProductImages.productImages;

    return Scaffold(
      appBar: AppBar(title: const Text('Art Gallery')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(TSizes.defaultSpace),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionList(
                  items: allCategories,
                  headerBuilder: (context, category) {
                    return SectionHeader(
                      leading: sectionAvatarTitle(image: AssetImage(TImages.user),title: "Jaison Fernandes"),
                      trailing: TextButton(
                        onPressed: () {},
                        child: const Text(
                          'View all',
                          style: TextStyle(color: TColors.textSecondary,fontSize: 16),
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
    );
  }
}

Widget sectionAvatarTitle({required ImageProvider<Object> image, required String title}) {
  return Row(
    children: [
      CircleAvatar(radius: 18, backgroundImage: image),
      const SizedBox(width: 4),
      Expanded(child: Text(title, overflow: TextOverflow.ellipsis,style: TTextTheme.lightTextTheme.headlineSmall,)),
    ],
  );
}

