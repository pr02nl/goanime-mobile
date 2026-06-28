import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../domain/models/paulo_flix_movie_progress_record.dart';
import '../../domain/repositories/paulo_flix_movie_progress_repository.dart';

/// Implementação Drift do `PauloFlixMovieProgressRepository`.
///
/// Persiste progresso de playback de filmes. A lógica é mais simples
/// que a do `PauloFlixEpisodeProgressRepositoryImpl` porque filmes
/// não têm seasons/episodes — apenas 1 progresso por `folderName`.
class PauloFlixMovieProgressRepositoryImpl
    implements PauloFlixMovieProgressRepository {
  final AppDatabase _db;
  PauloFlixMovieProgressRepositoryImpl(this._db);

  @override
  Future<void> updateProgress({
    required String folderName,
    required String serverUrl,
    required String displayName,
    String? imageUrl,
    String? videoUrl,
    required int positionSeconds,
    int? durationSeconds,
  }) async {
    final existing = await (_db.select(_db.pauloFlixMovieProgress)
          ..where((t) => t.folderName.equals(folderName))
          ..limit(1))
        .getSingleOrNull();

    final now = DateTime.now();
    final isCompleted = durationSeconds != null && durationSeconds > 0 &&
        positionSeconds / durationSeconds >= 0.9;

    if (existing != null) {
      await (_db.update(_db.pauloFlixMovieProgress)
            ..where((t) => t.folderName.equals(folderName)))
          .write(PauloFlixMovieProgressCompanion(
        positionSeconds: Value(positionSeconds),
        durationSeconds: durationSeconds == null
            ? const Value.absent()
            : Value(durationSeconds),
        videoUrl: videoUrl == null
            ? const Value.absent()
            : Value<String?>(videoUrl),
        isCompleted: Value(isCompleted),
        lastWatched: Value(now),
        lastSynced: Value(now),
      ));
    } else {
      await _db.into(_db.pauloFlixMovieProgress).insert(
            PauloFlixMovieProgressCompanion.insert(
              folderName: folderName,
              serverUrl: serverUrl,
              displayName: displayName,
              imageUrl: Value<String?>(imageUrl),
              videoUrl: Value<String?>(videoUrl),
              positionSeconds: Value(positionSeconds),
              durationSeconds: Value<int?>(durationSeconds),
              isCompleted: Value(isCompleted),
              lastWatched: Value<DateTime?>(now),
              lastSynced: now,
            ),
          );
    }
  }

  @override
  Future<void> resetProgress(String folderName) async {
    await (_db.update(_db.pauloFlixMovieProgress)
          ..where((t) => t.folderName.equals(folderName)))
        .write(const PauloFlixMovieProgressCompanion(
      positionSeconds: Value(0),
      isCompleted: Value(false),
      lastWatched: Value<DateTime?>(null),
    ));
  }

  @override
  Future<PauloFlixMovieProgressRecord?> getProgress(String folderName) async {
    final row = await (_db.select(_db.pauloFlixMovieProgress)
          ..where((t) => t.folderName.equals(folderName))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<PauloFlixMovieProgressRecord>> getInProgressMovies({
    int limit = 12,
  }) async {
    final rows = await (_db.select(_db.pauloFlixMovieProgress)
          ..where((t) =>
              t.positionSeconds.isBiggerThanValue(0) &
              t.isCompleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.lastWatched,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(limit))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Stream<List<PauloFlixMovieProgressRecord>> watchInProgressMovies({
    int limit = 12,
  }) {
    return (_db.select(_db.pauloFlixMovieProgress)
          ..where((t) =>
              t.positionSeconds.isBiggerThanValue(0) &
              t.isCompleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.lastWatched,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(limit))
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<List<PauloFlixMovieProgressRecord>> getAllProgress() async {
    final rows = await (_db.select(_db.pauloFlixMovieProgress)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.lastWatched,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Stream<List<PauloFlixMovieProgressRecord>> watchAllProgress() {
    return (_db.select(_db.pauloFlixMovieProgress)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.lastWatched,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  PauloFlixMovieProgressRecord _toDomain(
    PauloFlixMovieProgressData row,
  ) {
    return PauloFlixMovieProgressRecord(
      id: row.id,
      folderName: row.folderName,
      serverUrl: row.serverUrl,
      displayName: row.displayName,
      imageUrl: row.imageUrl,
      videoUrl: row.videoUrl,
      durationSeconds: row.durationSeconds,
      positionSeconds: row.positionSeconds,
      isCompleted: row.isCompleted,
      lastWatched: row.lastWatched,
      lastSynced: row.lastSynced,
    );
  }
}
