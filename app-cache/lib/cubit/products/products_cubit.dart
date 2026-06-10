import 'dart:io';
import 'package:century_ai/cubit/products/products_state.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/data/repositories/product_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart' as img;

class ProductsCubit extends Cubit<ProductsState> {
  final ProductRepository _productRepository;

  ProductsCubit(this._productRepository) : super(const ProductsState());

  Future<void> loadProducts({String? ownerId, int limit = 12}) async {
    return fetchFeaturedProducts(ownerId: ownerId, limit: limit);
  }

  Future<void> fetchSimilarProducts(
    String imageId, {
    String? ownerId,
    int limit = 12,
  }) async {
    if (imageId.trim().isEmpty) return;

    emit(
      state.copyWith(
        isLoading: true,
        errorMessage: null,
        products: const [],
        offset: 0,
        limit: limit,
        currentSimilarImageId: imageId,
        currentOwnerId: ownerId,
        clearQuery: true,
        clearCategory: true,
        clearRoom: true,
        clearGroup: true,
        clearProduct: true,
      ),
    );

    try {
      final products = await _productRepository.getSimilarProducts(
        imageId,
        ownerId: ownerId,
        limit: limit,
        offset: 0,
      );
      emit(
        state.copyWith(
          isLoading: false,
          products: products,
          hasMore: products.length >= limit,
          offset: products.length,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
          hasMore: false,
        ),
      );
    }
  }

  Future<void> fetchFeaturedProducts({
    String? ownerId,
    int limit = 12,
    bool isExterior = false,
  }) async {
    emit(
      state.copyWith(
        isLoading: true,
        errorMessage: null,
        offset: 0,
        limit: limit,
        isInterior: !isExterior,
        clearQuery: true,
        clearCategory: true,
        clearRoom: true,
        clearGroup: true,
        clearProduct: true,
        clearSimilarImageId: true,
        currentOwnerId: ownerId,
        isTrending: false,
      ),
    );
    try {
      final products = isExterior
          ? await _productRepository.getExteriorProducts(
              ownerId: ownerId,
              limit: limit,
              offset: 0,
            )
          : await _productRepository.getInteriorProducts(
              ownerId: ownerId,
              limit: limit,
              offset: 0,
            );
      emit(
        state.copyWith(
          isLoading: false,
          products: products,
          hasMore: products.length >= limit,
          offset: products.length,
          currentProduct: isExterior ? "Exterior" : "Interior",
          currentSubFilter: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
          hasMore: false,
        ),
      );
    }
  }

  Future<void> fetchProductsByCategory(
    String category, {
    required bool isInterior,
    String? ownerId,
    int limit = 12,
  }) async {
    final activeOwnerId = ownerId ?? state.currentOwnerId;
    emit(
      state.copyWith(
        isLoading: true,
        errorMessage: null,
        offset: 0,
        limit: limit,
        currentCategory: category,
        isInterior: isInterior,
        clearQuery: true,
        clearRoom: !isInterior,
        clearGroup: isInterior,
        clearProduct: true,
        clearSimilarImageId: true,
        currentOwnerId: activeOwnerId,
        isTrending: false,
      ),
    );
    try {
      final products = isInterior
          ? await _productRepository.getProductsByRoom(
              category,
              ownerId: activeOwnerId,
              limit: limit,
              offset: 0,
            )
          : await _productRepository.getProductsByGroup(
              category,
              ownerId: activeOwnerId,
              limit: limit,
              offset: 0,
            );
      emit(
        state.copyWith(
          isLoading: false,
          products: products,
          hasMore: products.length >= limit,
          offset: products.length,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
          hasMore: false,
        ),
      );
    }
  }

