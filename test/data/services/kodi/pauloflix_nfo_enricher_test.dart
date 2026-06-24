// Testes do `PauloFlixNfoEnricher` (Fase 2 do plano NFO enrichment).
//
// Estratégia TDD red → impl → green. Estes testes são escritos ANTES
// da implementação e devem FALHAR (RED) até que o enricher seja criado.
//
// Cobre:
//   - `fetchShowNfo` (tvshow.nfo): 6 casos — HTTP 200, 404, 500, timeout,
//     body vazio, XML inválido.
//   - `fetchMovieNfo` (movie.nfo): 4 casos — HTTP 200, 404, URL absoluta
//     vs path relativo, parse fail.
//   - `fetchEpisodeThumbs` (listing HTML): 4 casos — 1 thumb, 3 thumbs,
//     sem thumb, dedup (S01E001 vs S01E01).
//   - `fetchSeasonNfo` (season.nfo): 3 casos — season válida, 404, parse fail.
//   - `resolveThumbUrl` (helper estático): 2 casos — URL absoluta, path relativo.
// Total: 19+ casos.
//
// Ver plano `.hermes/plans/2026-06-23_224213-pauloflix-nfo-enrichment.md`.

import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/data/services/kodi/pauloflix_nfo_enricher.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// XML de tvshow.nfo válido usado em múltiplos testes.
const _validTvshowNfo = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<tvshow>
  <title>Mushoku Tensei</title>
  <plot>Um homem... reencarna em outro mundo.</plot>
  <genre>Action</genre>
  <genre>Adventure</genre>
  <year>2021</year>
  <rating>8.4</rating>
  <thumb aspect="poster">poster.jpg</thumb>
  <thumb aspect="fanart">fanart.jpg</thumb>
</tvshow>
''';

/// XML de movie.nfo válido usado em múltiplos testes.
const _validMovieNfo = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<movie>
  <title>Akira</title>
  <plot>Um motociclista... poderes telecinéticos.</plot>
  <genre>Action</genre>
  <year>1988</year>
  <rating>8.1</rating>
  <thumb aspect="poster">poster.jpg</thumb>
</movie>
''';

/// XML de season.nfo válido.
const _validSeasonNfo = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<season>
  <season>1</season>
  <plot>Primeira season de Mushoku Tensei.</plot>
