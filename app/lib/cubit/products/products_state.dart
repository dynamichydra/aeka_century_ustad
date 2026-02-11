import 'package:century_ai/core/constants/image_strings.dart';
import 'package:equatable/equatable.dart';

class ProductsState extends Equatable {
  final bool isLoading;
  final List<ProductImageModel> products;
  final String? errorMessage;

  const ProductsState({
    this.isLoading = false,
    this.products = const <ProductImageModel>[],
    this.errorMessage,
  });

  ProductsState copyWith({
    bool? isLoading,
    List<ProductImageModel>? products,
    String? errorMessage,
  }) {
    return ProductsState(
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [isLoading, products, errorMessage];
}
