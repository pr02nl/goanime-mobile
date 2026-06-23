import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/data/repositories/paulo_flix_episode_progress_repository_impl.dart';
import 'package:goanime/data/services/paulo_flix_episode_sync_service.dart';
import 'package:goanime/domain/repositories/paulo_flix_episode_progress_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Testes do `PauloFlixEpisodeSyncService` (Fase 1.4 do plano).
///
/// Estratégia: HTTP mockado com `MockClient` (mesmo padrão do
/// `TmdbService` test). Verifica que:
/// - GET show URL → parse HTML → extrai seasons → upsertSeason.
/// - GET season URL → parse HTML → extrai episodes → upsertEpisode.
/// - Re-sync preserva `positionSeconds`/`isCompleted` (não sobrescreve).
/// - Status code != 200 lança exceção.
void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  // Helper: HTML típico de uma listagem nginx/apache.
  String buildListingHtml(List<String> folderNames) {
    final links = folderNames
        .map((name) => '<a href="$name/">$name</a>')
        .join('\n');
    return '''
<!DOCTYPE html>
<html>
<head><title>Index of /tvshows/Naruto/</title></head>
<body>
<h1>Index of /tvshows/Naruto/</h1>
$links
</body>
</html>
''';
  }

  // Helper: HTML típico de uma listagem de episodes (com arquivos .mkv).
  String buildEpisodesHtml(List<String> fileNames) {
    final links = fileNames
        .map((name) => '<a href="$name">$name</a>')
        .join('\n');
    return '''
<!DOCTYPE html>
<html>
<head><title>Index of /tvshows/Naruto/Season 01/</title></head>
<body>
<h1>Index of /tvshows/Naruto/Season 01/</h1>
$links
</body>
</html>
''';
  }

  group('PauloFlixEpisodeSyncService', () {
    late AppDatabase db;
    late PauloFlixEpisodeProgressRepository repo;
    late PauloFlixEpisodeSyncService service;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = PauloFlixEpisodeProgressRepositoryImpl(db);
    });

    tearDown(() async => db.close());

    /// Cria o service com um handler que roteia por URL. Retorna a lista
    /// de requests capturados para asserções.
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

    test('syncSeasonEpisodes busca seasons + episodes e chama upsert*', () async {
      // Setup content.
      final contentId = await db.into(db.pauloFlixContent).insert(
            PauloFlixContentCompanion.insert(
              folderName: 'Naruto',
              displayName: 'Naruto',
              serverUrl: 'https://server/Naruto/',
              lastSynced: DateTime.now(),
            ),
          );

      // Mock: show URL → lista com 2 seasons; cada season → episodes.
      final requests = setupService((req, url) async {
        if (url == 'https://server/Naruto/') {
          return http.Response(
            buildListingHtml(['Season 01', 'Season 02']),
            200,
          );
        }
        if (url == 'https://server/Naruto/Season%2001/') {
          return http.Response(
            buildEpisodesHtml(['S01E01.mkv', 'S01E02.mkv', 'S01E03.mkv']),
            200,
          );
        }
        if (url == 'https://server/Naruto/Season%2002/') {
          return http.Response(
            buildEpisodesHtml(['S02E01.mkv']),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      await service.syncSeasonEpisodes(
        contentId: contentId,
        contentServerUrl: 'https://server/Naruto/',
      );

      // Verifica que fez 3 GETs: 1 show + 2 seasons.
      expect(requests, hasLength(3));
      expect(requests[0].url.toString(), 'https://server/Naruto/');
      expect(requests[1].url.path, contains('Season%2001'));
      expect(requests[2].url.path, contains('Season%2002'));

      // Verifica que 2 seasons + 4 episodes foram inseridas.
      final seasons = await (db.select(db.pauloFlixSeasons)
            ..where((t) => t.contentId.equals(contentId))
            ..orderBy([(t) => OrderingTerm(expression: t.seasonNumber)]))
          .get();
      expect(seasons, hasLength(2));
      expect(seasons[0].seasonNumber, 1);
      expect(seasons[0].episodeCount, 3);
      expect(seasons[1].seasonNumber, 2);
      expect(seasons[1].episodeCount, 1);

      final s1Episodes = await (db.select(db.pauloFlixEpisodes)
            ..where((t) => t.seasonId.equals(seasons[0].id))
            ..orderBy([(t) => OrderingTerm(expression: t.episodeNumber)]))
          .get();
      expect(s1Episodes, hasLength(3));
      expect(s1Episodes[0].episodeNumber, 1);
      expect(s1Episodes[0].title, 'Episode 01');
      expect(s1Episodes[0].videoUrl, contains('S01E01.mkv'));
    });

    test('preserva positionSeconds/isCompleted em re-sync', () async {
      // Setup: content + season + 1 episode já assistido.
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
              episodeCount: const Value(1),
              lastSynced: DateTime.now(),
            ),
          );
      await db.into(db.pauloFlixEpisodes).insert(
            PauloFlixEpisodesCompanion.insert(
              seasonId: seasonId,
              episodeNumber: 1,
              title: 'ep 1 - título antigo',
              videoUrl: 'https://server/Bleach/S01/old-name.mkv',
              positionSeconds: const Value(720),
              durationSeconds: const Value(1440),
              isCompleted: const Value(false),
              lastWatched: Value(DateTime(2026, 6, 1, 10, 0)),
              lastSynced: DateTime.now(),
            ),
          );

      // Re-sync: mesmo episode, mas título/URL diferentes (servidor renomeou).
      setupService((req, url) async {
        if (url == 'https://server/Bleach/') {
          return http.Response(
            buildListingHtml(['Season 01']),
            200,
          );
        }
        // season URL
        return http.Response(
          buildEpisodesHtml(['S01E01 - novo título.mkv']),
          200,
        );
      });

      await service.syncSeasonEpisodes(
        contentId: contentId,
        contentServerUrl: 'https://server/Bleach/',
      );

      // Verifica que:
      // 1. title/videoUrl foram ATUALIZADOS (do scraping novo)
      // 2. positionSeconds/isCompleted/lastWatched foram PRESERVADOS
      final seasonRow = await (db.select(db.pauloFlixSeasons)).getSingle();
      final ep = await (db.select(db.pauloFlixEpisodes)
            ..where((t) => t.seasonId.equals(seasonRow.id)))
          .getSingle();
      expect(ep.title, contains('novo título'),
          reason: 'title deve ser atualizado do scrape');
      expect(ep.videoUrl, contains('S01E01'));
      expect(ep.positionSeconds, 720,
          reason: 'positionSeconds deve ser PRESERVADO');
      expect(ep.durationSeconds, 1440,
          reason: 'durationSeconds deve ser PRESERVADO');
      expect(ep.isCompleted, false,
          reason: 'isCompleted deve ser PRESERVADO');
      expect(ep.lastWatched, isNotNull,
          reason: 'lastWatched deve ser PRESERVADO');
    });

    test('decodifica URL-encoded folder names (S01E01%20-%20Title.mkv)',
        () async {
      final contentId = await db.into(db.pauloFlixContent).insert(
            PauloFlixContentCompanion.insert(
              folderName: 'HxH',
              displayName: 'Hunter x Hunter',
              serverUrl: 'https://server/HxH/',
              lastSynced: DateTime.now(),
            ),
          );
      setupService((req, url) async {
        if (url == 'https://server/HxH/') {
          return http.Response(
            buildListingHtml(['Season 01']),
            200,
          );
        }
        return http.Response(
          buildEpisodesHtml([
            // URL-encoded: espaço = %20, hífen = %2D, etc.
            'S01E01%20-%20Pilot.mkv',
          ]),
          200,
        );
      });

      await service.syncSeasonEpisodes(
        contentId: contentId,
        contentServerUrl: 'https://server/HxH/',
      );

      final ep = await (db.select(db.pauloFlixEpisodes)).getSingle();
      expect(ep.title, contains('Pilot'));
    });

    test('lança exceção quando GET da show URL falha (status != 200)', () async {
      final contentId = await db.into(db.pauloFlixContent).insert(
            PauloFlixContentCompanion.insert(
              folderName: 'Offline',
              displayName: 'Offline',
              serverUrl: 'https://server/Offline/',
              lastSynced: DateTime.now(),
            ),
          );
      setupService((req, url) async {
        return http.Response('Internal Server Error', 500);
      });

      expect(
        () => service.syncSeasonEpisodes(
          contentId: contentId,
          contentServerUrl: 'https://server/Offline/',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('extrai season number de "S01 - East Blue"', () async {
      final contentId = await db.into(db.pauloFlixContent).insert(
            PauloFlixContentCompanion.insert(
              folderName: 'OnePiece',
              displayName: 'One Piece',
              serverUrl: 'https://server/OnePiece/',
              lastSynced: DateTime.now(),
            ),
          );
      setupService((req, url) async {
        if (url == 'https://server/OnePiece/') {
          return http.Response(
            buildListingHtml(['S01%20-%20East%20Blue']),
            200,
          );
        }
        return http.Response(buildEpisodesHtml(['S01E01.mkv']), 200);
      });

      await service.syncSeasonEpisodes(
        contentId: contentId,
        contentServerUrl: 'https://server/OnePiece/',
      );

      final season = await (db.select(db.pauloFlixSeasons)).getSingle();
      expect(season.seasonNumber, 1,
          reason: 'regex S01 deve extrair número 1 mesmo com sufixo');
    });

    test('extrai episode number de "E05" (sem prefixo Sxx)', () async {
      final contentId = await db.into(db.pauloFlixContent).insert(
            PauloFlixContentCompanion.insert(
              folderName: 'LooseEpisodes',
              displayName: 'Loose Episodes',
              serverUrl: 'https://server/LooseEpisodes/',
              lastSynced: DateTime.now(),
            ),
          );
      setupService((req, url) async {
        if (url == 'https://server/LooseEpisodes/') {
          return http.Response(
            buildListingHtml(['Season 01']),
            200,
          );
        }
        return http.Response(
          // Sem Sxx — só Exx.
          buildEpisodesHtml(['E05.mkv', 'E06.mkv']),
          200,
        );
      });

      await service.syncSeasonEpisodes(
        contentId: contentId,
        contentServerUrl: 'https://server/LooseEpisodes/',
      );

      final eps = await (db.select(db.pauloFlixEpisodes)
            ..orderBy([(t) => OrderingTerm(expression: t.episodeNumber)]))
          .get();
      expect(eps, hasLength(2));
      expect(eps[0].episodeNumber, 5);
      expect(eps[1].episodeNumber, 6);
    });
  });
}
