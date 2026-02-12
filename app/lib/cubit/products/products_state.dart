import 'package:century_ai/core/constants/image_strings.dart';
import 'package:equatable/equatable.dart';

class ProductsState extends Equatable {
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool hasMore;
  final int limit;
  final List<ProductImageModel> products;
  final String? errorMessage;

  const ProductsState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.limit = 12,
    this.products = const <ProductImageModel>[],
    this.errorMessage,
  });

  ProductsState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? hasMore,
    int? limit,
    List<ProductImageModel>? products,
    String? errorMessage,
  }) {
    return ProductsState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      limit: limit ?? this.limit,
      products: products ?? this.products,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isRefreshing,
    isLoadingMore,
    hasMore,
    limit,
    products,
    errorMessage,
  ];
}
