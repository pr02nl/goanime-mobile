import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/domain/models/pauloflix_content.dart';
import 'package:goanime/domain/models/paulo_flix_episode_record.dart';
import 'package:goanime/domain/models/paulo_flix_progress_stats.dart';
import 'package:goanime/domain/models/paulo_flix_season_record.dart';
import 'package:goanime/domain/repositories/paulo_flix_episode_progress_repository.dart';

/// Testes de **contrato** do repositório (Fase 1.2 do plano).
///
/// Esses testes validam que a interface `PauloFlixEpisodeProgressRepository`
/// tem **todos** os métodos necessários para o player, a home, e a tela
/// de episodes — e que cada um aceita os parâmetros esperados e retorna
/// o tipo correto.
///
/// **NÃO** testam lógica de negócio (update, recompute, sync) — isso é
/// coberto pelos testes do `PauloFlixEpisodeProgressRepositoryImpl`
/// (Fase 1.3). Aqui só validamos a **forma** do contrato.
///
/// Estratégia: criar um `_ContractStub` que implementa a interface e
/// delega tudo para o `AppDatabase.forTesting(NativeDatabase.memory())`,
/// exercitando as **assinaturas** de cada método sem dependências de
/// rede (sync on-demand é um no-op aqui).
void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('PauloFlixEpisodeProgressRepository — contrato', () {
    late AppDatabase db;
    late _ContractStub repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      // Cria 1 content para satisfazer FKs.
      await db.into(db.pauloFlixContent).insert(
            PauloFlixContentCompanion.insert(
              folderName: 'Test',
              displayName: 'Test',
              serverUrl: 'https://server/Test/',
              lastSynced: DateTime.now(),
            ),
          );
      repo = _ContractStub(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('expõe os 9 métodos esperados do contrato', () {
      // Validação estática: a interface tem exatamente os métodos que
      // o player, a home, e a tela de episodes esperam.
      final r = repo;
      expect(r.updateProgress, isA<Function>());
      expect(r.resetProgress, isA<Function>());
      expect(r.getStatsForContent, isA<Function>());
      expect(r.getInProgressContents, isA<Function>());
      expect(r.watchInProgressContents, isA<Function>());
      expect(r.getSeasonsForContent, isA<Function>());
      expect(r.watchSeasonsForContent, isA<Function>());
      expect(r.getEpisodesForSeason, isA<Function>());
      expect(r.watchEpisodesForSeason, isA<Function>());
      expect(r.upsertSeason, isA<Function>());
      expect(r.upsertEpisode, isA<Function>());
    });

    test('updateProgress aceita os 4 parâmetros nomeados', () async {
      // Cria 1 season para satisfazer FK.
      final seasonId = await db.into(db.pauloFlixSeasons).insert(
            PauloFlixSeasonsCompanion.insert(
              contentId: 1,
              seasonNumber: 1,
              displayName: 'S01',
              folderName: 'S01',
              lastSynced: DateTime.now(),
            ),
          );
      // Não falha (assinatura compatível com o contrato).
      await repo.updateProgress(
        seasonId: seasonId,
        episodeNumber: 1,
        positionSeconds: 100,
        durationSeconds: 1440,
      );
    });

    test('updateProgress aceita durationSeconds = null (sem info)', () async {
      final seasonId = await db.into(db.pauloFlixSeasons).insert(
            PauloFlixSeasonsCompanion.insert(
              contentId: 1,
              seasonNumber: 1,
              displayName: 'S01',
              folderName: 'S01',
              lastSynced: DateTime.now(),
            ),
          );
      // durationSeconds nullable — sem info, player não marca completo.
      await repo.updateProgress(
        seasonId: seasonId,
        episodeNumber: 1,
        positionSeconds: 100,
      );
    });

    test('resetProgress aceita os 2 parâmetros nomeados', () async {
      final seasonId = await db.into(db.pauloFlixSeasons).insert(
            PauloFlixSeasonsCompanion.insert(
              contentId: 1,
              seasonNumber: 1,
              displayName: 'S01',
              folderName: 'S01',
              lastSynced: DateTime.now(),
            ),
          );
      await repo.resetProgress(seasonId: seasonId, episodeNumber: 1);
    });

    test('getStatsForContent retorna PauloFlixProgressStats (não null)', () async {
      final stats = await repo.getStatsForContent(1);
      expect(stats, isA<PauloFlixProgressStats>());
      // Anime novo sem episodes → zeros.
      expect(stats.totalEpisodes, 0);
      expect(stats.completedEpisodes, 0);
      expect(stats.inProgressEpisodes, 0);
    });

    test('getInProgressContents aceita limit opcional (default 12)', () async {
      final list = await repo.getInProgressContents();
      expect(list, isA<List<PauloFlixContent>>());
      // Anime sem episodes parciais → lista vazia.
      expect(list, isEmpty);
    });

    test('getInProgressContents aceita limit customizado', () async {
      final list = await repo.getInProgressContents(limit: 5);
      expect(list, isA<List<PauloFlixContent>>());
    });

    test('watchInProgressContents retorna Stream<List<PauloFlixContent>>', () {
      final stream = repo.watchInProgressContents();
      expect(stream, isA<Stream<List<PauloFlixContent>>>());
    });

    test('getSeasonsForContent retorna List<PauloFlixSeasonRecord>', () async {
      final list = await repo.getSeasonsForContent(1);
      expect(list, isA<List<PauloFlixSeasonRecord>>());
      expect(list, isEmpty); // anime novo
    });

    test('watchSeasonsForContent retorna Stream<List<PauloFlixSeasonRecord>>', () {
      final stream = repo.watchSeasonsForContent(1);
      expect(stream, isA<Stream<List<PauloFlixSeasonRecord>>>());
    });

    test('getEpisodesForSeason retorna List<PauloFlixEpisodeRecord>', () async {
      final list = await repo.getEpisodesForSeason(1);
      expect(list, isA<List<PauloFlixEpisodeRecord>>());
      expect(list, isEmpty);
    });

    test(
      'watchEpisodesForSeason retorna Stream<List<PauloFlixEpisodeRecord>>',
      () {
        final stream = repo.watchEpisodesForSeason(1);
        expect(stream, isA<Stream<List<PauloFlixEpisodeRecord>>>());
      },
    );

    test('upsertSeason aceita os 4 parâmetros nomeados', () async {
      // Não falha (assinatura compatível com o contrato).
      await repo.upsertSeason(
        contentId: 1,
        seasonNumber: 1,
        displayName: 'S01',
        folderName: 'S01',
      );
    });

    test('upsertEpisode aceita os 4 parâmetros nomeados', () async {
      final seasonId = await db.into(db.pauloFlixSeasons).insert(
            PauloFlixSeasonsCompanion.insert(
              contentId: 1,
              seasonNumber: 1,
              displayName: 'S01',
              folderName: 'S01',
              lastSynced: DateTime.now(),
            ),
          );
      await repo.upsertEpisode(
        seasonId: seasonId,
        episodeNumber: 1,
        title: 'ep 1',
        videoUrl: 'https://server/ep1.mkv',
      );
    });

    test('interface é implementável (compile-time check)', () {
      // Se _ContractStub compila, a interface está bem-formada.
      final PauloFlixEpisodeProgressRepository r = _ContractStub(db);
      expect(r, isA<PauloFlixEpisodeProgressRepository>());
    });
  });
}

