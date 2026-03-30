import 'dart:convert';
import 'dart:io';

import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/cubit/home/home_cubit.dart';
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
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:century_ai/router/app_routes.dart';

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
  String _selectedSubCategory = "All";
  // TabIndex -> Category -> SubCategory -> NestedSubCategory -> Items
  Map<int, Map<String, Map<String, Map<String, List<ProductImageModel>>>>>
  _productsByTabCategorySub = {};
  String _selectedNestedSubCategory = "";

  double _bottomCtaReservedSpace(BuildContext context) {
    // Keep the scrolling content from being hidden behind the bottom CTA row.
    // Also accounts for device bottom inset (gesture nav / home indicator).
    return MediaQuery.of(context).padding.bottom + TSizes.defaultSpace + 72;
  }

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
      final fileNameAssetMap = <String, String>{};

      for (final assetPath in allAssets) {
        final exactKey = _normalizeAssetPath(assetPath);
        final softKey = _normalizeAssetPathSoft(assetPath);
        final fileNameKey = _fileNameFromPath(assetPath);

        exactAssetMap[exactKey] = assetPath;
        softAssetMap.putIfAbsent(softKey, () => assetPath);
        if (fileNameKey.isNotEmpty) {
          fileNameAssetMap.putIfAbsent(fileNameKey, () => assetPath);
        }
      }
      final decoded = jsonDecode(rawJson);

      if (decoded is! Map<String, dynamic>) return;

      final parsed =
          <int, Map<String, Map<String, Map<String, List<ProductImageModel>>>>>{
            0: {}, // Interiors
            1: {}, // Furnitures
          };

      void parseGroup(String groupKey, int tabIndex) {
        final groupData = decoded[groupKey];
        if (groupData is! Map<String, dynamic>) return;

        groupData.forEach((category, value) {
          final subGroupsMap = <String, List<ProductImageModel>>{};

          void addItemsFromList(List listData, String subCategory) {
            final items = <ProductImageModel>[];
            for (final item in listData) {
              if (item is! Map) continue;
              final map = item.cast<String, dynamic>();
              final rawPath = (map['image_path'] ?? '').toString().trim();
              if (rawPath.isEmpty) continue;

              final prefixedPath = rawPath.startsWith('assets/')
                  ? rawPath
                  : 'assets/$rawPath';

              // 1. Try Exact match
              // 2. Try Soft match (case-insensitive, no special chars)
              // 3. Try Filename match (last resort if folders moved)
              final resolvedPath =
                  exactAssetMap[_normalizeAssetPath(prefixedPath)] ??
                  softAssetMap[_normalizeAssetPathSoft(prefixedPath)] ??
                  fileNameAssetMap[_fileNameFromPath(rawPath)];

              if (resolvedPath == null) continue;

              items.add(
                ProductImageModel(
                  id:
                      (map['id'] ??
                              '${category}_${subCategory}_${items.length + 1}')
                          .toString(),
                  name: category,
                  image: resolvedPath,
                  isTrending: false,
                ),
              );
            }
            if (items.isNotEmpty) {
              subGroupsMap.putIfAbsent(subCategory, () => []).addAll(items);
            }
          }

          if (value is List) {
            addItemsFromList(value, "General");
            parsed[tabIndex]![category] = {
              "All": {"General": subGroupsMap["General"] ?? []},
            };
          } else if (value is Map) {
            final subCatsMap = <String, Map<String, List<ProductImageModel>>>{};
            value.forEach((subCat, nestedData) {
              if (nestedData is Map) {
                final nestedGroups = <String, List<ProductImageModel>>{};
                nestedData.forEach((nestedSubCat, subList) {
                  if (subList is List) {
                    final items = <ProductImageModel>[];
                    for (final item in subList) {
                      if (item is! Map) continue;
                      final map = item.cast<String, dynamic>();
                      final rawPath = (map['image_path'] ?? '')
                          .toString()
                          .trim();
                      if (rawPath.isEmpty) continue;

                      final prefixedPath = rawPath.startsWith('assets/')
                          ? rawPath
                          : 'assets/$rawPath';
                      final resolvedPath =
                          exactAssetMap[_normalizeAssetPath(prefixedPath)] ??
                          softAssetMap[_normalizeAssetPathSoft(prefixedPath)] ??
                          fileNameAssetMap[_fileNameFromPath(rawPath)];

                      if (resolvedPath == null) continue;

                      items.add(
                        ProductImageModel(
                          id:
                              (map['id'] ??
                                      '${category}_${subCat}_${nestedSubCat}_${items.length + 1}')
                                  .toString(),
                          name: category,
                          image: resolvedPath,
                          isTrending: false,
                        ),
                      );
                    }
                    if (items.isNotEmpty) {
                      nestedGroups[nestedSubCat] = items;
                    }
                  }
                });
                if (nestedGroups.isNotEmpty) {
                  subCatsMap[subCat] = nestedGroups;
                }
              } else if (nestedData is List) {
                // Fallback for old structure if any
                addItemsFromList(nestedData, "General");
                subCatsMap[subCat] = {"General": subGroupsMap["General"] ?? []};
              }
            });
            if (subCatsMap.isNotEmpty) {
              parsed[tabIndex]![category] = subCatsMap;
            }
          }
        });
      }

      parseGroup('interiors', 0);
      parseGroup('furnitures', 1);

      if (!mounted) return;
      setState(() {
        _productsByTabCategorySub = parsed;
      });
    } catch (e) {
      debugPrint('Error parsing assets/data/_data.json: $e');
    }
  }

  String _normalizeAssetPath(String value) {
    return value.replaceAll('\\', '/').trim().toLowerCase();
  }

  String _fileNameFromPath(String value) {
    final normalized = value.replaceAll('\\', '/').trim().toLowerCase();
    final index = normalized.lastIndexOf('/');
    return index >= 0 ? normalized.substring(index + 1) : normalized;
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
    final currentTabData = _productsByTabCategorySub[selectedIndex];
    if (currentTabData == null || currentTabData.isEmpty) {
      return fallbackProducts.take(4).toList();
    }

    final quickItems = <ProductImageModel>[];
    for (final entry in currentTabData.entries) {
      if (entry.value.isEmpty) continue;

      // Collect all nested products to pick a random one
      final allProducts = <ProductImageModel>[];
      for (final nestedMap in entry.value.values) {
        for (final productList in nestedMap.values) {
          allProducts.addAll(productList);
        }
      }

      if (allProducts.isEmpty) continue;

      // Use deterministic selection based on name hash for stability
      final stableIndex = entry.key.hashCode.abs() % allProducts.length;
      final randomProduct = allProducts[stableIndex];

      quickItems.add(
        ProductImageModel(
          id: 'cat_${entry.key}',
          name: entry.key,
          image: randomProduct.image,
          isTrending: false,
        ),
      );
    }

    return quickItems.isEmpty ? fallbackProducts.take(4).toList() : quickItems;
  }

  String _getSubCategoryIcon(
    String subCatName,
    Map<String, Map<String, List<ProductImageModel>>> categoryData,
  ) {
    final subCatData = categoryData[subCatName];
    if (subCatData == null || subCatData.isEmpty) return "";

    final allProducts = <ProductImageModel>[];
    for (final productList in subCatData.values) {
      allProducts.addAll(productList);
    }

    if (allProducts.isEmpty) return "";
    // Deterministic selection based on subcategory name for stability
    final stableIndex = subCatName.hashCode.abs() % allProducts.length;
    return allProducts[stableIndex].image;
  }

  List<ProductImageModel> _resolveVisibleProducts(
    List<ProductImageModel> fallbackProducts,
    int selectedIndex,
  ) {
    final currentTabData = _productsByTabCategorySub[selectedIndex];
    if (currentTabData == null || currentTabData.isEmpty) {
      return fallbackProducts;
    }

    final selectedCategory = _selectedCategory;
    if (selectedCategory == null) {
      return fallbackProducts;
    }

    final categoryGroups = currentTabData[selectedCategory];
    if (categoryGroups == null || categoryGroups.isEmpty) {
      return fallbackProducts;
    }

    if (_selectedSubCategory == "All") {
      final allItems = <ProductImageModel>[];
      for (final subCatMap in categoryGroups.values) {
        for (final items in subCatMap.values) {
          allItems.addAll(items);
        }
      }
      return allItems;
    } else {
      final subCatData = categoryGroups[_selectedSubCategory];
      if (subCatData == null) return [];

      if (_selectedNestedSubCategory == "All" ||
          _selectedNestedSubCategory.isEmpty) {
        final allNestedItems = <ProductImageModel>[];
        for (final items in subCatData.values) {
          allNestedItems.addAll(items);
        }
        return allNestedItems;
      } else {
        return subCatData[_selectedNestedSubCategory] ?? [];
      }
    }
  }

  Future<void> logDb() async {
    final db = await DbHelper.database;

    await db.query("products");
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && mounted) {
      context.push(
        AppRoutes.imagePreview,
        extra: {
          "imageFile": File(image.path),
          "image_category": "asdasdasd",
          "sub_category": "asdasdasdasd",
        },
      );
    }
  }

  Future<void> _openProductForEditing(String assetPath) async {
    try {
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
        context.push(
          AppRoutes.imagePreview,
          extra: {
            "imageFile": file,
            "image_category": "",
            "sub_category": "asdasdasdsa",
          },
        );
      }
    } catch (e) {
      debugPrint("Error loading asset: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeCubit = context.watch<HomeCubit>();
    final homeState = homeCubit.state;

    final ProductsState productsState = context.watch<ProductsCubit>().state;
    final products = productsState.products.isEmpty
        ? ProductImages.productImages
        : productsState.products;
    final quickProducts = _resolveQuickProducts(
      products,
      homeState.selectedIndex,
    );
    final visibleProducts = _resolveVisibleProducts(
      products,
      homeState.selectedIndex,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const HomeDrawer(),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
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
                      Center(
                        child: Text(
                          "Lets design Furniture with Century Decor",
                          style: TextStyle(
                            fontWeight: FontWeight.w200,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: ExteriorInteriorSwitchSlider(
                          value: homeState.isExterior,
                          onChanged: (val) => homeCubit.setExterior(val),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // SearchInput(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 4,
                              spreadRadius: 0,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          cursorHeight: 15,
                          style: const TextStyle(
                            fontWeight: FontWeight.w100,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 20,
                            ),

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),

                            suffixIconConstraints: const BoxConstraints(
                              maxHeight: 32,
                              maxWidth: 44,
                            ),
                            suffixIcon: GestureDetector(
                              onTap: () => homeCubit.fetchResults(),
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.12),
                                      blurRadius: 4,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 0),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Image.asset(
                                    "assets/icons/app_icons/ai_search.png",
                                    width: 12,
                                    height: 12,
                                  ),
                                ),
                              ),
                            ),

                            hintText: "Ai based furniture idea search",
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w100,
                            ),
                          ),
                          onChanged: (val) => homeCubit.setSearchQuery(val),
                          onSubmitted: (_) => homeCubit.fetchResults(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DefaultTabController(
                        length: 2,
                        initialIndex: homeState.selectedIndex,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 150,
                              height: 30,
                              child: TabBar(
                                isScrollable: true,
                                padding: EdgeInsets.zero,
                                labelPadding: const EdgeInsets.only(right: 16),
                                tabAlignment: TabAlignment.start,
                                indicator: const UnderlineTabIndicator(
                                  borderSide: BorderSide(
                                    width: 1.0,
                                    color: Color(0xFF5D5D5D),
                                  ),
                                ),
                                indicatorSize: TabBarIndicatorSize.label,
                                dividerColor: Colors.transparent,
                                labelColor: const Color(0xFF5D5D5D),
                                unselectedLabelColor: const Color(
                                  0xFF5D5D5D,
                                ).withOpacity(0.5),
                                labelStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                                tabs: const [
                                  Tab(text: "Interiors"),
                                  Tab(text: "Furnitures"),
                                ],
                                onTap: (index) {
                                  homeCubit.setSelectedIndex(index);
                                  // Reset selected category to first of new tab
                                  final newTabCategories =
                                      _productsByTabCategorySub[index]?.keys;
                                  if (newTabCategories != null &&
                                      newTabCategories.isNotEmpty) {
                                    setState(() {
                                      _selectedCategory =
                                          newTabCategories.first;
                                      _selectedSubCategory = "All";
                                      _selectedNestedSubCategory = "";
                                    });
                                  } else {
                                    setState(() {
                                      _selectedCategory = null;
                                      _selectedSubCategory = "All";
                                      _selectedNestedSubCategory = "";
                                    });
                                  }
                                },
                              ),
                            ),

                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 2,
                                        spreadRadius: 0,
                                        offset: const Offset(0, 0),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: homeState.isTrendingShowing
                                        ? TColors.primary
                                        : Colors.transparent,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () {
                                        homeCubit.toggleTrending();
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Image.asset(
                                          homeState.isTrendingShowing
                                              ? "assets/icons/app_icons/trendng2_white.png"
                                              : "assets/icons/app_icons/trendng2.png",
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
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 2,
                                        spreadRadius: 0,
                                        offset: const Offset(0, 0),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: homeState.isLikedShowing
                                        ? TColors.primary
                                        : Colors.transparent,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () {
                                        homeCubit.toggleLiked();
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Icon(
                                          Icons.favorite,
                                          size: 12,
                                          color: homeState.isLikedShowing
                                              ? Colors.white
                                              : const Color(0xFF898888),
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
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 2,
                                        spreadRadius: 0,
                                        offset: const Offset(0, 0),
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
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 90,
                        child: HorizontalIconGrid(
                          itemCount: quickProducts.length,
                          itemBuilder: (context, index) {
                            final product = quickProducts[index];
                            return CircularIconItem(
                              label: product.name,
                              isSelected: _selectedCategory == product.name,
                              useUnderline: true, // Level 1 Red Underline
                              selectedBorderColor: const Color(0xFFEEEEEE),
                              onTap: () {
                                setState(() {
                                  if (_selectedCategory == product.name) {
                                    _selectedCategory = null;
                                  } else {
                                    _selectedCategory = product.name;
                                  }
                                  _selectedSubCategory = "All";
                                  _selectedNestedSubCategory = "";
                                });
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
                      const SizedBox(height: 2),
                      _buildSubCategoryMenu(),
                      const SizedBox(height: 10),

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
                              itemCount: homeState.isLoading
                                  ? 6
                                  : visibleProducts.length,
                              itemBuilder: (context, index) {
                                if (homeState.isLoading) {
                                  return Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!,
                                    highlightColor: Colors.grey[100]!,
                                    child: AspectRatio(
                                      aspectRatio: 1.0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                final product = visibleProducts[index];

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
                              itemCount: homeState.isLoading
                                  ? 5
                                  : visibleProducts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                if (homeState.isLoading) {
                                  return Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!,
                                    highlightColor: Colors.grey[100]!,
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                final product = visibleProducts[index];

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
                      SizedBox(height: _bottomCtaReservedSpace(context)),
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
                      iconImage: "camera.png",
                      label: "Take Photo",
                      onTap: () => context.push(AppRoutes.camera),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _PremiumActionButton(
                      iconImage: "upload-image.png",
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

  Widget _buildSubCategoryMenu() {
    final selectedCategory = _selectedCategory;
    if (selectedCategory == null) return const SizedBox.shrink();

    final homeCubit = context.read<HomeCubit>();
    final selectedIndex = homeCubit.state.selectedIndex;
    final categoryData =
        _productsByTabCategorySub[selectedIndex]?[selectedCategory];

    if (categoryData == null || categoryData.isEmpty)
      return const SizedBox.shrink();

    final subCategories = ["All", ...categoryData.keys];

    // Determine nested subcategories if a subcategory is selected
    List<String> nestedSubCategories = [];
    if (_selectedSubCategory != "All") {
      final nestedData = categoryData[_selectedSubCategory];
      if (nestedData != null) {
        nestedSubCategories.addAll(nestedData.keys);
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary SubCategories as Icons
        SizedBox(
          height: 90,
          child: HorizontalIconGrid(
            itemCount: subCategories.length,
            itemBuilder: (context, index) {
              final subCat = subCategories[index];
              final isSelected = _selectedSubCategory == subCat;

              // Pick a random transparent icon based on subcategory name for stability
              final iconIndex = subCat.hashCode.abs() % 9;
              final iconImage = "assets/transparent/${iconIndex + 1}.png";

              return CircularIconItem(
                label: subCat,
                isSelected: isSelected,
                size: 52, // Slightly smaller than main categories
                useUnderline: true, // Enable underline style
                isCircular:
                    false, // Disable circular background for subcategories
                onTap: () {
                  setState(() {
                    if (_selectedSubCategory == subCat) {
                      _selectedSubCategory = "All";
                    } else {
                      _selectedSubCategory = subCat;
                    }
                    _selectedNestedSubCategory = ""; // Reset nested
                  });
                },
                child: Image.asset(iconImage, fit: BoxFit.contain),
              );
            },
          ),
        ),

        // Nested SubCategories (Pills)
        if (_selectedSubCategory != "All" &&
            nestedSubCategories.length > 1) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: nestedSubCategories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final nSubCat = nestedSubCategories[index];
                final isSelected = _selectedNestedSubCategory == nSubCat;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_selectedNestedSubCategory == nSubCat) {
                        _selectedNestedSubCategory = "";
                      } else {
                        _selectedNestedSubCategory = nSubCat;
                      }
                    });
                  },
                  // UI Design Tip: Customize the design of these Choice Chips/Pills here.
                  // You can change the decoration, padding, and text style to match your preference.
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFB5B5B5)
                            : const Color(0xFFD9D9D9),
                        width: 0.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.075),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        nSubCat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: const Color(0xFF5D5D5D),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _PremiumActionButton extends StatelessWidget {
  const _PremiumActionButton({
    required this.iconImage,
    required this.label,
    required this.onTap,
  });

  final String iconImage;
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
            Image.asset("assets/icons/app_icons/${iconImage}", height: 16),
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
