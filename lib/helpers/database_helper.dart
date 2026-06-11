import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static Database? _database;
  static const String dbName = 'anime.db';
  static const String animeTable = 'anime';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final path = p.join(await getDatabasesPath(), dbName);
    return await openDatabase(path, version: 1, onCreate: _createDb);
  }

  static Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $animeTable(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    ''');
  }

  static Future<void> addAnimeNames(List<String> animeNames) async {
    final db = await database;
    for (String name in animeNames) {
      await db.insert(animeTable, {'name': name});
    }
  }

  static Future<List<String>> getAnimeNames() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(animeTable);
    return List.generate(maps.length, (i) => maps[i]['name']);
  }
}
