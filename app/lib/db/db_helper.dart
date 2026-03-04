import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DbHelper {

  static Database? _database;

  static Future<Database> get database async {

    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "app.db");

    print("DB PATH: $path");

    _database = await openDatabase(
      path,
      version: 1,
    );

    return _database!;
  }
}