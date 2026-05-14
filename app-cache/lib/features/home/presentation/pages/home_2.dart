import 'dart:convert';
import 'dart:io';
import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/cubit/home/home_cubit.dart';
import 'package:flutter/services.dart' show rootBundle;
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
import 'package:century_ai/features/home/data/services/image_preparation_service.dart';
import 'package:century_ai/features/home/presentation/widgets/search_bar.dart';
import 'package:century_ai/router/app_routes.dart';

class HomeScreen2 extends StatelessWidget {
  const HomeScreen2({super.key});

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
  final ImagePreparationService _imagePreparationService =
      const ImagePreparationService();
  final TextEditingController _searchController = TextEditingController();
  bool _isGridView = false;
  bool _quickExpanded = false;
  String? _selectedCategory;
  // TabIndex -> Category -> SubCategory -> NestedSubCategory -> Items
  Map<int, Map<String, Map<String, Map<String, List<ProductImageModel>>>>>
  _productsByTabCategorySub = {};

  String _selectedSubCategory = "All";
  String _selectedNestedSubCategory = "";
  final ScrollController _scrollController = ScrollController();

  final Map<String, String> _categoryIcons = {};
  final Map<String, String> _categoryAllIcons = {};
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
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductsCubit>().fetchFeaturedProducts();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    // Trigger when 200px from the bottom
    if (currentScroll >= maxScroll - 200) {
      context.read<ProductsCubit>().loadMoreProducts();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProductsByCategoryFromAsset() async {
    try {
      final rawJson = await rootBundle.loadString('assets/data/test.json');
      final Map<String, dynamic> rootData = json.decode(rawJson);

      final nestedSubCategories =
          (rootData['nested_subcategories'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
      final parsed =
          <
            int,
            Map<String, Map<String, Map<String, List<ProductImageModel>>>>
          >{
            0: {},
            1: {},
          };

      void parseTab(List<dynamic> flatItems, int tabIndex) {
        final sorted = List<Map<String, dynamic>>.from(
          flatItems.whereType<Map>().map((e) => e.cast<String, dynamic>()),
        )..sort((a, b) {
            final aParent = a['parent_id'];
            final bParent = b['parent_id'];
            if (aParent == null && bParent != null) return -1;
            if (aParent != null && bParent == null) return 1;
            if (aParent == null && bParent == null) {
              final aOrder = (a['sort_order'] as num?)?.toInt() ?? 9999;
              final bOrder = (b['sort_order'] as num?)?.toInt() ?? 9999;
              if (aOrder != bOrder) return aOrder.compareTo(bOrder);
            }
            return ((a['id'] as num?)?.toInt() ?? 0).compareTo(
              (b['id'] as num?)?.toInt() ?? 0,
            );
          });

        final parentById = <int, Map<String, dynamic>>{};
        final childrenByParent = <int, List<Map<String, dynamic>>>{};
        for (final item in sorted) {
          final id = (item['id'] as num?)?.toInt();
          if (id == null) continue;
          if (item['parent_id'] == null) {
            parentById[id] = item;
          } else {
            final parentId = (item['parent_id'] as num?)?.toInt();
            if (parentId == null) continue;
            childrenByParent.putIfAbsent(parentId, () => []).add(item);
          }
        }

        final orderedParents = parentById.values.toList()
          ..sort((a, b) {
            final aOrder = (a['sort_order'] as num?)?.toInt() ?? 9999;
            final bOrder = (b['sort_order'] as num?)?.toInt() ?? 9999;
            if (aOrder != bOrder) return aOrder.compareTo(bOrder);
            return ((a['id'] as num?)?.toInt() ?? 0).compareTo(
              (b['id'] as num?)?.toInt() ?? 0,
            );
          });

        for (final parent in orderedParents) {
          final category = (parent['name'] ?? 'Unknown').toString();
          final rawCategoryIcon =
              (parent['image'] ?? '')
                  .toString()
                  .trim();
          final rawCategoryAllIcon =
              (parent['optional_all_img'] ?? parent['image'] ?? '')
                  .toString()
                  .trim();
          final categoryIcon = rawCategoryIcon.isEmpty
              ? ""
              : (rawCategoryIcon.startsWith('assets/')
                    ? rawCategoryIcon
                    : 'assets/$rawCategoryIcon');
          final categoryAllIcon = rawCategoryAllIcon.isEmpty
              ? ""
              : (rawCategoryAllIcon.startsWith('assets/')
                    ? rawCategoryAllIcon
                    : 'assets/$rawCategoryAllIcon');
          if (categoryIcon.isNotEmpty) {
            _categoryIcons[category] = categoryIcon;
          }
          if (categoryAllIcon.isNotEmpty) {
            _categoryAllIcons[category] = categoryAllIcon;
          }

          final categoryId = (parent['id'] as num?)?.toInt();
          if (categoryId == null) continue;
          final children = childrenByParent[categoryId] ?? <Map<String, dynamic>>[];
          children.sort((a, b) {
            final aOrder = (a['sort_order'] as num?)?.toInt() ?? 9999;
            final bOrder = (b['sort_order'] as num?)?.toInt() ?? 9999;
            if (aOrder != bOrder) return aOrder.compareTo(bOrder);
            return ((a['id'] as num?)?.toInt() ?? 0).compareTo(
              (b['id'] as num?)?.toInt() ?? 0,
            );
          });

          final subCatsMap = <String, Map<String, List<ProductImageModel>>>{};
          for (final sub in children) {
            final subCat = (sub['name'] ?? 'General').toString();
            final rawSubIcon =
                (sub['image'] ?? '')
                    .toString()
                    .trim();
            final subIcon = rawSubIcon.isEmpty
                ? ""
                : (rawSubIcon.startsWith('assets/')
                      ? rawSubIcon
                      : 'assets/$rawSubIcon');
            final iconToUse = subIcon.isNotEmpty ? subIcon : categoryIcon;
            if (subIcon.isNotEmpty) {
              _subCategoryIcons['$category::$subCat'] = subIcon;
            }

            final nestedKey = (sub['nested_key'] ?? '').toString();
            final subId = (sub['id'] ?? '${category}_$subCat').toString();

            if (nestedKey.isNotEmpty &&
                nestedSubCategories[nestedKey] is List &&
                (nestedSubCategories[nestedKey] as List).isNotEmpty) {
              final nestedGroups = <String, List<ProductImageModel>>{};
              final nestedNames = List<String>.from(
                (nestedSubCategories[nestedKey] as List).map((e) => e.toString()),
              );
              for (final nestedName in nestedNames) {
                nestedGroups[nestedName] = [
                  ProductImageModel(
                    id: '${subId}_$nestedName',
                    name: category,
                    image: iconToUse,
                    category: category,
                    subcategory: subCat,
                    nestedSubcategory: nestedName,
                    isTrending: false,
                  ),
                ];
              }
              subCatsMap[subCat] = nestedGroups;
            } else {
              subCatsMap[subCat] = {
                'General': [
                  ProductImageModel(
                    id: subId,
                    name: category,
                    image: iconToUse,
                    category: category,
                    subcategory: subCat,
                    nestedSubcategory: 'General',
                    isTrending: false,
                  ),
                ],
              };
            }
          }

          if (subCatsMap.isEmpty) {
            final parentNestedKey = (parent['nested_key'] ?? '').toString();
            if (parentNestedKey.isNotEmpty &&
                nestedSubCategories[parentNestedKey] is List &&
                (nestedSubCategories[parentNestedKey] as List).isNotEmpty) {
              final nestedGroups = <String, List<ProductImageModel>>{};
              final nestedNames = List<String>.from(
                (nestedSubCategories[parentNestedKey] as List).map(
                  (e) => e.toString(),
                ),
              );
              for (final nestedName in nestedNames) {
                nestedGroups[nestedName] = [
                  ProductImageModel(
                    id: '${categoryId}_$nestedName',
                    name: category,
                    image: categoryIcon,
                    category: category,
                    subcategory: 'General',
                    nestedSubcategory: nestedName,
                    isTrending: false,
                  ),
                ];
              }
              subCatsMap['General'] = nestedGroups;
            }
          }

          // Keep parent categories visible even when they do not have children.
          parsed[tabIndex]![category] = subCatsMap;
        }
      }

      parseTab((rootData['interior'] as List?) ?? const [], 0);
      parseTab((rootData['furniture'] as List?) ?? const [], 1);

      if (!mounted) return;
      setState(() {
        _productsByTabCategorySub = parsed;
        // Do NOT auto-select any category on initial load.
        // _selectedCategory remains null until the user taps one.
      });
    } catch (e) {
      debugPrint('Error parsing assets/data/test.json: $e');
    }
  }

  List<ProductImageModel> _resolveQuickProducts(
    int selectedIndex,
  ) {
    final currentTabData = _productsByTabCategorySub[selectedIndex];
    if (currentTabData == null || currentTabData.isEmpty) {
      return [];
    }

    final quickItems = <ProductImageModel>[];
    for (final entry in currentTabData.entries) {
      String iconImage = _categoryIcons[entry.key] ?? "";
      if (iconImage.isEmpty) {
        // Fallback for unexpected missing parent icon.
        final allProducts = <ProductImageModel>[];
        for (final nestedMap in entry.value.values) {
          for (final productList in nestedMap.values) {
            allProducts.addAll(productList);
          }
        }

        if (allProducts.isNotEmpty) {
          final stableIndex = entry.key.hashCode.abs() % allProducts.length;
          iconImage = allProducts[stableIndex].image;
        } else {
          continue;
        }
      }

      quickItems.add(
        ProductImageModel(
          id: 'cat_${entry.key}',
          name: entry.key,
          image: iconImage,
          isTrending: false,
        ),
      );
    }

    return quickItems;
  }

  String _getSubCategoryIcon(
    String categoryName,
    String subCatName,
    Map<String, Map<String, List<ProductImageModel>>> categoryData,
  ) {
    final keyedName = '$categoryName::$subCatName';
    if (_subCategoryIcons.containsKey(keyedName)) {
      return _subCategoryIcons[keyedName]!;
    }

    final subCatData = categoryData[subCatName];
    if (subCatData == null || subCatData.isEmpty) return "";

    final allProducts = <ProductImageModel>[];
    for (final productList in subCatData.values) {
      allProducts.addAll(productList);
    }

    if (allProducts.isEmpty) return "";
    final stableIndex = subCatName.hashCode.abs() % allProducts.length;
    return allProducts[stableIndex].image;
  }

  String _getParentCategoryAllIcon(
    String categoryName,
    Map<String, Map<String, List<ProductImageModel>>> categoryData,
  ) {
    if (_categoryAllIcons.containsKey(categoryName)) {
      return _categoryAllIcons[categoryName]!;
    }
    return _getParentCategoryIcon(categoryName, categoryData);
  }

  Widget _buildQuickCategoryItem(ProductImageModel product, int selectedIndex) {
    final homeState = context.read<HomeCubit>().state;
    return CircularIconItem(
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
          context.read<ProductsCubit>().fetchFeaturedProducts();
        } else {
          setState(() {
            _selectedCategory = product.name;
            _selectedSubCategory = "All";
            _selectedNestedSubCategory = "";
          });
          // Clear search when category is selected
          _searchController.clear();
          context.read<HomeCubit>().clearSearch();
          context.read<ProductsCubit>().fetchProductsByCategory(
            product.name,
            isInterior: selectedIndex == 0,
          );
        }
      },
      child: ClipOval(
        child: Image.asset(product.image, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildSplitCategoryMenu(
    List<ProductImageModel> quickProducts,
    int selectedIndex,
  ) {
    const int columns = 4;
    const double rowGap = 8;
    const double itemWidth = 72;

    final cells = <Widget>[];
    if (!_quickExpanded && quickProducts.length > columns) {
      cells.addAll(
        quickProducts
            .take(columns - 1)
            .map((p) => _buildQuickCategoryItem(p, selectedIndex)),
      );
      cells.add(
        CircularIconItem(
          label: 'View More',
          useUnderline: false,
          onTap: () => setState(() => _quickExpanded = true),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEEEEEE),
              border: Border.all(color: Colors.transparent),
            ),
            child: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: Color(0xFF5D5D5D),
            ),
          ),
        ),
      );
    } else {
      cells.addAll(
        quickProducts.map((p) => _buildQuickCategoryItem(p, selectedIndex)),
      );
      if (quickProducts.length > columns) {
        cells.add(
          CircularIconItem(
            label: 'View Less',
            useUnderline: false,
            onTap: () => setState(() => _quickExpanded = false),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEEEEEE),
                border: Border.all(color: Colors.transparent),
              ),
              child: const Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 20,
                color: Color(0xFF5D5D5D),
              ),
            ),
          ),
        );
      }
    }

    if (cells.isEmpty) return const SizedBox.shrink();

    final rows = <List<Widget>>[];
    for (int i = 0; i < cells.length; i += columns) {
      final end = (i + columns < cells.length) ? i + columns : cells.length;
      rows.add(cells.sublist(i, end));
    }

    return Column(
      children: rows.asMap().entries.map((entry) {
        final rowIndex = entry.key;
        final rowItems = entry.value;

        return Padding(
          padding: EdgeInsets.only(
            bottom: rowIndex == rows.length - 1 ? 0 : rowGap,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowItems
                .map(
                  (cell) => SizedBox(
                    width: itemWidth,
                    child: Center(child: cell),
                  ),
                )
                .toList(),
          ),
        );
      }).toList(),
    );
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



  Future<void> logDb() async {
    final db = await DbCore.database;

    final result = await db.query("products");
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null || !mounted) return;

    final lowerPath = image.path.toLowerCase();
    final isAllowed = lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.png');
    if (!isAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a JPG/JPEG or PNG image.')),
      );
      return;
    }

    final File imageFile = File(image.path);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: TColors.primary),
      ),
    );

    try {
      final productsCubit = context.read<ProductsCubit>();
      final newProduct = await productsCubit.uploadProductImageNew(imageFile);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss loader

      if (newProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to upload image to server.")),
        );
        return;
      }

      final imageBytes = await imageFile.readAsBytes();
      final imageId = newProduct.id;

      await SelectedImagesRepository.saveImage(
        SelectedImageData(
          id: imageId,
          imageData: imageBytes,
          imagePath: imageFile.path,
          category: 'Uploaded Image',
          subcategory: 'User Upload',
          selectedAt: DateTime.now(),
        ),
      );

      if (!mounted) return;
      context.push(
        AppRoutes.imagePreview,
        extra: {
          "imageFile": imageFile,
          "image_id": imageId,
          "image_category": "Uploaded Image",
          "sub_category": "User Upload",
        },
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error processing image: $e")),
        );
      }
    }
  }

  Future<void> _openProductForEditing(ProductImageModel product) async {
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
      final prepared = await _imagePreparationService.prepareProductImage(
        product: product,
        fallbackCategory: _selectedCategory ?? "Furniture",
        fallbackSubcategory: _selectedSubCategory,
      );

      if (mounted && isLoaderShowing) {
        isLoaderShowing = false;
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        context.push(
          AppRoutes.imagePreview,
          extra: {
            "imageFile": prepared.file,
            "image_id": prepared.imageId,
            "image_category": prepared.category,
            "sub_category": prepared.subcategory,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error preparing image: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeCubit = context.watch<HomeCubit>();
    final homeState = homeCubit.state;

    final ProductsState productsState = context.watch<ProductsCubit>().state;
    final List<ProductImageModel> displayProducts = productsState.products;
    final quickProducts = _resolveQuickProducts(
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
                context.read<HomeCubit>().resetFilters();
                // Fetch featured products
                return context.read<ProductsCubit>().fetchFeaturedProducts();
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification scrollInfo) {
                  if (scrollInfo.metrics.pixels >=
                      scrollInfo.metrics.maxScrollExtent - 200) {
                    context.read<ProductsCubit>().loadMoreProducts();
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
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
                          textAlign: TextAlign.center,
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
                          onChanged: (val) {
                            homeCubit.setExterior(val);
                            if (val) {
                              setState(() {
                                _selectedCategory = null;
                                _selectedSubCategory = "All";
                                _selectedNestedSubCategory = "";
                              });
                              _searchController.clear();
                              context.read<HomeCubit>().clearSearch();
                              context
                                  .read<ProductsCubit>()
                                  .fetchFeaturedProducts(isExterior: true);
                            } else {
                              homeCubit.setSelectedIndex(0);
                              setState(() {
                                _selectedCategory = null;
                                _selectedSubCategory = "All";
                                _selectedNestedSubCategory = "";
                              });
                              _searchController.clear();
                              context.read<HomeCubit>().clearSearch();
                              context
                                  .read<ProductsCubit>()
                                  .fetchFeaturedProducts(isExterior: false);
                            }
                          },
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
                            final currentTabData =
                                _productsByTabCategorySub[homeState
                                    .selectedIndex];
                            String? matchingCategory;

                            if (currentTabData != null) {
                              final queryLower = query.toLowerCase();
                              for (final categoryName in currentTabData.keys) {
                                final categoryLower = categoryName
                                    .toLowerCase();
                                if (categoryLower.contains(queryLower) ||
                                    queryLower.contains(categoryLower)) {
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
                              context
                                  .read<ProductsCubit>()
                                  .fetchProductsByCategory(
                                    matchingCategory,
                                    isInterior: homeState.selectedIndex == 0,
                                  );
                            } else {
                              _selectedCategory = null;
                              _selectedSubCategory = "All";
                              _selectedNestedSubCategory = "";

                              // Trigger search API if no category matched
                              context.read<ProductsCubit>().searchProducts(query);
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
                            if (homeState.isExterior)
                              Container(
                                padding: const EdgeInsets.only(bottom: 2),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Color(0xFF5D5D5D),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  "Wall panelling",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF5D5D5D),
                                  ),
                                ),
                              )
                            else
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
                                          color: const Color(0xFF898888),
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
                      const SizedBox(height: 16),
                      if (!homeState.isExterior) ...[
                        _buildSplitCategoryMenu(
                          quickProducts,
                          homeState.selectedIndex,
                        ),
                        const SizedBox(height: 10),
                        _buildSubCategoryMenu(),
                        const SizedBox(height: 10),
                      ],

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
                                       isFavorite: product.isFavorite,
                                       isNetwork: product.isNetworkImage,
                                       id: product.id,
                                       onFavoriteToggle: () {
                                         context.read<ProductsCubit>().toggleFavorite(
                                           itemId: product.id,
                                           ownerId: "anisasru@gmail.com",
                                         );
                                       },
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
                      if (productsState.isLoadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFEA202C),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      SizedBox(height: _bottomCtaReservedSpace(context)),
                    ],
                  ),
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
                    iconImage = _getParentCategoryAllIcon(
                      selectedCategory,
                      categoryData,
                    );
                  } else {
                    iconImage = _getSubCategoryIcon(
                      selectedCategory,
                      subCat,
                      categoryData,
                    );
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
                        if (_selectedSubCategory == subCat || subCat == "All") {
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
                          context
                              .read<ProductsCubit>()
                              .fetchProductsBySubCategory(
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
                          context
                              .read<ProductsCubit>()
                              .fetchProductsBySubCategory(
                                _selectedCategory!,
                                _selectedSubCategory,
                                isInterior: selectedIndex == 0,
                              );
                        } else {
                          setState(() {
                            _selectedNestedSubCategory = nSubCat;
                          });
                          context
                              .read<ProductsCubit>()
                              .fetchProductsByNestedSubCategory(
                                _selectedCategory!,
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
