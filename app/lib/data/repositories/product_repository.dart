import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/data/services/api_service.dart';

class ProductPageResult {
  final List<ProductImageModel> items;
  final int total;
  final int skip;
  final int limit;

  const ProductPageResult({
    required this.items,
    required this.total,
    required this.skip,
    required this.limit,
  });
}

class ProductRepository {
  final ApiService _apiService;

  ProductRepository(this._apiService);

  Future<List<ProductImageModel>> getProducts({int limit = 18}) async {
    final page = await getProductsPage(limit: limit, skip: 0);
    return page.items;
  }

  Future<ProductPageResult> getProductsPage({
    int limit = 18,
    int skip = 0,
    int? page,
  }) async {
    try {
      final data = await _apiService.getProductsPage(
        limit: limit,
        skip: skip,
        page: page,
      );
      final raw = (data['products'] as List?) ?? <dynamic>[];
      if (raw.isEmpty) {
        return ProductPageResult(
          items: const <ProductImageModel>[],
          total: (data['total'] as num?)?.toInt() ?? 0,
          skip: (data['skip'] as num?)?.toInt() ?? skip,
          limit: (data['limit'] as num?)?.toInt() ?? limit,
        );
      }

      final assets = ProductImages.productImages;
      final items = List<ProductImageModel>.generate(raw.length, (index) {
        final item = (raw[index] as Map).cast<String, dynamic>();
        final asset = assets[(skip + index) % assets.length];
        return ProductImageModel(
          id: (item['id'] ?? (skip + index + 1)).toString(),
          name: (item['title'] ?? asset.name).toString(),
          image: asset.image,
        );
      });

      return ProductPageResult(
        items: items,
        total: (data['total'] as num?)?.toInt() ?? items.length,
        skip: (data['skip'] as num?)?.toInt() ?? skip,
        limit: (data['limit'] as num?)?.toInt() ?? limit,
      );
    } catch (_) {
      final fallback = ProductImages.productImages;
      return ProductPageResult(
        items: skip == 0 ? fallback.take(limit).toList() : const [],
        total: fallback.length,
        skip: skip,
        limit: limit,
      );
    }
  }

  Future<List<ProductImageModel>> getFavoriteProducts({int limit = 8}) async {
    final products = await getProducts(limit: limit);
    return products.take(limit).toList();
  }
}