  Future<void> fetchProductsBySubCategory(
    String category,
    String subCategory, {
    required bool isInterior,
    String? ownerId,
    int limit = 12,
  }) async {
    final activeOwnerId = ownerId ?? state.currentOwnerId;
    if (subCategory == "All") {
      return fetchProductsByCategory(
        category,
        isInterior: isInterior,
        ownerId: activeOwnerId,
        limit: limit,
      );
    }

    final String productBase = isInterior ? subCategory : category;
    final String? subFilter = isInterior ? null : subCategory;

    emit(
      state.copyWith(
        isLoading: true,
        errorMessage: null,
        offset: 0,
        limit: limit,
        currentCategory: category,
        currentSubCategory: subCategory,
        currentSubFilter: subFilter,
        isInterior: isInterior,
        clearQuery: true,
        clearProduct: false,
        clearSimilarImageId: true,
        currentOwnerId: activeOwnerId,
        isTrending: false,
      ),
    );
    try {
      final products = await _productRepository.getProductsByProduct(
        productBase,
        subCategory: subFilter,
        ownerId: activeOwnerId,
        limit: limit,
        offset: 0,
      );
      emit(
        state.copyWith(
          isLoading: false,
          products: products,
          hasMore: products.length >= limit,
          offset: products.length,
          currentProduct: productBase,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
          hasMore: false,
        ),
      );
    }
  }

  Future<void> fetchProductsByNestedSubCategory(
    String category,
    String subCategory,
    String nestedSubCategory, {
    required bool isInterior,
    String? ownerId,
    int limit = 12,
  }) async {
    final activeOwnerId = ownerId ?? state.currentOwnerId;
    final String productBase = isInterior ? subCategory : category;
    final String? subFilter = nestedSubCategory;

    emit(
      state.copyWith(
        isLoading: true,
        errorMessage: null,
        offset: 0,
        limit: limit,
        currentCategory: category,
        currentSubCategory: subCategory,
        currentSubFilter: subFilter,
        currentProduct: productBase,
        isInterior: isInterior,
        clearQuery: true,
        clearSimilarImageId: true,
        currentOwnerId: activeOwnerId,
        isTrending: false,
      ),
    );
    try {
      final products = await _productRepository.getProductsByProduct(
        productBase,
        subCategory: subFilter,
        ownerId: activeOwnerId,
        limit: limit,
        offset: 0,
      );
      emit(
        state.copyWith(
          isLoading: false,
          products: products,
          hasMore: products.length >= limit,
          offset: products.length,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
          hasMore: false,
        ),
      );
    }
  }

  Future<void> fetchTrendingProducts({
    required String ownerId,
    String? applicationType,
    int limit = 200,
  }) async {
    emit(
      state.copyWith(
        isLoading: true,
        errorMessage: null,
        offset: 0,
        limit: limit,
        isTrending: true,
        currentOwnerId: ownerId,
        currentApplicationType: applicationType,
        clearQuery: true,
        clearCategory: true,
        clearRoom: true,
        clearGroup: true,
        clearProduct: true,
        clearSimilarImageId: true,
      ),
    );
    try {
      final products = await _productRepository.getTrendingProducts(
        ownerId: ownerId,
        applicationType: applicationType,
        limit: limit,
        offset: 0,
      );
      emit(
        state.copyWith(
          isLoading: false,
          products: products,
          hasMore: products.length >= limit,
          offset: products.length,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
          hasMore: false,
        ),
      );
    }
  }

  Future<void> fetchFavoriteProducts({required String ownerId}) async {
    emit(
      state.copyWith(
        isLoading: true,
        errorMessage: null,
        offset: 0,
        isFavoriteView: true,
        isTrending: false,
        currentOwnerId: ownerId,
        clearQuery: true,
        clearCategory: true,
        clearRoom: true,
        clearGroup: true,
        clearProduct: true,
        clearSimilarImageId: true,
      ),
    );
    try {
      final products = await _productRepository.getFavoriteProducts(
        ownerId: ownerId,
      );
      emit(
        state.copyWith(
          isLoading: false,
          products: products,
          hasMore:
              false, // Favorites endpoint doesn't seem to support pagination yet
          offset: products.length,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
          hasMore: false,
        ),
      );
    }
  }

