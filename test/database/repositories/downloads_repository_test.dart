import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/core/database/tables/downloads.dart' as tbl;
import 'package:goanime/data/repositories/downloads_repository_impl.dart';
import 'package:goanime/data/services/download_service.dart' show DownloadItem;

// Os enums `DownloadStatus` e `DownloadQuality` vêm de
// `core/database/tables/downloads.dart` (única fonte, usada por Drift).
// `DownloadItem` é o modelo de domínio (em `download_service.dart`).
// Re-apelidamos para evitar `tbl.` em todo lugar no teste.
typedef DownloadStatus = tbl.DownloadStatus;
typedef DownloadQuality = tbl.DownloadQuality;

void main() {
  late AppDatabase db;
  late DownloadsRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    repo = DownloadsRepositoryImpl(db);
  });

  DownloadItem item({
    String id = 'mal20_1',
    String animeId = 'mal:20',
    String animeName = 'Naruto',
    String episodeNumber = '1',
    String episodeTitle = 'Episode 1',
    DownloadStatus status = DownloadStatus.queued,
    DownloadQuality quality = DownloadQuality.high,
    String? filePath,
  }) {
    return DownloadItem(
      id: id,
      animeId: animeId,
      animeName: animeName,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      videoUrl: 'http://v/1.mp4',
      thumbnailUrl: 'http://t/1.jpg',
      quality: quality,
      status: status,
      filePath: filePath,
    );
  }

  group('DownloadsRepository', () {
    test('save + getAll retorna o download', () async {
      await repo.save(item());
      final all = await repo.getAll();
      expect(all, hasLength(1));
      expect(all.first.id, 'mal20_1');
      expect(all.first.animeName, 'Naruto');
    });

    test('save é idempotente via downloadId UNIQUE', () async {
      await repo.save(item(id: 'a'));
      await repo.save(item(id: 'a', status: DownloadStatus.completed));

      final all = await repo.getAll();
      expect(all, hasLength(1));
      expect(all.first.status, DownloadStatus.completed);
    });

    test('getById retorna o download correto ou null', () async {
      await repo.save(item(id: 'a'));
      final found = await repo.getById('a');
      expect(found, isNotNull);
      expect(found!.animeName, 'Naruto');

      final notFound = await repo.getById('nope');
      expect(notFound, isNull);
    });

    test('delete remove por id', () async {
      await repo.save(item(id: 'a'));
      await repo.save(item(id: 'b'));
      await repo.delete('a');
      final all = await repo.getAll();
      expect(all, hasLength(1));
      expect(all.first.id, 'b');
    });

    test('clearCompleted remove apenas os completed', () async {
      await repo.save(item(id: 'a', status: DownloadStatus.completed));
      await repo.save(item(id: 'b', status: DownloadStatus.queued));
      await repo.save(item(id: 'c', status: DownloadStatus.failed));

      await repo.clearCompleted();
      final all = await repo.getAll();
      expect(all, hasLength(2));
      expect(all.map((d) => d.id).toSet(), {'b', 'c'});
    });

    test('clearFailed remove failed e cancelled', () async {
      await repo.save(item(id: 'a', status: DownloadStatus.failed));
      await repo.save(item(id: 'b', status: DownloadStatus.cancelled));
      await repo.save(item(id: 'c', status: DownloadStatus.completed));

      await repo.clearFailed();
      final all = await repo.getAll();
      expect(all, hasLength(1));
      expect(all.first.id, 'c');
    });

    test('getAnimeDownloads filtra por animeId', () async {
      await repo.save(item(id: 'a1', animeId: 'mal:20'));
      await repo.save(item(id: 'a2', animeId: 'mal:20'));
      await repo.save(item(id: 'b1', animeId: 'mal:21'));

      final naruto = await repo.getAnimeDownloads('mal:20');
      expect(naruto, hasLength(2));
      expect(naruto.map((d) => d.id).toSet(), {'a1', 'a2'});
    });

    test('count retorna total', () async {
      expect(await repo.count(), 0);
      await repo.save(item(id: 'a'));
      await repo.save(item(id: 'b'));
      expect(await repo.count(), 2);
    });

    test('updateStatus altera status persistido', () async {
      await repo.save(item(id: 'a', status: DownloadStatus.queued));
      await repo.updateStatus('a', DownloadStatus.completed);
      final d = await repo.getById('a');
      expect(d!.status, DownloadStatus.completed);
    });

    test('updateProgress persiste bytes/progress', () async {
      await repo.save(item(id: 'a'));
      await repo.updateProgress('a', progress: 0.5, bytes: 52428800);
      final d = await repo.getById('a');
      expect(d!.progress, 0.5);
      expect(d.bytesDownloaded, 52428800);
    });

    test('resetStaleToQueued: downloading → queued (e persiste)', () async {
      await repo.save(item(id: 'a', status: DownloadStatus.downloading));
      await repo.save(item(id: 'b', status: DownloadStatus.queued));

      final updated = await repo.resetStaleToQueued();
      expect(updated, hasLength(1));
      expect(updated.first, 'a');

      // Re-busca confirma persistência.
      final a = await repo.getById('a');
      expect(a!.status, DownloadStatus.queued);
      final b = await repo.getById('b');
      expect(b!.status, DownloadStatus.queued);
    });
  });
}
