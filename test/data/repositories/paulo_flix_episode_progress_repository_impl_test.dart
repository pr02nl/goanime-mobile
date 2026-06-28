import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/data/repositories/paulo_flix_episode_progress_repository_impl.dart';
import 'package:goanime/domain/repositories/paulo_flix_episode_progress_repository.dart';

/// Testes do `PauloFlixEpisodeProgressRepositoryImpl` (Fase 1.3 do plano
/// `.hermes/plans/2026-06-22_2230-pauloflix-episodes-progress.md`).
///
/// Foco: lógica de negócio:
/// - `updateProgress` salva posição + lastWatched + marca completed se ≥90%
/// - `resetProgress` zera + recomputa season
/// - `_recomputeSeasonCompleted` agrega corretamente
/// - `getStatsForContent` retorna totais corretos
/// - `getInProgressContents` filtra + ordena + respeita isAvailable
/// - Streams emitem ao mudar dados
void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  // ─── Helpers ────────────────────────────────────────────────────────

  /// Cria content + season com N episodes (todos incompletos).
  /// Retorna (contentId, seasonId).
  Future<(int, int)> seedSeason(
    AppDatabase db, {
    required int contentId,
    required int episodeCount,
    String seasonName = 'Season 01',
  }) async {
    final seasonId = await db.into(db.pauloFlixSeasons).insert(
          PauloFlixSeasonsCompanion.insert(
            contentId: contentId,
            seasonNumber: 1,
            displayName: seasonName,
            folderName: seasonName,
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
              videoUrl: 'https://server/ep$i.mkv',
              lastSynced: DateTime.now(),
            ),
          );
    }
    return (contentId, seasonId);
  }

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

  // ─── Testes ─────────────────────────────────────────────────────────

  group('updateProgress', () {
    late AppDatabase db;
    late PauloFlixEpisodeProgressRepository repo;
    late int contentId;
    late int seasonId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      contentId = await seedContent(db);
      (_, seasonId) = await seedSeason(db, contentId: contentId, episodeCount: 3);
      repo = PauloFlixEpisodeProgressRepositoryImpl(db);
    });

    tearDown(() async => db.close());

    test('grava positionSeconds e lastWatched', () async {
      final before = DateTime.now();
      await repo.updateProgress(
        seasonId: seasonId,
        episodeNumber: 1,
        positionSeconds: 100,
        durationSeconds: 1440,
      );
      final after = DateTime.now();

      final ep = await (db.select(db.pauloFlixEpisodes)
            ..where((t) =>
                t.seasonId.equals(seasonId) &
                t.episodeNumber.equals(1)))
          .getSingle();
      expect(ep.positionSeconds, 100);
      expect(ep.durationSeconds, 1440);
      expect(ep.lastWatched, isNotNull);
      // lastWatched ∈ [before, after] (Drift perde ms, compara até segundo).
      expect(
        ep.lastWatched!.millisecondsSinceEpoch,
        greaterThanOrEqualTo(before.millisecondsSinceEpoch ~/ 1000 * 1000),
      );
      expect(
        ep.lastWatched!.millisecondsSinceEpoch,
        lessThanOrEqualTo(after.millisecondsSinceEpoch),
      );
      // isCompleted continua false (ratio = 100/1440 ≈ 7%).
      expect(ep.isCompleted, false);
    });

    test('marca isCompleted = true quando ratio >= 0.9', () async {
      await repo.updateProgress(
        seasonId: seasonId,
        episodeNumber: 1,
        positionSeconds: 1300, // 1300/1440 = 90.3%
        durationSeconds: 1440,
      );
      final ep = await (db.select(db.pauloFlixEpisodes)
            ..where((t) =>
                t.seasonId.equals(seasonId) &
                t.episodeNumber.equals(1)))
          .getSingle();
      expect(ep.isCompleted, true);
    });

    test('NÃO marca isCompleted quando ratio < 0.9', () async {
      await repo.updateProgress(
        seasonId: seasonId,
        episodeNumber: 1,
        positionSeconds: 1200, // 1200/1440 = 83.3%
        durationSeconds: 1440,
      );
      final ep = await (db.select(db.pauloFlixEpisodes)
            ..where((t) =>
                t.seasonId.equals(seasonId) &
                t.episodeNumber.equals(1)))
          .getSingle();
      expect(ep.isCompleted, false);
    });

    test('NÃO marca isCompleted quando durationSeconds = null', () async {
      // Player ainda não descobriu a duração.
      await repo.updateProgress(
        seasonId: seasonId,
        episodeNumber: 1,
        positionSeconds: 99999, // absurdamente grande
        // sem durationSeconds
      );
      final ep = await (db.select(db.pauloFlixEpisodes)
            ..where((t) =>
                t.seasonId.equals(seasonId) &
                t.episodeNumber.equals(1)))
          .getSingle();
      expect(ep.isCompleted, false);
    });

    test('marca season.isCompleted = true quando TODOS episodes completos',
        () async {
      // Marca ep 1, 2, 3 como completos.
      for (var i = 1; i <= 3; i++) {
        await repo.updateProgress(
          seasonId: seasonId,
          episodeNumber: i,
          positionSeconds: 1440,
          durationSeconds: 1440,
        );
      }
      final season = await (db.select(db.pauloFlixSeasons)
            ..where((t) => t.id.equals(seasonId)))
          .getSingle();
      expect(season.isCompleted, true);
    });

    test(
      'NÃO marca season.isCompleted quando apenas 1 episode completo (dos 3)',
      () async {
        await repo.updateProgress(
          seasonId: seasonId,
          episodeNumber: 1,
          positionSeconds: 1440,
          durationSeconds: 1440,
        );
        final season = await (db.select(db.pauloFlixSeasons)
              ..where((t) => t.id.equals(seasonId)))
            .getSingle();
        expect(season.isCompleted, false);
      },
    );
  });

  group('resetProgress (decisão 6 + bug fix recompute)', () {
    late AppDatabase db;
    late PauloFlixEpisodeProgressRepository repo;
    late int contentId;
    late int seasonId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      contentId = await seedContent(db);
      (_, seasonId) = await seedSeason(db, contentId: contentId, episodeCount: 2);
      repo = PauloFlixEpisodeProgressRepositoryImpl(db);
    });

    tearDown(() async => db.close());

    test('zera positionSeconds e isCompleted do episode', () async {
      // Setup: episode marcado como completo.
      await repo.updateProgress(
        seasonId: seasonId,
        episodeNumber: 1,
        positionSeconds: 1440,
        durationSeconds: 1440,
      );
      // (com isso, season.isCompleted continua false pq ep 2 não está
      // completo — mas o episode 1 está completo.)

      // Reset.
      await repo.resetProgress(seasonId: seasonId, episodeNumber: 1);

      final ep = await (db.select(db.pauloFlixEpisodes)
            ..where((t) =>
                t.seasonId.equals(seasonId) &
                t.episodeNumber.equals(1)))
          .getSingle();
      expect(ep.positionSeconds, 0);
      expect(ep.isCompleted, false);
    });

    test(
      'BUG FIX: reseta season.isCompleted para false quando era o último completo',
      () async {
        // Setup: marca ep 1 e ep 2 como completos → season fica completa.
        for (var i = 1; i <= 2; i++) {
          await repo.updateProgress(
            seasonId: seasonId,
            episodeNumber: i,
            positionSeconds: 1440,
            durationSeconds: 1440,
          );
        }
        // Confirma season.isCompleted = true.
        var season = await (db.select(db.pauloFlixSeasons)
              ..where((t) => t.id.equals(seasonId)))
            .getSingle();
        expect(season.isCompleted, true,
            reason: 'precondição: season deve estar completa');

        // Reset do episode 1 → season NÃO pode continuar completa.
        await repo.resetProgress(seasonId: seasonId, episodeNumber: 1);

        season = await (db.select(db.pauloFlixSeasons)
              ..where((t) => t.id.equals(seasonId)))
            .getSingle();
        expect(season.isCompleted, false,
            reason: 'reset deve disparar recompute e flag deve virar false');
      },
    );
  });

  group('getStatsForContent (decisão 7)', () {
    late AppDatabase db;
    late PauloFlixEpisodeProgressRepository repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = PauloFlixEpisodeProgressRepositoryImpl(db);
    });

    tearDown(() async => db.close());

    test('retorna zeros para content sem episodes', () async {
      final contentId = await seedContent(db);
      final stats = await repo.getStatsForContent(contentId);
      expect(stats.totalEpisodes, 0);
      expect(stats.completedEpisodes, 0);
      expect(stats.inProgressEpisodes, 0);
      expect(stats.progressRatio, 0.0);
      expect(stats.isAnimeCompleted, false);
      expect(stats.isAnimeInProgress, false);
    });

    test('conta corretamente: 2/4 completos, 1 in progress', () async {
      final contentId = await seedContent(db);
      final (_, seasonId) =
          await seedSeason(db, contentId: contentId, episodeCount: 4);

      // 2 completos (ep 1, 2).
      for (var i = 1; i <= 2; i++) {
        await repo.updateProgress(
          seasonId: seasonId,
          episodeNumber: i,
          positionSeconds: 1440,
          durationSeconds: 1440,
        );
      }
      // 1 parcial (ep 3): 50% assistido.
      await repo.updateProgress(
        seasonId: seasonId,
        episodeNumber: 3,
        positionSeconds: 720,
        durationSeconds: 1440,
      );
      // ep 4 nunca assistido.

      final stats = await repo.getStatsForContent(contentId);
      expect(stats.totalEpisodes, 4);
      expect(stats.completedEpisodes, 2);
      expect(stats.inProgressEpisodes, 1);
      expect(stats.progressRatio, 0.5);
      expect(stats.isAnimeCompleted, false);
      expect(stats.isAnimeInProgress, true);
    });

    test('isAnimeCompleted = true quando todos os episodes completos', () async {
      final contentId = await seedContent(db);
      final (_, seasonId) =
          await seedSeason(db, contentId: contentId, episodeCount: 2);
      for (var i = 1; i <= 2; i++) {
        await repo.updateProgress(
          seasonId: seasonId,
          episodeNumber: i,
          positionSeconds: 1440,
          durationSeconds: 1440,
        );
      }
      final stats = await repo.getStatsForContent(contentId);
      expect(stats.isAnimeCompleted, true);
    });

    test('agrega episodes de MÚLTIPLAS seasons do mesmo content', () async {
      final contentId = await seedContent(db);
      // Season 1: 2 episodes
      final s1 = await db.into(db.pauloFlixSeasons).insert(
            PauloFlixSeasonsCompanion.insert(
              contentId: contentId,
              seasonNumber: 1,
              displayName: 'S01',
              folderName: 'S01',
              episodeCount: const Value(2),
              lastSynced: DateTime.now(),
            ),
          );
      // Season 2: 1 episode
      final s2 = await db.into(db.pauloFlixSeasons).insert(
            PauloFlixSeasonsCompanion.insert(
              contentId: contentId,
              seasonNumber: 2,
              displayName: 'S02',
              folderName: 'S02',
              episodeCount: const Value(1),
              lastSynced: DateTime.now(),
            ),
          );
      for (final (seasonId, n) in [(s1, 2), (s2, 1)]) {
        for (var i = 1; i <= n; i++) {
          await db.into(db.pauloFlixEpisodes).insert(
                PauloFlixEpisodesCompanion.insert(
                  seasonId: seasonId,
                  episodeNumber: i,
                  title: 's${seasonId}ep$i',
                  videoUrl: 'https://server/s${seasonId}ep$i.mkv',
                  lastSynced: DateTime.now(),
                ),
              );
        }
      }
      // Marca 1 episode de cada season como completo.
      await repo.updateProgress(
        seasonId: s1,
        episodeNumber: 1,
        positionSeconds: 1440,
        durationSeconds: 1440,
      );
      await repo.updateProgress(
        seasonId: s2,
        episodeNumber: 1,
        positionSeconds: 1440,
        durationSeconds: 1440,
      );

      final stats = await repo.getStatsForContent(contentId);
      expect(stats.totalEpisodes, 3); // 2 da s1 + 1 da s2
      expect(stats.completedEpisodes, 2);
    });
  });

  group('getInProgressContents (decisão 8)', () {
    late AppDatabase db;
    late PauloFlixEpisodeProgressRepository repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = PauloFlixEpisodeProgressRepositoryImpl(db);
    });

    tearDown(() async => db.close());

    test('retorna lista vazia quando não há animes em andamento', () async {
      final list = await repo.getInProgressContents();
      expect(list, isEmpty);
    });

    test('inclui anime com episode parcialmente assistido', () async {
      final contentId = await seedContent(db);
      final (_, seasonId) =
          await seedSeason(db, contentId: contentId, episodeCount: 1);
      await repo.updateProgress(
        seasonId: seasonId,
        episodeNumber: 1,
        positionSeconds: 720,
        durationSeconds: 1440,
      );

      final list = await repo.getInProgressContents();
      expect(list, hasLength(1));
      expect(list.first.id, contentId);
    });

    test('EXCLUI anime com episode completo (não em andamento)', () async {
      final contentId = await seedContent(db);
      final (_, seasonId) =
          await seedSeason(db, contentId: contentId, episodeCount: 1);
      // Episode completo.
      await repo.updateProgress(
        seasonId: seasonId,
        episodeNumber: 1,
        positionSeconds: 1440,
        durationSeconds: 1440,
      );

      final list = await repo.getInProgressContents();
      expect(list, isEmpty,
          reason: 'ep completo não conta como em andamento');
    });

    test('EXCLUI anime com positionSeconds = 0 (nunca assistido)', () async {
      final contentId = await seedContent(db);
      await seedSeason(db, contentId: contentId, episodeCount: 1);
      // (não chama updateProgress → positionSeconds fica 0)

      final list = await repo.getInProgressContents();
      expect(list, isEmpty);
    });

    test('EXCLUI anime com isAvailable = false (removido do servidor)', () async {
      final contentId = await seedContent(db);
      final (_, seasonId) =
          await seedSeason(db, contentId: contentId, episodeCount: 1);
      await repo.updateProgress(
        seasonId: seasonId,
        episodeNumber: 1,
        positionSeconds: 720,
        durationSeconds: 1440,
      );
      // Marca content como indisponível.
      await (db.update(db.pauloFlixContent)
            ..where((t) => t.id.equals(contentId)))
          .write(const PauloFlixContentCompanion(isAvailable: Value(false)));

      final list = await repo.getInProgressContents();
      expect(list, isEmpty);
    });

    test('ordena por MAX(episode.lastWatched) DESC', () async {
      // 3 animes, cada um com 1 episode parcialmente assistido.
      // Assistido em momentos diferentes → deve vir mais recente primeiro.
      final c1 = await seedContent(db, name: 'A1');
      final (_, s1) = await seedSeason(db, contentId: c1, episodeCount: 1);
      final c2 = await seedContent(db, name: 'A2');
      final (_, s2) = await seedSeason(db, contentId: c2, episodeCount: 1);
      final c3 = await seedContent(db, name: 'A3');
      final (_, s3) = await seedSeason(db, contentId: c3, episodeCount: 1);

      // c1 assistido primeiro (mais antigo)
      await repo.updateProgress(
        seasonId: s1,
        episodeNumber: 1,
        positionSeconds: 100,
        durationSeconds: 1440,
      );
      // Pequeno delay para garantir lastWatched distinto.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      // c2 assistido segundo
      await repo.updateProgress(
        seasonId: s2,
        episodeNumber: 1,
        positionSeconds: 100,
        durationSeconds: 1440,
      );
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      // c3 assistido por último (mais recente)
      await repo.updateProgress(
        seasonId: s3,
        episodeNumber: 1,
        positionSeconds: 100,
        durationSeconds: 1440,
      );

      final list = await repo.getInProgressContents();
      expect(list, hasLength(3));
      // c3 (mais recente) primeiro, c1 (mais antigo) por último.
      expect(list.map((c) => c.folderName).toList(), ['A3', 'A2', 'A1']);
    });

    test('respeita o limit', () async {
      // Cria 5 animes, cada um com 1 episode parcial.
      for (var i = 0; i < 5; i++) {
        final c = await seedContent(db, name: 'A$i');
        final (_, s) = await seedSeason(db, contentId: c, episodeCount: 1);
        await repo.updateProgress(
          seasonId: s,
          episodeNumber: 1,
          positionSeconds: 100,
          durationSeconds: 1440,
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final list = await repo.getInProgressContents(limit: 3);
      expect(list, hasLength(3));
    });
  });

  group('Streams (reatividade)', () {
    late AppDatabase db;
    late PauloFlixEpisodeProgressRepository repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = PauloFlixEpisodeProgressRepositoryImpl(db);
    });

    tearDown(() async => db.close());

    test(
      'watchInProgressContents emite novo evento ao adicionar episode parcial',
      () async {
        final contentId = await seedContent(db);
        final (_, seasonId) =
            await seedSeason(db, contentId: contentId, episodeCount: 1);

        final emissions = <int>[];
        final sub = repo.watchInProgressContents().listen((list) {
          emissions.add(list.length);
        });
        addTearDown(sub.cancel);

        // Espera primeiro evento (lista vazia).
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final initial = emissions.length;
        expect(initial, greaterThanOrEqualTo(1));
        expect(emissions.last, 0);

        // Adiciona progresso parcial → stream deve emitir nova lista.
        await repo.updateProgress(
          seasonId: seasonId,
          episodeNumber: 1,
          positionSeconds: 100,
          durationSeconds: 1440,
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(emissions.length, greaterThan(initial));
        expect(emissions.last, 1);
      },
    );

    test('watchEpisodesForSeason emite ao atualizar posição', () async {
      final contentId = await seedContent(db);
      final (_, seasonId) =
          await seedSeason(db, contentId: contentId, episodeCount: 1);

      final positions = <int>[];
      final sub = repo.watchEpisodesForSeason(seasonId).listen((eps) {
        if (eps.isNotEmpty) positions.add(eps.first.positionSeconds);
      });
      addTearDown(sub.cancel);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      await repo.updateProgress(
        seasonId: seasonId,
        episodeNumber: 1,
        positionSeconds: 500,
        durationSeconds: 1440,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(positions, contains(500));
    });
  });
}
