import 'dart:io';
import 'package:century_ai/cubit/products/products_state.dart';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/data/repositories/product_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProductsCubit extends Cubit<ProductsState> {
  final ProductRepository _productRepository;

  ProductsCubit(this._productRepository) : super(const ProductsState());

  Future<void> loadProducts({int limit = 12}) async {
    emit(
      state.copyWith(
        isLoading: true,
        isRefreshing: false,
        isLoadingMore: false,
        errorMessage: null,
        limit: limit,
      ),
    );
    try {
      final page = await _productRepository.getProductsPage(limit: limit, skip: 0);
      final hasMore = (page.skip + page.items.length) < page.total;
      emit(
        state.copyWith(
          isLoading: false,
          products: page.items,
          hasMore: hasMore,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> fetchFeaturedProducts() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final products = await _productRepository.getFeaturedProducts();
      emit(state.copyWith(isLoading: false, products: products, hasMore: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> fetchProductsByCategory(String category, {required bool isInterior}) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final products = isInterior
          ? await _productRepository.getProductsByRoom(category)
          : await _productRepository.getProductsByGroup(category);
      emit(state.copyWith(isLoading: false, products: products, hasMore: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> fetchProductsBySubCategory(String category, String subCategory, {required bool isInterior}) async {
    if (subCategory == "All") {
      return fetchProductsByCategory(category, isInterior: isInterior);
    }
    
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      // Standardizing based on user requirement:
      // If Interior: subCategory (Icon) is the 'product'
      // If Furniture: category (Group) is the 'product', subCategory (Icon) is 'subCategory'
      final String productBase = isInterior ? subCategory : category;
      final String? subFilter = isInterior ? null : subCategory;

      final products = await _productRepository.getProductsByProduct(productBase, subCategory: subFilter);
      emit(state.copyWith(isLoading: false, products: products, hasMore: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> fetchProductsByNestedSubCategory(String category, String subCategory, String nestedSubCategory, {required bool isInterior}) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      // Standardizing for nested levels (mainly Interiors):
      // Product remains the subCategory (Icon), and nestedSubCategory (Pill) is the sub-filter
      final String productBase = isInterior ? subCategory : category;
      final String? subFilter = isInterior ? nestedSubCategory : nestedSubCategory;

      final products = await _productRepository.getProductsByProduct(productBase, subCategory: subFilter);
      emit(state.copyWith(isLoading: false, products: products, hasMore: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> searchProducts(String query) async {
    if (query.trim().isEmpty) {
      return fetchFeaturedProducts();
    }
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final products = await _productRepository.searchProducts(query);
      emit(state.copyWith(isLoading: false, products: products, hasMore: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
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

  Future<ProductImageModel?> uploadProductImage(File file) async {
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

  Future<void> refreshProducts() async {
    emit(state.copyWith(isRefreshing: true, errorMessage: null));
    try {
      final page = await _productRepository.getProductsPage(
        limit: state.limit,
        skip: 0,
      );
      final hasMore = (page.skip + page.items.length) < page.total;
      emit(
        state.copyWith(
          isRefreshing: false,
          products: page.items,
          hasMore: hasMore,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isRefreshing: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> loadMoreProducts() async {
    if (state.isLoadingMore || state.isLoading || state.isRefreshing || !state.hasMore) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true, errorMessage: null));
    try {
      final page = await _productRepository.getProductsPage(
        limit: state.limit,
        skip: state.products.length,
      );
      final merged = <String, dynamic>{};
      for (final p in state.products) {
        merged[p.id] = p;
      }
      for (final p in page.items) {
        merged[p.id] = p;
      }
      final next = merged.values.cast<ProductImageModel>().toList();
      final hasMore = (page.skip + page.items.length) < page.total;

      emit(
        state.copyWith(
          isLoadingMore: false,
          products: next,
          hasMore: hasMore,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingMore: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
