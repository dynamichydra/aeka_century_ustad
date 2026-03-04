import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:century_ai/common/widgets/exterior_interior/exterior_interior.dart';
import 'package:century_ai/common/widgets/horizontal_icon_grid/circular_icon_item.dart';
import 'package:century_ai/common/widgets/horizontal_icon_grid/horizontal_icon_grid.dart';
import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/cubit/products/products_cubit.dart';
import 'package:century_ai/cubit/products/products_state.dart';
import 'package:century_ai/db/db_helper.dart';
import 'package:century_ai/features/home/presentation/widgets/home_drawer.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/core/constants/sizes.dart';
import 'package:century_ai/features/home/widgets/product_containers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isGridView = false;
  int _selectedIndex = 0;

  Future<void> logDb()async{
    final db = await DbHelper.database;

    final result = await db.query("products");

    print("===================================");
    print(result);
    print("===================================");
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);


    if (image != null && mounted) {
      context.push("/image_preview", extra: File(image.path));
    }
  }

  Future<void> _openProductForEditing(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      final fileName = assetPath.replaceAll("/", "_");
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      if (mounted) {
        context.push("/image_preview", extra: file);
      }
    } catch (e) {
      debugPrint("Error loading asset: $e");
    }
  }
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
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => context.read<ProductsCubit>().refreshProducts(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Text("Lets design Furniture with Century Decor", style: TextStyle(fontWeight: FontWeight.w200, fontSize: 14),)),
                      const SizedBox(height: TSizes.spaceBtwItems),
                      Center(child: ExteriorInteriorSwitchSlider()),
                      const SizedBox(height: TSizes.spaceBtwItems),
                      // SearchInput(),
                      TextField(
                        cursorHeight: 15,
                        style: const TextStyle(fontWeight: FontWeight.w100, fontSize: 13),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 13,
                            horizontal: 20,
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            maxHeight: 36,
                            maxWidth: 44,
                          ),
                          suffixIcon: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 1,
                                  spreadRadius: 1,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Center(
                                child: Image.asset(
                                  "assets/icons/app_icons/ai_search.png",
                                  width: 10,
                                  height: 10,
                                ),
                              ),
                            ),
                          ),
                          hintText: "Ai based furniture idea search",
                          hintStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w100),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              _buildTab("Interior", 0),
                              const SizedBox(width: 16),
                              _buildTab("Furniture", 1),
                            ],
                          ),

                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black.withOpacity(
                                      0.08,
                                    ), // light border
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                        0.08,
                                      ), // soft premium shadow
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () {
                                      // your action here
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Image.asset(
                                        "assets/icons/app_icons/trendng2.png",
                                        width: 12,
                                        height: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black.withOpacity(
                                      0.08,
                                    ), // light subtle border
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                        0.08,
                                      ), // soft premium shadow
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () {
                                      // your action here
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: Icon(
                                        Icons.favorite,
                                        size: 12,
                                        color: Color(0xFF898888),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              /// 🔲 Layout toggle button
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black.withOpacity(
                                      0.08,
                                    ), // light border
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                        0.08,
                                      ), // softer premium shadow
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () {
                                      setState(() {
                                        _isGridView = !_isGridView;
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Icon(
                                        _isGridView
                                            ? Icons.view_list
                                            : Icons.grid_view,
                                        size: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: TSizes.spaceBtwItems),
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
                              isSelected: index == 2,
                              selectedBorderColor: TColors.warmBeige,
                              onTap: () {
                                _openProductForEditing(product.image);
                              },
                              child: ClipOval(
                                child: Image.asset(
                                  product.image,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
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
                                    _openProductForEditing(product.image);
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
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final product = products[index];

                                return GestureDetector(
                                  onTap: () {
                                    _openProductForEditing(product.image);
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
                      const SizedBox(
                        height: 100,
                      ), // Spacing for floating buttons
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: TSizes.defaultSpace,
              left: TSizes.defaultSpace,
              right: TSizes.defaultSpace,
              child: Row(
                children: [
                  Expanded(
                    child: _PremiumActionButton(
                      icon: Icons.camera_alt,
                      label: "Take Photo",
                      onTap: () => context.push("/camera"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _PremiumActionButton(
                      icon: Icons.image,
                      label: "Upload Photo",
                      onTap: _pickFromGallery,
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

  Widget _buildTab(String title, int index) {
    final bool isActive = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: isActive ? Colors.black : Colors.grey,
            ),
            child: Text(title),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 1,
            width: isActive ? 50 : 0,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumActionButton extends StatelessWidget {
  const _PremiumActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF1F1919)),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F1919),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
