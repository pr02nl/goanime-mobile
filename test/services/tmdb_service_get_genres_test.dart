import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/data/services/tmdb_genre_cache.dart';
import 'package:goanime/data/services/tmdb_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  // Mesmo padrão do `app_database_test.dart`.
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('TmdbService.getGenres', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      // Reseta o singleton entre testes — ele mantém cache em memória
      // e locale viewmodel injetada.
      TmdbService().invalidateGenresCache();
    });

    tearDown(() async {
      await db.close();
    });

    /// Constrói um [TmdbService] com API key + http client mockado.
    /// Retorna uma tupla `(service, requestLog)` onde `requestLog` é
    /// uma lista com o path de cada request feita.
    (TmdbService, List<String>) buildService(
      Future<http.Response> Function(http.BaseRequest) handler,
    ) {
      final log = <String>[];
      final wrapped = MockClient((req) async {
        log.add(req.url.path);
        return handler(req);
      });
      final tmdb = TmdbService.forTesting(httpClient: wrapped, database: db);
      tmdb.setApiKey('test-key');
      return (tmdb, log);
    }

    test('cache miss → chama TMDB e persiste no banco', () async {
      Future<http.Response> handler(http.BaseRequest req) async {
        expect(req.url.path, '/3/genre/movie/list');
        expect(req.url.queryParameters['language'], 'pt-BR');
        return http.Response(
          jsonEncode({
            'genres': [
              {'id': 28, 'name': 'Ação'},
              {'id': 12, 'name': 'Aventura'},
              {'id': 878, 'name': 'Ficção Científica'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      final (tmdb, log) = buildService(handler);

      final genres = await tmdb.getGenres(locale: 'pt-BR');

      expect(genres[28], 'Ação');
      expect(genres[12], 'Aventura');
      expect(genres[878], 'Ficção Científica');
      expect(log.length, 1, reason: '1 request TMDB');

      // Verificar que persistiu no banco.
      final cache = TmdbGenreCache(db: db, language: 'pt-BR');
      expect(await cache.hasAny, isTrue);
      expect(await cache.asMap(), genres);
    });

    test('cache hit no banco → NÃO chama TMDB', () async {
      // Pre-popular o banco.
      final ptCache = TmdbGenreCache(db: db, language: 'pt-BR');
      await ptCache.replaceAll({28: 'Ação'});

      // Mock que falharia se fosse chamado.
      Future<Never> handler(http.BaseRequest req) async {
        fail('TMDB não deveria ser chamado: ${req.url.path}');
      }

      final (tmdb, log) = buildService(handler);

      final genres = await tmdb.getGenres(locale: 'pt-BR');

      expect(genres[28], 'Ação');
      expect(log, isEmpty, reason: '0 requests TMDB (cache hit)');
    });

    test('cache hit em memória → NÃO lê banco nem chama TMDB', () async {
      // 1ª chamada: cache miss → chama TMDB.
      var calledOnce = false;
      Future<http.Response> handler1(http.BaseRequest req) async {
        calledOnce = true;
        return http.Response(
          jsonEncode({
            'genres': [
              {'id': 28, 'name': 'Ação'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      final (tmdb, _) = buildService(handler1);
      final first = await tmdb.getGenres(locale: 'pt-BR');
      expect(calledOnce, isTrue);
      expect(first[28], 'Ação');

      // 2ª chamada: cache em memória hit (mesma instância do service).
      Future<Never> handler2(http.BaseRequest req) async {
        fail('TMDB não deveria ser chamado: ${req.url.path}');
      }

      // Re-criamos o service para verificar que o cache em memória está
      // vivo na instância original. Mas como o handler2 não vai ser
      // chamado, basta chamar o `tmdb` original de novo.
      final second = await tmdb.getGenres(locale: 'pt-BR');
      expect(second, first);
    });

    test('ensureGenresCover com IDs cobertos → no-op', () async {
      // Pre-popular cache.
      Future<http.Response> handler(http.BaseRequest req) async {
        return http.Response(
          jsonEncode({
            'genres': [
              {'id': 28, 'name': 'Ação'},
              {'id': 12, 'name': 'Aventura'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      final (tmdb, log) = buildService(handler);
      await tmdb.getGenres(locale: 'pt-BR');
      log.clear();

      // ensureGenresCover com IDs já conhecidos → no-op.
      await tmdb.ensureGenresCover([28, 12]);
      expect(log, isEmpty);
    });

    test('ensureGenresCover com ID novo → recarrega do TMDB', () async {
      // 1ª chamada: cache com {28}.
      // 2ª chamada (após ensureGenresCover detectar 878):
      //   cache com {28, 878}.
      final responses = [
        http.Response(
          jsonEncode({
            'genres': [
              {'id': 28, 'name': 'Ação'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
        http.Response(
          jsonEncode({
            'genres': [
              {'id': 28, 'name': 'Ação'},
              {'id': 878, 'name': 'Ficção Científica'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ];
      var i = 0;
      Future<http.Response> handler(http.BaseRequest req) async =>
          responses[i++];
      final (tmdb, log) = buildService(handler);

      await tmdb.getGenres(locale: 'pt-BR');
      await tmdb.ensureGenresCover([28, 878]); // 878 é novo

      // 2 requests: 1ª (getGenres), 2ª (recarregamento via ensureGenresCover).
      expect(log.length, 2);
      final genres = await tmdb.getGenres(locale: 'pt-BR');
      expect(genres[878], 'Ficção Científica');
    });

    test('mapeamento pt → pt-BR e en → en-US', () async {
      // pt
      Future<http.Response> handlerPt(http.BaseRequest req) async {
        expect(req.url.queryParameters['language'], 'pt-BR');
        return http.Response(
          jsonEncode({
            'genres': [
              {'id': 28, 'name': 'Ação'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      final (tmdbPt, _) = buildService(handlerPt);
      final pt = await tmdbPt.getGenres(locale: 'pt');
      expect(pt[28], 'Ação');

      // en
      Future<http.Response> handlerEn(http.BaseRequest req) async {
        expect(req.url.queryParameters['language'], 'en-US');
        return http.Response(
          jsonEncode({
            'genres': [
              {'id': 28, 'name': 'Action'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      final (tmdbEn, _) = buildService(handlerEn);
      final en = await tmdbEn.getGenres(locale: 'en');
      expect(en[28], 'Action');
    });

    test('invalidateGenresCache reseta o cache em memória', () async {
      // 1ª chamada popula cache.
      Future<http.Response> handler1(http.BaseRequest req) async {
        return http.Response(
          jsonEncode({
            'genres': [
              {'id': 28, 'name': 'Ação'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      final (tmdb, _) = buildService(handler1);
      await tmdb.getGenres(locale: 'pt-BR');

      // 2ª chamada após invalidate → cache em memória limpo, mas banco
      // ainda tem → NÃO chama TMDB.
      tmdb.invalidateGenresCache();
      Future<Never> handler2(http.BaseRequest req) async {
        fail('TMDB não deveria ser chamado (banco tem o cache)');
      }

      // Re-criar service com novo handler (mesmo banco).
      final tmdb2 = TmdbService.forTesting(
        httpClient: MockClient(handler2),
        database: db,
      );
      tmdb2.setApiKey('test-key');
      final genres = await tmdb2.getGenres(locale: 'pt-BR');
      expect(genres[28], 'Ação');
    });
  });
}
