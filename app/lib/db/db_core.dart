import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Core database initialization and management
class DbCore {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    return await _initDatabase();
  }

  static Future<Database> _initDatabase() async {
    // Avoid multiple concurrent initializations
    if (_database != null) return _database!;

    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, "app.db");

      print("🗄️ [DbCore] DB PATH: $path");

      // Check whether the database already physically exists
      var exists = await databaseExists(path);

      if (!exists) {
        print("📦 [DbCore] Copying fresh database from assets...");

        try {
          // Ensure directory exists - crucial for Android
          await Directory(dirname(path)).create(recursive: true);
        } catch (e) {
          print("⚠️ [DbCore] Error creating directory: $e");
        }

        // Copy from asset
        try {
          ByteData data = await rootBundle.load("assets/db/app.db");
          List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

          await File(path).writeAsBytes(bytes, flush: true);
          print("✨ [DbCore] Database copied successfully");
        } catch (e) {
          print("❌ [DbCore] Error copying database from assets: $e");
          // Re-throw to prevent opening a non-existent/empty database
          rethrow;
        }
      } else {
        print("📖 [DbCore] Opening existing local database...");
      }

      _database = await openDatabase(
        path,
        version: 1,
        onOpen: (db) {
          print("🔓 [DbCore] Database connection opened");
        },
      );

      return _database!;
    } catch (e) {
      print("🚨 [DbCore] CRITICAL ERROR initializing database: $e");
      rethrow;
    }
  }

  static Future<void> ensureTablesExist(Map<String, String> tableCreationScripts) async {
    if (_database == null) {
      await database;
    }

    for (final entry in tableCreationScripts.entries) {
      final tableName = entry.key;
      final createScript = entry.value;

      try {
        await _database!.execute(createScript);
        print("✅ Ensured table '$tableName' exists");
      } catch (e) {
        print("❌ Error creating table '$tableName': $e");
      }
    }
  }

  static Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print("🔒 Database closed");
    }
  }
}
