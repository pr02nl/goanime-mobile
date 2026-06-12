import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

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
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, dbName);
    final db = sqlite3.open(dbPath);
    _createDb(db);
    return db;
  }

  static void _createDb(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS $animeTable(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    ''');
  }

  static Future<void> addAnimeNames(List<String> animeNames) async {
    final db = await database;
    final stmt = db.prepare('INSERT INTO $animeTable (name) VALUES (?)');
    try {
      for (final name in animeNames) {
        stmt.execute([name]);
      }
    } finally {
      stmt.close();
    }
  }

  static Future<List<String>> getAnimeNames() async {
    final db = await database;
    final result = db.select('SELECT name FROM $animeTable');
    return result.map((row) => row['name'] as String).toList();
  }
}
