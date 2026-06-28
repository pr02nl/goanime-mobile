// Testes de integração do `PauloFlixMoviesService.syncContent()`.
//
// Estratégia: HTTP mockado com `MockClient` + banco Drift em memória
// (`AppDatabase.forTesting(NativeDatabase.memory())`), mesmo padrão
// do `PauloFlixNfoEnricher` test.
//
// Cobre:
//   - sync bem-sucedido com movie_index.json real (2 filmes)
//   - year como string é parseado para int
//   - rating como number é parseado para double
//   - file resolvido para URL absoluta
//   - subtitles null (ausente no JSON)
//   - callbacks onProgress/onError disparam
//   - HTTP 404 → false + onError
//   - movies array vazio → false + onError
//   - chave 'movies' ausente no JSON → false

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/data/repositories/pauloflix_movies_repository_impl.dart';
import 'package:goanime/data/services/pauloflix_movies_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// JSON index real de exemplo (extraído de docs/movie_index.json),
/// com year como string, rating como number, file e sem subtitles.
const _movieIndexJson = '''
{
  "updated_at": "2026-06-27T13:53:47.099092+00:00",
  "total_movies": 2,
  "movies": [
    {
      "title": "2012",
      "original_title": "2012",
      "sort_title": "2012",
      "path": "2012 (2009)",
      "year": "2009",
      "rating": 5.9,
      "plot": "Bilhões de habitantes da Terra não estão cientes...",
      "genre": ["Ficção científica"],
      "director": "Roland Emmerich",
      "tmdb_id": 0,
      "poster": "/movies/2012 (2009)/poster.jpg",
      "fanart": "/movies/2012 (2009)/fanart.jpg",
      "file": "/movies/2012 (2009)/2012.2009.1080p.mp4",
      "nfo": {}
    },
    {
      "title": "A Colônia",
      "original_title": "Double Team",
      "sort_title": "A Colônia",
      "path": "A Colonia (1997)",
      "year": "1997",
      "rating": 5.3,
      "plot": "Um espião internacional...",
      "genre": ["Ficção científica"],
      "director": "徐克",
      "tmdb_id": 0,
      "poster": "/movies/A Colonia (1997)/poster.jpg",
      "fanart": "/movies/A Colonia (1997)/fanart.jpg",
      "file": "/movies/A Colonia (1997)/Double Team (1997).mkv",
      "nfo": {}
    }
  ]
}
''';