  Future<void> toggleFavorite({
    required String itemId,
    required String ownerId,
  }) async {
    // Determine current state before optimistic update
    final product = state.products.firstWhere((p) => p.id == itemId);
    final wasFavorite = product.isFavorite;

    // Optimistic UI update
    final updatedProducts = state.products.map((p) {
      if (p.id == itemId) {
        return p.copyWith(isFavorite: !wasFavorite);
      }
      return p;
    }).toList();

    emit(state.copyWith(products: updatedProducts));

    try {
      final bool success;
      if (wasFavorite) {
        // Use DELETE to unfavorite
        success = await _productRepository.removeFavorite(
          itemId: itemId,
          ownerId: ownerId,
        );
      } else {
        // Use POST to favorite
        success = await _productRepository.toggleFavorite(
          itemId: itemId,
          ownerId: ownerId,
        );
      }

      if (!success) {
        // Rollback on failure
        _rollbackFavorite(itemId);
      }
    } catch (e) {
      // Rollback on error
      _rollbackFavorite(itemId);
    }
  }

  void _rollbackFavorite(String itemId) {
    final rolledBackProducts = state.products.map((p) {
      if (p.id == itemId) {
        return p.copyWith(isFavorite: !p.isFavorite);
      }
      return p;
    }).toList();
    emit(state.copyWith(products: rolledBackProducts));
  }

  Future<void> searchProducts(
    String query, {
    String? ownerId,
    int limit = 12,
  }) async {
    final activeOwnerId = ownerId ?? state.currentOwnerId ?? "user13@gmail.com";
    if (query.trim().isEmpty) {
      return fetchFeaturedProducts(
        ownerId: activeOwnerId,
        limit: limit,
        isExterior: state.isInterior == false,
      );
    }
    emit(
      state.copyWith(
        isLoading: true,
        errorMessage: null,
        offset: 0,
        limit: limit,
        currentQuery: query,
        clearCategory: true,
        clearRoom: true,
        clearGroup: true,
        clearProduct: true,
        clearSimilarImageId: true,
        isTrending: false,
        currentOwnerId: activeOwnerId,
      ),
    );
    try {
      final products = await _productRepository.searchProducts(
        query,
        ownerId: activeOwnerId,
        limit: limit,
        offset: 0,
      );
      emit(
        state.copyWith(
          isLoading: false,
          products: products,
          hasMore: products.length >= limit,
          offset: products.length,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
          hasMore: false,
        ),
      );
    }
  }