</season>
''';

void main() {
  // ============================================================
  // PauloFlixNfoEnricher.fetchShowNfo
  // ============================================================
  group('PauloFlixNfoEnricher.fetchShowNfo', () {
    test('returns KodiShowNfo on HTTP 200 with valid XML', () async {
      final client = MockClient((request) async {
        // Espera GET .../tvshow.nfo
        expect(request.url.path, endsWith('tvshow.nfo'));
        expect(request.method, 'GET');
        return http.Response(_validTvshowNfo, 200,
            headers: {'content-type': 'application/xml'});
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final nfo = await enricher.fetchShowNfo('http://server/anime/');

      expect(nfo, isNotNull);
      expect(nfo!.title, equals('Mushoku Tensei'));
      expect(nfo.plot, contains('reencarna'));
      expect(nfo.genres, equals(['Action', 'Adventure']));
      expect(nfo.year, equals(2021));
      expect(nfo.rating, closeTo(8.4, 0.01));
      expect(nfo.posterThumb, equals('poster.jpg'));
      expect(nfo.fanartThumb, equals('fanart.jpg'));
    });

    test('returns null on HTTP 404', () async {
      final client = MockClient((request) async {
        return http.Response('Not Found', 404);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final nfo = await enricher.fetchShowNfo('http://server/anime/');

      expect(nfo, isNull);
    });

    test('returns null on HTTP 500', () async {
      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final nfo = await enricher.fetchShowNfo('http://server/anime/');

      expect(nfo, isNull);
    });

    test('returns null on HTTP timeout (>10s)', () async {
      // MockClient que nunca responde antes do timeout.
      final client = MockClient((request) async {
        // Sleep > 10s para forçar o timeout interno do enricher.
        await Future<void>.delayed(const Duration(seconds: 12));
        return http.Response('ok', 200);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      // wrap em um timeout nosso para não ficar pendurado no test runner
      // se o enricher por algum motivo não tiver o .timeout(10s).
      final nfo = await enricher
          .fetchShowNfo('http://server/anime/')
          .timeout(const Duration(seconds: 15));

      expect(nfo, isNull);
    });

    test('returns null on HTTP 200 with empty body', () async {
      final client = MockClient((request) async {
        return http.Response('', 200);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final nfo = await enricher.fetchShowNfo('http://server/anime/');

      expect(nfo, isNull);
    });

    test('returns null on HTTP 200 with invalid XML', () async {
      final client = MockClient((request) async {
        return http.Response('<tvshow><title>Unclosed', 200);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final nfo = await enricher.fetchShowNfo('http://server/anime/');

      expect(nfo, isNull);
    });
  });

  // ============================================================
  // PauloFlixNfoEnricher.fetchMovieNfo
  // ============================================================
  group('PauloFlixNfoEnricher.fetchMovieNfo', () {
    test('returns KodiShowNfo on HTTP 200 with valid movie XML', () async {
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('movie.nfo'));
        return http.Response(_validMovieNfo, 200);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final nfo = await enricher.fetchMovieNfo('http://server/filme/');

      expect(nfo, isNotNull);
      expect(nfo!.title, equals('Akira'));
      expect(nfo.year, equals(1988));
      expect(nfo.posterThumb, equals('poster.jpg'));
    });

    test('returns null on HTTP 404', () async {
      final client = MockClient((request) async {
        return http.Response('Not Found', 404);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final nfo = await enricher.fetchMovieNfo('http://server/filme/');

      expect(nfo, isNull);
    });

    test('returns null on HTTP 200 with invalid XML', () async {
      final client = MockClient((request) async {
        return http.Response('not-xml', 200);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final nfo = await enricher.fetchMovieNfo('http://server/filme/');

      expect(nfo, isNull);
    });

    test('returns null on HTTP 500', () async {
      final client = MockClient((request) async {
        return http.Response('oops', 500);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final nfo = await enricher.fetchMovieNfo('http://server/filme/');

      expect(nfo, isNull);
    });
  });

  // ============================================================
  // PauloFlixNfoEnricher.fetchEpisodeThumbs
  // ============================================================
  group('PauloFlixNfoEnricher.fetchEpisodeThumbs', () {
    test('extracts single S01E001-thumb.jpg from listing', () async {
      const listing = '''<html><body>
<a href="S01E001-thumb.jpg">S01E001-thumb.jpg</a>
<a href="S01E001.mkv">S01E001.mkv</a>
</body></html>''';
      final client = MockClient((request) async {
        return http.Response(listing, 200,
            headers: {'content-type': 'text/html'});
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      // URL pré-codificada no input (o caller é responsável por
      // encodar espaços no serverUrl antes de chamar).
      final thumbs =
          await enricher.fetchEpisodeThumbs('http://server/anime/Season%201/');

      expect(thumbs.length, equals(1));
      expect(thumbs[1], equals('http://server/anime/Season%201/S01E001-thumb.jpg'));
    });

    test('extracts multiple thumbs in order (S01E001, E002, E003)', () async {
      const listing = '''<html><body>
<a href="S01E001-thumb.jpg">S01E001-thumb.jpg</a>
<a href="S01E002-thumb.png">S01E002-thumb.png</a>
<a href="S01E003-thumb.webp">S01E003-thumb.webp</a>
</body></html>''';
      final client = MockClient((request) async {
        return http.Response(listing, 200);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final thumbs =
          await enricher.fetchEpisodeThumbs('http://server/anime/Season%201/');

      expect(thumbs.length, equals(3));
      expect(thumbs[1], contains('S01E001-thumb.jpg'));
      expect(thumbs[2], contains('S01E002-thumb.png'));
      expect(thumbs[3], contains('S01E003-thumb.webp'));
    });

    test('returns empty map when no thumb files in listing', () async {
      const listing = '''<html><body>
