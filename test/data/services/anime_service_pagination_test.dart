// Testes de unidade do sistema de paginação incremental do AnimeService.
//
// Estratégia: HTTP mockado com `MockClient` do `http/testing.dart`.
// O `AnimeService.configure(mockClient)` injeta o client mockado.
//
// Cobre:
//   - chunk 0 retorna episódios 0-29 (primeira página)
//   - chunk 1 retorna episódios 30-59 (segunda página)
//   - último chunk retorna episódios restantes (< 30)
//   - chunk além do total retorna lista vazia
//   - cache evita nova requisição HTTP na segunda chamada
//   - forceRefresh ignora cache
//   - clearParseCache limpa o cache
//   - episódios vazios retorna lista vazia

import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/data/services/anime_service.dart';
import 'package:goanime/domain/models/anime.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Gera HTML mockado do AnimeFire com [count] episódios.
/// Cada episódio segue o seletor CSS do AnimeFire:
/// `a.lEp.epT.divNumEp.smallbox.px-2.mx-1.text-left.d-flex`
String _makeEpisodeHtml(int count) {
  final buffer = StringBuffer();
  for (int i = 1; i <= count; i++) {
    buffer.writeln(
      '<a class="lEp epT divNumEp smallbox px-2 mx-1 text-left d-flex" '
      'href="/anime/test-anime/episodio/$i">'
      '$i'
      '</a>',
    );
  }
  return '''<!DOCTYPE html>
<html>
<body>
  <div class="container">
    ${buffer.toString()}
  </div>
</body>
</html>''';
}

/// Cria um [Anime] de teste com a URL fornecida.
Anime _makeAnime({String suffix = ''}) {
  return Anime(
    name: 'Test Anime$suffix',
    url: 'https://animefire.plus/anime/test-anime$suffix',
    source: AnimeSource.animeFire,
    fallbackImageUrl: 'https://animefire.plus/img/test.jpg',
  );
}

