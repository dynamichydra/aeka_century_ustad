import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

class LaminateCacheService {
  final _box = GetStorage();
  static const String _keyPrefix = "laminate_cache_";
  static const int _cacheDurationDays = 14;

  String _generateCategoryKey(String category, String subcategory, String itemType) {
    return "${_keyPrefix}cat_${itemType}_${category}_${subcategory}";
  }

  String _generateHexKey(String hex, String itemType) {
    return "${_keyPrefix}hex_${itemType}_${hex.replaceAll('#', '')}";
  }

  void saveCategoryTextures(String category, String subcategory, List<dynamic> textures, {String itemType = "Laminates"}) {
    _save(_generateCategoryKey(category, subcategory, itemType), textures);
  }

  List<dynamic>? getCategoryTextures(String category, String subcategory, {String itemType = "Laminates"}) {
    return _get(_generateCategoryKey(category, subcategory, itemType));
  }

  void saveHexTextures(String hex, List<dynamic> textures, {String itemType = "Laminates"}) {
    _save(_generateHexKey(hex, itemType), textures);
  }

  List<dynamic>? getHexTextures(String hex, {String itemType = "Laminates"}) {
    return _get(_generateHexKey(hex, itemType));
  }

  void _save(String key, List<dynamic> textures) {
    final data = {
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "textures": textures,
    };
    _box.write(key, data);
  }

  List<dynamic>? _get(String key) {
    try {
      final cached = _box.read(key);
      if (cached == null || cached is! Map) return null;

      final timestamp = cached["timestamp"] as int?;
      if (timestamp == null) return null;

      final cachedDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      if (now.difference(cachedDate).inDays > _cacheDurationDays) {
        _box.remove(key);
        return null;
      }

      final textures = cached["textures"];
      if (textures is List) {
        return textures;
      }
      return null;
    } catch (e) {
      debugPrint("❌ Error reading from laminate cache: $e");
      return null;
    }
  }
}
