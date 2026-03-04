import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DbHelper {

  static Database? _database;

  static Future<Database> get database async {

    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "app.db");

    print("DB PATH: $path");

    // Check whether the database already physically exists in the app's local device files
    var exists = await databaseExists(path);

    if (!exists) {
      // This will only happen the very first time you launch the app, or if you wipe app data.
      print("Copying fresh database from assets...");

      // Make sure the parent directory actually exists
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}
      
      // Copy from asset
      ByteData data = await rootBundle.load("assets/db/app.db");
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      
      // Write to local path
      await File(path).writeAsBytes(bytes, flush: true);
    } else {
      print("Opening the existing local database...");
    }

    _database = await openDatabase(
      path,
      version: 1,
    );

    return _database!;
  }
}