import 'package:flutter/foundation.dart';
import 'package:century_ai/core/network/apis/laminate_api.dart';
import 'package:century_ai/core/network/cache/laminate_cache_service.dart';

class TextureController {
  final LaminateService laminateApi;
  final LaminateCacheService cacheService;
  final bool isExterior;

  TextureController({
    required this.laminateApi,
    required this.cacheService,
    required this.isExterior,
  });

  static const Map<String, List<String>> laminateCategoriesMap = {
    "Abstract Patterns": [
      "All",
      "Glitters",
      "Exclusives",
      "Wallpaper",
      "Noir Collection",
      "Patterns",
      "Textile",
      "Cane",
      "Fabric",
      "High Gloss",
      "Adaluxe",
      "Urban Leather",
      "Linen",
      "Tessuto",
      "Iyo Petal",
      "Lusio",
    ],
    "Woodgrains": [
      "All",
      "Woodgrains",
      "Synchro Series",
      "Evoke Oak",
      "Willow Wood",
      "Exotic Woodgrains",
      "Pinkora",
      "Vava Oxford",
      "Crasse",
      "Natural Horizontal",
      "Horizontal",
      "White Woods",
      "Acacia",
      "Ash",
      "Hickory, Elm & Chestnut",
      "Maple",
      "Pine",
      "Beech & Anegre",
      "Cherry & Pear",
      "Sapeli, Mahogany & Rosewood",
      "Teak",
      "Walnut",
      "Oak",
      "Wenge",
      "Dyed Wood",
    ],
    "Stones": [
      "All",
      "Stones",
      "Archi Concrete",
      "Slate",
      "Kering Matne",
      "Black",
      "White",
    ],
    "Solid": [
      "All",
      "Yellow & Orange",
      "Green",
      "Grey",
      "Voilet",
      "Blue",
      "Red",
      "Pink",
      "Brown & Beige",
    ],
  };

  static const Map<String, List<String>> exteriaCategoriesMap = {
    "Abstract Patterns": ["All", "Cement", "Grunge & Rustic", "Others"],
    "Woodgrains": ["All", "Dark", "Medium", "Light"],
    "Stones": ["All", "Marble", "Travertine", "Ivory"],
    "Solid": ["All", "Green", "White", "Blue", "Yellow", "Grey", "Other"],
  };

  Map<String, List<String>> get activeCategoriesMap =>
      isExterior ? exteriaCategoriesMap : laminateCategoriesMap;

  List<String> getCategories() {
    return activeCategoriesMap.keys.toList();
  }

  List<String> getSubCategories(String category) {
    return activeCategoriesMap[category] ?? [];
  }

