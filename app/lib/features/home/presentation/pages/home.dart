import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/cubit/home/home_cubit.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:century_ai/common/widgets/exterior_interior/exterior_interior.dart';
import 'package:century_ai/common/widgets/horizontal_icon_grid/circular_icon_item.dart';
import 'package:century_ai/cubit/products/products_cubit.dart';
import 'package:century_ai/cubit/products/products_state.dart';
import 'package:century_ai/db/repositories/selected_images_repository.dart';
import 'package:century_ai/db/models/selected_image_data.dart';
import 'package:century_ai/db/db_core.dart';
import 'package:century_ai/features/home/presentation/widgets/home_drawer.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/core/constants/sizes.dart';
import 'package:century_ai/features/home/widgets/product_containers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:century_ai/features/home/presentation/widgets/search_bar.dart';
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

  final Map<String, String> _categoryIcons = {};
  final Map<String, String> _subCategoryIcons = {};

  double _bottomCtaReservedSpace(BuildContext context) {
    // Keep the scrolling content from being hidden behind the bottom CTA row.
    // Also accounts for device bottom inset (gesture nav / home indicator).
    return MediaQuery.of(context).padding.bottom + TSizes.defaultSpace + 72;
  }

  @override
  void initState() {
    super.initState();
    _loadProductsByCategoryFromAsset();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductsCubit>().fetchFeaturedProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProductsByCategoryFromAsset() async {
    try {
      final rawJson = await rootBundle.loadString('assets/data/data.json');
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
      final parsed =
          <
            int,
            Map<String, Map<String, Map<String, List<ProductImageModel>>>>
          >{};
      final List<dynamic> rootData = json.decode(rawJson);

      for (int tabIndex = 0; tabIndex < rootData.length; tabIndex++) {
        final rootNode = rootData[tabIndex];
        final List<dynamic> categories = rootNode['children'] ?? [];
        parsed[tabIndex] = {};

        for (final catNode in categories) {
          final category = catNode['name'] ?? 'Unknown';
          if (catNode['optional_all_img'] != null) {
            final rawIcon = catNode['optional_all_img'].toString();
            _categoryIcons[category] = rawIcon.startsWith('assets/')
                ? rawIcon
                : 'assets/$rawIcon';
          }
          final subCatsMap = <String, Map<String, List<ProductImageModel>>>{};
          final List<dynamic> catChildren = catNode['children'] ?? [];

          for (final subCatNode in catChildren) {
            if (subCatNode is! Map) continue;
            final subCatMapRaw = subCatNode.cast<String, dynamic>();

            // If this node is a product directly under Category
            if (subCatMapRaw['image_path'] != null) {
              final product = _parseOneProduct(
                subCatMapRaw,
                category,
                'General',
                'General',
                exactAssetMap,
                softAssetMap,
                fileNameAssetMap,
              );
              if (product != null) {
                subCatsMap
                    .putIfAbsent('General', () => {})
                    .putIfAbsent('General', () => [])
                    .add(product);
              }
              continue;
            }

            // Otherwise treated as a SubCategory
            final subCat = subCatMapRaw['name'] ?? 'General';
            if (subCatMapRaw['image'] != null) {
              final rawIcon = subCatMapRaw['image'].toString();
              _subCategoryIcons[subCat] = rawIcon.startsWith('assets/')
                  ? rawIcon
                  : 'assets/$rawIcon';
            }
            final nestedGroups = <String, List<ProductImageModel>>{};
            final List<dynamic> subCatChildren = subCatMapRaw['children'] ?? [];

            for (final nestedNode in subCatChildren) {
              if (nestedNode is! Map) continue;
              final nestedNodeMap = nestedNode.cast<String, dynamic>();

              // If this node is a product directly under SubCategory
              if (nestedNodeMap['image_path'] != null) {
                final product = _parseOneProduct(
                  nestedNodeMap,
                  category,
                  subCat,
                  'General',
                  exactAssetMap,
                  softAssetMap,
                  fileNameAssetMap,
                );
                if (product != null) {
                  nestedGroups.putIfAbsent('General', () => []).add(product);
                }
                // Even if it's a product, it might have children according to some formats,
                // but usually we stop here or continue.
                if (nestedNodeMap['children'] == null ||
                    (nestedNodeMap['children'] as List).isEmpty) {
                  continue;
                }
              }

              // Otherwise treated as a NestedSubCategory
              final nestedSubCat = nestedNodeMap['name'] ?? 'General';
              final itemsList = <ProductImageModel>[];
              final List<dynamic> leafItems = nestedNodeMap['children'] ?? [];

              for (final item in leafItems) {
                if (item is! Map) continue;
                final map = item.cast<String, dynamic>();
                final product = _parseOneProduct(
                  map,
                  category,
                  subCat,
                  nestedSubCat,
                  exactAssetMap,
                  softAssetMap,
                  fileNameAssetMap,
                );
                if (product != null) {
                  itemsList.add(product);
                }
              }

              if (itemsList.isNotEmpty) {
                nestedGroups[nestedSubCat] = itemsList;
              }
            }

            if (nestedGroups.isNotEmpty) {
              subCatsMap[subCat] = nestedGroups;
            }
          }

          if (subCatsMap.isNotEmpty) {
            parsed[tabIndex]![category] = subCatsMap;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _productsByTabCategorySub = parsed;
        // Do NOT auto-select any category on initial load.
        // _selectedCategory remains null until the user taps one.
      });
    } catch (e) {
      debugPrint('Error parsing assets/data/_data.json: $e');
    }
  }

  ProductImageModel? _parseOneProduct(
    Map<String, dynamic> map,
    String category,
    String subCat,
    String nestedSubCat,
    Map<String, String> exactAssetMap,
    Map<String, String> softAssetMap,
    Map<String, String> fileNameAssetMap,
  ) {
    final rawPath = (map['image_path'] ?? '').toString().trim();
    if (rawPath.isEmpty) return null;

    final prefixedPath = rawPath.startsWith('assets/')
        ? rawPath
        : 'assets/$rawPath';
    final resolvedPath =
        exactAssetMap[_normalizeAssetPath(prefixedPath)] ??
        softAssetMap[_normalizeAssetPathSoft(prefixedPath)] ??
        fileNameAssetMap[_fileNameFromPath(rawPath)];

    if (resolvedPath == null) return null;

    return ProductImageModel(
      id:
          (map['id'] ??
                  '${category}_${subCat}_${nestedSubCat}_${DateTime.now().microsecondsSinceEpoch}')
              .toString(),
      name: category,
      image: resolvedPath,
      category: category,
      subcategory: subCat,
      nestedSubcategory: nestedSubCat,
      isTrending: false,
    );
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
    if (_subCategoryIcons.containsKey(subCatName)) {
      return _subCategoryIcons[subCatName]!;
    }

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

  String _getParentCategoryIcon(
    String categoryName,
    Map<String, Map<String, List<ProductImageModel>>> categoryData,
  ) {
    if (_categoryIcons.containsKey(categoryName)) {
      return _categoryIcons[categoryName]!;
    }

    final allProducts = <ProductImageModel>[];
    for (final nestedMap in categoryData.values) {
      for (final productList in nestedMap.values) {
        allProducts.addAll(productList);
      }
    }

    if (allProducts.isEmpty) return "";
    final stableIndex = categoryName.hashCode.abs() % allProducts.length;
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
    final db = await DbCore.database;

    await db.query("products");
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && mounted) {
      final File imageFile = File(image.path);
      // Show upload option or directly upload
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Upload Furniture"),
          content: const Text(
            "Do you want to upload this image to the catalog?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<ProductsCubit>().uploadProductImage(imageFile);
              },
              child: const Text("Upload"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openProductForEditing(ProductImageModel product) async {
    final assetPath = product.image;
    bool isLoaderShowing = false;
    
    // Show loading dialog for network images
    if (product.isNetworkImage) {
      isLoaderShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: TColors.primary),
        ),
      ).then((_) {
        isLoaderShowing = false;
      });
    }

    try {
      File file;
      List<int> imageBytes;
      
      if (product.isNetworkImage) {
        final response = await http.get(Uri.parse(assetPath));
        if (response.statusCode == 200) {
          imageBytes = response.bodyBytes;
          final tempDir = await getTemporaryDirectory();
          final fileName = 'downloaded_${DateTime.now().millisecondsSinceEpoch}.jpg';
          file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(imageBytes);
          
          if (mounted && isLoaderShowing) {
            isLoaderShowing = false;
            Navigator.of(context, rootNavigator: true).pop();
          }
        } else {
          throw Exception("Failed to download image: ${response.statusCode}");
        }
      } else {
        final byteData = await rootBundle.load(assetPath);
        imageBytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
        final tempDir = await getTemporaryDirectory();
        final fileName = assetPath.replaceAll("/", "_");
        file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(imageBytes);
      }

      // Save to SQLite
      await SelectedImagesRepository.saveImage(
        SelectedImageData(
          id: product.id,
          imageData: imageBytes,
          imagePath: assetPath,
          category: product.category ?? _selectedCategory ?? "Furniture",
          subcategory: product.subcategory ?? _selectedSubCategory,
          selectedAt: DateTime.now(),
        ),
      );

      if (mounted) {
        context.push(
          AppRoutes.imagePreview,
          extra: {
            "imageFile": file,
            "image_id": product.id,
            "image_category": product.category ?? _selectedCategory ?? "Furniture",
            "sub_category": product.subcategory ?? _selectedSubCategory,
          },
        );
      }
    } catch (e) {
      if (mounted && isLoaderShowing) {
        isLoaderShowing = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
      debugPrint("Error preparing image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error preparing image: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeCubit = context.watch<HomeCubit>();
    final homeState = homeCubit.state;

    final ProductsState productsState = context.watch<ProductsCubit>().state;
    final List<ProductImageModel> displayProducts = productsState.products;
    final products =
        ProductImages.productImages; // Used only for category icons structure
    final quickProducts = _resolveQuickProducts(
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
              onRefresh: () async {
                // Clear search and categories on refresh
                _searchController.clear();
                setState(() {
                  _selectedCategory = null;
                  _selectedSubCategory = "All";
                  _selectedNestedSubCategory = "";
                });
                context.read<HomeCubit>().clearSearch();
                // Fetch featured products
                return context.read<ProductsCubit>().fetchFeaturedProducts();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          "Lets design Furniture with Century Decor",
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
                            color: Color(0xFF5D5D5D),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: ExteriorInteriorSwitchSlider(
                          value: homeState.isExterior,
                          onChanged: (val) => homeCubit.setExterior(val),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // SearchInput(),
                      HomeSearchBar(
                        controller: _searchController,
                        onCategoryCleared: () {
                          setState(() {
                            _selectedCategory = null;
                            _selectedSubCategory = "All";
                            _selectedNestedSubCategory = "";
                          });
                        },
                        onSearchStarted: (query) {
                          setState(() {
                            // Find matching category in the current tab
                            final currentTabData = _productsByTabCategorySub[homeState.selectedIndex];
                            String? matchingCategory;
                            
                            if (currentTabData != null) {
                              final queryLower = query.toLowerCase();
                              for (final categoryName in currentTabData.keys) {
                                final categoryLower = categoryName.toLowerCase();
                                if (categoryLower.contains(queryLower) || queryLower.contains(categoryLower)) {
                                  matchingCategory = categoryName;
                                  break;
                                }
                              }
                            }

                            if (matchingCategory != null) {
                              _selectedCategory = matchingCategory;
                              _selectedSubCategory = "All";
                              _selectedNestedSubCategory = "";
                              
                              // Trigger product fetch for the matched category
                              context.read<ProductsCubit>().fetchProductsByCategory(
                                matchingCategory,
                                isInterior: homeState.selectedIndex == 0,
                              );
                            } else {
                              _selectedCategory = null;
                              _selectedSubCategory = "All";
                              _selectedNestedSubCategory = "";
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DefaultTabController(
                        length: 2,
                        initialIndex: homeState.selectedIndex,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 150,
                              height: 20,
                              child: TabBar(
                                isScrollable: true,
                                padding: EdgeInsets.zero,
                                labelPadding: const EdgeInsets.only(right: 16),
                                tabAlignment: TabAlignment.start,
                                indicator: const UnderlineTabIndicator(
                                  borderSide: BorderSide(
                                    width: 1.5,
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
                                  fontWeight: FontWeight.w500,
                                ),
                                tabs: const [
                                  Tab(text: "Interiors"),
                                  Tab(text: "Furnitures"),
                                ],
                                onTap: (index) {
                                  homeCubit.setSelectedIndex(index);
                                  // Fetch featured or generic products for the new tab
                                  context
                                      .read<ProductsCubit>()
                                      .fetchFeaturedProducts();
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
                                        padding: const EdgeInsets.all(8),
                                        child: Image.asset(
                                          homeState.isTrendingShowing
                                              ? "assets/icons/app_icons/trendng2_white.png"
                                              : "assets/icons/app_icons/trendng2.png",
                                          width: 16,
                                          height: 16,
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
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.favorite,
                                          size: 16,
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
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          _isGridView
                                              ? Icons.grid_view
                                              : Icons.view_list,
                                          size: 16,
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
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 90,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: quickProducts.map((product) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: CircularIconItem(
                                  label: product.name,
                                  isSelected: _selectedCategory == product.name,
                                  useUnderline: false,
                                  selectedBorderColor: const Color(0xFFEEEEEE),
                                  onTap: () {
                                    // Tap again to deselect; tap new to select
                                    if (_selectedCategory == product.name) {
                                      setState(() {
                                        _selectedCategory = null;
                                        _selectedSubCategory = "All";
                                        _selectedNestedSubCategory = "";
                                      });
                                      // Clear search when category is deselected
                                      _searchController.clear();
                                      context.read<HomeCubit>().clearSearch();
                                      // Fetch featured products when category is deselected
                                      context
                                          .read<ProductsCubit>()
                                          .fetchFeaturedProducts();
                                    } else {
                                      setState(() {
                                        _selectedCategory = product.name;
                                        _selectedSubCategory = "All";
                                        _selectedNestedSubCategory = "";
                                      });
                                      // Clear search when category is selected
                                      _searchController.clear();
                                      context.read<HomeCubit>().clearSearch();
                                      context
                                          .read<ProductsCubit>()
                                          .fetchProductsByCategory(
                                            product.name,
                                            isInterior:
                                                homeState.selectedIndex == 0,
                                          );
                                    }
                                  },
                                  child: ClipOval(
                                    child: Image.asset(
                                      product.image,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      // const SizedBox(height: 2),
                      const SizedBox(height: 10),
                      _buildSubCategoryMenu(),
                      const SizedBox(height: 10),
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
                              itemCount: productsState.isLoading
                                  ? 6
                                  : displayProducts.length,
                              itemBuilder: (context, index) {
                                if (productsState.isLoading) {
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
                                final product = displayProducts[index];

                                return GestureDetector(
                                  onTap: () {
                                    _openProductForEditing(product);
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: ProductContainers(
                                      imagePath: product.image,
                                      isTrending: product.isTrending,
                                      isNetwork: product.isNetworkImage,
                                    ),
                                  ),
                                );
                              },
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: productsState.isLoading
                                  ? 5
                                  : displayProducts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                if (productsState.isLoading) {
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
                                final product = displayProducts[index];

                                return GestureDetector(
                                  onTap: () {
                                    _openProductForEditing(product);
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: ProductContainers(
                                      imagePath: product.image,
                                      isTrending: product.isTrending,
                                      isNetwork: product.isNetworkImage,
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

    if (categoryData == null || categoryData.isEmpty) {
      return const SizedBox.shrink();
    }

    // Determine if we have multiple subcategories or at least one meaningful subcategory name.
    final bool hasMultipleSubCats = categoryData.length > 1;
    final bool hasMeaningfulSingleSubCat =
        categoryData.length == 1 &&
        categoryData.keys.first.isNotEmpty &&
        categoryData.keys.first != "General";

    // Determine nested subcategories if a subcategory is selected
    List<String> nestedSubCategories = [];
    if (_selectedSubCategory != "All") {
      final nestedData = categoryData[_selectedSubCategory];
      if (nestedData != null) {
        nestedSubCategories.addAll(nestedData.keys);
      }
    } else if (categoryData.length == 1) {
      nestedSubCategories.addAll(categoryData.values.first.keys);
    }

    final bool hasMultipleNestedSubCats = nestedSubCategories.length > 1;

    if (!hasMultipleSubCats &&
        !hasMeaningfulSingleSubCat &&
        !hasMultipleNestedSubCats) {
      return const SizedBox.shrink();
    }

    final subCategories = (categoryData.length > 1)
        ? ["All", ...categoryData.keys]
        : categoryData.keys.toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary SubCategories as Icons
        if (hasMultipleSubCats || hasMeaningfulSingleSubCat)
          SizedBox(
            height: 80,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: subCategories.map((subCat) {
                  final isSelected = _selectedSubCategory == subCat;
                  String iconImage = "";
                  if (subCat == "All") {
                    iconImage = _getParentCategoryIcon(
                      selectedCategory,
                      categoryData,
                    );
                  } else {
                    iconImage = _getSubCategoryIcon(subCat, categoryData);
                  }

                  if (iconImage.isEmpty) {
                    final iconIndex = subCat.hashCode.abs() % 9;
                    iconImage = "assets/transparent/${iconIndex + 1}.png";
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: CircularIconItem(
                      label: subCat,
                      isSelected: isSelected,
                      size: 50,
                      useUnderline: true,
                      isCircular: false,
                      onTap: () {
                        // Tap again to deselect; tap new to select
                        if (_selectedSubCategory == subCat) {
                          setState(() {
                            _selectedSubCategory = "All";
                            _selectedNestedSubCategory = "";
                          });
                          context.read<ProductsCubit>().fetchProductsByCategory(
                                selectedCategory,
                                isInterior: selectedIndex == 0,
                              );
                        } else {
                          setState(() {
                            _selectedSubCategory = subCat;
                            _selectedNestedSubCategory = "";
                          });
                          context.read<ProductsCubit>().fetchProductsBySubCategory(
                                selectedCategory,
                                subCat,
                                isInterior: selectedIndex == 0,
                              );
                        }
                      },
                      child: Image.asset(
                        iconImage,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint(
                            'SubCategory Image.asset failed for path: "$iconImage" - Error: $error',
                          );
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                iconImage.isEmpty
                                    ? "EMPTY"
                                    : iconImage.split('/').last,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

        // Nested SubCategories (Pills)
        if (nestedSubCategories.length > 1) ...[
          if (hasMultipleSubCats || hasMeaningfulSingleSubCat)
            const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: nestedSubCategories.map((nSubCat) {
                  final isSelected = _selectedNestedSubCategory == nSubCat;

                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () {
                        // Tap again to deselect; tap new to select
                        if (_selectedNestedSubCategory == nSubCat) {
                          setState(() {
                            _selectedNestedSubCategory = "";
                          });
                          context.read<ProductsCubit>().fetchProductsBySubCategory(
                            selectedCategory,
                            _selectedSubCategory,
                            isInterior: selectedIndex == 0,
                          );
                        } else {
                          setState(() {
                            _selectedNestedSubCategory = nSubCat;
                          });
                          context.read<ProductsCubit>().fetchProductsByNestedSubCategory(
                            selectedCategory,
                            _selectedSubCategory,
                            nSubCat,
                            isInterior: selectedIndex == 0,
                          );
                        }
                      },
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
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                              color: const Color(0xFF5D5D5D),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
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
            Image.asset("assets/icons/app_icons/${iconImage}", height: 12),
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
