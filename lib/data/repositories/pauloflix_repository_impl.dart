import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/database/drift_utils.dart';
import '../../core/utils/genre_codec.dart';
import '../../domain/models/pauloflix_content.dart';
import '../../domain/repositories/pauloflix_repository.dart';

/// Implementação Drift do `PauloFlixRepository` (animes do file server).
///
/// Usa [DriftUtils] para `searchByName`, `markAsUnavailable`, `getStats`.
/// Mantém localmente `getAll`, `getByFolderName`, `watch` (tipados com
/// Drift, preservando reatividade) e `saveContent`/`saveBatch`.
class PauloFlixRepositoryImpl implements PauloFlixRepository {
  final AppDatabase _db;
  PauloFlixRepositoryImpl(this._db);

  @override
  Future<List<PauloFlixContent>> getAll() async {
    final rows = await (_db.select(_db.pauloFlixContent)
          ..where((t) => t.isAvailable.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.displayName)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<PauloFlixContent>> searchByName(String query) async {
    return DriftUtils.searchByName(
      _db,
      'paulo_flix_content',
      query,
      (data) => _toDomain(_db.pauloFlixContent.map(data)),
    );
  }

  @override
  Future<PauloFlixContent?> getByFolderName(String folderName) async {
    final row = await (_db.select(_db.pauloFlixContent)
          ..where((t) => t.folderName.equals(folderName))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> saveContent(PauloFlixContent content) async {
    // **UPSERT real (Drift `DoUpdate`)** sobre `folderName` (UNIQUE).
    // NUNCA usar `InsertMode.insertOrReplace` aqui — no SQLite isso
    // vira `INSERT OR REPLACE` que faz **DELETE + INSERT** (não UPSERT
    // real). Como `paulo_flix_content.id` é `INTEGER PRIMARY KEY` sem a
    // keyword `AUTOINCREMENT` estrita, o id é reusado em delete+insert,
    // e o `ON DELETE CASCADE` da FK em `paulo_flix_seasons.contentId`
    // apaga as seasons + episodes + progresso do user junto.
    // Sintoma: cards abertos em memória antes do re-sync passam a
    // apontar pra id morto → próximo clique causa
    // `FOREIGN KEY constraint failed` no INSERT de season.
    await _db.into(_db.pauloFlixContent).insert(
          PauloFlixContentCompanion.insert(
            folderName: content.folderName,
            displayName: content.displayName,
            serverUrl: content.serverUrl,
            imageUrl: Value(content.imageUrl),
            bannerUrl: Value(content.bannerUrl),
            description: Value(content.description),
            score: Value(content.score),
            genresJson: Value(encodeGenres(content.genres)),
            status: Value(content.status),
            episodeCount: Value(content.episodeCount),
            originalTitle: Value(content.originalTitle),
            year: Value(content.year),
            tmdbId: Value(content.tmdbId),
            lastSynced: content.lastSynced,
            isAvailable: Value(content.isAvailable),
          ),
          onConflict: DoUpdate(
            (old) => PauloFlixContentCompanion(
              displayName: Value(content.displayName),
              serverUrl: Value(content.serverUrl),
              imageUrl: Value(content.imageUrl),
              bannerUrl: Value(content.bannerUrl),
              description: Value(content.description),
              score: Value(content.score),
              genresJson: Value(encodeGenres(content.genres)),
              status: Value(content.status),
              episodeCount: Value(content.episodeCount),
              originalTitle: Value(content.originalTitle),
              year: Value(content.year),
              tmdbId: Value(content.tmdbId),
              lastSynced: Value(content.lastSynced),
              isAvailable: Value(content.isAvailable),
            ),
            target: [_db.pauloFlixContent.folderName],
          ),
        );
  }

  @override
  Future<void> saveBatch(List<PauloFlixContent> contents) async {
    await _db.batch((batch) {
      for (final content in contents) {
        batch.insert(
          _db.pauloFlixContent,
          PauloFlixContentCompanion.insert(
            folderName: content.folderName,
            displayName: content.displayName,
            serverUrl: content.serverUrl,
            imageUrl: Value(content.imageUrl),
            bannerUrl: Value(content.bannerUrl),
            description: Value(content.description),
            score: Value(content.score),
            genresJson: Value(encodeGenres(content.genres)),
            status: Value(content.status),
            episodeCount: Value(content.episodeCount),
            originalTitle: Value(content.originalTitle),
            year: Value(content.year),
            tmdbId: Value(content.tmdbId),
            lastSynced: content.lastSynced,
            isAvailable: Value(content.isAvailable),
          ),
          onConflict: DoUpdate(
            (old) => PauloFlixContentCompanion(
              displayName: Value(content.displayName),
              serverUrl: Value(content.serverUrl),
              imageUrl: Value(content.imageUrl),
              bannerUrl: Value(content.bannerUrl),
              description: Value(content.description),
              score: Value(content.score),
              genresJson: Value(encodeGenres(content.genres)),
              status: Value(content.status),
              episodeCount: Value(content.episodeCount),
              originalTitle: Value(content.originalTitle),
              year: Value(content.year),
              tmdbId: Value(content.tmdbId),
              lastSynced: Value(content.lastSynced),
              isAvailable: Value(content.isAvailable),
            ),
            target: [_db.pauloFlixContent.folderName],
          ),
        );
      }
    });
  }

  @override
  Future<void> markAsUnavailable(String folderName) async {
    await DriftUtils.markAsUnavailable(_db, 'paulo_flix_content', folderName);
  }

  @override
  Future<Map<String, int>> getStats() async {
    return DriftUtils.getStats(_db, 'paulo_flix_content');
  }

  @override
  Stream<List<PauloFlixContent>> watch() {
    return (_db.select(_db.pauloFlixContent)
          ..where((t) => t.isAvailable.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.displayName)]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  // ── helpers ──────────────────────────────────────────────────────

  PauloFlixContent _toDomain(PauloFlixContentData row) {
    return PauloFlixContent(
      id: row.id,
      folderName: row.folderName,
      displayName: row.displayName,
      serverUrl: row.serverUrl,
      imageUrl: row.imageUrl,
      bannerUrl: row.bannerUrl,
      description: row.description,
      score: row.score,
      genres: decodeGenresOrFallback(row.genresJson),
      status: row.status,
      episodeCount: row.episodeCount,
      originalTitle: row.originalTitle,
      year: row.year,
      tmdbId: row.tmdbId,
      lastSynced: row.lastSynced,
      isAvailable: row.isAvailable,
    );
  }
}
