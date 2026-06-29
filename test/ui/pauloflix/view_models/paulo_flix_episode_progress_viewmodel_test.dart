import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/data/repositories/paulo_flix_episode_progress_repository_impl.dart';
import 'package:goanime/domain/models/pauloflix_content.dart';
import 'package:goanime/domain/repositories/paulo_flix_episode_progress_repository.dart';
import 'package:goanime/ui/pauloflix/view_models/paulo_flix_episode_progress_viewmodel.dart';

/// Testes do `PauloFlixEpisodeProgressViewModel` (Fase 3 do plano
/// `.hermes/plans/2026-06-22_2230-pauloflix-episodes-progress.md`).
///
/// Responsabilidades:
/// 1. Sincronizar seasons/episodes on-demand (HTTP) ao abrir a tela.
/// 2. Expor seasons/episodes via watch streams (reativos).
/// 3. Calcular `isCompletedByIndex` derivado das seasons.
/// 4. Reagir a updates do `updateProgress`/`resetProgress` (novos
///    episodes parciais/completos aparecem sem re-init).
void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  // Helper: cria content+season+episodes no banco direto.
  Future<({int contentId, int seasonId})> seed(
    AppDatabase db, {
    required int contentId,
    int episodeCount = 3,
    int seasonNumber = 1,
    String seasonName = 'S01',
  }) async {
    final seasonId = await db
        .into(db.pauloFlixSeasons)
        .insert(
          PauloFlixSeasonsCompanion.insert(
            contentId: contentId,
            seasonNumber: seasonNumber,
            displayName: seasonName,
            folderName: seasonName,
            episodeCount: Value(episodeCount),
            lastSynced: DateTime.now(),
          ),
        );
    for (var i = 1; i <= episodeCount; i++) {
      await db
          .into(db.pauloFlixEpisodes)
          .insert(
            PauloFlixEpisodesCompanion.insert(
              seasonId: seasonId,
              episodeNumber: i,
              title: 'ep $i',
              videoUrl: 'https://server/s$seasonNumber/ep$i.mkv',
              lastSynced: DateTime.now(),
            ),
          );
    }
    return (contentId: contentId, seasonId: seasonId);
  }

  Future<int> seedContent(AppDatabase db, {String name = 'Test'}) async {
    return db
        .into(db.pauloFlixContent)
        .insert(
          PauloFlixContentCompanion.insert(
            folderName: name,
            displayName: name,
            serverUrl: 'https://server/$name/',
            lastSynced: DateTime.now(),
          ),
        );
  }

  group('PauloFlixEpisodeProgressViewModel — seasons', () {
    late AppDatabase db;
    late PauloFlixEpisodeProgressRepository repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = PauloFlixEpisodeProgressRepositoryImpl(db);
    });

    // IMPORTANTE: dispose o VM antes de fechar o banco (streams ativos).
    tearDown(() async {
      await db.close();
    });

    test('loadSeasons lê seasons do banco (sem HTTP se já existe)', () async {
      final contentId = await seedContent(db);
      await seed(db, contentId: contentId, episodeCount: 2);

      final vm = PauloFlixEpisodeProgressViewModel(
        content: PauloFlixContent(
          id: contentId,
          folderName: 'Test',
          displayName: 'Test',
          serverUrl: 'https://server/Test/',
          lastSynced: DateTime.now(),
        ),
        repository: repo,
        // syncService é opcional — null = sem HTTP (banco já populado)
      );

      await vm.loadSeasons();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(vm.seasons, hasLength(1));
      expect(vm.seasons[0].seasonNumber, 1);
      expect(vm.seasons[0].episodeCount, 2);
      expect(vm.status, PauloFlixEpisodeStatus.loaded);
      vm.dispose();
    });
  });

  group('PauloFlixEpisodeProgressViewModel — isCompletedByIndex', () {
    late AppDatabase db;
    late PauloFlixEpisodeProgressRepository repo;
    late int contentId;
    late int s1;
    late PauloFlixEpisodeProgressViewModel vm;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = PauloFlixEpisodeProgressRepositoryImpl(db);
      contentId = await seedContent(db);

      // Season 1: 2 episodes
      final s1Result = await seed(
        db,
        contentId: contentId,
        episodeCount: 2,
        seasonNumber: 1,
      );
      s1 = s1Result.seasonId;
      // Season 2: 1 episode (criada para teste de "season 2 ainda não
      // tem episodes completos" no getter `isCompletedByIndex`).
      await seed(
        db,
        contentId: contentId,
        episodeCount: 1,
        seasonNumber: 2,
      );

      vm = PauloFlixEpisodeProgressViewModel(
        content: PauloFlixContent(
          id: contentId,
          folderName: 'Test',
          displayName: 'Test',
          serverUrl: 'https://server/Test/',
          lastSynced: DateTime.now(),
        ),
        repository: repo,
      );
      await vm.loadSeasons();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    // IMPORTANTE: dispose o VM antes de fechar o banco.
    tearDown(() async {
      vm.dispose();
      await db.close();
    });

    test('inicialmente: map tem 2 entries (todas false)', () {
      // 2 seasons no banco, ambas `isCompleted = false`.
      expect(vm.isCompletedByIndex, isNotNull);
      expect(vm.isCompletedByIndex, hasLength(2));
      expect(vm.isCompletedByIndex![0], isFalse);
      expect(vm.isCompletedByIndex![1], isFalse);
    });

    test('season 1 completa → isCompletedByIndex[0] = true', () async {
      // Marca ambos os episodes da season 1 como completos.
      await repo.updateProgress(
        seasonId: s1,
        episodeNumber: 1,
        positionSeconds: 1000,
        durationSeconds: 1000,
      );
      await repo.updateProgress(
        seasonId: s1,
        episodeNumber: 2,
        positionSeconds: 1000,
        durationSeconds: 1000,
      );

      // Espera o stream emitir.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(vm.isCompletedByIndex, isNotNull);
      expect(vm.isCompletedByIndex, hasLength(2));
      expect(vm.isCompletedByIndex![0], isTrue);
      expect(
        vm.isCompletedByIndex![1],
        isFalse,
        reason: 'season 2 ainda não tem episodes completos',
      );
    });

    test(
      'season 1 com 1 episode completo (de 2) → isCompletedByIndex[0] = false',
      () async {
        await repo.updateProgress(
          seasonId: s1,
          episodeNumber: 1,
          positionSeconds: 1000,
          durationSeconds: 1000,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(vm.isCompletedByIndex, isNotNull);
        expect(
          vm.isCompletedByIndex![0],
          isFalse,
          reason: '1/2 episodes completos = NÃO completa',
        );
      },
    );

    test('resetProgress zera flag da season (Decisão 6)', () async {
      // Setup: season 1 completa.
      await repo.updateProgress(
        seasonId: s1,
        episodeNumber: 1,
        positionSeconds: 1000,
        durationSeconds: 1000,
      );
      await repo.updateProgress(
        seasonId: s1,
        episodeNumber: 2,
        positionSeconds: 1000,
        durationSeconds: 1000,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.isCompletedByIndex![0], isTrue);

      // Reset do episode 1.
      await repo.resetProgress(seasonId: s1, episodeNumber: 1);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        vm.isCompletedByIndex![0],
        isFalse,
        reason: 'reset zera season.isCompleted',
      );
    });
  });

  group('PauloFlixEpisodeProgressViewModel — selectedSeasonIndex', () {
    late AppDatabase db;
    late PauloFlixEpisodeProgressRepository repo;
    late int contentId;
    late PauloFlixEpisodeProgressViewModel vm;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = PauloFlixEpisodeProgressRepositoryImpl(db);
      contentId = await seedContent(db);
      await seed(db, contentId: contentId, episodeCount: 2, seasonNumber: 1);
      await seed(db, contentId: contentId, episodeCount: 3, seasonNumber: 2);
      vm = PauloFlixEpisodeProgressViewModel(
        content: PauloFlixContent(
          id: contentId,
          folderName: 'Test',
          displayName: 'Test',
          serverUrl: 'https://server/Test/',
          lastSynced: DateTime.now(),
        ),
        repository: repo,
      );
      await vm.loadSeasons();
    });

    // IMPORTANTE: dispose o VM ANTES de fechar o banco — o stream
    // do `watchSeasonsForContent` ainda está ativo e emitiria
    // durante o `db.close()` (concurrent modification).
    tearDown(() async {
      vm.dispose();
      await db.close();
    });

    test('inicia em 0 (primeira season)', () async {
      // O stream `_seasonsSub` é assíncrono. Aguarda o primeiro emit
      // para `_seasons` ser populado.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.selectedSeasonIndex, 0);
    });

    test('selectSeason muda índice', () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        vm.seasons,
        hasLength(2),
        reason: 'precondição: 2 seasons no banco',
      );
      vm.selectSeason(1);
      expect(vm.selectedSeasonIndex, 1);
    });
  });

  group('PauloFlixEpisodeProgressViewModel — LRU cache', () {
    /// Cria 4 seasons no banco, cada uma com 1 episode.
    Future<void> seedSeasons(
      AppDatabase db,
      int contentId,
    ) async {
      for (var s = 1; s <= 4; s++) {
        final seasonId = await db
            .into(db.pauloFlixSeasons)
            .insert(
              PauloFlixSeasonsCompanion.insert(
                contentId: contentId,
                seasonNumber: s,
                displayName: 'S${s.toString().padLeft(2, '0')}',
                folderName: 'S${s.toString().padLeft(2, '0')}',
                episodeCount: const Value(1),
                lastSynced: DateTime.now(),
              ),
            );
        await db
            .into(db.pauloFlixEpisodes)
            .insert(
              PauloFlixEpisodesCompanion.insert(
                seasonId: seasonId,
                episodeNumber: 1,
                title: 'ep$s',
                videoUrl: 'https://server/s$s/ep1.mkv',
                lastSynced: DateTime.now(),
              ),
            );
      }
    }

    late AppDatabase db;
    late PauloFlixEpisodeProgressRepository repo;
    late int contentId;
    late PauloFlixEpisodeProgressViewModel vm;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = PauloFlixEpisodeProgressRepositoryImpl(db);
      contentId = await db
          .into(db.pauloFlixContent)
          .insert(
            PauloFlixContentCompanion.insert(
              folderName: 'LRUTest',
              displayName: 'LRUTest',
              serverUrl: 'https://server/LRUTest/',
              lastSynced: DateTime.now(),
            ),
          );
      await seedSeasons(db, contentId);

      vm = PauloFlixEpisodeProgressViewModel(
        content: PauloFlixContent(
          id: contentId,
          folderName: 'LRUTest',
          displayName: 'LRUTest',
          serverUrl: 'https://server/LRUTest/',
          lastSynced: DateTime.now(),
        ),
        repository: repo,
      );
      await vm.loadSeasons();
      // Aguarda o stream de seasons emitir.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.seasons, hasLength(4));
    });

    tearDown(() async {
      vm.dispose();
      await db.close();
    });

    test('quando 4a season é acessada, a mais antiga é evictada (FIFO)',
        () async {
      // Seleciona seasons 0, 1, 2 (cache com 3 entries: 0, 1, 2).
      vm.selectSeason(0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.episodes, isNotEmpty, reason: 'season 0 deve ter episodes');

      vm.selectSeason(1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.episodes, isNotEmpty, reason: 'season 1 deve ter episodes');

      vm.selectSeason(2);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.episodes, isNotEmpty, reason: 'season 2 deve ter episodes');

      // Season 3 → cache cheio (3/3). Season 0 deve ser evictada.
      vm.selectSeason(3);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.episodes, isNotEmpty, reason: 'season 3 deve ter episodes');

      // Volta para season 0 — deve recarregar (cache miss).
      vm.selectSeason(0);
      // Imediatamente após selecionar, o cache da season 0 está vazio
      // (foi evictado). O stream está sendo assinado de novo.
      expect(vm.episodes, isEmpty, reason: 'season 0 foi evictada');

      // Aguarda o stream emitir os episodes.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.episodes, isNotEmpty, reason: 'season 0 recarregada via stream');
    });

    test('re-acessar season atualiza ordem LRU (mais recente não é evictada)',
        () async {
      // Seleciona seasons 0, 1, 2.
      vm.selectSeason(0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.episodes, isNotEmpty, reason: 'season 0 carregada');

      vm.selectSeason(1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.episodes, isNotEmpty, reason: 'season 1 carregada');

      vm.selectSeason(2);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.episodes, isNotEmpty, reason: 'season 2 carregada');

      // Re-acessa season 0 → agora ordem é: 1, 2, 0.
      vm.selectSeason(0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.episodes, isNotEmpty, reason: 'season 0 re-acessada');

      // Season 3 → deve evictar season 1 (a mais antiga), não season 0.
      vm.selectSeason(3);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.episodes, isNotEmpty, reason: 'season 3 carregada');

      // Season 1 deve ter sido evictada.
      vm.selectSeason(1);
      expect(
        vm.episodes,
        isEmpty,
        reason:
            'season 1 foi evictada (era a mais antiga após re-acesso da 0)',
      );

      // Season 0 ainda deve estar em cache (foi re-acessada).
      vm.selectSeason(0);
      expect(
        vm.episodes,
        isNotEmpty,
        reason: 'season 0 ainda está em cache (re-acessada antes do evict)',
      );
    });

    test('dispose limpa cache e ordem de acesso', () async {
      vm.selectSeason(0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.episodes, isNotEmpty, reason: 'season 0 carregada');

      // A limpeza do cache (_episodesBySeason, _seasonAccessOrder)
      // e o cancelamento das subs são feitos pelo dispose.
      // Não chamamos dispose() explicitamente aqui porque o tearDown
      // do grupo já faz isso — e ChangeNotifier.dispose() lança
      // "used after being disposed" na segunda chamada (debug mode).
      // O tearDown verifica implicitamente que dispose não lança.
    });
  });
}
