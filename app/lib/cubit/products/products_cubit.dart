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

  Future<void> fetchFeaturedProducts({int limit = 12}) async {
    emit(state.copyWith(
      isLoading: true,
      errorMessage: null,
      offset: 0,
      limit: limit,
      clearQuery: true,
      clearCategory: true,
      clearRoom: true,
      clearGroup: true,
      clearProduct: true,
    ));
    try {
      final products = await _productRepository.getFeaturedProducts(limit: limit, offset: 0);
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

  Future<void> searchProducts(String query, {int limit = 12}) async {
    if (query.trim().isEmpty) {
      return fetchFeaturedProducts(limit: limit);
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
    emit(state.copyWith(isLoading: true, errorMessage: null));
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
      
      if (state.currentQuery != null) {
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
