import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/pauloflix_content.dart';

class PauloFlixDatabaseService {
  static Database? _database;
  static const String _dbFileName = 'pauloflix.db';
  static const String _tableName = 'pauloflix_content';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<String> _resolveDatabasePath() async {
    final docsDir = await getApplicationDocumentsDirectory();

    if (Platform.isAndroid) {
      final legacyDir = Directory(
        p.join(docsDir.parent.path, 'databases'),
      );
      final legacyPath = p.join(legacyDir.path, _dbFileName);
      if (await File(legacyPath).exists()) {
        return legacyPath;
      }
      if (!await legacyDir.exists()) {
        await legacyDir.create(recursive: true);
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
        status TEXT,
        episodeCount INTEGER,
        malId INTEGER,
        anilistId INTEGER,
        lastSynced TEXT NOT NULL,
        isAvailable INTEGER NOT NULL DEFAULT 1
      )
    ''');

    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_folderName ON $_tableName(folderName)
    ''');

    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_isAvailable ON $_tableName(isAvailable)
    ''');
  }

  Future<void> saveContent(PauloFlixContent content) async {
    final db = await database;
    final map = content.toMap();

    db.execute('''
      INSERT OR REPLACE INTO $_tableName
      (folderName, displayName, serverUrl, imageUrl, bannerUrl, description,
       score, genres, status, episodeCount, malId, anilistId, lastSynced, isAvailable)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      map['folderName'],
      map['displayName'],
      map['serverUrl'],
      map['imageUrl'],
      map['bannerUrl'],
      map['description'],
      map['score'],
      map['genres'],
      map['status'],
      map['episodeCount'],
      map['malId'],
      map['anilistId'],
      map['lastSynced'],
      map['isAvailable'],
    ]);
  }

  Future<void> saveBatch(List<PauloFlixContent> contents) async {
    final db = await database;
    db.execute('BEGIN TRANSACTION');
    try {
      for (final content in contents) {
        final map = content.toMap();
        db.execute('''
          INSERT OR REPLACE INTO $_tableName
          (folderName, displayName, serverUrl, imageUrl, bannerUrl, description,
           score, genres, status, episodeCount, malId, anilistId, lastSynced, isAvailable)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          map['folderName'],
          map['displayName'],
          map['serverUrl'],
          map['imageUrl'],
          map['bannerUrl'],
          map['description'],
          map['score'],
          map['genres'],
          map['status'],
          map['episodeCount'],
          map['malId'],
          map['anilistId'],
          map['lastSynced'],
          map['isAvailable'],
        ]);
      }
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<List<PauloFlixContent>> getAllContent() async {
    final db = await database;
    final result = db.select(
      'SELECT * FROM $_tableName WHERE isAvailable = 1 ORDER BY displayName',
    );
    return result.map((row) => PauloFlixContent.fromMap(row)).toList();
  }

  Future<List<PauloFlixContent>> searchByName(String query) async {
    final db = await database;
    final result = db.select(
      'SELECT * FROM $_tableName WHERE displayName LIKE ? AND isAvailable = 1 ORDER BY displayName',
      ['%$query%'],
    );
    return result.map((row) => PauloFlixContent.fromMap(row)).toList();
  }

  Future<PauloFlixContent?> getByFolderName(String folderName) async {
    final db = await database;
    final result = db.select(
      'SELECT * FROM $_tableName WHERE folderName = ?',
      [folderName],
    );
    if (result.isEmpty) return null;
    return PauloFlixContent.fromMap(result.first);
  }

  Future<PauloFlixContent?> getByMalId(int malId) async {
    final db = await database;
    final result = db.select(
      'SELECT * FROM $_tableName WHERE malId = ?',
      [malId],
    );
    if (result.isEmpty) return null;
    return PauloFlixContent.fromMap(result.first);
  }

  Future<void> markAsUnavailable(String folderName) async {
    final db = await database;
    db.execute(
      'UPDATE $_tableName SET isAvailable = 0 WHERE folderName = ?',
      [folderName],
    );
  }

  Future<void> removeStaleContent({int maxDays = 30}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: maxDays)).toIso8601String();
    db.execute(
      'DELETE FROM $_tableName WHERE lastSynced < ? AND isAvailable = 0',
      [cutoff],
    );
  }

  Future<Map<String, int>> getStats() async {
    final db = await database;
    final total = db.select('SELECT COUNT(*) as count FROM $_tableName').first['count'] as int;
    final available = db.select(
      'SELECT COUNT(*) as count FROM $_tableName WHERE isAvailable = 1',
    ).first['count'] as int;
    final withMetadata = db.select(
      'SELECT COUNT(*) as count FROM $_tableName WHERE imageUrl IS NOT NULL AND isAvailable = 1',
    ).first['count'] as int;

    return {
      'total': total,
      'available': available,
      'withMetadata': withMetadata,
    };
  }
}
