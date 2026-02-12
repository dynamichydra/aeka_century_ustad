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
