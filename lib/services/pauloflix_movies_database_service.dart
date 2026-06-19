import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/models/pauloflix_movie.dart';

/// Persistência SQLite para conteúdo PauloFlix Movies (independente do banco de animes).
class PauloFlixMoviesDatabaseService {
  static Database? _database;
  static Completer<Database>? _initCompleter;
  static const String _dbFileName = 'pauloflix_movies.db';
  static const String _tableName = 'pauloflix_movies';

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<Database>();
    try {
      _database = await _initDatabase();
      _initCompleter!.complete(_database!);
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
    return _database!;
  }

  Future<String> _resolveDatabasePath() async {
    final docsDir = await getApplicationDocumentsDirectory();

    if (Platform.isAndroid) {
      final legacyDir = Directory(p.join(docsDir.parent.path, 'databases'));
      final legacyPath = p.join(legacyDir.path, _dbFileName);
      if (File(legacyPath).existsSync()) {
        return legacyPath;
      }
      if (!Directory(legacyPath).existsSync()) {
        Directory(legacyPath).createSync(recursive: true);
      }
      return legacyPath;
    }

    return p.join(docsDir.path, _dbFileName);
  }

  Future<Database> _initDatabase() async {
    final dbPath = await _resolveDatabasePath();
    final db = sqlite3.open(dbPath);
    _createTables(db);
    return db;
  }

  void _createTables(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folderName TEXT NOT NULL UNIQUE,
        displayName TEXT NOT NULL,
        serverUrl TEXT NOT NULL,
        imageUrl TEXT,
        bannerUrl TEXT,
        description TEXT,
        score REAL,
        genres TEXT,
        releaseDate TEXT,
        runtime INTEGER,
        year INTEGER,
        tmdbId INTEGER,
        isCollection INTEGER NOT NULL DEFAULT 0,
        availableMovieCount INTEGER NOT NULL DEFAULT 0,
        lastSynced TEXT NOT NULL,
        isAvailable INTEGER NOT NULL DEFAULT 1
      )
    ''');

    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movies_folderName ON $_tableName(folderName)
    ''');

    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movies_isAvailable ON $_tableName(isAvailable)
    ''');

    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movies_tmdbId ON $_tableName(tmdbId)
    ''');
  }

  Future<void> saveContent(PauloFlixMovie content) async {
    final db = await database;
    final map = content.toMap();

    db.execute(
      '''
      INSERT OR REPLACE INTO $_tableName
      (folderName, displayName, serverUrl, imageUrl, bannerUrl, description,
       score, genres, releaseDate, runtime, year, tmdbId, isCollection,
       availableMovieCount, lastSynced, isAvailable)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
      [
        map['folderName'],
        map['displayName'],
        map['serverUrl'],
        map['imageUrl'],
        map['bannerUrl'],
        map['description'],
        map['score'],
        map['genres'],
        map['releaseDate'],
        map['runtime'],
        map['year'],
        map['tmdbId'],
        map['isCollection'],
        map['availableMovieCount'],
        map['lastSynced'],
        map['isAvailable'],
      ],
    );
  }

  Future<void> saveBatch(List<PauloFlixMovie> contents) async {
    final db = await database;
    db.execute('BEGIN TRANSACTION');
    try {
      for (final content in contents) {
        await saveContent(content);
      }
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<List<PauloFlixMovie>> getAllContent() async {
    final db = await database;
    final result = db.select(
      'SELECT * FROM $_tableName WHERE isAvailable = 1 ORDER BY displayName',
    );
    return result.map((row) => PauloFlixMovie.fromMap(row)).toList();
  }

  Future<List<PauloFlixMovie>> searchByName(String query) async {
    final db = await database;
    final result = db.select(
      'SELECT * FROM $_tableName WHERE displayName LIKE ? AND isAvailable = 1 ORDER BY displayName',
      ['%$query%'],
    );
    return result.map((row) => PauloFlixMovie.fromMap(row)).toList();
  }

  Future<PauloFlixMovie?> getByFolderName(String folderName) async {
    final db = await database;
    final result = db.select('SELECT * FROM $_tableName WHERE folderName = ?', [
      folderName,
    ]);
    if (result.isEmpty) return null;
    return PauloFlixMovie.fromMap(result.first);
  }

  Future<PauloFlixMovie?> getByTmdbId(int tmdbId) async {
    final db = await database;
    final result = db.select('SELECT * FROM $_tableName WHERE tmdbId = ?', [
      tmdbId,
    ]);
    if (result.isEmpty) return null;
    return PauloFlixMovie.fromMap(result.first);
  }

  Future<void> markAsUnavailable(String folderName) async {
    final db = await database;
    db.execute('UPDATE $_tableName SET isAvailable = 0 WHERE folderName = ?', [
      folderName,
    ]);
  }

  Future<void> removeStaleContent({int maxDays = 30}) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: maxDays))
        .toIso8601String();
    db.execute(
      'DELETE FROM $_tableName WHERE lastSynced < ? AND isAvailable = 0',
      [cutoff],
    );
  }

  Future<Map<String, int>> getStats() async {
    final db = await database;
    final total =
        db.select('SELECT COUNT(*) as count FROM $_tableName').first['count']
            as int;
    final available =
        db
                .select(
                  'SELECT COUNT(*) as count FROM $_tableName WHERE isAvailable = 1',
                )
                .first['count']
            as int;
    final withMetadata =
        db
                .select(
                  'SELECT COUNT(*) as count FROM $_tableName WHERE imageUrl IS NOT NULL AND imageUrl != "" AND isAvailable = 1',
                )
                .first['count']
            as int;
    final collections =
        db
                .select(
                  'SELECT COUNT(*) as count FROM $_tableName WHERE isCollection = 1 AND isAvailable = 1',
                )
                .first['count']
            as int;

    return {
      'total': total,
      'available': available,
      'withMetadata': withMetadata,
      'collections': collections,
    };
  }
}