/// Stub mínimo que implementa a interface delega para o Drift diretamente.
/// Usado só para validar a **forma** do contrato nos testes acima.
/// A impl real (`PauloFlixEpisodeProgressRepositoryImpl`) vem na Fase 1.3.
class _ContractStub implements PauloFlixEpisodeProgressRepository {
  final AppDatabase _db;
  _ContractStub(this._db);

  @override
  Future<void> updateProgress({
    required int seasonId,
    required int episodeNumber,
    required int positionSeconds,
    int? durationSeconds,
  }) async {
    await (_db.update(_db.pauloFlixEpisodes)
          ..where((t) =>
              t.seasonId.equals(seasonId) &
              t.episodeNumber.equals(episodeNumber)))
        .write(PauloFlixEpisodesCompanion(
      positionSeconds: Value(positionSeconds),
      durationSeconds:
          durationSeconds == null ? const Value.absent() : Value(durationSeconds),
      lastWatched: Value(DateTime.now()),
    ));
  }

  @override
  Future<void> resetProgress({
    required int seasonId,
    required int episodeNumber,
  }) async {
    await (_db.update(_db.pauloFlixEpisodes)
          ..where((t) =>
              t.seasonId.equals(seasonId) &
              t.episodeNumber.equals(episodeNumber)))
        .write(const PauloFlixEpisodesCompanion(
      positionSeconds: Value(0),
      isCompleted: Value(false),
    ));
  }

