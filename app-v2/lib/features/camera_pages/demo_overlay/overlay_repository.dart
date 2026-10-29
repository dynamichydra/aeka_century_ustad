import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_layer_model.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_session_model.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_image_cache_service.dart';
import 'package:century_ai/features/camera_pages/demo_overlay/overlay_export_service.dart';

/// Orchestration layer between the Cubit (UI state) and storage/export concerns.
///
/// ARCHITECTURE RESPONSIBILITIES:
///   - Session persistence: save/load editing sessions as JSON.
///   - Export orchestration: delegates to [OverlayExportService].
///   - Cache coordination: keeps [OverlayImageCacheService] in sync with
///     the active overlay stack (evicts stale textures after layer changes).
///
/// CUBIT RULE:
///   The Cubit must ONLY manage UI state + user interactions.
///   Any I/O, cache management, or export logic MUST go through this repository.
///
/// INJECTION:
///   Uses [OverlayImageCacheService.instance] by default (singleton).
///   All services injectable for testing.
class OverlayRepository {
  final OverlayImageCacheService cacheService;
  final OverlayExportService _exportService;

  OverlayRepository({
    OverlayImageCacheService? cacheService,
    OverlayExportService? exportService,
  })  : cacheService = cacheService ?? OverlayImageCacheService.instance,
        _exportService = exportService ?? OverlayExportService();

  // ─── Cache Coordination ───────────────────────────────────────────────────

  /// Syncs the image cache to the current overlay stack.
  ///
  /// Disposes decoded textures for layers that are no longer in [layers].
  /// Call this after any layer add/remove/undo operation.
  void syncCache(List<OverlayLayer> layers) {
    final Set<String> activeIds = layers.map((l) => l.id).toSet();
    cacheService.clearUnused(activeIds);
  }

  /// Disposes ALL cached textures. Call when the editing session ends.
  void clearCache() {
    cacheService.clearAll();
  }

  // ─── Export Orchestration ─────────────────────────────────────────────────

  /// Exports [session] as a native-resolution composited PNG.
  ///
  /// Returns the absolute path of the saved file, or null on failure.
  /// Delegates to [OverlayExportService] which uses [OverlayCompositionEngine].
  Future<String?> exportSession(OverlaySession session) async {
    debugPrint(
      '📤 OverlayRepository: Exporting session "${session.sessionId}" '
      'with ${session.layers.length} layer(s).',
    );
    return await _exportService.exportComposite(
      baseImagePath: session.baseImagePath,
      layers: session.layers,
    );
  }

  // ─── Session Persistence ──────────────────────────────────────────────────

  /// Saves [session] metadata as JSON to the app documents directory.
  ///
  /// NOTE: [warpedOverlayBytes] are NOT persisted (too large).
  /// Only laminate metadata is saved. Bytes must be re-fetched on restore.
  Future<void> saveSession(OverlaySession session) async {
    try {
      final String filePath = await _sessionFilePath(session.sessionId);
      final File file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(session.toJson()), flush: true);
      debugPrint(
        '💾 OverlayRepository: Session "${session.sessionId}" saved to $filePath',
      );
    } catch (e) {
      debugPrint('❌ OverlayRepository: Failed to save session — $e');
    }
  }

  /// Loads a previously saved session by [sessionId].
  ///
  /// Returns null if the session file does not exist or cannot be parsed.
  /// Restored layers will have empty [warpedOverlayBytes] — re-fetch as needed.
  Future<OverlaySession?> loadSession(String sessionId) async {
    try {
      final String filePath = await _sessionFilePath(sessionId);
      final File file = File(filePath);
      if (!await file.exists()) {
        debugPrint(
          '⚠️  OverlayRepository: Session "$sessionId" not found at $filePath',
        );
        return null;
      }
      final Map<String, dynamic> json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final session = OverlaySession.fromJson(json);
      debugPrint(
        '📂 OverlayRepository: Loaded session "$sessionId" '
        'with ${session.layers.length} layer(s).',
      );
      return session;
    } catch (e) {
      debugPrint(
        '❌ OverlayRepository: Failed to load session "$sessionId" — $e',
      );
      return null;
    }
  }

  /// Lists all saved session IDs (file names without extension).
  Future<List<String>> listSessionIds() async {
    try {
      final Directory dir = await _sessionsDirectory();
      if (!await dir.exists()) return [];
      return dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
          .toList();
    } catch (e) {
      debugPrint('❌ OverlayRepository: Failed to list sessions — $e');
      return [];
    }
  }

  /// Deletes the persisted session file for [sessionId].
  Future<void> deleteSession(String sessionId) async {
    try {
      final String filePath = await _sessionFilePath(sessionId);
      final File file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️  OverlayRepository: Deleted session "$sessionId"');
      }
    } catch (e) {
      debugPrint('❌ OverlayRepository: Failed to delete session — $e');
    }
  }

  // ─── Private Helpers ──────────────────────────────────────────────────────

  Future<Directory> _sessionsDirectory() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/overlay_sessions');
  }

  Future<String> _sessionFilePath(String sessionId) async {
    final Directory dir = await _sessionsDirectory();
    return '${dir.path}/$sessionId.json';
  }
}
