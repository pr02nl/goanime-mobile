import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/data/repositories/paulo_flix_episode_progress_repository_impl.dart';
import 'package:goanime/data/services/paulo_flix_episode_sync_service.dart';
import 'package:goanime/domain/repositories/paulo_flix_episode_progress_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Testes do `PauloFlixEpisodeSyncService.reconcileSeasonEpisodes` (Fase 2).
///
/// Cenários cobertos:
/// - Re-sync preserva `positionSeconds`/`isCompleted` (já existia)
/// - Re-sync com season renomeada (mudou pasta): atualiza
///   `folderName`/`displayName` mantendo progresso
/// - Server removeu season sem progresso → deletada
/// - Server removeu season COM progresso → MANTIDA (segurança)
/// - Server removeu episode sem progresso → deletado
/// - Server removeu episode COM progresso → MANTIDO
/// - Stats retornadas batem com o que aconteceu
void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  String buildListingHtml(List<String> folderNames) {
    final links = folderNames.map((name) => '<a href="$name/">$name</a>').join('\n');
    return '''
<!DOCTYPE html>
<html><body>
<h1>Index</h1>
$links
</body></html>
''';
  }

  String buildEpisodesHtml(List<String> fileNames) {
    final links = fileNames.map((name) => '<a href="$name">$name</a>').join('\n');
    return '''
<!DOCTYPE html>
<html><body>
<h1>Index</h1>
$links
</body></html>
''';
  }

  group('PauloFlixEpisodeSyncService.reconcileSeasonEpisodes', () {
    late AppDatabase db;
    late PauloFlixEpisodeProgressRepository repo;
    late PauloFlixEpisodeSyncService service;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = PauloFlixEpisodeProgressRepositoryImpl(db);
    });

    tearDown(() async => db.close());

    /// Cria o service com um handler que roteia por URL. Retorna a
    /// lista de requests capturados para asserções.
    List<http.BaseRequest> setupService(
      Future<http.Response> Function(http.BaseRequest, String) handler,
    ) {
      final capturedRequests = <http.BaseRequest>[];
      final mockClient = MockClient((req) async {
        capturedRequests.add(req);
        return handler(req, req.url.toString());
      });
      service = PauloFlixEpisodeSyncService(repo, httpClient: mockClient);
      return capturedRequests;
    }

    test('season renomeada: atualiza folderName mantendo progresso', () async {
      // Setup: Naruto com season 01 já existente.
      final contentId = await db.into(db.pauloFlixContent).insert(
            PauloFlixContentCompanion.insert(
              folderName: 'Naruto',
              displayName: 'Naruto',
              serverUrl: 'https://server/Naruto/',
              lastSynced: DateTime.now(),
            ),
          );
      final seasonId = await db.into(db.pauloFlixSeasons).insert(
            PauloFlixSeasonsCompanion.insert(
              contentId: contentId,
              seasonNumber: 1,
              displayName: 'Season 01',
              folderName: 'Season 01',
              lastSynced: DateTime(2020),
            ),
          );
      await db.into(db.pauloFlixEpisodes).insert(
            PauloFlixEpisodesCompanion.insert(
              seasonId: seasonId,
              episodeNumber: 1,
              title: 'ep 1',
              videoUrl: 'https://server/Naruto/Season%2001/S01E01.mkv',
              positionSeconds: const Value(600),
              durationSeconds: const Value(1200),
              lastSynced: DateTime(2020),
            ),
          );

      // Mock: server agora retorna "Season 01 - East Blue" (renomeou).
      setupService((req, url) async {
        if (url == 'https://server/Naruto/') {
          return http.Response(
            buildListingHtml(['Season 01 - East Blue']),
            200,
          );
        }
        if (url.contains('Season%2001%20-%20East%20Blue')) {
          return http.Response(
            buildEpisodesHtml(['S01E01.mkv']),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final stats = await service.reconcileSeasonEpisodes(
        contentId: contentId,
        contentServerUrl: 'https://server/Naruto/',
      );

      // Verifica: folderName atualizada, progresso preservado.
      final updatedSeason = await (db.select(db.pauloFlixSeasons)).getSingle();
      expect(updatedSeason.folderName, 'Season 01 - East Blue');
      expect(updatedSeason.displayName, 'Season 01 - East Blue');
      final ep = await (db.select(db.pauloFlixEpisodes)).getSingle();
      expect(ep.positionSeconds, 600,
          reason: 'positionSeconds preservado');
      expect(ep.durationSeconds, 1200);
      expect(stats.seasonsRemoved, 0);
      expect(stats.episodesRemoved, 0);
    });

    test('season removida do servidor + COM progresso → MANTIDA (segurança)', () async {
      final contentId = await db.into(db.pauloFlixContent).insert(
            PauloFlixContentCompanion.insert(
              folderName: 'Bleach',
              displayName: 'Bleach',
              serverUrl: 'https://server/Bleach/',
              lastSynced: DateTime.now(),
            ),
          );
      final seasonId = await db.into(db.pauloFlixSeasons).insert(
            PauloFlixSeasonsCompanion.insert(
              contentId: contentId,
              seasonNumber: 1,
              displayName: 'S01',
              folderName: 'S01',
              lastSynced: DateTime.now(),
            ),
          );
      await db.into(db.pauloFlixEpisodes).insert(
            PauloFlixEpisodesCompanion.insert(
              seasonId: seasonId,
              episodeNumber: 1,
              title: 'ep 1',
              videoUrl: 'https://server/Bleach/S01/S01E01.mkv',
              positionSeconds: const Value(600), // tem progresso
              lastSynced: DateTime.now(),
            ),
          );

      // Server retorna VAZIO (a season S01 sumiu).
      setupService((req, url) async => http.Response(buildListingHtml([]), 200));

      final stats = await service.reconcileSeasonEpisodes(
        contentId: contentId,
        contentServerUrl: 'https://server/Bleach/',
      );

      // Season mantida (progresso), mas stats devem reportar 1 kept.
      final seasons = await db.select(db.pauloFlixSeasons).get();
      expect(seasons, hasLength(1), reason: 'season COM progresso mantida');
      expect(stats.seasonsRemoved, 0);
      expect(stats.seasonsKept, 1);
    });

    test('season removida do servidor + sem progresso → REMOVIDA', () async {
      final contentId = await db.into(db.pauloFlixContent).insert(
            PauloFlixContentCompanion.insert(
              folderName: 'HxH',
              displayName: 'Hunter x Hunter',
              serverUrl: 'https://server/HxH/',
              lastSynced: DateTime.now(),
            ),
          );
      final seasonId = await db.into(db.pauloFlixSeasons).insert(
            PauloFlixSeasonsCompanion.insert(
              contentId: contentId,
              seasonNumber: 1,
              displayName: 'S01',
              folderName: 'S01',
              lastSynced: DateTime.now(),
            ),
          );
      // Episode SEM progresso.
      await db.into(db.pauloFlixEpisodes).insert(
            PauloFlixEpisodesCompanion.insert(
              seasonId: seasonId,
              episodeNumber: 1,
              title: 'ep 1',
              videoUrl: 'https://server/HxH/S01/S01E01.mkv',
              lastSynced: DateTime.now(),
            ),
          );

      // Server retorna VAZIO.
      setupService((req, url) async => http.Response(buildListingHtml([]), 200));

      final stats = await service.reconcileSeasonEpisodes(
        contentId: contentId,
        contentServerUrl: 'https://server/HxH/',
      );

      expect(stats.seasonsRemoved, 1);
      expect(stats.seasonsKept, 0);
      final seasons = await db.select(db.pauloFlixSeasons).get();
      expect(seasons, isEmpty);
      // Cascade: episodes também sumiram.
      final eps = await db.select(db.pauloFlixEpisodes).get();
      expect(eps, isEmpty);
    });

    test('episode removido do servidor + COM progresso → MANTIDO', () async {
      final contentId = await db.into(db.pauloFlixContent).insert(
            PauloFlixContentCompanion.insert(
              folderName: 'OP',
              displayName: 'One Piece',
              serverUrl: 'https://server/OP/',
              lastSynced: DateTime.now(),
            ),
          );
      final seasonId = await db.into(db.pauloFlixSeasons).insert(
            PauloFlixSeasonsCompanion.insert(
              contentId: contentId,
              seasonNumber: 1,
              displayName: 'S01',
              folderName: 'S01',
              lastSynced: DateTime.now(),
            ),
          );
      await db.into(db.pauloFlixEpisodes).insert(
            PauloFlixEpisodesCompanion.insert(
              seasonId: seasonId,
              episodeNumber: 1,
              title: 'ep 1',
              videoUrl: 'a.mkv',
              positionSeconds: const Value(500), // progresso
              lastSynced: DateTime.now(),
            ),
          );
      await db.into(db.pauloFlixEpisodes).insert(
            PauloFlixEpisodesCompanion.insert(
              seasonId: seasonId,
              episodeNumber: 2,
              title: 'ep 2',
              videoUrl: 'b.mkv',
              lastSynced: DateTime.now(),
            ),
          );

      // Server: season 1 com SÓ o ep 2 (ep 1 sumiu).
      setupService((req, url) async {
        if (url == 'https://server/OP/') {
          return http.Response(buildListingHtml(['S01']), 200);
        }
        return http.Response(buildEpisodesHtml(['S01E02.mkv']), 200);
      });

      final stats = await service.reconcileSeasonEpisodes(
        contentId: contentId,
        contentServerUrl: 'https://server/OP/',
      );

      // ep 1 mantido (progresso), ep 2 mantido (scraped).
      expect(stats.episodesRemoved, 0);
      expect(stats.episodesKept, 1, reason: 'ep 1 mantido por progresso');
      final eps = await (db.select(db.pauloFlixEpisodes)
            ..orderBy([(t) => OrderingTerm(expression: t.episodeNumber)]))
          .get();
      expect(eps, hasLength(2));
      expect(eps[0].episodeNumber, 1);
      expect(eps[0].positionSeconds, 500);
      expect(eps[1].episodeNumber, 2);
    });

    test('episode removido do servidor + sem progresso → REMOVIDO', () async {
      final contentId = await db.into(db.pauloFlixContent).insert(
            PauloFlixContentCompanion.insert(
              folderName: 'Boruto',
              displayName: 'Boruto',
              serverUrl: 'https://server/Boruto/',
              lastSynced: DateTime.now(),
            ),
          );
      final seasonId = await db.into(db.pauloFlixSeasons).insert(
            PauloFlixSeasonsCompanion.insert(
              contentId: contentId,
              seasonNumber: 1,
              displayName: 'S01',
              folderName: 'S01',
              lastSynced: DateTime.now(),
            ),
          );
      // 3 episodes, todos sem progresso.
      for (final n in [1, 2, 3]) {
        await db.into(db.pauloFlixEpisodes).insert(
              PauloFlixEpisodesCompanion.insert(
                seasonId: seasonId,
                episodeNumber: n,
                title: 'ep $n',
                videoUrl: 'a.mkv',
                lastSynced: DateTime.now(),
              ),
            );
      }

      // Server: só tem ep 1 e 3 — ep 2 sumiu.
      setupService((req, url) async {
        if (url == 'https://server/Boruto/') {
          return http.Response(buildListingHtml(['S01']), 200);
        }
        return http.Response(
          buildEpisodesHtml(['S01E01.mkv', 'S01E03.mkv']),
          200,
        );
      });

      final stats = await service.reconcileSeasonEpisodes(
        contentId: contentId,
        contentServerUrl: 'https://server/Boruto/',
      );

      expect(stats.episodesRemoved, 1, reason: 'ep 2 removido (sem progresso)');
      final eps = await (db.select(db.pauloFlixEpisodes)
            ..orderBy([(t) => OrderingTerm(expression: t.episodeNumber)]))
          .get();
      expect(eps, hasLength(2));
      expect(eps.map((e) => e.episodeNumber), [1, 3]);
    });
  });
}
