import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/genre_codec.dart';
import '../../domain/models/pauloflix_movie.dart';
import '../../domain/repositories/pauloflix_movies_repository.dart';

/// Implementação Drift do `PauloFlixMoviesRepository` (filmes do file server).
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
    final escaped = _escapeLike(query);
    final pattern = '%$escaped%';
    final rows = await _db.customSelect(
      'SELECT * FROM paulo_flix_movies '
      "WHERE display_name LIKE ?1 ESCAPE '\\' "
      'AND is_available = 1 '
      'ORDER BY display_name',
      variables: [Variable.withString(pattern)],
      readsFrom: {_db.pauloFlixMovies},
    ).get();
    return rows.map((r) => _toDomain(_db.pauloFlixMovies.map(r.data))).toList();
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
    // **UPSERT real (Drift `DoUpdate`)** sobre `folderName` (UNIQUE).
    // Ver `PauloFlixRepositoryImpl.saveContent` para o rationale
    // completo — `InsertMode.insertOrReplace` faz DELETE+INSERT, troca
    // o `id` e quebra as FKs em cascade. Aqui não há `paulo_flix_movies`
    // com FKs cascade saindo no momento, mas a mesma semântica é
    // correta (evita re-sincronizações "perderem" o id do filme).
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
            releaseDate: Value(content.releaseDate),
            runtime: Value(content.runtime),
            year: Value(content.year),
            tmdbId: Value(content.tmdbId),
            isCollection: Value(content.isCollection),
            availableMovieCount: Value(content.availableMovieCount),
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
              releaseDate: Value(content.releaseDate),
              runtime: Value(content.runtime),
              year: Value(content.year),
              tmdbId: Value(content.tmdbId),
              isCollection: Value(content.isCollection),
              availableMovieCount: Value(content.availableMovieCount),
              lastSynced: Value(content.lastSynced),
              isAvailable: Value(content.isAvailable),
            ),
            target: [_db.pauloFlixMovies.folderName],
          ),
        );
  }

  @override
  Future<void> saveBatch(List<PauloFlixMovie> contents) async {
    // Ver `PauloFlixRepositoryImpl.saveBatch` para o rationale.
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
            releaseDate: Value(content.releaseDate),
            runtime: Value(content.runtime),
            year: Value(content.year),
            tmdbId: Value(content.tmdbId),
            isCollection: Value(content.isCollection),
            availableMovieCount: Value(content.availableMovieCount),
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
              releaseDate: Value(content.releaseDate),
              runtime: Value(content.runtime),
              year: Value(content.year),
              tmdbId: Value(content.tmdbId),
              isCollection: Value(content.isCollection),
              availableMovieCount: Value(content.availableMovieCount),
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
    await (_db.update(_db.pauloFlixMovies)
          ..where((t) => t.folderName.equals(folderName)))
        .write(const PauloFlixMoviesCompanion(isAvailable: Value(false)));
  }

  @override
  Future<Map<String, int>> getStats() async {
    final countExp = _db.pauloFlixMovies.id.count();
    final totalRow = await (_db.selectOnly(_db.pauloFlixMovies)
          ..addColumns([countExp]))
        .getSingle();
    final availRow = await (_db.selectOnly(_db.pauloFlixMovies)
          ..addColumns([countExp])
          ..where(_db.pauloFlixMovies.isAvailable.equals(true)))
        .getSingle();
    final metadataRow = await (_db.selectOnly(_db.pauloFlixMovies)
          ..addColumns([countExp])
          ..where(_db.pauloFlixMovies.isAvailable.equals(true) &
              _db.pauloFlixMovies.imageUrl.isNotNull()))
        .getSingle();
    final collRow = await (_db.selectOnly(_db.pauloFlixMovies)
          ..addColumns([countExp])
          ..where(_db.pauloFlixMovies.isAvailable.equals(true) &
              _db.pauloFlixMovies.isCollection.equals(true)))
        .getSingle();
    return {
      'total': totalRow.read(countExp) ?? 0,
      'available': availRow.read(countExp) ?? 0,
      'withMetadata': metadataRow.read(countExp) ?? 0,
      'collections': collRow.read(countExp) ?? 0,
    };
  }

  @override
  Stream<List<PauloFlixMovie>> watch() {
    return (_db.select(_db.pauloFlixMovies)
          ..where((t) => t.isAvailable.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.displayName)]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  // ---- helpers -----------------------------------------------------------

  String _escapeLike(String q) => q
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

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
      releaseDate: row.releaseDate,
      runtime: row.runtime,
      year: row.year,
      tmdbId: row.tmdbId,
      isCollection: row.isCollection,
      availableMovieCount: row.availableMovieCount,
      lastSynced: row.lastSynced,
      isAvailable: row.isAvailable,
    );
  }
}
