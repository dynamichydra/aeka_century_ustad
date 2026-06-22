import 'dart:collection';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// LRU-evicting shared cache for decoded [ui.Image] GPU textures.
///
/// SINGLETON — accessed via [OverlayImageCacheService.instance].
/// Injectable via constructor for testing.
///
/// ARCHITECTURE ROLE:
///   Single source of truth for all ui.Image decode/cache/dispose operations.
///   Eliminates duplicate decoding between [OverlayRendererWidget] and
///   [OverlayExportService] — each layer is decoded EXACTLY ONCE.
///
/// LRU EVICTION RULES:
///   - Maximum [maxCacheSize] decoded images in cache (default: 20).
///   - On access: entry is promoted to most-recently-used.
///   - On insert overflow: least-recently-used entry is disposed + removed.
///   - [clearUnused]: immediately disposes all entries not in [activeKeys].
///   - [clearAll]: disposes and removes every cached image.
///   - Every disposal calls [ui.Image.dispose] to release GPU texture memory.
///
/// CONCURRENCY SAFETY:
///   In-progress decodes are tracked in [_pending] to prevent duplicate
///   concurrent codec allocations for the same key.
class OverlayImageCacheService {
  /// Global singleton instance. Use this unless injecting for tests.
  static final OverlayImageCacheService instance = OverlayImageCacheService._(20);

  /// Maximum number of decoded [ui.Image] entries allowed in cache.
  final int maxCacheSize;

  OverlayImageCacheService._(this.maxCacheSize);

  /// Injectable constructor for unit testing (smaller LRU cap).
  factory OverlayImageCacheService.forTesting() {
    return OverlayImageCacheService._(5);
  }

  /// LRU cache: insertion order maintained, promoted on access.
  /// LinkedHashMap key order = LRU order (first = oldest = LRU).
  final LinkedHashMap<String, ui.Image> _cache =
      LinkedHashMap<String, ui.Image>();

  /// In-progress decode futures — prevents duplicate concurrent decodes
  /// for the same key when multiple callers request the same image.
  final Map<String, Future<ui.Image>> _pending = {};

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Returns the decoded [ui.Image] for [key], decoding from [bytes] if needed.
  ///
  /// - On cache hit: promotes entry to MRU and returns immediately.
  /// - On decode-in-progress: awaits the pending future (no duplicate decode).
  /// - On cache miss: decodes [bytes], caches, and returns the result.
  Future<ui.Image> getDecodedImage(String key, Uint8List bytes) async {
    // 1. Cache hit — promote to MRU (remove then re-insert at end).
    if (_cache.containsKey(key)) {
      final img = _cache.remove(key)!;
      _cache[key] = img;
      return img;
    }

    // 2. Already decoding — share the in-progress future.
    if (_pending.containsKey(key)) {
      return _pending[key]!;
    }

    // 3. Cache miss — decode and cache.
    final future = _decodePng(bytes).then((img) {
      _pending.remove(key);
      _evictIfNeeded();
      _cache[key] = img;
      debugPrint(
        '🖼️  OverlayImageCache: decoded "$key" '
        '(${img.width}×${img.height}) | cache=$cacheSize/$maxCacheSize',
      );
      return img;
    }).catchError((Object e) {
      _pending.remove(key);
      debugPrint('❌ OverlayImageCache: decode failed for "$key" — $e');
      throw e;
    });

    _pending[key] = future;
    return future;
  }

  /// Immediately disposes and removes the entry for [key].
  ///
  /// Call this when a specific layer is deleted from the editor.
  void disposeImage(String key) {
    final img = _cache.remove(key);
    if (img != null) {
      img.dispose();
      debugPrint('🗑️  OverlayImageCache: disposed "$key"');
    }
  }

  /// Disposes and removes all cache entries whose keys are NOT in [activeKeys].
  ///
  /// Call this after the overlay stack changes to evict stale layer textures.
  void clearUnused(Set<String> activeKeys) {
    final stale =
        _cache.keys.where((k) => !activeKeys.contains(k)).toList();
    for (final key in stale) {
      disposeImage(key);
    }
    if (stale.isNotEmpty) {
      debugPrint(
        '🧹 OverlayImageCache: cleared ${stale.length} stale entries '
        '| remaining=$cacheSize',
      );
    }
  }

  /// Disposes and removes ALL cached images.
  ///
  /// Call this when the editing session ends or the app is backgrounded.
  void clearAll() {
    final count = _cache.length;
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
    debugPrint('🧹 OverlayImageCache: clearAll() disposed $count textures.');
  }

  /// Current number of decoded images in cache.
  int get cacheSize => _cache.length;

  // ─── Private Helpers ───────────────────────────────────────────────────────

  /// Evicts the least-recently-used entry if cache is at capacity.
  void _evictIfNeeded() {
    while (_cache.length >= maxCacheSize) {
      // First key = oldest (LRU) because LinkedHashMap maintains insertion order.
      final lruKey = _cache.keys.first;
      final img = _cache.remove(lruKey);
      img?.dispose();
      debugPrint(
        '♻️  OverlayImageCache: LRU evicted "$lruKey" '
        '| cache=$cacheSize/$maxCacheSize',
      );
    }
  }

  /// Decodes raw PNG bytes into a [ui.Image] GPU texture.
  Future<ui.Image> _decodePng(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
