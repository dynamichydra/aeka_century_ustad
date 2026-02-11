import 'package:century_ai/cubit/products/products_state.dart';
import 'package:century_ai/data/repositories/product_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProductsCubit extends Cubit<ProductsState> {
  final ProductRepository _productRepository;

  ProductsCubit(this._productRepository) : super(const ProductsState());

  Future<void> loadProducts({int limit = 18}) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final products = await _productRepository.getProducts(limit: limit);
      emit(state.copyWith(isLoading: false, products: products));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }
}
