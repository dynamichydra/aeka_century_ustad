import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Core database initialization and management
class DbCore {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "app.db");

    print("🗄️ DB PATH: $path");

    // Check whether the database already physically exists
    var exists = await databaseExists(path);

    if (!exists) {
      print("📦 Copying fresh database from assets...");

      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copy from asset
      ByteData data = await rootBundle.load("assets/db/app.db");
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      await File(path).writeAsBytes(bytes, flush: true);
    } else {
      print("📖 Opening existing local database...");
    }

    _database = await openDatabase(
      path,
      version: 1,
    );

    return _database!;
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
