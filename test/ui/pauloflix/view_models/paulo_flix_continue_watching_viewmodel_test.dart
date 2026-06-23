import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/data/repositories/paulo_flix_episode_progress_repository_impl.dart';
import 'package:goanime/domain/repositories/paulo_flix_episode_progress_repository.dart';
import 'package:goanime/ui/pauloflix/view_models/paulo_flix_continue_watching_viewmodel.dart';

/// Testes do `PauloFlixContinueWatchingViewModel` (Fase 5.1 do plano
/// `.hermes/plans/2026-06-22_2230-pauloflix-episodes-progress.md`).
///
/// Responsabilidade: assinar `repo.watchInProgressContents(limit: 12)`,
/// expor a lista + loading state, e reagir a updates do banco
/// (episode parou de ser parcial → some da lista automaticamente).
void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  // Helper: cria content + season + episode (parcial ou completo).
  // Retorna o contentId (int).
  Future<int> seedContent({
    required AppDatabase db,
    required String contentName,
    int episodeCount = 1,
    bool isCompleted = false,
    int positionSeconds = 720, // 50% de 1440s default
    int durationSeconds = 1440,
  }) async {
    final contentId = await db.into(db.pauloFlixContent).insert(
          PauloFlixContentCompanion.insert(
            folderName: contentName,
            displayName: contentName,
            serverUrl: 'https://server/$contentName/',
            lastSynced: DateTime.now(),
          ),
        );
    final seasonId = await db.into(db.pauloFlixSeasons).insert(
          PauloFlixSeasonsCompanion.insert(
            contentId: contentId,
            seasonNumber: 1,
            displayName: 'S01',
            folderName: 'S01',
            episodeCount: Value(episodeCount),
            lastSynced: DateTime.now(),
          ),
        );
    for (var i = 1; i <= episodeCount; i++) {
      await db.into(db.pauloFlixEpisodes).insert(
            PauloFlixEpisodesCompanion.insert(
              seasonId: seasonId,
              episodeNumber: i,
              title: 'ep $i',
              videoUrl: 'https://server/s1/ep$i.mkv',
              positionSeconds: Value(positionSeconds),
              durationSeconds: Value(durationSeconds),
              isCompleted: Value(isCompleted),
              lastWatched:
                  Value(DateTime.now().subtract(Duration(minutes: i))),
              lastSynced: DateTime.now(),
            ),
          );
    }
    return contentId;
  }

  group('PauloFlixContinueWatchingViewModel', () {
    late AppDatabase db;
    late PauloFlixEpisodeProgressRepository repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = PauloFlixEpisodeProgressRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('inicia com loading = true (antes do primeiro evento)', () {
      final vm = PauloFlixContinueWatchingViewModel(repository: repo);
      expect(vm.loading, isTrue);
      expect(vm.contents, isEmpty);
      vm.dispose();
    });

    test('carrega lista inicial do banco via stream', () async {
      await seedContent(
        db: db,
        contentName: 'Naruto',
      );
      await seedContent(db: db, contentName: 'Bleach');

      final vm = PauloFlixContinueWatchingViewModel(repository: repo);

      // Espera o primeiro evento do stream.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(vm.loading, isFalse);
      expect(vm.contents, hasLength(2));
      // Mais recente primeiro (Naruto lastWatched mais recente que Bleach
      // que tem `i=1` subtraído — mas ambos têm `i=1`, então depende
      // de timestamp). Verifica apenas que ambos estão.
      expect(
        vm.contents.map((c) => c.folderName).toSet(),
        {'Naruto', 'Bleach'},
      );
      vm.dispose();
    });

    test('exclui animes com isAvailable = false (removido do servidor)',
        () async {
      final contentId = await seedContent(db: db, contentName: 'Offline');
      // Marca content como indisponível.
      await (db.update(db.pauloFlixContent)
            ..where((t) => t.id.equals(contentId)))
          .write(const PauloFlixContentCompanion(isAvailable: Value(false)));

      final vm = PauloFlixContinueWatchingViewModel(repository: repo);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(vm.contents, isEmpty);
      vm.dispose();
    });

    test('exclui animes sem episodes parciais (só completos)', () async {
      await seedContent(
        db: db,
        contentName: 'Completo',
        isCompleted: true,
      );

      final vm = PauloFlixContinueWatchingViewModel(repository: repo);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Completo → fora do "em andamento" (já está na home de alguma
      // outra seção, ou não é mais "continue").
      expect(vm.contents, isEmpty);
      vm.dispose();
    });

    test('exclui animes com positionSeconds = 0 (nunca assistido)',
        () async {
      // `seedContent(positionSeconds: 0)` cria o episode com
      // positionSeconds=0 e isCompleted=false. O filtro da query
      // (`positionSeconds > 0 && !isCompleted`) exclui automaticamente.
      await seedContent(
        db: db,
        contentName: 'Vazio',
        positionSeconds: 0,
      );

      final vm = PauloFlixContinueWatchingViewModel(repository: repo);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(vm.contents, isEmpty);
      vm.dispose();
    });

    test('respeita o limit (default 12)', () async {
      for (var i = 0; i < 15; i++) {
        await seedContent(db: db, contentName: 'A$i');
      }

      final vm = PauloFlixContinueWatchingViewModel(repository: repo);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(vm.contents, hasLength(12),
          reason: 'limit default = 12');
      vm.dispose();
    });

    test('aceita limit customizado', () async {
      for (var i = 0; i < 5; i++) {
        await seedContent(db: db, contentName: 'B$i');
      }

      final vm = PauloFlixContinueWatchingViewModel(
        repository: repo,
        limit: 3,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(vm.contents, hasLength(3));
      vm.dispose();
    });

    test('reage a update no banco (episode parou de ser parcial → some)',
        () async {
      final contentId = await seedContent(db: db, contentName: 'Reativo');
      expect(contentId, isPositive);

      final vm = PauloFlixContinueWatchingViewModel(repository: repo);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.contents, hasLength(1));

      // Marca episode como completo → deve sumir da lista.
      final season = await (db.select(db.pauloFlixSeasons)
            ..where((t) => t.contentId.equals(contentId)))
          .getSingle();
      final episode = await (db.select(db.pauloFlixEpisodes)
            ..where((t) => t.seasonId.equals(season.id)))
          .getSingle();
      await (db.update(db.pauloFlixEpisodes)
            ..where((t) => t.id.equals(episode.id)))
          .write(const PauloFlixEpisodesCompanion(
        isCompleted: Value(true),
        positionSeconds: Value(1440),
        durationSeconds: Value(1440),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(vm.contents, isEmpty,
          reason: 'episode completo some da lista "em andamento"');
      vm.dispose();
    });

    test('reage a novo episode parcial (anime aparece na lista)',
        () async {
      // Banco vazio.
      final vm = PauloFlixContinueWatchingViewModel(repository: repo);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.contents, isEmpty);

      // Adiciona anime com episode parcial.
      await seedContent(db: db, contentName: 'Novo');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(vm.contents, hasLength(1));
      vm.dispose();
    });
  });
}
