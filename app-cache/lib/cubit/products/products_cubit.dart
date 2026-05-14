import 'dart:io';
import 'package:century_ai/cubit/products/products_state.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/data/repositories/product_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProductsCubit extends Cubit<ProductsState> {
  final ProductRepository _productRepository;

  ProductsCubit(this._productRepository) : super(const ProductsState());

  Future<void> loadProducts({int limit = 12}) async {
    return fetchFeaturedProducts(limit: limit);
  }

  Future<void> fetchSimilarProducts(
    String imageId, {
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

  Future<void> fetchFeaturedProducts({int limit = 12, bool isExterior = false}) async {
    emit(state.copyWith(
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
      isTrending: false,
    ));
    try {
      final products = isExterior
          ? await _productRepository.getProductsByProduct(
              "Exterior Building Material",
              limit: limit,
              offset: 0)
          : await _productRepository.getFeaturedProducts(
              limit: limit, offset: 0);
      emit(state.copyWith(
        isLoading: false,
        products: products,
        hasMore: products.length >= limit,
        offset: products.length,
        currentProduct: isExterior ? "Exterior Building Material" : null,
        currentSubFilter: null,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString(), hasMore: false));
    }
  }

  Future<void> fetchProductsByCategory(String category, {required bool isInterior, int limit = 12}) async {
    emit(state.copyWith(
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
      isTrending: false,
    ));
    try {
      final products = isInterior
          ? await _productRepository.getProductsByRoom(category, limit: limit, offset: 0)
          : await _productRepository.getProductsByGroup(category, limit: limit, offset: 0);
      emit(state.copyWith(
        isLoading: false,
        products: products,
        hasMore: products.length >= limit,
        offset: products.length,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString(), hasMore: false));
    }
  }

  Future<void> fetchProductsBySubCategory(String category, String subCategory, {required bool isInterior, int limit = 12}) async {
    if (subCategory == "All") {
      return fetchProductsByCategory(category, isInterior: isInterior, limit: limit);
    }
    
    final String productBase = isInterior ? subCategory : category;
    final String? subFilter = isInterior ? null : subCategory;

    emit(state.copyWith(
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
      isTrending: false,
    ));
    try {
      final products = await _productRepository.getProductsByProduct(productBase, subCategory: subFilter, limit: limit, offset: 0);
      emit(state.copyWith(
        isLoading: false,
        products: products,
        hasMore: products.length >= limit,
        offset: products.length,
        currentProduct: productBase,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString(), hasMore: false));
    }
  }

  Future<void> fetchProductsByNestedSubCategory(String category, String subCategory, String nestedSubCategory, {required bool isInterior, int limit = 12}) async {
    final String productBase = isInterior ? subCategory : category;
    final String? subFilter = nestedSubCategory;

    emit(state.copyWith(
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
      isTrending: false,
    ));
    try {
      final products = await _productRepository.getProductsByProduct(productBase, subCategory: subFilter, limit: limit, offset: 0);
      emit(state.copyWith(
        isLoading: false, 
        products: products, 
        hasMore: products.length >= limit,
        offset: products.length,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString(), hasMore: false));
    }
  }

  Future<void> fetchTrendingProducts({
    required String ownerId,
    int limit = 12,
  }) async {
    emit(state.copyWith(
      isLoading: true,
      errorMessage: null,
      offset: 0,
      limit: limit,
      isTrending: true,
      currentOwnerId: ownerId,
      clearQuery: true,
      clearCategory: true,
      clearRoom: true,
      clearGroup: true,
      clearProduct: true,
      clearSimilarImageId: true,
    ));
    try {
      final products = await _productRepository.getTrendingProducts(
        ownerId: ownerId,
        limit: limit,
        offset: 0,
      );
      emit(state.copyWith(
        isLoading: false,
        products: products,
        hasMore: products.length >= limit,
        offset: products.length,
      ));
    } catch (e) {
      emit(state.copyWith(
          isLoading: false, errorMessage: e.toString(), hasMore: false));
    }
  }

  Future<void> fetchFavoriteProducts({
    required String ownerId,
  }) async {
    emit(state.copyWith(
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
    ));
    try {
      final products = await _productRepository.getFavoriteProducts(
        ownerId: ownerId,
      );
      emit(state.copyWith(
        isLoading: false,
        products: products,
        hasMore: false, // Favorites endpoint doesn't seem to support pagination yet
        offset: products.length,
      ));
    } catch (e) {
      emit(state.copyWith(
          isLoading: false, errorMessage: e.toString(), hasMore: false));
    }
  }

  Future<void> toggleFavorite({
    required String itemId,
    required String ownerId,
  }) async {
    // Optimistic UI update
    final updatedProducts = state.products.map((p) {
      if (p.id == itemId) {
        return p.copyWith(isFavorite: !p.isFavorite);
      }
      return p;
    }).toList();

    emit(state.copyWith(products: updatedProducts));

    try {
      final success = await _productRepository.toggleFavorite(
        itemId: itemId,
        ownerId: ownerId,
      );
      if (!success) {
        // Rollback on failure
        final rolledBackProducts = state.products.map((p) {
          if (p.id == itemId) {
            return p.copyWith(isFavorite: !p.isFavorite);
          }
          return p;
        }).toList();
        emit(state.copyWith(products: rolledBackProducts));
      }
    } catch (e) {
      // Rollback on error
      final rolledBackProducts = state.products.map((p) {
        if (p.id == itemId) {
          return p.copyWith(isFavorite: !p.isFavorite);
        }
        return p;
      }).toList();
      emit(state.copyWith(products: rolledBackProducts));
    }
  }

  Future<void> searchProducts(String query, {int limit = 12}) async {
    if (query.trim().isEmpty) {
      return fetchFeaturedProducts(limit: limit, isExterior: state.isInterior == false);
    }
    emit(state.copyWith(
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
    ));
    try {
      final products = await _productRepository.searchProducts(query, limit: limit, offset: 0);
      emit(state.copyWith(
        isLoading: false,
        products: products,
        hasMore: products.length >= limit,
        offset: products.length,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString(), hasMore: false));
    }
  }

  Future<void> searchProductsByImage(File file) async {
    emit(state.copyWith(
      isLoading: true,
      errorMessage: null,
      clearSimilarImageId: true,
    ));
    try {
      final products = await _productRepository.searchProductsByImage(file);
      emit(state.copyWith(isLoading: false, products: products, hasMore: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<ProductImageModel?> uploadProductImageNew(File file) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final newProduct = await _productRepository.uploadProductImage(file);
      if (newProduct != null) {
        final updatedProducts = List<ProductImageModel>.from(state.products)..insert(0, newProduct);
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

    debugPrint('🔄 CUBIT_LOG: loadMoreProducts called. Current offset: ${state.offset}, Limit: ${state.limit}');
    emit(state.copyWith(isLoadingMore: true, errorMessage: null));
    try {
      List<ProductImageModel> newProducts = [];

      if (state.isTrending && state.currentOwnerId != null) {
        debugPrint('📈 CUBIT_LOG: Loading more trending products for owner: ${state.currentOwnerId}');
        newProducts = await _productRepository.getTrendingProducts(
          ownerId: state.currentOwnerId!,
          limit: state.limit,
          offset: state.offset,
        );
      } else if (state.currentSimilarImageId != null) {
        newProducts = await _productRepository.getSimilarProducts(
          state.currentSimilarImageId!,
          limit: state.limit,
          offset: state.offset,
        );
      } else if (state.currentQuery != null) {
        debugPrint('🔍 CUBIT_LOG: Loading more for search query: ${state.currentQuery}');
        newProducts = await _productRepository.searchProducts(state.currentQuery!, limit: state.limit, offset: state.offset);
      } else if (state.currentProduct != null) {
        debugPrint('📦 CUBIT_LOG: Loading more for product: ${state.currentProduct}, subFilter: ${state.currentSubFilter}');
        newProducts = await _productRepository.getProductsByProduct(
          state.currentProduct!, 
          subCategory: (state.currentSubFilter == "All") ? null : state.currentSubFilter, 
          limit: state.limit, 
          offset: state.offset
        );
      } else if (state.currentCategory != null) {
        debugPrint('📂 CUBIT_LOG: Loading more for category: ${state.currentCategory}, isInterior: ${state.isInterior}');
        newProducts = state.isInterior == true
            ? await _productRepository.getProductsByRoom(state.currentCategory!, limit: state.limit, offset: state.offset)
            : await _productRepository.getProductsByGroup(state.currentCategory!, limit: state.limit, offset: state.offset);
      } else {
        debugPrint('✨ CUBIT_LOG: Loading more featured products');
        newProducts = await _productRepository.getFeaturedProducts(limit: state.limit, offset: state.offset);
      }

      debugPrint('✅ CUBIT_LOG: Fetched ${newProducts.length} more products');
      emit(state.copyWith(
        isLoadingMore: false,
        products: [...state.products, ...newProducts],
        hasMore: newProducts.length >= state.limit,
        offset: state.offset + newProducts.length,
      ));
    } catch (e) {
      debugPrint('❌ CUBIT_LOG ERROR: loadMoreProducts failure: $e');
      emit(state.copyWith(isLoadingMore: false, errorMessage: e.toString(), hasMore: false));
    }
  }
}
