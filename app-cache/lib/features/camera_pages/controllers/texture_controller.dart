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

  Future<List<dynamic>> fetchTexturesByCategory({
    required String category,
    required String? subcategory,
  }) async {
    String subCat = (subcategory == "All" || subcategory == null) ? "" : subcategory;

    // Try cache first
    final cached = cacheService.getCategoryTextures(
      category,
      subCat,
      itemType: isExterior ? "Exteria" : "Laminates",
    );
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final response = await laminateApi.fetchByCategory(
      category: category,
      subcategory: subCat,
      itemType: isExterior ? "Exteria" : "Laminates",
    );

    if (response != null && response is Map && response['laminates'] != null) {
      final textures = response['laminates'] as List<dynamic>;
      cacheService.saveCategoryTextures(
        category,
        subCat,
        textures,
        itemType: isExterior ? "Exteria" : "Laminates",
      );
      return textures;
    }
    return [];
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
      if (response.containsKey('laminates') && response['laminates'] != null) {
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