  /// Fetches laminates by category with pagination support.
  ///
  /// - [page] = 1: Returns all laminates currently in cache (if any) plus
  ///   fetches page 1 from API if cache is empty.
  /// - [page] > 1: Always calls the API to fetch that specific page,
  ///   merges new items into the cache, and returns only the NEW items
  ///   for that page.
  ///
  /// Returns: `{"textures": List<dynamic>, "totalCount": int?}`
  Future<Map<String, dynamic>> fetchTexturesByCategory({
    required String category,
    required String? subcategory,
    int? page,
    int? pageLimit,
  }) async {
    final String subCat =
        (subcategory == "All" || subcategory == null) ? "" : subcategory;
    final String itemType = isExterior ? "Exteria" : "Laminates";
    final int reqPage = page ?? 1;
    final int limit = pageLimit ?? 12;

    // Load existing cache for this category
    final cachedData = cacheService.getCategoryTextures(
      category,
      subCat,
      itemType: itemType,
    );
    final List<dynamic> cachedTextures =
        (cachedData?["textures"] as List<dynamic>?) ?? [];
    final int? cachedTotalCount = cachedData?["totalCount"] as int?;

    // ── PAGE 1: Serve from cache if we have ANY cached items ──────────────────
    if (reqPage == 1 && cachedTextures.isNotEmpty) {
      debugPrint(
        "📦 [CACHE HIT] Page 1 served from cache: ${cachedTextures.length} items "
        "(totalCount: $cachedTotalCount) for '$category' / '$subCat'",
      );
      return {
        "textures": cachedTextures,
        "totalCount": cachedTotalCount,
      };
    }

    // ── PAGE > 1 OR EMPTY CACHE: Call the API ────────────────────────────────
    debugPrint(
      "🌐 [API CALL] Page $reqPage → category: '$category', subcategory: '$subCat', "
      "pageLimit: $limit",
    );

    final response = await laminateApi.fetchByCategory(
      category: category,
      subcategory: subCat,
      itemType: itemType,
      page: reqPage,
      pageLimit: limit,
    );

    debugPrint("📥 [API RESPONSE] Page $reqPage → $response");

    if (response != null && response is Map) {
      final List<dynamic> newItems =
          (response['data'] ?? response['laminates']) as List<dynamic>? ?? [];
      final int? totalCount =
          (response['totalCount'] ?? response['total_count'] ?? response['count'])
              as int?;

      debugPrint(
        "✅ [API SUCCESS] Page $reqPage → ${newItems.length} items "
        "(totalCount: $totalCount)",
      );

      if (newItems.isNotEmpty) {
        // Merge new items into cache (de-duplicate by id)
        final List<dynamic> merged = List.from(cachedTextures);
        final Set<String> existingIds =
            merged.map((e) => e['id']?.toString() ?? e.toString()).toSet();

        for (final item in newItems) {
          final String itemId = item['id']?.toString() ?? item.toString();
          if (!existingIds.contains(itemId)) {
            merged.add(item);
            existingIds.add(itemId);
          }
        }

        cacheService.saveCategoryTextures(
          category,
          subCat,
          merged,
          totalCount: totalCount ?? cachedTotalCount,
          itemType: itemType,
        );

        debugPrint(
          "💾 [CACHE SAVED] ${merged.length} total items cached for '$category'/'$subCat'",
        );
      }

      // For page 1 with empty cache: return new items directly.
      // For page > 1: return ONLY the new items so the caller can append.
      return {
        "textures": newItems,
        "totalCount": totalCount ?? cachedTotalCount,
      };
    }

    debugPrint("⚠️ [API EMPTY] No response for page $reqPage");
    return {
      "textures": <dynamic>[],
      "totalCount": cachedTotalCount ?? 0,
    };
  }

  Future<List<dynamic>> fetchTexturesByColor(String hex) async {
    // Try cache first
    final cached = cacheService.getHexTextures(
      hex,
      itemType: isExterior ? "Exteria" : "Laminates",
    );
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final response = await laminateApi.fetchByHex(
      hexCodes: [hex],
      itemType: isExterior ? "Exteria" : "Laminates",
    );

    List<dynamic> textures = [];
    if (response != null && response is Map && response.isNotEmpty) {
      if (response.containsKey('data') && response['data'] != null) {
        textures = response['data'] as List<dynamic>;
      } else if (response.containsKey('laminates') &&
          response['laminates'] != null) {
        textures = response['laminates'] as List<dynamic>;
      } else {
        final key = response.keys.first;
        if (response[key] is List) {
          textures = response[key] as List<dynamic>;
        }
      }

      if (textures.isNotEmpty) {
        cacheService.saveHexTextures(
          hex,
          textures,
          itemType: isExterior ? "Exteria" : "Laminates",
        );
      }
    }
    return textures;
  }

  Future<List<dynamic>> fetchTexturesBySku(String skuId) async {
    if (skuId.trim().isEmpty) return [];

    final response = await laminateApi.fetchBySku(
      skuId: skuId.trim().toUpperCase(),
      laminateType: isExterior ? "Exteria" : "Laminates",
    );

    if (response != null && response is Map) {
      if (response['data'] != null) {
        final data = response['data'];
        if (data is List) {
          return data;
        } else if (data is Map) {
          return [data];
        }
      } else if (response['laminates'] != null) {
        return response['laminates'] as List<dynamic>;
      }
    }
    return [];
  }
}