<a href="S01E001.mkv">S01E001.mkv</a>
<a href="S01E002.mkv">S01E002.mkv</a>
<a href="poster.jpg">poster.jpg</a>
</body></html>''';
      final client = MockClient((request) async {
        return http.Response(listing, 200);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final thumbs =
          await enricher.fetchEpisodeThumbs('http://server/anime/Season%201/');

      expect(thumbs, isEmpty);
    });

    test('deduplicates by episode number (S01E001 wins over S01E01)', () async {
      // Caso real: arquivos duplicados por causa de renomeações.
      // O que aparece PRIMEIRO no listing vence.
      const listing = '''<html><body>
<a href="S01E001-thumb.jpg">S01E001-thumb.jpg</a>
<a href="S01E01-thumb.jpg">S01E01-thumb.jpg</a>
<a href="S01E002-thumb.jpg">S01E002-thumb.jpg</a>
</body></html>''';
      final client = MockClient((request) async {
        return http.Response(listing, 200);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final thumbs =
          await enricher.fetchEpisodeThumbs('http://server/anime/Season%201/');

      // 2 entries únicas (ep 1 e ep 2), e ep 1 = S01E001-thumb.jpg (3-digit)
      expect(thumbs.length, equals(2));
      expect(thumbs[1], contains('S01E001-thumb.jpg'));
      expect(thumbs[2], contains('S01E002-thumb.jpg'));
    });

    test('returns empty map on HTTP 404', () async {
      final client = MockClient((request) async {
        return http.Response('Not Found', 404);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final thumbs =
          await enricher.fetchEpisodeThumbs('http://server/anime/Season%201/');

      expect(thumbs, isEmpty);
    });
  });

  // ============================================================
  // PauloFlixNfoEnricher.fetchSeasonNfo
  // ============================================================
  group('PauloFlixNfoEnricher.fetchSeasonNfo', () {
    test('returns KodiSeasonNfo on HTTP 200 with valid season XML', () async {
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('season.nfo'));
        return http.Response(_validSeasonNfo, 200);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final nfo =
          await enricher.fetchSeasonNfo('http://server/anime/Season%201/');

      expect(nfo, isNotNull);
      expect(nfo!.seasonNumber, equals(1));
      expect(nfo.plot, contains('Primeira season'));
    });

    test('returns null on HTTP 404', () async {
      final client = MockClient((request) async {
        return http.Response('Not Found', 404);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final nfo =
          await enricher.fetchSeasonNfo('http://server/anime/Season%201/');

      expect(nfo, isNull);
    });

    test('returns null on HTTP 200 with invalid XML', () async {
      final client = MockClient((request) async {
        return http.Response('<season><plot>unclosed', 200);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final nfo =
          await enricher.fetchSeasonNfo('http://server/anime/Season%201/');

      expect(nfo, isNull);
    });
  });

  // ============================================================
  // PauloFlixNfoEnricher.resolveThumbUrl (helper estático)
  // ============================================================
  group('PauloFlixNfoEnricher.resolveThumbUrl', () {
    test('returns absolute http URL as-is', () {
      final url = PauloFlixNfoEnricher.resolveThumbUrl(
          'http://server/anime/', 'http://cdn.example.com/poster.jpg');
      expect(url, equals('http://cdn.example.com/poster.jpg'));
    });

    test('returns absolute https URL as-is', () {
      final url = PauloFlixNfoEnricher.resolveThumbUrl(
          'http://server/anime/', 'https://cdn.example.com/poster.jpg');
      expect(url, equals('https://cdn.example.com/poster.jpg'));
    });

    test('joins serverUrl + relative thumb with URL encoding', () {
      final url = PauloFlixNfoEnricher.resolveThumbUrl(
          'http://server/anime/', 'poster.jpg');
      expect(url, equals('http://server/anime/poster.jpg'));
    });

    test('appends trailing slash if serverUrl has none', () {
      final url = PauloFlixNfoEnricher.resolveThumbUrl(
          'http://server/anime', 'poster.jpg');
      expect(url, equals('http://server/anime/poster.jpg'));
    });

    test('URL-encodes spaces in relative thumb path', () {
      final url = PauloFlixNfoEnricher.resolveThumbUrl(
          'http://server/', 'my poster.jpg');
      expect(url, equals('http://server/my%20poster.jpg'));
    });
  });
}
