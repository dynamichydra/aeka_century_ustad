import 'dart:io';
import 'package:century_ai/core/constants/image_strings.dart';
import 'package:century_ai/data/services/api_service.dart';
import 'package:flutter/widgets.dart';

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

  ProductImageModel _mapToModel(Map<String, dynamic> json) {
    return ProductImageModel(
      id: json['itemId']?.toString() ??
          json['furnitureId']?.toString() ??
          json['id']?.toString() ??
          '',
      furnitureId: json['furnitureId']?.toString(),
      itemId: json['itemId']?.toString(),
      name: json['product'] ?? json['furnitureCategory'] ?? 'Unknown',
      image: json['imageUrl'] ?? '',
      isTrending: json['isTrending'] == true ||
          json['isTrending']?.toString().toLowerCase() == 'true' ||
          json['isTrending'] == 1 ||
          json['is_trending'] == true ||
          json['is_trending']?.toString().toLowerCase() == 'true' ||
          json['is_trending'] == 1 ||
          json['trending'] == true ||
          json['trending']?.toString().toLowerCase() == 'true' ||
          json['trending'] == 1,
      isNetwork: true,
      category: json['furnitureCategory'],
      subcategory: (json['subCategory'] as List?)?.join(', '),
      isFavorite: json['isFavourited'] == true ||
          json['isFavorite'] == true ||
          json['isFavourited']?.toString().toLowerCase() == 'true' ||
          json['isFavorite']?.toString().toLowerCase() == 'true',
      applicationType: json['applicationType']?.toString(),
    );
  }

  Future<List<ProductImageModel>> getFeaturedProducts({String? ownerId, int limit = 10, int offset = 0}) async {
    try {
      final data = await _apiService.getFeaturedFurniture(ownerId: ownerId, limit: limit, offset: offset);
      final products = data.map((item) => _mapToModel(item.cast<String, dynamic>())).toList();
      debugPrint('📦 REPO_LOG: Fetched ${products.length} featured products (Offset: $offset, Limit: $limit)');
      return products;
    } catch (e) {
      debugPrint('❌ REPO_LOG ERROR: getFeaturedProducts failure: $e');
      return [];
    }
  }

  Future<List<ProductImageModel>> getInteriorProducts({String? ownerId, int limit = 10, int offset = 0}) async {
    try {
      final data = await _apiService.getInteriorFurniture(ownerId: ownerId, limit: limit, offset: offset);
      final products = data.map((item) => _mapToModel(item.cast<String, dynamic>())).toList();
      debugPrint('📦 REPO_LOG: Fetched ${products.length} interior products (Offset: $offset, Limit: $limit)');
      return products;
    } catch (e) {
      debugPrint('❌ REPO_LOG ERROR: getInteriorProducts failure: $e');
      return [];
    }
  }

  Future<List<ProductImageModel>> getExteriorProducts({String? ownerId, int limit = 10, int offset = 0}) async {
    try {
      final data = await _apiService.getExteriorFurniture(ownerId: ownerId, limit: limit, offset: offset);
      final products = data.map((item) => _mapToModel(item.cast<String, dynamic>())).toList();
      debugPrint('📦 REPO_LOG: Fetched ${products.length} exterior products (Offset: $offset, Limit: $limit)');
      return products;
    } catch (e) {
      debugPrint('❌ REPO_LOG ERROR: getExteriorProducts failure: $e');
      return [];
    }
  }

  Future<List<ProductImageModel>> getProductsByRoom(String room, {String? ownerId, int limit = 20, int offset = 0}) async {
    try {
      final data = await _apiService.getFurnitureByRoom(room, ownerId: ownerId, limit: limit, offset: offset);
      final products = data.map((item) => _mapToModel(item.cast<String, dynamic>())).toList();
      debugPrint('📦 REPO_LOG: Fetched ${products.length} products for room: $room, owner: $ownerId (Offset: $offset, Limit: $limit)');
      return products;
    } catch (e) {
      debugPrint('❌ REPO_LOG ERROR: getProductsByRoom failure for $room: $e');
      return [];
    }
  }

  Future<List<ProductImageModel>> getProductsByGroup(String group, {String? ownerId, int limit = 20, int offset = 0}) async {
    try {
      final data = await _apiService.getFurnitureByGroup(group, ownerId: ownerId, limit: limit, offset: offset);
      final products = data.map((item) => _mapToModel(item.cast<String, dynamic>())).toList();
      debugPrint('📦 REPO_LOG: Fetched ${products.length} products for group: $group, owner: $ownerId (Offset: $offset, Limit: $limit)');
      return products;
    } catch (e) {
      debugPrint('❌ REPO_LOG ERROR: getProductsByGroup failure for $group: $e');
      return [];
    }
  }

  Future<List<ProductImageModel>> getProductsByProduct(String product, {String? subCategory, String? ownerId, int limit = 20, int offset = 0}) async {
    try {
      final data = await _apiService.getFurnitureByProduct(product, subCategory: subCategory, ownerId: ownerId, limit: limit, offset: offset);
      final products = data.map((item) => _mapToModel(item.cast<String, dynamic>())).toList();
      debugPrint('📦 REPO_LOG: Fetched ${products.length} products for product: $product, owner: $ownerId (Sub: ${subCategory ?? "None"}, Offset: $offset, Limit: $limit)');
      return products;
    } catch (e) {
      debugPrint('❌ REPO_LOG ERROR: getProductsByProduct failure for $product/$subCategory: $e');
      return [];
    }
  }

  Future<ProductImageModel?> uploadProductImage(File file) async {
    try {
      final data = await _apiService.uploadFurniture(file);
      return _mapToModel(data.cast<String, dynamic>());
    } catch (e) {
      return null;
    }
  }

  Future<List<ProductImageModel>> searchProducts(String query, {String? ownerId, int limit = 20, int offset = 0}) async {
    try {
      final data = await _apiService.searchFurnitureByText(query, ownerId: ownerId, limit: limit, offset: offset);
      final products = data.map((item) => _mapToModel(item.cast<String, dynamic>())).toList();
      debugPrint('🔍 SEARCH_LOG: Text search "$query" found ${products.length} results (Offset: $offset, Limit: $limit)');
      return products;
    } catch (e) {
      debugPrint('❌ SEARCH_LOG ERROR: searchProducts failure for "$query": $e');
      return [];
    }
  }

  Future<List<ProductImageModel>> searchProductsByImage(File file) async {
    try {
      final data = await _apiService.searchFurnitureBySimilarImage(file);
      final products = data.map((item) => _mapToModel(item.cast<String, dynamic>())).toList();
      debugPrint('🔍 SEARCH_LOG: Image search found ${products.length} similar results');
      return products;
    } catch (e) {
      debugPrint('❌ SEARCH_LOG ERROR: searchProductsByImage failure: $e');
      return [];
    }
  }

  Future<List<ProductImageModel>> getSimilarProducts(
    String id, {
    String? ownerId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final data = await _apiService.getSimilarProducts(
        id,
        ownerId: ownerId,
        limit: limit,
        offset: offset,
      );
      final products =
          data.map((item) => _mapToModel(item.cast<String, dynamic>())).toList();
      debugPrint(
        'REPO_LOG: Fetched ${products.length} similar products for id: $id (Offset: $offset, Limit: $limit)',
      );
      return products;
    } catch (e) {
      debugPrint('REPO_LOG ERROR: getSimilarProducts failure for id $id: $e');
      return [];
    }
  }

  Future<List<ProductImageModel>> getTrendingProducts({
    required String ownerId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final data = await _apiService.getTrendingProducts(
        ownerId: ownerId,
        limit: limit,
        offset: offset,
      );
      final products = data.map((item) {
        final model = _mapToModel(item.cast<String, dynamic>());
        return model.copyWith(isTrending: true);
      }).toList();
      debugPrint(
        '📦 REPO_LOG: Fetched ${products.length} trending products for owner: $ownerId (Offset: $offset, Limit: $limit)',
      );
      return products;
    } catch (e) {
      debugPrint('❌ REPO_LOG ERROR: getTrendingProducts failure: $e');
      return [];
    }
  }

  Future<List<ProductImageModel>> getFavoriteProducts({
    required String ownerId,
  }) async {
    try {
      final data = await _apiService.getFavoriteProducts(ownerId: ownerId);
      final products = data.map((item) {
        final model = _mapToModel(item.cast<String, dynamic>());
        // Since we are fetching from the favorites endpoint, we can mark them as liked
        return model.copyWith(isFavorite: true);
      }).toList();
      debugPrint(
        '📦 REPO_LOG: Fetched ${products.length} favorite products for owner: $ownerId',
      );
      return products;
    } catch (e) {
      debugPrint('❌ REPO_LOG ERROR: getFavoriteProducts failure: $e');
      return [];
    }
  }

  Future<bool> toggleFavorite({
    required String itemId,
    required String ownerId,
  }) async {
    try {
      await _apiService.toggleFavorite(itemId: itemId, ownerId: ownerId);
      return true;
    } catch (e) {
      debugPrint('❌ REPO_LOG ERROR: toggleFavorite failure for $itemId: $e');
      return false;
    }
  }

  Future<bool> removeFavorite({
    required String itemId,
    required String ownerId,
  }) async {
    try {
      await _apiService.removeFavorite(itemId: itemId, ownerId: ownerId);
      return true;
    } catch (e) {
      debugPrint('❌ REPO_LOG ERROR: removeFavorite failure for $itemId: $e');
      return false;
    }
  }

  // --- Legacy Methods ---

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

      final items = raw.map((item) => _mapToModel((item as Map).cast<String, dynamic>())).toList();

      return ProductPageResult(
        items: items,
        total: (data['total'] as num?)?.toInt() ?? items.length,
        skip: (data['skip'] as num?)?.toInt() ?? skip,
        limit: (data['limit'] as num?)?.toInt() ?? limit,
      );
    } catch (_) {
      return ProductPageResult(
        items: const [],
        total: 0,
        skip: skip,
        limit: limit,
      );
    }
  }

}