void main() {
  group('AnimeService paginação incremental', () {
    setUp(() {
      AnimeService.configure(null);
      AnimeService.clearParseCache();
    });

    tearDown(() {
      AnimeService.configure(null);
      AnimeService.clearParseCache();
    });

    test(
      'getAnimeEpisodesChunk com chunkIndex=0 retorna os primeiros 30 episódios',
      () async {
        final anime = _makeAnime();
        AnimeService.configure(
          MockClient((request) async {
            return http.Response(_makeEpisodeHtml(100), 200);
          }),
        );

        final result = await AnimeService.getAnimeEpisodesChunk(
          anime,
          chunkIndex: 0,
          chunkSize: 30,
        );

        expect(result.total, 100);
        expect(result.episodes, hasLength(30));
        expect(result.episodes.first.number, '1');
        expect(result.episodes.last.number, '30');
      },
    );

    test(
      'getAnimeEpisodesChunk com chunkIndex=1 retorna episódios 31-60',
      () async {
        final anime = _makeAnime();
        AnimeService.configure(
          MockClient((request) async {
            return http.Response(_makeEpisodeHtml(100), 200);
          }),
        );

        final result = await AnimeService.getAnimeEpisodesChunk(
          anime,
          chunkIndex: 1,
          chunkSize: 30,
        );

        expect(result.total, 100);
        expect(result.episodes, hasLength(30));
        expect(result.episodes.first.number, '31');
        expect(result.episodes.last.number, '60');
      },
    );

    test(
      'último chunk com menos de 30 episódios retorna apenas o remanescente',
      () async {
        final anime = _makeAnime();
        AnimeService.configure(
          MockClient((request) async {
            return http.Response(_makeEpisodeHtml(65), 200);
          }),
        );

        // chunk 0: 0-29 (30 eps)
        // chunk 1: 30-59 (30 eps)
        // chunk 2: 60-64 (5 eps)
        final result = await AnimeService.getAnimeEpisodesChunk(
          anime,
          chunkIndex: 2,
          chunkSize: 30,
        );

        expect(result.total, 65);
        expect(result.episodes, hasLength(5));
        expect(result.episodes.first.number, '61');
        expect(result.episodes.last.number, '65');
      },
    );

    test(
      'chunk além do total retorna lista vazia',
      () async {
        final anime = _makeAnime();
        AnimeService.configure(
          MockClient((request) async {
            return http.Response(_makeEpisodeHtml(30), 200);
          }),
        );

        final result = await AnimeService.getAnimeEpisodesChunk(
          anime,
          chunkIndex: 5, // 5*30 = 150, mas só 30 episódios
          chunkSize: 30,
        );

        expect(result.total, 30);
        expect(result.episodes, isEmpty);
      },
    );

    test(
      'getAnimeEpisodeList faz apenas 1 requisição para o mesmo anime (cache)',
      () async {
        final anime = _makeAnime();
        var requestCount = 0;
        AnimeService.configure(
          MockClient((request) async {
            requestCount++;
            return http.Response(_makeEpisodeHtml(50), 200);
          }),
        );

        // Primeira chamada — faz HTTP
        final firstResult = await AnimeService.getAnimeEpisodeList(anime);
        expect(firstResult, hasLength(50));
        expect(requestCount, 1);

        // Segunda chamada — usa cache, NÃO faz HTTP
        final secondResult = await AnimeService.getAnimeEpisodeList(anime);
        expect(secondResult, hasLength(50));
        expect(requestCount, 1, reason: 'cache deve evitar nova requisição');

        // getAnimeEpisodesChunk também usa cache
        final chunkResult = await AnimeService.getAnimeEpisodesChunk(
          anime,
          chunkIndex: 0,
          chunkSize: 30,
        );
        expect(chunkResult.total, 50);
        expect(requestCount, 1, reason: 'chunk também deve usar cache');
      },
    );

    test(
      'forceRefresh ignora cache e faz nova requisição',
      () async {
        final anime = _makeAnime();
        var requestCount = 0;
        AnimeService.configure(
          MockClient((request) async {
            requestCount++;
            return http.Response(_makeEpisodeHtml(50), 200);
          }),
        );

        // Primeira chamada — popula cache
        await AnimeService.getAnimeEpisodeList(anime);
        expect(requestCount, 1);

        // forceRefresh=true ignora cache
        await AnimeService.getAnimeEpisodeList(anime, forceRefresh: true);
        expect(requestCount, 2, reason: 'forceRefresh deve refazer requisição');

        // Sem forceRefresh, volta a usar cache
        await AnimeService.getAnimeEpisodeList(anime);
        expect(requestCount, 2, reason: 'deve usar cache novamente');
      },
    );

    test(
      'clearParseCache limpa o cache entre chamadas',
      () async {
        final anime = _makeAnime();
        var requestCount = 0;
        AnimeService.configure(
          MockClient((request) async {
            requestCount++;
            return http.Response(_makeEpisodeHtml(30), 200);
          }),
        );

        // Primeira chamada
        await AnimeService.getAnimeEpisodeList(anime);
        expect(requestCount, 1);

        // Limpa cache
        AnimeService.clearParseCache();

        // Deve fazer nova requisição
        await AnimeService.getAnimeEpisodeList(anime);
        expect(requestCount, 2, reason: 'clearParseCache deve forçar nova requisição');
      },
    );

    test(
      'animes diferentes têm caches independentes',
      () async {
        final anime1 = _makeAnime(suffix: '-1');
        final anime2 = _makeAnime(suffix: '-2');

        final requestUrls = <String>[];
        AnimeService.configure(
          MockClient((request) async {
            requestUrls.add(request.url.toString());
            return http.Response(_makeEpisodeHtml(10), 200);
          }),
        );

        // Carrega anime1
        await AnimeService.getAnimeEpisodeList(anime1);
        expect(requestUrls, hasLength(1));

        // Carrega anime2 (URL diferente, faz requisição)
        await AnimeService.getAnimeEpisodeList(anime2);
        expect(requestUrls, hasLength(2));

        // Re-carrega anime1 (cache hit)
        await AnimeService.getAnimeEpisodeList(anime1);
        expect(requestUrls, hasLength(2), reason: 'anime1 deve estar em cache');
      },
    );

    test(
      'episódios vazios retorna lista vazia e total 0',
      () async {
        final anime = _makeAnime();
        AnimeService.configure(
          MockClient((_) async {
            return http.Response('<html><body></body></html>', 200);
          }),
        );

        final list = await AnimeService.getAnimeEpisodeList(anime);
        expect(list, isEmpty);

        final chunk = await AnimeService.getAnimeEpisodesChunk(
          anime,
          chunkIndex: 0,
        );
        expect(chunk.total, 0);
        expect(chunk.episodes, isEmpty);
      },
    );

    test(
      'chunk com chunkSize customizado',
      () async {
        final anime = _makeAnime();
        AnimeService.configure(
          MockClient((request) async {
            return http.Response(_makeEpisodeHtml(100), 200);
          }),
        );

        // chunkSize=10
        final result = await AnimeService.getAnimeEpisodesChunk(
          anime,
          chunkIndex: 0,
          chunkSize: 10,
        );
        expect(result.total, 100);
        expect(result.episodes, hasLength(10));
        expect(result.episodes.first.number, '1');
        expect(result.episodes.last.number, '10');
      },
    );

    test(
      'episódios retornados têm thumbnail = anime.imageUrl como fallback',
      () async {
        final anime = _makeAnime();
        AnimeService.configure(
          MockClient((request) async {
            return http.Response(_makeEpisodeHtml(5), 200);
          }),
        );

        final list = await AnimeService.getAnimeEpisodeList(anime);
        for (final ep in list) {
          expect(ep.thumbnail, anime.imageUrl);
          expect(ep.url, startsWith('/anime/test-anime/episodio/'));
        }
      },
    );

    // ─── LRU cache ─────────────────────────────────────────────────

    test(
      'LRU: 21º anime diferente faz o mais antigo ser evictado',
      () async {
        final animes = List.generate(21, (i) => _makeAnime(suffix: '-$i'));
        final requestCount = {for (final a in animes) a.url: 0};

        AnimeService.configure(
          MockClient((request) async {
            final url = request.url.toString();
            requestCount[url] = (requestCount[url] ?? 0) + 1;
            return http.Response(_makeEpisodeHtml(5), 200);
          }),
        );

        // Carrega 20 animes (limite)
        for (int i = 0; i < 20; i++) {
          await AnimeService.getAnimeEpisodeList(animes[i]);
        }

        // Verifica que todos estão em cache (re-carregar não faz HTTP)
        for (int i = 0; i < 20; i++) {
          expect(requestCount[animes[i].url], 1,
            reason: 'anime $i deve estar em cache e não refazer HTTP',
          );
        }

        // Carrega o 21º anime — força evicção do mais antigo (anime 0)
        await AnimeService.getAnimeEpisodeList(animes[20]);

        // anime 1 (segundo mais antigo) ainda está em cache
        // (verificar antes de recarregar anime 0, pois recarregar
        //  um item evictado adiciona ao cache e pode evictar outro)
        await AnimeService.getAnimeEpisodeList(animes[1]);
        expect(requestCount[animes[1].url], 1,
          reason: 'anime 1 deve permanecer em cache',
        );

        // anime 0 foi evictado → re-carregar faz nova requisição
        await AnimeService.getAnimeEpisodeList(animes[0]);
        expect(requestCount[animes[0].url], 2,
          reason: 'anime 0 (mais antigo) foi evictado, deve refazer HTTP',
        );
      },
    );

    test(
      'LRU: re-acessar um anime o move para o fim, evitando evicção',
      () async {
        final animes = List.generate(22, (i) => _makeAnime(suffix: '-$i'));
        final requestCount = {for (final a in animes) a.url: 0};

        AnimeService.configure(
          MockClient((request) async {
            final url = request.url.toString();
            requestCount[url] = (requestCount[url] ?? 0) + 1;
            return http.Response(_makeEpisodeHtml(5), 200);
          }),
        );

        // Carrega 20 animes: 0-19
        for (int i = 0; i < 20; i++) {
          await AnimeService.getAnimeEpisodeList(animes[i]);
        }

        // Re-acessa anime 0 — move para o fim da ordem LRU
        await AnimeService.getAnimeEpisodeList(animes[0]);

        // Carrega anime 20 — não estoura limite ainda, ainda está em 20
        await AnimeService.getAnimeEpisodeList(animes[20]);

        // Carrega anime 21 — agora estourou, evicta o mais antigo
        // O mais antigo agora é anime 1 (pois anime 0 foi re-acessado)
        await AnimeService.getAnimeEpisodeList(animes[21]);

        // anime 0 foi re-acessado, deve estar em cache
        expect(requestCount[animes[0].url], 1,
          reason: 'anime 0 foi re-acessado e deve estar em cache',
        );

        // anime 1 foi evictado (era o mais antigo)
        await AnimeService.getAnimeEpisodeList(animes[1]);
        expect(requestCount[animes[1].url], 2,
          reason: 'anime 1 (mais antigo após re-access) foi evictado',
        );
      },
    );

    test(
      'LRU: clearParseCache limpa cache E ordem de acesso',
      () async {
        final anime1 = _makeAnime(suffix: '-a');
        final anime2 = _makeAnime(suffix: '-b');
        var requestCount = 0;

        AnimeService.configure(
          MockClient((request) async {
            requestCount++;
            return http.Response(_makeEpisodeHtml(5), 200);
          }),
        );

        // Popula cache
        await AnimeService.getAnimeEpisodeList(anime1);
        await AnimeService.getAnimeEpisodeList(anime2);
        expect(requestCount, 2);

        AnimeService.clearParseCache();

        // Ambos devem refazer HTTP após limpeza
        await AnimeService.getAnimeEpisodeList(anime1);
        await AnimeService.getAnimeEpisodeList(anime2);
        expect(requestCount, 4,
          reason: 'clearParseCache deve limpar tudo, ambos refazem HTTP',
        );
      },
    );
  });
}
