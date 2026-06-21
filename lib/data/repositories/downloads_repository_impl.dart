import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/database/tables/downloads.dart' as dl;
import '../../data/services/download_service.dart' as svc;
import '../../domain/repositories/downloads_repository.dart';

/// Implementação Drift do `DownloadsRepository`.
///
/// Substitui o acesso direto a `downloads.db` (sqlite3 FFI) que o
/// `DownloadService` fazia. O `DownloadService` continua existindo
/// (fila HTTP, `ChangeNotifier`, signals) e chama este repository
/// por trás — Fase 4 remove a persistência duplicada.
class DownloadsRepositoryImpl implements DownloadsRepository {
  final AppDatabase _db;
  DownloadsRepositoryImpl(this._db);

  @override
  Future<void> save(DownloadItem item) async {
    await _db.into(_db.downloads).insert(
          DownloadsCompanion.insert(
            downloadId: item.id,
            animeId: item.animeId,
            animeName: item.animeName,
            episodeNumber: item.episodeNumber,
            episodeTitle: item.episodeTitle,
            videoUrl: item.videoUrl,
            thumbnailUrl: item.thumbnailUrl,
            quality: item.quality,
            status: item.status,
            progress: Value(item.progress),
            bytesDownloaded: Value(item.bytesDownloaded),
            totalBytes: Value(item.totalBytes),
            filePath: Value(item.filePath),
            error: Value(item.error),
            createdAt: item.createdAt,
            completedAt: Value(item.completedAt),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }
  @override
  Future<List<DownloadItem>> getAll() async {
    final rows = await _db.select(_db.downloads).get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<DownloadItem?> getById(String id) async {
    final row = await (_db.select(_db.downloads)
          ..where((t) => t.downloadId.equals(id))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<DownloadItem>> getAnimeDownloads(String animeId) async {
    final rows = await (_db.select(_db.downloads)
          ..where((t) => t.animeId.equals(animeId))
          ..orderBy([(t) => OrderingTerm(expression: t.episodeNumber)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.downloads)..where((t) => t.downloadId.equals(id)))
        .go();
  }

  @override
  Future<int> count() async {
    final countExp = _db.downloads.id.count();
    final row = await (_db.selectOnly(_db.downloads)
          ..addColumns([countExp]))
        .getSingle();
    return row.read(countExp) ?? 0;
  }

  @override
  Future<void> updateStatus(String id, dl.DownloadStatus status) async {
    await (_db.update(_db.downloads)..where((t) => t.downloadId.equals(id)))
        .write(DownloadsCompanion(status: Value(status)));
  }

  @override
  Future<void> updateProgress(
    String id, {
    required double progress,
    required int bytes,
  }) async {
    await (_db.update(_db.downloads)..where((t) => t.downloadId.equals(id)))
        .write(DownloadsCompanion(
      progress: Value(progress),
      bytesDownloaded: Value(bytes),
    ));
  }

  @override
  Future<void> clearCompleted() async {
    await (_db.delete(_db.downloads)
          ..where((t) => t.status.equalsValue(dl.DownloadStatus.completed)))
        .go();
  }

  @override
  Future<void> clearFailed() async {
    await (_db.delete(_db.downloads)
          ..where((t) =>
              t.status.equalsValue(dl.DownloadStatus.failed) |
              t.status.equalsValue(dl.DownloadStatus.cancelled)))
        .go();
  }

  @override
  Future<List<String>> resetStaleToQueued() async {
    // Encontra todos com status downloading.
    final rows = await (_db.select(_db.downloads)
          ..where((t) => t.status.equalsValue(dl.DownloadStatus.downloading)))
        .get();
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r.downloadId).toList();
    await (_db.update(_db.downloads)
          ..where((t) => t.downloadId.isIn(ids)))
        .write(const DownloadsCompanion(
      status: Value(dl.DownloadStatus.queued),
    ));
    return ids;
  }

  @override
  Stream<List<DownloadItem>> watch() {
    return _db.select(_db.downloads).watch().map(
          (rows) => rows.map(_toDomain).toList(),
        );
  }

  // ---- helpers -----------------------------------------------------------

  DownloadItem _toDomain(Download row) {
    return svc.DownloadItem(
      id: row.downloadId,
      animeId: row.animeId,
      animeName: row.animeName,
      episodeNumber: row.episodeNumber,
      episodeTitle: row.episodeTitle,
      videoUrl: row.videoUrl,
      thumbnailUrl: row.thumbnailUrl,
      quality: row.quality,
      status: row.status,
      progress: row.progress,
      bytesDownloaded: row.bytesDownloaded,
      totalBytes: row.totalBytes,
      filePath: row.filePath,
      error: row.error,
      createdAt: row.createdAt,
      completedAt: row.completedAt,
    );
  }
}
