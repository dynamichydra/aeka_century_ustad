import 'package:century_ai/common/widgets/chips/rounded_choice_chips.dart';
import 'package:century_ai/common/widgets/exterior_interior/exterior_interior.dart';
import 'package:century_ai/common/widgets/images/t_circular_image.dart';
import 'package:century_ai/common/widgets/images/t_rounded_image.dart';
import 'package:century_ai/common/widgets/profile/profile.dart';
import 'package:century_ai/common/widgets/search_input/search_input.dart';
import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/core/constants/enums.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/core/constants/sizes.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isGridView = false;
  String _selectedCategory = 'Interiors';

  @override
  Widget build(BuildContext context) {
    final products = ProductImages.productImages;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async => await Future.delayed(const Duration(seconds: 1)),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: TSizes.defaultSpace),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: TSizes.spaceBtwItems),
                    
                    // 1️⃣ Header Row (User image only, small)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Profile(avatarRadius: 18, needUserName: false), // Small avatar, no name
                      ],
                    ),

                    const SizedBox(height: TSizes.spaceBtwSections),

                    // 2️⃣ Interior / Exterior Toggle
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: TSizes.sm),
                        decoration: BoxDecoration(
                          color: TColors.lightGray.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(TSizes.borderRadiusLg),
                        ),
                        child: const ExteriorInteriorSwitchSlider(),
                      ),
                    ),

                    const SizedBox(height: TSizes.spaceBtwItems),

                    // 3️⃣ Search Bar
                    const SearchInput(),

                    const SizedBox(height: TSizes.spaceBtwSections),

                    // 4️⃣ Tabs + Action Buttons Row (Refined)
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildTab("Interiors"),
                                const SizedBox(width: TSizes.spaceBtwItems),
                                _buildTab("Furniture's"),
                              ],
                            ),
                          ),
                        ),
                        _buildBorderedIconButton(Iconsax.flash, TColors.sunsetOrange),
                        const SizedBox(width: TSizes.sm),
                        _buildBorderedIconButton(Iconsax.heart, TColors.dangerRed),
                        const SizedBox(width: TSizes.sm),
                        _buildBorderedIconButton(_isGridView ? Icons.view_list : Icons.grid_view, TColors.charcoalGray, onTap: () => setState(() => _isGridView = !_isGridView)),
                      ],
                    ),

                    const SizedBox(height: TSizes.spaceBtwItems),

                    // 5️⃣ Horizontal Circular Category List
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(width: TSizes.spaceBtwItems),
                        itemBuilder: (context, index) {
                          return Column(
                            children: [
                              TCircularImage(
                                image: products[index].image,
                                width: 50,
                                height: 50,
                                padding: 0,
                                backgroundColor: TColors.lightGray,
                              ),
                              const SizedBox(height: TSizes.xs),
                              Text(
                                products[index].name,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: TSizes.spaceBtwSections),

                    // 6️⃣ Image Feed
                    _isGridView ? _buildGridView(products) : _buildListView(products),
                    
                    const SizedBox(height: 120), // Spacing for floating buttons
                  ],
                ),
              ),
            ),

            // 7️⃣ Bottom Floating Buttons (Refined: White background, pill shape)
            Positioned(
              bottom: TSizes.defaultSpace,
              left: TSizes.defaultSpace,
              right: TSizes.defaultSpace,
              child: Row(
                children: [
                  Expanded(
                    child: _buildFloatingButton(
                      icon: Iconsax.camera,
                      label: "Take a Photo",
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: TSizes.sm),
                  Expanded(
                    child: _buildFloatingButton(
                      icon: Iconsax.document_upload,
                      label: "Upload",
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Refined Tab Widget
  Widget _buildTab(String label) {
    bool isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = label),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isSelected ? TColors.charcoalGray : TColors.darkGray,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 20,
              color: TColors.charcoalGray,
            ),
        ],
      ),
    );
  }

  // Refined Bordered Action Icon
  Widget _buildBorderedIconButton(IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(TSizes.sm),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: TColors.lightGray),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // Refined Floating Button
  Widget _buildFloatingButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: TColors.pureWhite,
        foregroundColor: TColors.charcoalGray,
        elevation: 2,
        padding: const EdgeInsets.symmetric(vertical: TSizes.md),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)), // Pill shape
        side: const BorderSide(color: TColors.lightGray),
      ),
    );
  }

  Widget _buildListView(List<ProductImageModel> products) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: TSizes.spaceBtwItems),
      itemBuilder: (context, index) {
        return Stack(
          children: [
            TRoundedImage(
              image: products[index].image,
              imageType: ImageType.asset,
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
              borderRadius: TSizes.borderRadiusLg,
              padding: 0,
            ),
            Positioned(
              top: TSizes.md,
              right: TSizes.md,
              child: Container(
                decoration: BoxDecoration(
                  color: TColors.pureWhite.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Iconsax.heart, color: TColors.dangerRed, size: 20),
                  onPressed: () {},
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGridView(List<ProductImageModel> products) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: TSizes.spaceBtwItems,
        crossAxisSpacing: TSizes.spaceBtwItems,
        childAspectRatio: 0.7,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return TRoundedImage(
          image: products[index].image,
          imageType: ImageType.asset,
          width: double.infinity,
          fit: BoxFit.cover,
          borderRadius: TSizes.borderRadiusLg,
          padding: 0,
        );
      },
    );
  }
}
