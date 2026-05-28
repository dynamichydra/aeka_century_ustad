import 'package:sqflite/sqflite.dart';
import 'package:century_ai/db/db_core.dart';
import 'package:century_ai/db/models/selected_image_data.dart';

/// Repository for managing selected images in SQLite
/// Used by: Home pages and Image Preview pages
class SelectedImagesRepository {
  static const String tableName = 'selected_images';

  static const String _createTableScript =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      product_id TEXT PRIMARY KEY,
      image_data BLOB NOT NULL,
      image_path TEXT NOT NULL,
      category TEXT,
      subcategory TEXT,
      selected_at TEXT NOT NULL,
      application_type TEXT
    )
  ''';

  /// Initialize the selected_images table
  static Future<void> initializeTable() async {
    await DbCore.ensureTablesExist({tableName: _createTableScript});
    try {
      final db = await DbCore.database;
      await db.execute('ALTER TABLE $tableName ADD COLUMN application_type TEXT');
      print('Added column application_type to $tableName');
    } catch (_) {
      // Column already exists or table didn't need alter
    }
  }

  /// Save selected image to database once.
  /// The product_id is unique, so we skip saving duplicates.
  static Future<void> saveImage(SelectedImageData imageData) async {
    final db = await DbCore.database;
    final alreadyExists = await imageExists(imageData.id);
    if (alreadyExists) {
      print('Skipping duplicate image with ID: ${imageData.id}');
      return;
    }

    print('Saving selected image with ID: ${imageData.id}');

    await db.insert(
      tableName,
      imageData.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    print('Image saved successfully');
  }

  /// Retrieve selected image by ID
  static Future<SelectedImageData?> getImage(String productId) async {
    final db = await DbCore.database;

    final result = await db.query(
      tableName,
      where: 'product_id = ?',
      whereArgs: [productId],
    );

    if (result.isNotEmpty) {
      print('Retrieved image with ID: $productId from database');
      return SelectedImageData.fromMap(result.first);
    }

    print('No image found with ID: $productId');
    return null;
  }

  /// Delete selected image by ID
  static Future<void> deleteImage(String productId) async {
    final db = await DbCore.database;

    print('Deleting image with ID: $productId');

    await db.delete(tableName, where: 'product_id = ?', whereArgs: [productId]);

    print('Image deleted successfully');
  }

  /// Get all selected images
  static Future<List<SelectedImageData>> getAllImages() async {
    final db = await DbCore.database;

    final result = await db.query(tableName, orderBy: 'selected_at DESC');

    print('Retrieved ${result.length} images from database');

    return result.map((map) => SelectedImageData.fromMap(map)).toList();
  }

  /// Clear all selected images
  static Future<void> clearAllImages() async {
    final db = await DbCore.database;

    print('Clearing all selected images...');

    await db.delete(tableName);

    print('All images cleared');
  }

  /// Get image count
  static Future<int> getImageCount() async {
    final db = await DbCore.database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName',
    );

    final count = Sqflite.firstIntValue(result) ?? 0;

    print('Total images in database: $count');

    return count;
  }

  /// Check if image exists
  static Future<bool> imageExists(String productId) async {
    final db = await DbCore.database;

    final result = await db.query(
      tableName,
      where: 'product_id = ?',
      whereArgs: [productId],
    );

    return result.isNotEmpty;
  }
}
