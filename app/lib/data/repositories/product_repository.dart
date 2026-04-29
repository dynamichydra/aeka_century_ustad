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
      id: json['id'] ?? '',
      name: json['product'] ?? json['furnitureCategory'] ?? 'Unknown',
      image: json['imageUrl'] ?? '',
      isTrending: false,
      isNetwork: true,
      category: json['furnitureCategory'],
      subcategory: (json['subCategory'] as List?)?.join(', '),
    );
  }

  Future<List<ProductImageModel>> getFeaturedProducts({int limit = 10, int offset = 0}) async {
    try {
      final data = await _apiService.getFeaturedFurniture(limit: limit, offset: offset);
      final products = data.map((item) => _mapToModel(item.cast<String, dynamic>())).toList();
      debugPrint('📦 REPO_LOG: Fetched ${products.length} featured products (Offset: $offset, Limit: $limit)');
      return products;
    } catch (e) {
      debugPrint('❌ REPO_LOG ERROR: getFeaturedProducts failure: $e');
      return [];
    }
  }

  Future<List<ProductImageModel>> getProductsByRoom(String room, {int limit = 20, int offset = 0}) async {
    try {
      final data = await _apiService.getFurnitureByRoom(room, limit: limit, offset: offset);
      final products = data.map((item) => _mapToModel(item.cast<String, dynamic>())).toList();
      debugPrint('📦 REPO_LOG: Fetched ${products.length} products for room: $room (Offset: $offset, Limit: $limit)');
      return products;
    } catch (e) {
      debugPrint('❌ REPO_LOG ERROR: getProductsByRoom failure for $room: $e');
      return [];
    }
  }

  Future<List<ProductImageModel>> getProductsByGroup(String group, {int limit = 20, int offset = 0}) async {
    try {
      final data = await _apiService.getFurnitureByGroup(group, limit: limit, offset: offset);
      final products = data.map((item) => _mapToModel(item.cast<String, dynamic>())).toList();
      debugPrint('📦 REPO_LOG: Fetched ${products.length} products for group: $group (Offset: $offset, Limit: $limit)');
      return products;
    } catch (e) {
      debugPrint('❌ REPO_LOG ERROR: getProductsByGroup failure for $group: $e');
      return [];
    }
  }

  Future<List<ProductImageModel>> getProductsByProduct(String product, {String? subCategory, int limit = 20, int offset = 0}) async {
    try {
      final data = await _apiService.getFurnitureByProduct(product, subCategory: subCategory, limit: limit, offset: offset);
      final products = data.map((item) => _mapToModel(item.cast<String, dynamic>())).toList();
      debugPrint('📦 REPO_LOG: Fetched ${products.length} products for product: $product (Sub: ${subCategory ?? "None"}, Offset: $offset, Limit: $limit)');
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

  Future<List<ProductImageModel>> searchProducts(String query, {int limit = 20, int offset = 0}) async {
    try {
      final data = await _apiService.searchFurnitureByText(query, limit: limit, offset: offset);
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

  Future<List<ProductImageModel>> getFavoriteProducts({int limit = 8}) async {
    final products = await getProducts(limit: limit);
    return products.take(limit).toList();
  }
}