  Future<void> searchProductsByImage(File file) async {
    emit(
      state.copyWith(
        isLoading: true,
        errorMessage: null,
        clearSimilarImageId: true,
      ),
    );
    try {
      final normalizedFile = await _normalizeImageOrientation(file);
      final products = await _productRepository.searchProductsByImage(
        normalizedFile,
      );
      emit(
        state.copyWith(isLoading: false, products: products, hasMore: false),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<ProductImageModel?> uploadProductImageNew(File file) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final normalizedFile = await _normalizeImageOrientation(file);
      final newProduct = await _productRepository.uploadProductImage(
        normalizedFile,
      );
      if (newProduct != null) {
        final updatedProducts = List<ProductImageModel>.from(state.products)
          ..insert(0, newProduct);
        emit(state.copyWith(isLoading: false, products: updatedProducts));
        return newProduct;
      } else {
        emit(state.copyWith(isLoading: false, errorMessage: 'Upload failed'));
        return null;
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
      return null;
    }
  }

  Future<void> loadMoreProducts() async {
    if (state.isLoadingMore || !state.hasMore) return;

    debugPrint(
      '🔄 CUBIT_LOG: loadMoreProducts called. Current offset: ${state.offset}, Limit: ${state.limit}',
    );
    emit(state.copyWith(isLoadingMore: true, errorMessage: null));
    try {
      List<ProductImageModel> newProducts = [];

      if (state.isTrending && state.currentOwnerId != null) {
        debugPrint(
          '📈 CUBIT_LOG: Loading more trending products for owner: ${state.currentOwnerId}',
        );
        newProducts = await _productRepository.getTrendingProducts(
          ownerId: state.currentOwnerId!,
          applicationType: state.currentApplicationType,
          limit: state.limit,
          offset: state.offset,
        );
      } else if (state.currentSimilarImageId != null) {
        newProducts = await _productRepository.getSimilarProducts(
          state.currentSimilarImageId!,
          ownerId: state.currentOwnerId,
          limit: state.limit,
          offset: state.offset,
        );
      } else if (state.currentQuery != null) {
        debugPrint(
          '🔍 CUBIT_LOG: Loading more for search query: ${state.currentQuery}',
        );
        newProducts = await _productRepository.searchProducts(
          state.currentQuery!,
          ownerId: state.currentOwnerId,
          limit: state.limit,
          offset: state.offset,
        );
      } else if (state.currentProduct != null) {
        debugPrint(
          '📦 CUBIT_LOG: Loading more for product: ${state.currentProduct}, subFilter: ${state.currentSubFilter}',
        );
        if (state.currentProduct == "Exterior") {
          newProducts = await _productRepository.getExteriorProducts(
            ownerId: state.currentOwnerId,
            limit: state.limit,
            offset: state.offset,
          );
        } else if (state.currentProduct == "Interior") {
          newProducts = await _productRepository.getInteriorProducts(
            ownerId: state.currentOwnerId,
            limit: state.limit,
            offset: state.offset,
          );
        } else {
          newProducts = await _productRepository.getProductsByProduct(
            state.currentProduct!,
            subCategory: (state.currentSubFilter == "All")
                ? null
                : state.currentSubFilter,
            ownerId: state.currentOwnerId,
            limit: state.limit,
            offset: state.offset,
          );
        }
      } else if (state.currentCategory != null) {
        debugPrint(
          '📂 CUBIT_LOG: Loading more for category: ${state.currentCategory}, isInterior: ${state.isInterior}',
        );
        newProducts = state.isInterior == true
            ? await _productRepository.getProductsByRoom(
                state.currentCategory!,
                ownerId: state.currentOwnerId,
                limit: state.limit,
                offset: state.offset,
              )
            : await _productRepository.getProductsByGroup(
                state.currentCategory!,
                ownerId: state.currentOwnerId,
                limit: state.limit,
                offset: state.offset,
              );
      } else {
        debugPrint('✨ CUBIT_LOG: Loading more featured products');
        newProducts = await _productRepository.getFeaturedProducts(
          ownerId: state.currentOwnerId,
          limit: state.limit,
          offset: state.offset,
        );
      }

      debugPrint('✅ CUBIT_LOG: Fetched ${newProducts.length} more products');
      emit(
        state.copyWith(
          isLoadingMore: false,
          products: [...state.products, ...newProducts],
          hasMore: newProducts.length >= state.limit,
          offset: state.offset + newProducts.length,
        ),
      );
    } catch (e) {
      debugPrint('❌ CUBIT_LOG ERROR: loadMoreProducts failure: $e');
      emit(
        state.copyWith(
          isLoadingMore: false,
          errorMessage: e.toString(),
          hasMore: false,
        ),
      );
    }
  }
}

/// Helper function to bake orientation in a separate isolate (background thread)
Uint8List _performBakeOrientation(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return bytes;
  final baked = img.bakeOrientation(image);
  return img.encodeJpg(baked, quality: 90);
}

/// Normalizes the orientation of the image in-place
Future<File> _normalizeImageOrientation(File file) async {
  try {
    final bytes = await file.readAsBytes();
    final bakedBytes = await compute(_performBakeOrientation, bytes);
    await file.writeAsBytes(bakedBytes);
  } catch (e) {
    debugPrint("Error normalizing image orientation: $e");
  }
  return file;
}