/// JSON com subtitles para testar o parsing de legendas.
const _movieIndexWithSubtitlesJson = '''
{
  "updated_at": "2026-06-27T13:53:47.099092+00:00",
  "total_movies": 1,
  "movies": [
    {
      "title": "Filme Com Legenda",
      "path": "Filme Com Legenda",
      "year": "2020",
      "rating": 7.0,
      "poster": "/movies/poster.jpg",
      "fanart": "/movies/fanart.jpg",
      "file": "/movies/filme.mp4",
      "subtitles": [
        { "file": "/movies/legenda.srt", "lang": "por", "name": "Português" },
        { "file": "/movies/legenda_eng.srt", "lang": "eng", "name": "English" }
      ],
      "nfo": {}
    }
  ]
}
''';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late PauloFlixMoviesRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    repo = PauloFlixMoviesRepositoryImpl(db);
  });

  tearDown(() async {
    // Restaura o client default para não vazar mock entre testes
    PauloFlixMoviesService.configure(http.Client());
  });

  group('PauloFlixMoviesService.syncContent', () {
    test('sync bem-sucedido com movie_index.json real (2 filmes)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          _movieIndexJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      PauloFlixMoviesService.configure(mockClient);

      final progressMessages = <String>[];
      final errorMessages = <String>[];
      final result = await PauloFlixMoviesService.syncContent(
        repository: repo,
        onProgress: (msg) => progressMessages.add(msg),
        onError: (msg) => errorMessages.add(msg),
      );

      expect(result, isTrue);
      expect(errorMessages, isEmpty);

      // Callbacks de progresso disparam
      expect(progressMessages, isNotEmpty);
      expect(progressMessages.first, contains('Baixando índice JSON'));
      expect(progressMessages.last, contains('Sincronização completa'));

      // Verifica filmes no banco
      final all = await repo.getAll();
      expect(all, hasLength(2));

      // --- Filme 1: "2012" ---
      final movie1 = all.firstWhere((m) => m.folderName == '2012 (2009)');
      expect(movie1.displayName, '2012');
      expect(movie1.year, 2009); // year string parseado para int
      expect(movie1.score, closeTo(5.9, 0.01)); // rating num → double
      expect(
        movie1.videoUrl,
        'https://media.oliveira.braga.nom.br/movies/2012 (2009)/2012.2009.1080p.mp4',
      );
      expect(
        movie1.imageUrl,
        'https://media.oliveira.braga.nom.br/movies/2012 (2009)/poster.jpg',
      );
      expect(
        movie1.bannerUrl,
        'https://media.oliveira.braga.nom.br/movies/2012 (2009)/fanart.jpg',
      );
      expect(movie1.genres, ['Ficção científica']);
      expect(movie1.subtitles, isNull); // sem subtitles no JSON
      expect(movie1.isAvailable, isTrue);

      // --- Filme 2: "A Colônia" ---
      final movie2 = all.firstWhere((m) => m.folderName == 'A Colonia (1997)');
      expect(movie2.displayName, 'A Colônia');
      expect(movie2.year, 1997);
      expect(movie2.score, closeTo(5.3, 0.01));
      expect(
        movie2.videoUrl,
        'https://media.oliveira.braga.nom.br/movies/A Colonia (1997)/Double Team (1997).mkv',
      );
      expect(movie2.subtitles, isNull);
      expect(movie2.isAvailable, isTrue);
    });

    test('sync com subtitles no JSON', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          _movieIndexWithSubtitlesJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      PauloFlixMoviesService.configure(mockClient);

      final result = await PauloFlixMoviesService.syncContent(repository: repo);

      expect(result, isTrue);

      final all = await repo.getAll();
      expect(all, hasLength(1));

      final movie = all.first;
      expect(movie.year, 2020);
      expect(movie.score, closeTo(7.0, 0.01));
      expect(
        movie.videoUrl,
        'https://media.oliveira.braga.nom.br/movies/filme.mp4',
      );

      // Subtitles parseados corretamente
      expect(movie.subtitles, isNotNull);
      expect(movie.subtitles!.length, 2);
      expect(
        movie.subtitles![0].file,
        'https://media.oliveira.braga.nom.br/movies/legenda.srt',
      );
      expect(movie.subtitles![0].lang, 'por');
      expect(movie.subtitles![0].name, 'Português');
      expect(
        movie.subtitles![1].file,
        'https://media.oliveira.braga.nom.br/movies/legenda_eng.srt',
      );
      expect(movie.subtitles![1].lang, 'eng');
      expect(movie.subtitles![1].name, 'English');
    });

    test('re-sync preserva id do filme (UPSERT via DoUpdate)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          _movieIndexJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      PauloFlixMoviesService.configure(mockClient);

      // Primeiro sync
      await PauloFlixMoviesService.syncContent(repository: repo);
      final firstId = (await repo.getByFolderName('2012 (2009)'))!.id;

      // Segundo sync (mesmo JSON)
      await PauloFlixMoviesService.syncContent(repository: repo);

      final all = await repo.getAll();
      expect(all, hasLength(2), reason: 're-sync não deve duplicar filmes');
      final updated = await repo.getByFolderName('2012 (2009)');
      expect(
        updated!.id,
        equals(firstId),
        reason: 'id deve ser preservado no re-sync',
      );
    });

    test('marca filmes removidos como isAvailable=false', () async {
      // Primeiro sync: insere 2 filmes
      final mockClient1 = MockClient((request) async {
        return http.Response(
          _movieIndexJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      PauloFlixMoviesService.configure(mockClient1);
      await PauloFlixMoviesService.syncContent(repository: repo);

      // Segundo sync: só 1 filme (o outro foi removido do servidor)
      const removedJson = '''
{
  "updated_at": "2026-06-27T14:00:00.000+00:00",
  "total_movies": 1,
  "movies": [
    {
      "title": "2012",
      "path": "2012 (2009)",
      "year": "2009",
      "rating": 5.9,
      "poster": "/movies/2012 (2009)/poster.jpg",
      "fanart": "/movies/2012 (2009)/fanart.jpg",
      "file": "/movies/2012 (2009)/2012.mp4",
      "nfo": {}
    }
  ]
}
''';
      final mockClient2 = MockClient((request) async {
        return http.Response(
          removedJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      PauloFlixMoviesService.configure(mockClient2);
      final progressMessages = <String>[];
      await PauloFlixMoviesService.syncContent(
        repository: repo,
        onProgress: (msg) => progressMessages.add(msg),
      );

      // 2012 continua disponível
      final movie1 = await repo.getByFolderName('2012 (2009)');
      expect(movie1, isNotNull);
      expect(movie1!.isAvailable, isTrue);

      // A Colônia foi marcada como indisponível
      final movie2 = await repo.getByFolderName('A Colonia (1997)');
      expect(movie2, isNotNull);
      expect(movie2!.isAvailable, isFalse);

      // getAll filtra isAvailable=false
      final all = await repo.getAll();
      expect(all, hasLength(1));

      // Callback de progresso menciona filmes removidos
      expect(progressMessages.any((m) => m.contains('removidos')), isTrue);
    });

    test('HTTP 404 retorna false e chama onError', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });
      PauloFlixMoviesService.configure(mockClient);

      final errorMessages = <String>[];
      final result = await PauloFlixMoviesService.syncContent(
        repository: repo,
        onError: (msg) => errorMessages.add(msg),
      );

      expect(result, isFalse);
      expect(errorMessages, isNotEmpty);
      expect(errorMessages.first, contains('HTTP 404'));
    });

    test('JSON com movies array vazio retorna false e chama onError', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"movies": []}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      PauloFlixMoviesService.configure(mockClient);

      final errorMessages = <String>[];
      final result = await PauloFlixMoviesService.syncContent(
        repository: repo,
        onError: (msg) => errorMessages.add(msg),
      );

      expect(result, isFalse);
      expect(errorMessages, isNotEmpty);
      expect(errorMessages.first, contains('Nenhum filme'));
    });

    test('JSON sem chave movies retorna false', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"updated_at": "2026-01-01T00:00:00Z"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      PauloFlixMoviesService.configure(mockClient);

      final result = await PauloFlixMoviesService.syncContent(repository: repo);

      expect(result, isFalse);
    });

    test('filme sem file tem videoUrl null mas ainda é salvo', () async {
      const jsonWithoutFile = '''
{
  "movies": [
    {
      "title": "Filme Sem Video",
      "path": "Filme Sem Video",
      "year": "2023",
      "rating": 6.0,
      "poster": "/movies/poster.jpg",
      "fanart": "/movies/fanart.jpg",
      "nfo": {}
    }
  ]
}
''';
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonWithoutFile,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      PauloFlixMoviesService.configure(mockClient);

      final result = await PauloFlixMoviesService.syncContent(repository: repo);

      expect(result, isTrue);

      final all = await repo.getAll();
      expect(all, hasLength(1));
      expect(all.first.videoUrl, isNull);
      expect(all.first.isAvailable, isTrue);
    });

    test('rating como string no JSON é parseado corretamente', () async {
      const jsonWithStringRating = '''
{
  "movies": [
    {
      "title": "Filme Rating String",
      "path": "Filme Rating String",
      "year": "2020",
      "rating": "8.5",
      "poster": "/movies/poster.jpg",
      "fanart": "/movies/fanart.jpg",
      "file": "/movies/filme.mp4",
      "nfo": {}
    }
  ]
}
''';
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonWithStringRating,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      PauloFlixMoviesService.configure(mockClient);

      final result = await PauloFlixMoviesService.syncContent(repository: repo);

      expect(result, isTrue);

      final all = await repo.getAll();
      expect(all, hasLength(1));
      expect(all.first.score, closeTo(8.5, 0.01));
    });
  });
}
