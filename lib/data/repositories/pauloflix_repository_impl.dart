import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/genre_codec.dart';
import '../../domain/models/pauloflix_content.dart';
import '../../domain/repositories/pauloflix_repository.dart';

/// Implementação Drift do `PauloFlixRepository` (animes do file server).
///
/// Substitui `PauloFlixDatabaseService` (sqlite3 FFI). Os dois coexistem
/// durante a Fase 3; Fase 4 remove o service legado.
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
    // Drift `like()` não tem parâmetro `escape`, então usamos `customSelect`
    // com SQL puro e `ESCAPE '\'` explícito — o que garante que `%` e `_`
    // no termo de busca sejam tratados como literais.
    final escaped = _escapeLike(query);
    final pattern = '%$escaped%';
    final rows = await _db.customSelect(
      'SELECT * FROM paulo_flix_content '
      "WHERE display_name LIKE ?1 ESCAPE '\\' "
      'AND is_available = 1 '
      'ORDER BY display_name',
      variables: [Variable.withString(pattern)],
      readsFrom: {_db.pauloFlixContent},
    ).get();
    return rows.map((r) => _toDomain(_db.pauloFlixContent.map(r.data))).toList();
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
  Future<PauloFlixContent?> getByMalId(int malId) async {
    final row = await (_db.select(_db.pauloFlixContent)
          ..where((t) => t.malId.equals(malId))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> saveContent(PauloFlixContent content) async {
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
            malId: Value(content.malId),
            anilistId: Value(content.anilistId),
            lastSynced: content.lastSynced,
            isAvailable: Value(content.isAvailable),
          ),
          mode: InsertMode.insertOrReplace,
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
            malId: Value(content.malId),
            anilistId: Value(content.anilistId),
            lastSynced: content.lastSynced,
            isAvailable: Value(content.isAvailable),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  @override
  Future<void> markAsUnavailable(String folderName) async {
    await (_db.update(_db.pauloFlixContent)
          ..where((t) => t.folderName.equals(folderName)))
        .write(const PauloFlixContentCompanion(isAvailable: Value(false)));
  }

  @override
  Future<Map<String, int>> getStats() async {
    final totalExp = _db.pauloFlixContent.id.count();
    final totalRow = await (_db.selectOnly(_db.pauloFlixContent)
          ..addColumns([totalExp]))
        .getSingle();
    final availRow = await (_db.selectOnly(_db.pauloFlixContent)
          ..addColumns([totalExp])
          ..where(_db.pauloFlixContent.isAvailable.equals(true)))
        .getSingle();
    final metadataRow = await (_db.selectOnly(_db.pauloFlixContent)
          ..addColumns([totalExp])
          ..where(_db.pauloFlixContent.isAvailable.equals(true) &
              _db.pauloFlixContent.imageUrl.isNotNull()))
        .getSingle();
    return {
      'total': totalRow.read(totalExp) ?? 0,
      'available': availRow.read(totalExp) ?? 0,
      'withMetadata': metadataRow.read(totalExp) ?? 0,
    };
  }

  @override
  Stream<List<PauloFlixContent>> watch() {
    return (_db.select(_db.pauloFlixContent)
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
      malId: row.malId,
      anilistId: row.anilistId,
      lastSynced: row.lastSynced,
      isAvailable: row.isAvailable,
    );
  }
}
