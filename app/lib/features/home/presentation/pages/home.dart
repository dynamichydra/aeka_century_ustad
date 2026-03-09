import 'dart:convert';
import 'dart:io';

import 'package:century_ai/cubit/home/home_cubit.dart';
import 'package:century_ai/cubit/home/home_state.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:century_ai/common/widgets/exterior_interior/exterior_interior.dart';
import 'package:century_ai/common/widgets/horizontal_icon_grid/circular_icon_item.dart';
import 'package:century_ai/common/widgets/horizontal_icon_grid/horizontal_icon_grid.dart';
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeCubit(),
      child: const _HomeScreenContent(),
    );
  }
}

class _HomeScreenContent extends StatefulWidget {
  const _HomeScreenContent();

  @override
  State<_HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<_HomeScreenContent> {
  final TextEditingController _searchController = TextEditingController();
  bool _isGridView = false;
  String? _selectedCategory;
  Map<int, Map<String, List<ProductImageModel>>> _productsByTabAndCategory = {};

  @override
  void initState() {
    super.initState();
    _loadProductsByCategoryFromAsset();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProductsByCategoryFromAsset() async {
    try {
      final rawJson = await rootBundle.loadString('assets/data/_data.json');
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = manifest.listAssets();
      final exactAssetMap = <String, String>{};
      final softAssetMap = <String, String>{};

      for (final assetPath in allAssets) {
        final exactKey = _normalizeAssetPath(assetPath);
        final softKey = _normalizeAssetPathSoft(assetPath);
        exactAssetMap[exactKey] = assetPath;
        softAssetMap.putIfAbsent(softKey, () => assetPath);
      }
      final decoded = jsonDecode(rawJson);

      if (decoded is! Map<String, dynamic>) return;

      final parsed = <int, Map<String, List<ProductImageModel>>>{
        0: {}, // Interiors
        1: {}, // Furnitures
      };

      void parseGroup(String groupKey, int tabIndex) {
        final groupData = decoded[groupKey];
        if (groupData is! Map<String, dynamic>) return;

        groupData.forEach((category, value) {
          if (value is! List) return;

          final items = <ProductImageModel>[];
          for (final item in value) {
            if (item is! Map) continue;
            final map = item.cast<String, dynamic>();
            final rawPath = (map['image_path'] ?? '').toString().trim();
            if (rawPath.isEmpty) continue;

            final prefixedPath =
                rawPath.startsWith('assets/') ? rawPath : 'assets/$rawPath';
            final resolvedPath =
                exactAssetMap[_normalizeAssetPath(prefixedPath)] ??
                softAssetMap[_normalizeAssetPathSoft(prefixedPath)];
            if (resolvedPath == null) continue;

            items.add(
              ProductImageModel(
                id: (map['id'] ?? '${category}_${items.length + 1}').toString(),
                name: category,
                image: resolvedPath,
                isTrending: false,
                imageCategory: groupKey == 'interiors' ? 'Interiors' : 'Furnitures',
                subCategory: category,
              ),
            );
          }

          if (items.isNotEmpty) {
            parsed[tabIndex]![category] = items;
          }
        });
      }

      parseGroup('interiors', 0);
      parseGroup('furnitures', 1);

      if (!mounted) return;
      setState(() {
        _productsByTabAndCategory = parsed;
        final initialTabCategories = _productsByTabAndCategory[context.read<HomeCubit>().state.selectedIndex]?.keys;
        if (initialTabCategories != null && initialTabCategories.isNotEmpty) {
          _selectedCategory = initialTabCategories.first;
        }
      });
    } catch (e) {
      debugPrint('Error parsing assets/data/_data.json: $e');
    }
  }

  String _normalizeAssetPath(String value) {
    return value.replaceAll('\\', '/').trim().toLowerCase();
  }

  String _normalizeAssetPathSoft(String value) {
    return _normalizeAssetPath(value).replaceAll(RegExp(r'[\s_\-]+'), '');
  }

  String _normalizeCategory(String value) {
    return value.trim().toLowerCase();
  }

  List<ProductImageModel> _resolveQuickProducts(
    List<ProductImageModel> fallbackProducts,
    int selectedIndex,
  ) {
    final currentTabData = _productsByTabAndCategory[selectedIndex];
    if (currentTabData == null || currentTabData.isEmpty) {
      return fallbackProducts.take(4).toList();
    }

    final quickItems = <ProductImageModel>[];
    for (final entry in currentTabData.entries) {
      if (entry.value.isEmpty) continue;
      quickItems.add(
        ProductImageModel(
          id: 'cat_${entry.key}',
          name: entry.key,
          image: entry.value.first.image,
          isTrending: false,
          imageCategory: selectedIndex == 0 ? 'Interiors' : 'Furnitures',
          subCategory: entry.key,
        ),
      );
    }

    return quickItems.isEmpty ? fallbackProducts.take(4).toList() : quickItems;
  }

  List<ProductImageModel> _resolveVisibleProducts(
    List<ProductImageModel> fallbackProducts,
    int selectedIndex,
  ) {
    final currentTabData = _productsByTabAndCategory[selectedIndex];
    if (currentTabData == null || currentTabData.isEmpty) {
      return fallbackProducts;
    }

    final selectedCategory = _selectedCategory;
    if (selectedCategory == null) {
      return fallbackProducts;
    }

    final filtered = currentTabData[selectedCategory];
    if (filtered == null || filtered.isEmpty) {
      final normalizedSelected = _normalizeCategory(selectedCategory);
      for (final entry in currentTabData.entries) {
        if (_normalizeCategory(entry.key) == normalizedSelected &&
            entry.value.isNotEmpty) {
          return entry.value;
        }
      }
      return fallbackProducts;
    }
    return filtered;
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && mounted) {
      context.push("/image_preview", extra: {
        "imageFile": File(image.path),
        "image_category": "Gallery",
        "sub_category": "Uploaded",
      });
    }
  }

  Future<void> _openProductForEditing(ProductImageModel product) async {
    try {
      final assetPath = product.image;
      final byteData = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      final fileName = assetPath.replaceAll("/", "_");
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );
      if (mounted) {
        context.push("/image_preview", extra: {
          "imageFile": file,
          "image_category": product.imageCategory ?? "",
          "sub_category": product.subCategory ?? "",
        });
      }
    } catch (e) {
      debugPrint("Error loading asset: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeCubit = context.watch<HomeCubit>();
    final homeState = homeCubit.state;
    final productsState = context.watch<ProductsCubit>().state;
    
    final products = productsState.products.isEmpty
        ? ProductImages.productImages
        : productsState.products;
    
    final quickProducts = _resolveQuickProducts(products, homeState.selectedIndex);
    final visibleProducts = _resolveVisibleProducts(products, homeState.selectedIndex);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      drawer: const HomeDrawer(),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => context.read<ProductsCubit>().refreshProducts(),
              color: const Color(0xFF1F1919),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildTopBar(),
                  _buildHeroSection(homeState, homeCubit),
                  _buildSearchSection(homeCubit),
                  _buildTabsAndFilters(homeState, homeCubit),
                  _buildCategoryGrid(quickProducts),
                  _buildProductSection(visibleProducts),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
            _buildFloatingActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Builder(
                  builder: (context) => GestureDetector(
                    onTap: () => Scaffold.of(context).openDrawer(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Iconsax.menu, size: 20, color: Color(0xFF1F1919)),
                    ),
                  ),
                ),
                Image.asset(TImages.lightAppLogo, height: 24),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Iconsax.notification, size: 20, color: Color(0xFF1F1919)),
                ),
              ],
            ),
            const SizedBox(height: 15),
            const Text(
              "Let's design Furniture with Century Decor",
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 13,
                color: Color(0xFF898888),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(HomeState homeState, HomeCubit homeCubit) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: ExteriorInteriorSwitchSlider(
            value: homeState.isExterior,
            onChanged: (val) => homeCubit.setExterior(val),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection(HomeCubit homeCubit) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            cursorColor: const Color(0xFF1F1919),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
            decoration: InputDecoration(
              hintText: "AI based furniture idea search...",
              hintStyle: TextStyle(color: Colors.black.withOpacity(0.35), fontSize: 13),
              prefixIcon: const Icon(Iconsax.search_normal, size: 18, color: Color(0xFF898888)),
              suffixIcon: Padding(
                padding: const EdgeInsets.all(4.0),
                child: GestureDetector(
                  onTap: () => homeCubit.fetchResults(_searchController.text),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1F1919),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      "assets/icons/app_icons/ai_search.png",
                      width: 14,
                      height: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            ),
            onSubmitted: (val) => homeCubit.fetchResults(val),
          ),
        ),
      ),
    );
  }

  Widget _buildTabsAndFilters(HomeState homeState, HomeCubit homeCubit) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Tabs
            Row(
              children: [
                _buildTabItem("Interiors", homeState.selectedIndex == 0, () {
                  homeCubit.setSelectedIndex(0);
                  _updateSelectedCategory(0);
                }),
                const SizedBox(width: 20),
                _buildTabItem("Furnitures", homeState.selectedIndex == 1, () {
                  homeCubit.setSelectedIndex(1);
                  _updateSelectedCategory(1);
                }),
              ],
            ),
            // Filter Icons
            Row(
              children: [
                _buildFilterIcon(
                  homeState.isTrendingShowing ? "assets/icons/app_icons/trendng2_white.png" : "assets/icons/app_icons/trendng2.png",
                  homeState.isTrendingShowing,
                  () => homeCubit.toggleTrending(),
                  isImage: true,
                ),
                const SizedBox(width: 8),
                _buildFilterIcon(
                  "",
                  homeState.isLikedShowing,
                  () => homeCubit.toggleLiked(),
                  icon: Icons.favorite,
                ),
                const SizedBox(width: 8),
                _buildFilterIcon(
                  "",
                  false,
                  () => setState(() => _isGridView = !_isGridView),
                  icon: _isGridView ? Icons.view_list : Icons.grid_view,
                  activeColor: Colors.transparent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateSelectedCategory(int index) {
    final newTabCategories = _productsByTabAndCategory[index]?.keys;
    if (newTabCategories != null && newTabCategories.isNotEmpty) {
      setState(() => _selectedCategory = newTabCategories.first);
    } else {
      setState(() => _selectedCategory = null);
    }
  }

  Widget _buildTabItem(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              color: isSelected ? const Color(0xFF1F1919) : const Color(0xFF898888),
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF1F1919),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterIcon(String path, bool isActive, VoidCallback onTap, {bool isImage = false, IconData? icon, Color? activeColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? (activeColor ?? const Color(0xFF1F1919)) : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isImage
            ? Image.asset(path, width: 14, height: 14)
            : Icon(icon, size: 14, color: isActive ? Colors.white : const Color(0xFF898888)),
      ),
    );
  }

  Widget _buildCategoryGrid(List<ProductImageModel> quickProducts) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: SizedBox(
          height: 90,
          child: HorizontalIconGrid(
            itemCount: quickProducts.length,
            itemBuilder: (context, index) {
              final product = quickProducts[index];
              final isSelected = _selectedCategory == product.name;
              return CircularIconItem(
                label: product.name,
                isSelected: isSelected,
                selectedBorderColor: const Color(0xFF1F1919),
                onTap: () => setState(() => _selectedCategory = product.name),
                child: ClipOval(
                  child: Image.asset(product.image, fit: BoxFit.cover),
                ),
              );
            },
            viewMoreWidget: CircularIconItem(
              label: 'Explore All',
              onTap: () {},
              child: Container(
                decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle),
                child: const Icon(Iconsax.arrow_right_3, size: 18, color: Color(0xFF1F1919)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductSection(List<ProductImageModel> products) {
    if (_isGridView) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 0.85,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildProductCard(products[index]),
            childCount: products.length,
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _buildProductCard(products[index], isList: true),
        ),
        childCount: products.length,
      ),
    );
  }

  Widget _buildProductCard(ProductImageModel product, {bool isList = false}) {
    return GestureDetector(
      onTap: () => _openProductForEditing(product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              flex: isList ? 0 : 1,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Hero(
                      tag: product.id,
                      child: Image.asset(
                        product.image,
                        width: double.infinity,
                        height: isList ? 220 : double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (product.isTrending)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: const [
                            Icon(Iconsax.flash, size: 12, color: Colors.orange),
                            SizedBox(width: 4),
                            Text("Trending", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!isList)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.subCategory ?? "Premium Collection",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1F1919)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.imageCategory ?? "",
                      style: const TextStyle(fontSize: 10, color: Color(0xFF898888)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Positioned(
      bottom: 25,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1919),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildActionBtn(Iconsax.camera, "Take Photo", () => context.push("/camera")),
            ),
            Container(width: 1, height: 25, color: Colors.white.withOpacity(0.15)),
            Expanded(
              child: _buildActionBtn(Iconsax.image, "Upload", _pickFromGallery),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
