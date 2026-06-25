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

/// XML de episodedetails.nfo mínimo para o parser aceitar.
///
/// **Top-level** (não dentro de group) para que múltiplos groups
/// (fetchEpisodeNfo, fetchEpisodeNfos) possam reusar sem duplicar.
const validEpisodeNfo = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<episodedetails>
  <title>Episode Title</title>
  <plot>Episode plot.</plot>
  <season>2</season>
  <episode>1</episode>
</episodedetails>
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
///
/// **Fase 10 do plano NFO enrichment V2:** o tag correto do Kodi
/// para o número da season é `<seasonnumber>` (NÃO `<season>`).
/// Era `<season>` no parser inline antigo (Fase 1), corrigido na
/// Fase 9 quando o parser foi refatorado para suportar plot/poster.
const _validSeasonNfo = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<season>
  <seasonnumber>1</seasonnumber>
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
  // PauloFlixNfoEnricher.fetchEpisodeNfo
  // ============================================================
  //
  // **Fase N+5 — bug fix:** o método antes hardcodava `S01` no
  // filename, então season 2+ batia em 404 (`S01E001.nfo` em vez
  // do correto `S02E001.nfo`). Estes testes garantem que o
  // season number é respeitado.
  group('PauloFlixNfoEnricher.fetchEpisodeNfo', () {
    test('builds filename S02E001.nfo for season=2 (not S01 hardcoded)',
        () async {
      final client = MockClient((request) async {
        // **O teste-chave:** valida que o filename é S02E001.nfo
        // (com S02), NÃO S01E001.nfo (bug pré-fix). Se o método
        // voltar a hardcodar S01, este teste falha.
        expect(
          request.url.path,
          endsWith('S02E001.nfo'),
          reason:
              'fetchEpisodeNfo deve usar o seasonNumber passado pelo '
              'caller no filename, não hardcodar S01. Got: '
              '${request.url.path}',
        );
        return http.Response(validEpisodeNfo, 200,
            headers: {'content-type': 'application/xml'});
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final nfo = await enricher.fetchEpisodeNfo(
        'http://server/anime/Season%2002/',
        2,
        1,
      );

      expect(nfo, isNotNull);
      expect(nfo!.plot, equals('Episode plot.'));
    });

    test('zero-pads season 10 to S10E001.nfo (2 digits)', () async {
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('S10E001.nfo'));
        return http.Response(validEpisodeNfo, 200,
            headers: {'content-type': 'application/xml'});
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final nfo = await enricher.fetchEpisodeNfo(
        'http://server/anime/Season%2010/',
        10,
        1,
      );

      expect(nfo, isNotNull);
    });

    test('zero-pads episode 100 to S01E100.nfo (3 digits)', () async {
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('S01E100.nfo'));
        return http.Response(validEpisodeNfo, 200,
            headers: {'content-type': 'application/xml'});
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final nfo = await enricher.fetchEpisodeNfo(
        'http://server/anime/Season%2001/',
        1,
        100,
      );

      expect(nfo, isNotNull);
    });

    test(
      'episode 13 com NFO no padrão 2-dígitos (S01E13.nfo) é encontrado '
      '(fallback 2-dígito quando 3-dígitos dá 404)',
      () async {
        // **Bug real (Junho 2026 — Solo Leveling S01):** o servidor tem
        // eps 1-12 com filename Kodi zero-padded 3-dígitos (S01E001.nfo)
        // + duplicatas 2-dígitos (S01E01.nfo), mas eps 13-25 existem
        // APENAS como 2-dígitos (S01E13.nfo). O `fetchEpisodeNfo`
        // tentava S01E013.nfo → 404 → ignorava o NFO. Corrigido pra
        // tentar 3-dígito primeiro, depois 2-dígitos quando 404.
        final client = MockClient((request) async {
          if (request.url.path.endsWith('S01E013.nfo')) {
            return http.Response('', 404);
          }
          if (request.url.path.endsWith('S01E13.nfo')) {
            return http.Response(
              validEpisodeNfo,
              200,
              headers: {'content-type': 'application/xml'},
            );
          }
          return http.Response('unexpected: ${request.url.path}', 500);
        });
        final enricher = PauloFlixNfoEnricher(client: client);

        final nfo = await enricher.fetchEpisodeNfo(
          'http://server/anime/Season%2001/',
          1,
          13,
        );

        expect(nfo, isNotNull, reason: 'deve cair no fallback 2-dígitos');
        expect(nfo!.plot, equals('Episode plot.'));
      },
    );

    test(
      'episode 5 prefere 3-dígitos (S01E005.nfo) quando ambos existem',
      () async {
        // Caso normal: ep tem 3-dígitos E 2-dígitos no servidor.
        // O comportamento deve ser determinístico — prefere 3-dígitos
        // (padrão Kodi), ignora 2-dígitos. Garante que não fazemos
        // 1 GET extra à toa quando o 3-dígitos está disponível.
        final client = MockClient((request) async {
          if (request.url.path.endsWith('S01E005.nfo')) {
            return http.Response(
              validEpisodeNfo,
              200,
              headers: {'content-type': 'application/xml'},
            );
          }
          // S01E05.nfo NÃO deve ser chamado — 3-dígitos já respondeu.
          return http.Response(
            'should not be called: ${request.url.path}',
            500,
          );
        });
        final enricher = PauloFlixNfoEnricher(client: client);

        final nfo = await enricher.fetchEpisodeNfo(
          'http://server/anime/Season%2001/',
          1,
          5,
        );

        expect(nfo, isNotNull);
        expect(nfo!.plot, equals('Episode plot.'));
      },
    );

    test(
      'episode 1 sem nenhum NFO disponível retorna null (sem exception)',
      () async {
        // Caso de borda: o listing descobriu o ep (via .mkv), mas não
        // tem NFO nem thumb. fetchEpisodeNfo deve retornar null
        // silenciosamente (não propagar exception).
        final client = MockClient((request) async {
          return http.Response('', 404);
        });
        final enricher = PauloFlixNfoEnricher(client: client);

        final nfo = await enricher.fetchEpisodeNfo(
          'http://server/anime/Season%2001/',
          1,
          1,
        );

        expect(nfo, isNull);
      },
    );
  });

  // ============================================================
  // PauloFlixNfoEnricher.fetchEpisodeNfos
  // ============================================================
  //
  // **Fase N+6 — bug fix:** o método antes (a) descobria episodes
  // via `fetchEpisodeThumbs` (pulava seasons sem thumb) e (b)
  // descartava as URLs das thumbs. Agora descobre via NFO e
  // retorna o `thumbUrl` no record.
  group('PauloFlixNfoEnricher.fetchEpisodeNfos', () {
    /// HTML de listing com NFOs de episode (sem thumbs) — testa
    /// o caso "season com NFO mas sem thumb" (pré-fix era pulado).
    const listingWithNfoOnly = '''<html><body>
<a href="../">../</a>
<a href="S01E001.nfo">S01E001.nfo</a>
<a href="S01E002.nfo">S01E002.nfo</a>
<a href="S01E01.mkv">S01E01.mkv</a>
<a href="S01E02.mkv">S01E02.mkv</a>
</body></html>''';

    /// HTML de listing com NFOs + thumbs — testa o caso normal
    /// (season com tudo).
    const listingWithNfoAndThumb = '''<html><body>
<a href="../">../</a>
<a href="S01E001.nfo">S01E001.nfo</a>
<a href="S01E002.nfo">S01E002.nfo</a>
<a href="S01E001-thumb.jpg">S01E001-thumb.jpg</a>
<a href="S01E01.mkv">S01E01.mkv</a>
</body></html>''';

    test('discovers episodes via NFO pattern (not thumb)', () async {
      // **O teste-chave do bug:** antes desta correção, a season
      // com NFOs mas sem thumbs era pulada. Agora é descoberta.
      final client = MockClient((request) async {
        // 1ª chamada: listing HTML (episode numbers via NFO).
        if (!request.url.path.endsWith('.nfo')) {
          return http.Response(listingWithNfoOnly, 200);
        }
        // 2ª chamada: GET de cada NFO. Para episode 1 e 2.
        return http.Response(validEpisodeNfo, 200,
            headers: {'content-type': 'application/xml'});
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final result = await enricher.fetchEpisodeNfos(
        'http://server/anime/Season%2001/',
        1,
      );

      // 2 episodes descobertos (NFO pattern), mesmo sem thumb.
      expect(result.keys, containsAll(<int>[1, 2]));
      // **Fase N+7:** o record agora carrega o KodiEpisodeNfo completo
      // (V2: +originalTitle, outline, aired, rating, runtime).
      expect(result[1]?.nfo?.plot, isNotNull);
    });

    test('returns thumbUrl in record when season has thumbs', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('S01E001.nfo')) {
          return http.Response(validEpisodeNfo, 200,
              headers: {'content-type': 'application/xml'});
        }
        // listing HTML
        return http.Response(listingWithNfoAndThumb, 200);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final result = await enricher.fetchEpisodeNfos(
        'http://server/anime/Season%2001/',
        1,
      );

      // Episode 1 tem thumb.
      expect(result[1]?.thumbUrl, isNotNull);
      expect(result[1]!.thumbUrl, contains('S01E001-thumb.jpg'));
      // Episode 2 não tem thumb → null.
      expect(result[2]?.thumbUrl, isNull);
    });

    test('returns empty map when listing has no NFOs', () async {
      const listingEmpty = '''<html><body>
<a href="../">../</a>
<a href="S01E01.mkv">S01E01.mkv</a>
</body></html>''';
      final client = MockClient((request) async {
        return http.Response(listingEmpty, 200);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final result = await enricher.fetchEpisodeNfos(
        'http://server/anime/Season%2001/',
        1,
      );

      expect(result, isEmpty);
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

  // ============================================================
  // PauloFlixNfoEnricher.fetchShowImages
  // ============================================================
  //
  // **Fase N+1 — bug fix:** antes desta correção, o `fetchAllShows`
  // lia os JPGs físicos da pasta **raiz** `/tvshows/` e atribuía o
  // mesmo `poster.jpg`/`fanart.jpg` a TODOS os shows. As imagens
  // reais ficam **dentro de cada pasta de show**; este método cobre
  // a detecção por show.
  group('PauloFlixNfoEnricher.fetchShowImages', () {
    /// HTML de listing com poster.jpg/fanart.jpg explícitos.
    const listingWithJpgFiles = '''<html><body>
<a href="../">../</a>
<a href="poster.jpg">poster.jpg</a>
<a href="fanart.jpg">fanart.jpg</a>
<a href="Season 01/">Season 01/</a>
<a href="S01E01.mkv">S01E01.mkv</a>
</body></html>''';

    /// HTML de listing sem JPGs (só pastas e episódios).
    const listingWithoutJpgFiles = '''<html><body>
<a href="../">../</a>
<a href="Season 01/">Season 01/</a>
<a href="S01E01.mkv">S01E01.mkv</a>
</body></html>''';

    test('detects poster.jpg and fanart.jpg in show folder listing',
        () async {
      final client = MockClient((request) async {
        // Não terminamos com .nfo — é o listing HTML da pasta.
        expect(request.url.path, endsWith('HxH/'));
        return http.Response(listingWithJpgFiles, 200);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final images = await enricher.fetchShowImages('http://server/HxH/');

      expect(images.poster, equals('poster.jpg'));
      expect(images.fanart, equals('fanart.jpg'));
    });

    test('returns empty DetectedShowImages on HTTP 404', () async {
      final client = MockClient((request) async {
        return http.Response('Not Found', 404);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final images = await enricher.fetchShowImages('http://server/HxH/');

      expect(images.poster, isNull);
      expect(images.fanart, isNull);
    });

    test('returns empty when listing has no JPG files', () async {
      final client = MockClient((request) async {
        return http.Response(listingWithoutJpgFiles, 200);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final images = await enricher.fetchShowImages('http://server/HxH/');

      expect(images.poster, isNull);
      expect(images.fanart, isNull);
    });
  });

  // ============================================================
  // PauloFlixNfoEnricher.fetchShowNfoWithImages
  // ============================================================
  //
  // Compõe `fetchShowNfo` + `fetchShowImages` em paralelo (1 RTT
  // total) para o caller ter ambos os dados com 1 chamada.
  group('PauloFlixNfoEnricher.fetchShowNfoWithImages', () {
    test('returns NFO + detected images on HTTP 200 (both endpoints)',
        () async {
      const listingHtml = '''<html><body>
<a href="../">../</a>
<a href="poster.jpg">poster.jpg</a>
<a href="fanart.jpg">fanart.jpg</a>
</body></html>''';
      final client = MockClient((request) async {
        if (request.url.path.endsWith('tvshow.nfo')) {
          return http.Response(_validTvshowNfo, 200,
              headers: {'content-type': 'application/xml'});
        }
        // listing HTML da pasta
        return http.Response(listingHtml, 200);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final result = await enricher.fetchShowNfoWithImages('http://server/anime/');

      expect(result.nfo, isNotNull);
      expect(result.nfo!.title, equals('Mushoku Tensei'));
      // NFO tem thumb aspect=poster, então o fromNfo vai usar isso
      // (não o JPG físico). Mas aqui só checamos que o JPG foi
      // detectado — o caller decide a prioridade.
      expect(result.images.poster, equals('poster.jpg'));
      expect(result.images.fanart, equals('fanart.jpg'));
    });

    test('returns nfo=null + empty images when both endpoints 404',
        () async {
      final client = MockClient((request) async {
        return http.Response('Not Found', 404);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final result = await enricher.fetchShowNfoWithImages('http://server/anime/');

      expect(result.nfo, isNull);
      expect(result.images.poster, isNull);
      expect(result.images.fanart, isNull);
    });

    test('returns nfo + images detected from listing (no NFO thumb)',
        () async {
      // NFO sem `<thumb>` — força o caller a usar o JPG físico
      // detectado no listing.
      const nfoWithoutThumb = '''<?xml version="1.0"?>
<tvshow>
  <title>Mushoku Tensei</title>
  <plot>Plot.</plot>
</tvshow>''';
      const listingHtml = '''<html><body>
<a href="poster.jpg">poster.jpg</a>
</body></html>''';
      final client = MockClient((request) async {
        if (request.url.path.endsWith('tvshow.nfo')) {
          return http.Response(nfoWithoutThumb, 200,
              headers: {'content-type': 'application/xml'});
        }
        return http.Response(listingHtml, 200);
      });
      final enricher = PauloFlixNfoEnricher(client: client);

      final result = await enricher.fetchShowNfoWithImages('http://server/anime/');

      expect(result.nfo, isNotNull);
      expect(result.nfo!.posterThumb, isNull); // NFO sem thumb
      expect(result.images.poster, equals('poster.jpg'));
      // O caller pode usar result.images.poster como fallback.
    });
  });
}