  @override
  Future<PauloFlixProgressStats> getStatsForContent(int contentId) async {
    final row = await _db.customSelect(
      'SELECT '
      '  COUNT(*) AS total, '
      '  COALESCE(SUM(CASE WHEN e.is_completed = 1 THEN 1 ELSE 0 END), 0) '
      '    AS completed, '
      '  COALESCE(SUM(CASE WHEN e.position_seconds > 0 AND e.is_completed = 0 '
      '           THEN 1 ELSE 0 END), 0) AS in_progress '
      'FROM paulo_flix_episodes e '
      'INNER JOIN paulo_flix_seasons s ON e.season_id = s.id '
      'WHERE s.content_id = ?1',
      variables: [Variable.withInt(contentId)],
      readsFrom: {_db.pauloFlixEpisodes, _db.pauloFlixSeasons},
    ).getSingle();
    return PauloFlixProgressStats(
      totalEpisodes: row.read<int>('total'),
      completedEpisodes: row.read<int>('completed'),
      inProgressEpisodes: row.read<int>('in_progress'),
    );
  }

  @override
  Future<List<PauloFlixContent>> getInProgressContents({int limit = 12}) async {
    return [];
  }

  @override
  Stream<List<PauloFlixContent>> watchInProgressContents({int limit = 12}) {
    return const Stream.empty();
  }

  @override
  Future<List<PauloFlixSeasonRecord>> getSeasonsForContent(int contentId) async {
    return [];
  }

  @override
  Stream<List<PauloFlixSeasonRecord>> watchSeasonsForContent(int contentId) {
    return const Stream.empty();
  }

  @override
  Future<List<PauloFlixEpisodeRecord>> getEpisodesForSeason(int seasonId) async {
    return [];
  }

  @override
  Stream<List<PauloFlixEpisodeRecord>> watchEpisodesForSeason(int seasonId) {
    return const Stream.empty();
  }

  @override
  Future<int> upsertSeason({
    required int contentId,
    required int seasonNumber,
    required String displayName,
    required String folderName,
  }) async {
    final existing = await (_db.select(_db.pauloFlixSeasons)
          ..where((t) =>
              t.contentId.equals(contentId) &
              t.seasonNumber.equals(seasonNumber))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    return _db.into(_db.pauloFlixSeasons).insert(
          PauloFlixSeasonsCompanion.insert(
            contentId: contentId,
            seasonNumber: seasonNumber,
            displayName: displayName,
            folderName: folderName,
            lastSynced: DateTime.now(),
          ),
        );
  }

  @override
  Future<void> upsertEpisode({
    required int seasonId,
    required int episodeNumber,
    required String title,
    required String videoUrl,
  }) async {
    final existing = await (_db.select(_db.pauloFlixEpisodes)
          ..where((t) =>
              t.seasonId.equals(seasonId) &
              t.episodeNumber.equals(episodeNumber))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return;
    await _db.into(_db.pauloFlixEpisodes).insert(
          PauloFlixEpisodesCompanion.insert(
            seasonId: seasonId,
            episodeNumber: episodeNumber,
            title: title,
            videoUrl: videoUrl,
            lastSynced: DateTime.now(),
          ),
        );
  }

  @override
  Future<void> updateSeasonCount(int seasonId, int count) async {
    await (_db.update(_db.pauloFlixSeasons)
          ..where((t) => t.id.equals(seasonId)))
        .write(PauloFlixSeasonsCompanion(
      episodeCount: Value(count),
    ));
  }
}
