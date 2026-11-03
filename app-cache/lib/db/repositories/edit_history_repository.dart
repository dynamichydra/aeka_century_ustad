import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:century_ai/db/db_core.dart';
import 'package:century_ai/db/models/edit_history_data.dart';

/// Repository for managing image edit history in SQLite
class EditHistoryRepository {
  static const String tableName = 'edit_history';

  static const String _createTableScript = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      id TEXT PRIMARY KEY,
      furniture_id TEXT NOT NULL,
      session_id TEXT NOT NULL,
      original_image_path TEXT NOT NULL,
      edited_image_path TEXT NOT NULL,
      edited_at TEXT NOT NULL,
      owner_id TEXT NOT NULL,
      used_laminates TEXT,
      laminate_name TEXT,
      laminate_sku TEXT,
      parent_edit_id TEXT,
      system_area REAL,
      user_area REAL
    )
  ''';

  /// App documents folder, cached at startup for [_resolvePath].
  static String? _docsPath;

  /// Initialize the edit_history table
  static Future<void> initializeTable() async {
    _docsPath = (await getApplicationDocumentsDirectory()).path;
    await DbCore.ensureTablesExist({tableName: _createTableScript});
  }

  /// Rows store absolute paths, but the iOS app folder (`…/Application/<id>/`)
  /// changes on reinstall and on every `flutter run`, which broke older
  /// edits' images. Re-point anything under Documents/ to the current folder.
  static String _resolvePath(String path) {
    if (path.isEmpty || path.startsWith('http') || _docsPath == null) {
      return path;
    }
    if (File(path).existsSync()) return path;
    const marker = '/Documents/';
    final i = path.indexOf(marker);
    if (i < 0) return path;
    final moved = p.join(_docsPath!, path.substring(i + marker.length));
    return File(moved).existsSync() ? moved : path;
  }

  static EditHistoryData _fromRow(Map<String, Object?> row) {
    final map = Map<String, dynamic>.from(row);
    for (final key in const ['edited_image_path', 'original_image_path']) {
      final value = map[key];
      if (value is String) map[key] = _resolvePath(value);
    }
    return EditHistoryData.fromMap(map);
  }

  /// Save an edit record to the database
  static Future<void> saveEdit(EditHistoryData editData) async {
    final db = await DbCore.database;

    debugPrint('Saving edit record for furniture ID: ${editData.furnitureId}, parentEditId: ${editData.parentEditId}');

    await db.insert(
      tableName,
      editData.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint('Edit record saved successfully');
  }

  /// Retrieve all edits for a specific furniture ID
  static Future<List<EditHistoryData>> getEditsByFurnitureId(String furnitureId) async {
    final db = await DbCore.database;

    final result = await db.query(
      tableName,
      where: 'furniture_id = ?',
      whereArgs: [furnitureId],
      orderBy: 'edited_at DESC',
    );

    debugPrint('Retrieved ${result.length} edits for furniture ID: $furnitureId');

    return result.map(_fromRow).toList();
  }

  /// Retrieve a specific edit record by its primary ID
  static Future<EditHistoryData?> getEditById(String id) async {
    final db = await DbCore.database;

    final result = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) return null;
    return _fromRow(result.first);
  }

  /// Walk the parent chain starting from [editId] and return ALL laminates
  /// from this edit and every ancestor, deduplicated by laminate 'id'.
  ///
  /// Example chain:  C (parent=B) → B (parent=A) → A (parent=null)
  /// Returns: C's laminates + B's laminates + A's laminates  (deduped)
  static Future<List<Map<String, dynamic>>> getCumulativeLaminates(
    String editId,
  ) async {
    final List<Map<String, dynamic>> allLaminates = [];
    final Set<dynamic> seenIds = {};
    String? currentId = editId;

    while (currentId != null) {
      final record = await getEditById(currentId);
      if (record == null) break;

      // Parse and merge this record's laminates
      if (record.usedLaminates != null && record.usedLaminates!.isNotEmpty) {
        try {
          final decoded = jsonDecode(record.usedLaminates!);
          if (decoded is List) {
            for (final lam in decoded) {
              if (lam is Map<String, dynamic>) {
                final lamId = lam['id'];
                if (!seenIds.contains(lamId)) {
                  seenIds.add(lamId);
                  allLaminates.add(lam);
                }
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing laminates for edit $currentId: $e');
        }
      }

      // Walk up to parent
      currentId = record.parentEditId;
    }

    debugPrint(
      '🔗 getCumulativeLaminates("$editId") → ${allLaminates.length} total laminates',
    );
    return allLaminates;
  }

  /// Retrieve all edits for a specific session ID
  static Future<List<EditHistoryData>> getEditsBySessionId(String sessionId) async {
    final db = await DbCore.database;

    final result = await db.query(
      tableName,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'edited_at DESC',
    );

    debugPrint('Retrieved ${result.length} edits for session ID: $sessionId');

    return result.map(_fromRow).toList();
  }

  /// Retrieve all edits for a specific owner
  static Future<List<EditHistoryData>> getEditsByOwner(String ownerId) async {
    final db = await DbCore.database;

    final result = await db.query(
      tableName,
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'edited_at DESC',
    );

    debugPrint('Retrieved ${result.length} edits for owner: $ownerId');

    return result.map(_fromRow).toList();
  }

  /// Delete an edit record by ID
  static Future<void> deleteEdit(String id) async {
    final db = await DbCore.database;

    debugPrint('Deleting edit record with ID: $id');

    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);

    debugPrint('Edit record deleted successfully');
  }

  /// Update the session ID for a specific edited image path
  static Future<void> updateSessionIdByImagePath(
    String imagePath,
    String responseId,
  ) async {
    final db = await DbCore.database;
    await db.update(
      tableName,
      {'session_id': responseId},
      where: 'edited_image_path = ?',
      whereArgs: [imagePath],
    );
    debugPrint('Updated session ID to $responseId for image: $imagePath');
  }

  /// Clear all edit history
  static Future<void> clearAllHistory() async {
    final db = await DbCore.database;

    debugPrint('Clearing all edit history...');

    await db.delete(tableName);

    debugPrint('All edit history cleared');
  }
}
