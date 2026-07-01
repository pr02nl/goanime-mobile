import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/database/drift_utils.dart';
import '../../core/utils/genre_codec.dart';
import '../../domain/models/pauloflix_movie.dart';
import '../../domain/models/pauloflix_movie_item.dart';
import '../../domain/repositories/pauloflix_movies_repository.dart';

/// Implementação Drift do `PauloFlixMoviesRepository` (filmes do file server).
///
/// Usa [DriftUtils] para `searchByName`, `markAsUnavailable`, `getStats`.
/// Mantém localmente `getAll`, `getByFolderName`, `watch` (tipados com
/// Drift, preservando reatividade) e `saveContent`/`saveBatch`.
class PauloFlixMoviesRepositoryImpl implements PauloFlixMoviesRepository {
  final AppDatabase _db;
  PauloFlixMoviesRepositoryImpl(this._db);

  @override
  Future<List<PauloFlixMovie>> getAll() async {
    final rows = await (_db.select(_db.pauloFlixMovies)
          ..where((t) => t.isAvailable.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.displayName)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<PauloFlixMovie>> searchByName(String query) async {
    return DriftUtils.searchByName(
      _db,
      'paulo_flix_movies',
      query,
      (data) => _toDomain(_db.pauloFlixMovies.map(data)),
    );
  }

  @override
  Future<PauloFlixMovie?> getByFolderName(String folderName) async {
    final row = await (_db.select(_db.pauloFlixMovies)
          ..where((t) => t.folderName.equals(folderName))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<PauloFlixMovie?> getByTmdbId(int tmdbId) async {
    final row = await (_db.select(_db.pauloFlixMovies)
          ..where((t) => t.tmdbId.equals(tmdbId))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> saveContent(PauloFlixMovie content) async {
    await _db.into(_db.pauloFlixMovies).insert(
          PauloFlixMoviesCompanion.insert(
            folderName: content.folderName,
            displayName: content.displayName,
            serverUrl: content.serverUrl,
            imageUrl: Value(content.imageUrl),
            bannerUrl: Value(content.bannerUrl),
            description: Value(content.description),
            score: Value(content.score),
            genresJson: Value(encodeGenres(content.genres)),
            runtime: Value(content.runtime),
            year: Value(content.year),
            tmdbId: Value(content.tmdbId),
            videoUrl: Value(content.videoUrl),
            subtitlesJson: Value(content.subtitles != null && content.subtitles!.isNotEmpty
                ? jsonEncode(content.subtitles!.map((s) => s.toJson()).toList())
                : null),
            lastSynced: content.lastSynced,
            isAvailable: Value(content.isAvailable),
          ),
          onConflict: DoUpdate(
            (old) => PauloFlixMoviesCompanion(
              displayName: Value(content.displayName),
              serverUrl: Value(content.serverUrl),
              imageUrl: Value(content.imageUrl),
              bannerUrl: Value(content.bannerUrl),
              description: Value(content.description),
              score: Value(content.score),
              genresJson: Value(encodeGenres(content.genres)),
              runtime: Value(content.runtime),
              year: Value(content.year),
              tmdbId: Value(content.tmdbId),
              videoUrl: Value(content.videoUrl),
              subtitlesJson: Value(content.subtitles != null && content.subtitles!.isNotEmpty
                  ? jsonEncode(content.subtitles!.map((s) => s.toJson()).toList())
                  : null),
              lastSynced: Value(content.lastSynced),
              isAvailable: Value(content.isAvailable),
            ),
            target: [_db.pauloFlixMovies.folderName],
          ),
        );
  }

  @override
  Future<void> saveBatch(List<PauloFlixMovie> contents) async {
    await _db.batch((batch) {
      for (final content in contents) {
        batch.insert(
          _db.pauloFlixMovies,
          PauloFlixMoviesCompanion.insert(
            folderName: content.folderName,
            displayName: content.displayName,
            serverUrl: content.serverUrl,
            imageUrl: Value(content.imageUrl),
            bannerUrl: Value(content.bannerUrl),
            description: Value(content.description),
            score: Value(content.score),
            genresJson: Value(encodeGenres(content.genres)),
            runtime: Value(content.runtime),
            year: Value(content.year),
            tmdbId: Value(content.tmdbId),
            videoUrl: Value(content.videoUrl),
            subtitlesJson: Value(content.subtitles != null && content.subtitles!.isNotEmpty
                ? jsonEncode(content.subtitles!.map((s) => s.toJson()).toList())
                : null),
            lastSynced: content.lastSynced,
            isAvailable: Value(content.isAvailable),
          ),
          onConflict: DoUpdate(
            (old) => PauloFlixMoviesCompanion(
              displayName: Value(content.displayName),
              serverUrl: Value(content.serverUrl),
              imageUrl: Value(content.imageUrl),
              bannerUrl: Value(content.bannerUrl),
              description: Value(content.description),
              score: Value(content.score),
              genresJson: Value(encodeGenres(content.genres)),
              runtime: Value(content.runtime),
              year: Value(content.year),
              tmdbId: Value(content.tmdbId),
              videoUrl: Value(content.videoUrl),
              subtitlesJson: Value(content.subtitles != null && content.subtitles!.isNotEmpty
                  ? jsonEncode(content.subtitles!.map((s) => s.toJson()).toList())
                  : null),
              lastSynced: Value(content.lastSynced),
              isAvailable: Value(content.isAvailable),
            ),
            target: [_db.pauloFlixMovies.folderName],
          ),
        );
      }
    });
  }

  @override
  Future<void> markAsUnavailable(String folderName) async {
    await DriftUtils.markAsUnavailable(_db, 'paulo_flix_movies', folderName);
  }

  @override
  Future<Map<String, int>> getStats() async {
    return DriftUtils.getStats(_db, 'paulo_flix_movies');
  }

  @override
  Stream<List<PauloFlixMovie>> watch() {
    return (_db.select(_db.pauloFlixMovies)
          ..where((t) => t.isAvailable.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.displayName)]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  // ── helpers ──────────────────────────────────────────────────────

  PauloFlixMovie _toDomain(PauloFlixMovy row) {
    return PauloFlixMovie(
      id: row.id,
      folderName: row.folderName,
      displayName: row.displayName,
      serverUrl: row.serverUrl,
      imageUrl: row.imageUrl,
      bannerUrl: row.bannerUrl,
      description: row.description,
      score: row.score,
      genres: decodeGenresOrFallback(row.genresJson),
      runtime: row.runtime,
      year: row.year,
      tmdbId: row.tmdbId,
      videoUrl: row.videoUrl,
      subtitles: row.subtitlesJson != null
          ? (jsonDecode(row.subtitlesJson!) as List)
              .map((s) => ExternalSubtitleEntry.fromJson(s as Map<String, dynamic>))
              .toList()
          : null,
      lastSynced: row.lastSynced,
      isAvailable: row.isAvailable,
    );
  }
}
