import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '../../domain/models/watchlist_anime.dart';

class WatchlistService {
  static sql.Database? _database;
  static const String tableName = 'watchlist';
  static const String _dbFileName = 'watchlist.db';

  Future<sql.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Resolve database path preserving the legacy sqflite location on Android.
  /// sqflite's getDatabasesPath() returned <data>/databases/ while
  /// getApplicationDocumentsDirectory() returns <data>/app_flutter/.
  Future<String> _resolveDatabasePath() async {
    final docsDir = await getApplicationDocumentsDirectory();

    if (Platform.isAndroid) {
      final legacyDir = Directory(join(docsDir.parent.path, 'databases'));
      final legacyPath = join(legacyDir.path, _dbFileName);
      if (File(legacyPath).existsSync()) {
        return legacyPath;
      }
      if (!Directory(legacyPath).existsSync()) {
        Directory(legacyPath).createSync(recursive: true);
      }
      return legacyPath;
    }

    return join(docsDir.path, _dbFileName);
  }

  Future<sql.Database> _initDatabase() async {
    final dbPath = await _resolveDatabasePath();

    final db = sql.sqlite3.open(dbPath);
    db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        animeId TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        coverImage TEXT NOT NULL,
        myAnimeListUrl TEXT NOT NULL,
        addedAt TEXT NOT NULL
      )
    ''');
    return db;
  }

  // Adicionar anime à watchlist
  Future<bool> addToWatchlist(WatchlistAnime anime) async {
    try {
      final db = await database;
      final map = anime.toMap();
      db.execute(
        '''INSERT OR REPLACE INTO $tableName
           (animeId, title, coverImage, myAnimeListUrl, addedAt)
           VALUES (?, ?, ?, ?, ?)''',
        [
          map['animeId'],
          map['title'],
          map['coverImage'],
          map['myAnimeListUrl'],
          map['addedAt'],
        ],
      );
      return true;
    } catch (e) {
      debugPrint('Error adding to watchlist: $e');
      return false;
    }
  }

  // Remover anime da watchlist
  Future<bool> removeFromWatchlist(String animeId) async {
    try {
      final db = await database;
      db.execute('DELETE FROM $tableName WHERE animeId = ?', [animeId]);
      return true;
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
      return false;
    }
  }

  // Verificar se anime está na watchlist
  Future<bool> isInWatchlist(String animeId) async {
    try {
      final db = await database;
      final result = db.select(
        'SELECT 1 FROM $tableName WHERE animeId = ? LIMIT 1',
        [animeId],
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking watchlist: $e');
      return false;
    }
  }

  // Obter todos os animes da watchlist
  Future<List<WatchlistAnime>> getWatchlist() async {
    try {
      final db = await database;
      final result = db.select(
        'SELECT * FROM $tableName ORDER BY addedAt DESC',
      );
      return result
          .map((row) => WatchlistAnime.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugPrint('Error getting watchlist: $e');
      return [];
    }
  }

  // Limpar toda a watchlist
  Future<bool> clearWatchlist() async {
    try {
      final db = await database;
      db.execute('DELETE FROM $tableName');
      return true;
    } catch (e) {
      debugPrint('Error clearing watchlist: $e');
      return false;
    }
  }

  // Obter contagem de itens na watchlist
  Future<int> getWatchlistCount() async {
    try {
      final db = await database;
      final result = db.select('SELECT COUNT(*) as cnt FROM $tableName');
      return result.first['cnt'] as int;
    } catch (e) {
      debugPrint('Error getting watchlist count: $e');
      return 0;
    }
  }
}
