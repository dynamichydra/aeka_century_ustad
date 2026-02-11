import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/data/services/api_service.dart';

class ProductRepository {
  final ApiService _apiService;

  ProductRepository(this._apiService);

  Future<List<ProductImageModel>> getProducts({int limit = 18}) async {
    try {
      final raw = await _apiService.getProducts(limit: limit, skip: 0);
      if (raw.isEmpty) return ProductImages.productImages;

      final assets = ProductImages.productImages;
      return List<ProductImageModel>.generate(raw.length, (index) {
        final item = (raw[index] as Map).cast<String, dynamic>();
        final asset = assets[index % assets.length];
        return ProductImageModel(
          id: (item['id'] ?? index + 1).toString(),
          name: (item['title'] ?? asset.name).toString(),
          image: asset.image,
        );
      });
    } catch (_) {
      return ProductImages.productImages;
    }
  }

  Future<List<ProductImageModel>> getFavoriteProducts({int limit = 8}) async {
    final products = await getProducts(limit: limit);
    return products.take(limit).toList();
  }
}
