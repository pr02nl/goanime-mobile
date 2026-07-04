import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/data/repositories/paulo_flix_episode_progress_repository_impl.dart';
import 'package:goanime/domain/models/pauloflix_content.dart';
import 'package:goanime/domain/repositories/paulo_flix_episode_progress_repository.dart';
import 'package:goanime/ui/pauloflix/view_models/paulo_flix_episode_progress_viewmodel.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  Future<int> seedContent(AppDatabase db, {String name = 'Test'}) async {
    return db.into(db.pauloFlixContent).insert(
          PauloFlixContentCompanion.insert(
            folderName: name,
            displayName: name,
            serverUrl: 'https://server/$name/',
            lastSynced: DateTime.now(),
          ),
        );
  }

  Future<({int contentId, int s1Id, int s2Id})> seedFull(
    AppDatabase db,
    int contentId,
  ) async {
    final s1 = await db.into(db.pauloFlixSeasons).insert(
          PauloFlixSeasonsCompanion.insert(
            contentId: contentId,
            seasonNumber: 1,
            displayName: 'Temporada 1',
            folderName: 'S01',
            episodeCount: const Value(2),
            lastSynced: DateTime.now(),
          ),
        );
    for (var i = 1; i <= 2; i++) {
      await db.into(db.pauloFlixEpisodes).insert(
            PauloFlixEpisodesCompanion.insert(
              seasonId: s1,
              episodeNumber: i,
              title: 'S01E$i',
              videoUrl: 'https://server/s1/ep$i.mkv',
              lastSynced: DateTime.now(),
            ),
          );
    }
    final s2 = await db.into(db.pauloFlixSeasons).insert(
          PauloFlixSeasonsCompanion.insert(
            contentId: contentId,
            seasonNumber: 2,
            displayName: 'Temporada 2',
            folderName: 'S02',
            episodeCount: const Value(1),
            lastSynced: DateTime.now(),
          ),
        );
    await db.into(db.pauloFlixEpisodes).insert(
          PauloFlixEpisodesCompanion.insert(
            seasonId: s2,
            episodeNumber: 1,
            title: 'S02E01',
            videoUrl: 'https://server/s2/ep1.mkv',
            lastSynced: DateTime.now(),
          ),
        );
    return (contentId: contentId, s1Id: s1, s2Id: s2);
  }

  PauloFlixEpisodeProgressViewModel createVm(
    AppDatabase db,
    PauloFlixEpisodeProgressRepository repo,
    int contentId,
  ) {
    return PauloFlixEpisodeProgressViewModel(
      content: PauloFlixContent(
        id: contentId,
        folderName: 'Test',
        displayName: 'Test',
        serverUrl: 'https://server/Test/',
        lastSynced: DateTime.now(),
      ),
      repository: repo,
    );
  }

  group('PauloFlixEpisodeProgressViewModel — refreshProgress (leitura direta)', () {
    late AppDatabase db;
    late PauloFlixEpisodeProgressRepository repo;
    late int contentId;
    late int s1Id;
    late PauloFlixEpisodeProgressViewModel vm;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = PauloFlixEpisodeProgressRepositoryImpl(db);
      contentId = await seedContent(db);
      final seeded = await seedFull(db, contentId);
      s1Id = seeded.s1Id;

      vm = createVm(db, repo, contentId);
      await vm.loadSeasons();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(vm.status, PauloFlixEpisodeStatus.loaded);
      expect(vm.episodes, hasLength(2));
    });

    tearDown(() async {
      vm.dispose();
      await db.close();
    });

    test('não altera status (sem loading spinner)', () async {
      expect(vm.status, PauloFlixEpisodeStatus.loaded);
      await vm.refreshProgress();
      expect(vm.status, PauloFlixEpisodeStatus.loaded);
    });

    test('episodes permanece populado imediatamente (sem empty state)', () async {
      await vm.refreshProgress();
      expect(vm.episodes, isNotEmpty);
      expect(vm.episodes, hasLength(2));
    });

    test('isCompletedByIndex preserva valores antigos', () async {
      expect(vm.isCompletedByIndex![0], isFalse);
      await vm.refreshProgress();
      expect(vm.isCompletedByIndex![0], isFalse);
    });

    test('episodes reflete dados frescos do banco', () async {
      await repo.updateProgress(
        seasonId: s1Id,
        episodeNumber: 1,
        positionSeconds: 500,
        durationSeconds: 1000,
      );
      await repo.updateProgress(
        seasonId: s1Id,
        episodeNumber: 2,
        positionSeconds: 999,
        durationSeconds: 1000,
      );
      await vm.refreshProgress();

      expect(vm.episodes[0].positionSeconds, 500);
      expect(vm.episodes[1].positionSeconds, 999);
    });

    test('completa season: isCompletedByIndex atualiza', () async {
      await repo.updateProgress(
        seasonId: s1Id,
        episodeNumber: 1,
        positionSeconds: 1000,
        durationSeconds: 1000,
      );
      await repo.updateProgress(
        seasonId: s1Id,
        episodeNumber: 2,
        positionSeconds: 1000,
        durationSeconds: 1000,
      );
      await vm.refreshProgress();

      expect(vm.isCompletedByIndex![0], isTrue);
      expect(vm.isCompletedByIndex![1], isFalse);
    });

    test('chamado múltiplas vezes não causa erro', () async {
      await vm.refreshProgress();
      await vm.refreshProgress();
      await vm.refreshProgress();
      expect(vm.episodes, hasLength(2));
    });

    test('seasons reflete dados frescos do banco', () async {
      final s3 = await db.into(db.pauloFlixSeasons).insert(
            PauloFlixSeasonsCompanion.insert(
              contentId: contentId,
              seasonNumber: 3,
              displayName: 'Temporada 3',
              folderName: 'S03',
              episodeCount: const Value(1),
              lastSynced: DateTime.now(),
            ),
          );
      await db.into(db.pauloFlixEpisodes).insert(
            PauloFlixEpisodesCompanion.insert(
              seasonId: s3,
              episodeNumber: 1,
              title: 'S03E01',
              videoUrl: 'https://server/s3/ep1.mkv',
              lastSynced: DateTime.now(),
            ),
          );
      await vm.refreshProgress();

      expect(vm.seasons, hasLength(3));
      expect(vm.seasons[2].seasonNumber, 3);
    });

    test('selectSeason funciona após refreshProgress', () async {
      await vm.refreshProgress();
      vm.selectSeason(1);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(vm.selectedSeasonIndex, 1);
      expect(vm.episodes, hasLength(1));
      expect(vm.episodes[0].episodeNumber, 1);
    });

    test('refreshProgress após refresh() não quebra estado', () async {
      await vm.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(vm.status, PauloFlixEpisodeStatus.loaded);
      expect(vm.episodes, isNotEmpty);

      await vm.refreshProgress();
      expect(vm.episodes, isNotEmpty);
      expect(vm.episodes[0].episodeNumber, 1);
    });

    test('positionSeconds zero após resetProgress', () async {
      await repo.updateProgress(
        seasonId: s1Id,
        episodeNumber: 1,
        positionSeconds: 800,
        durationSeconds: 1000,
      );
      await repo.resetProgress(seasonId: s1Id, episodeNumber: 1);
      await vm.refreshProgress();

      expect(vm.episodes[0].positionSeconds, 0);
      expect(vm.episodes[0].isCompleted, isFalse);
    });
  });
}
