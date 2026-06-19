import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import '../services/pauloflix_database_service.dart';

class DatabaseHelper {
  static Database? _database;
  static Completer<Database>? _initCompleter;
  static const String dbName = 'anime.db';
  static const String animeTable = 'anime';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<Database>();
    try {
      _database = await _initDatabase();
      _initCompleter!.complete(_database!);
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      _database = null;
      rethrow;
    }
    return _database!;
  }

  /// Resolve database path, migrating from the legacy sqflite location if
  /// necessary. sqflite's getDatabasesPath() returned <data>/databases/ on
  /// Android while getApplicationDocumentsDirectory() returns
  /// <data>/app_flutter/. We check the legacy path first so existing data
  /// is preserved.
  static Future<String> _resolveDatabasePath() async {
    final docsDir = await getApplicationDocumentsDirectory();

    if (Platform.isAndroid) {
      final legacyDir = Directory(
        p.join(docsDir.parent.path, 'databases'),
      );
      final legacyPath = p.join(legacyDir.path, dbName);
      if (File(legacyPath).existsSync()) {
        return legacyPath;
      }
      // No legacy DB — use the new location
      if (!legacyDir.existsSync()) {
        legacyDir.createSync(recursive: true);
      }
      return legacyPath;
    }

    return p.join(docsDir.path, dbName);
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await _resolveDatabasePath();
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
      db.execute('BEGIN TRANSACTION');
      for (final name in animeNames) {
        stmt.execute([name]);
      }
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    } finally {
      stmt.close();
    }
  }

  static Future<List<String>> getAnimeNames() async {
    final db = await database;
    final result = db.select('SELECT name FROM $animeTable');
    return result.map((row) => row['name'] as String).toList();
  }

  /// Inicializa todos os bancos de dados necessários
  static Future<void> initializeAll() async {
    // Banco principal (anime names)
    await database;

    // Banco PauloFlix
    final pauloflixDb = PauloFlixDatabaseService();
    await pauloflixDb.database;
  }
}
