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
      laminate_sku TEXT
    )
  ''';

  /// Initialize the edit_history table
  static Future<void> initializeTable() async {
    await DbCore.ensureTablesExist({tableName: _createTableScript});
  }

  /// Save an edit record to the database
  static Future<void> saveEdit(EditHistoryData editData) async {
    final db = await DbCore.database;
    
    print('Saving edit record for furniture ID: ${editData.furnitureId}');

    await db.insert(
      tableName,
      editData.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    print('Edit record saved successfully');
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

    print('Retrieved ${result.length} edits for furniture ID: $furnitureId');

    return result.map((map) => EditHistoryData.fromMap(map)).toList();
  }

  /// Retrieve a specific edit record by its primary ID (which is the server-returned response ID)
  static Future<EditHistoryData?> getEditById(String id) async {
    final db = await DbCore.database;

    final result = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) return null;
    return EditHistoryData.fromMap(result.first);
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

    print('Retrieved ${result.length} edits for session ID: $sessionId');

    return result.map((map) => EditHistoryData.fromMap(map)).toList();
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

    print('Retrieved ${result.length} edits for owner: $ownerId');

    return result.map((map) => EditHistoryData.fromMap(map)).toList();
  }

  /// Delete an edit record by ID
  static Future<void> deleteEdit(String id) async {
    final db = await DbCore.database;

    print('Deleting edit record with ID: $id');

    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);

    print('Edit record deleted successfully');
  }

  /// Update the session ID for a specific edited image path
  static Future<void> updateSessionIdByImagePath(String imagePath, String responseId) async {
    final db = await DbCore.database;
    await db.update(
      tableName,
      {'session_id': responseId},
      where: 'edited_image_path = ?',
      whereArgs: [imagePath],
    );
    print('Updated session ID to $responseId for image: $imagePath');
  }

  /// Clear all edit history
  static Future<void> clearAllHistory() async {
    final db = await DbCore.database;

    print('Clearing all edit history...');

    await db.delete(tableName);

    print('All edit history cleared');
  }
}
