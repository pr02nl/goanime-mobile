import 'package:drift/drift.dart' hide isNotNull, isNull;

import '../../core/database/app_database.dart';
import '../../domain/models/watchlist_anime.dart';
import '../../domain/repositories/watchlist_repository.dart';

/// Implementação do `WatchlistRepository` sobre Drift.
///
/// **Fase 3**: substitui `WatchlistService` (sqlite3 FFI) como fonte
/// de verdade. Os dois coexistem durante a migração (Fase 4 remove o
/// legado).
class WatchlistRepositoryImpl implements WatchlistRepository {
  final AppDatabase _db;
  WatchlistRepositoryImpl(this._db);

  @override
  Future<List<WatchlistAnime>> getAll() async {
    final rows = await (_db.select(_db.watchlistItems)
          ..orderBy([
            (t) => OrderingTerm.desc(t.addedAt),
          ]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<WatchlistAnime?> getByAnimeId(String animeId) async {
    final query = _db.select(_db.watchlistItems)
      ..where((t) => t.animeId.equals(animeId))
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> add(WatchlistAnime anime) async {
    await _db.into(_db.watchlistItems).insert(
          WatchlistItemsCompanion.insert(
            animeId: anime.animeId,
            title: anime.title,
            coverImage: anime.coverImage,
            myAnimeListUrl: anime.myAnimeListUrl,
            addedAt: anime.addedAt,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  @override
  Future<void> remove(String animeId) async {
    await (_db.delete(_db.watchlistItems)
          ..where((t) => t.animeId.equals(animeId)))
        .go();
  }

  @override
  Future<bool> isInWatchlist(String animeId) async {
    final query = _db.select(_db.watchlistItems)
      ..where((t) => t.animeId.equals(animeId))
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row != null;
  }

  @override
  Future<int> count() async {
    final countExp = _db.watchlistItems.id.count();
    final result = await (_db.selectOnly(_db.watchlistItems)
          ..addColumns([countExp]))
        .getSingle();
    return result.read(countExp) ?? 0;
  }

  @override
  Future<void> clear() async {
    await _db.delete(_db.watchlistItems).go();
  }

  @override
  Stream<List<WatchlistAnime>> watch() {
    return (_db.select(_db.watchlistItems)
          ..orderBy([
            (t) => OrderingTerm.desc(t.addedAt),
          ]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  WatchlistAnime _toDomain(WatchlistItem row) {
    return WatchlistAnime(
      id: row.id,
      animeId: row.animeId,
      title: row.title,
      coverImage: row.coverImage,
      myAnimeListUrl: row.myAnimeListUrl,
      addedAt: row.addedAt,
    );
  }
}
