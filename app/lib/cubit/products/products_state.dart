import 'package:century_ai/core/constants/image_strings.dart';
import 'package:equatable/equatable.dart';

class ProductsState extends Equatable {
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool hasMore;
  final int limit;
  final int offset;
  final List<ProductImageModel> products;
  final String? errorMessage;

  // Track current fetch context for infinite scroll
  final String? currentCategory;
  final String? currentSubCategory;
  final String? currentSubFilter;
  final String? currentQuery;
  final String? currentRoom;
  final String? currentGroup;
  final String? currentProduct;
  final bool? isInterior;

  const ProductsState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.limit = 12,
    this.offset = 0,
    this.products = const <ProductImageModel>[],
    this.errorMessage,
    this.currentCategory,
    this.currentSubCategory,
    this.currentSubFilter,
    this.currentQuery,
    this.currentRoom,
    this.currentGroup,
    this.currentProduct,
    this.isInterior,
  });

  ProductsState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? hasMore,
    int? limit,
    int? offset,
    List<ProductImageModel>? products,
    String? errorMessage,
    String? currentCategory,
    String? currentSubCategory,
    String? currentSubFilter,
    String? currentQuery,
    String? currentRoom,
    String? currentGroup,
    String? currentProduct,
    bool? isInterior,
    bool clearQuery = false,
    bool clearCategory = false,
    bool clearRoom = false,
    bool clearGroup = false,
    bool clearProduct = false,
  }) {
    return ProductsState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      products: products ?? this.products,
      errorMessage: errorMessage,
      currentCategory: clearCategory ? null : (currentCategory ?? this.currentCategory),
      currentSubCategory: clearCategory ? null : (currentSubCategory ?? this.currentSubCategory),
      currentSubFilter: clearCategory ? null : (currentSubFilter ?? this.currentSubFilter),
      currentQuery: clearQuery ? null : (currentQuery ?? this.currentQuery),
      currentRoom: clearRoom ? null : (currentRoom ?? this.currentRoom),
      currentGroup: clearGroup ? null : (currentGroup ?? this.currentGroup),
      currentProduct: clearProduct ? null : (currentProduct ?? this.currentProduct),
      isInterior: isInterior ?? this.isInterior,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isRefreshing,
    isLoadingMore,
    hasMore,
    limit,
    offset,
    products,
    errorMessage,
    currentCategory,
    currentSubCategory,
    currentSubFilter,
    currentQuery,
    currentRoom,
    currentGroup,
    currentProduct,
    isInterior,
  ];
}
