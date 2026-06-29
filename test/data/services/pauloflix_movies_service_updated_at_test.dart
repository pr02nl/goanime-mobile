// Testes da verificação de `updated_at` no
// `PauloFlixMoviesService.syncContent()`.
//
// Estratégia: HTTP mockado com `MockClient` + `SharedPreferences`
// mockado via `setMockInitialValues`. O service compara o `updated_at`
// do JSON baixado com o último valor salvo em SharedPreferences. Se
// igual, pula o processamento (retorna true sem tocar no banco).

import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/data/services/pauloflix_movies_service.dart';
import 'package:goanime/domain/models/pauloflix_movie.dart';
import 'package:goanime/domain/repositories/pauloflix_movies_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chave usada pelo PauloFlixMoviesService para armazenar o último updated_at.
const _lastUpdatedAtKey = 'last_movie_index_updated_at';

/// JSON index com 1 filme e updated_at definido.
const _movieIndexJson = '''{
  "updated_at": "2026-06-27T13:53:47.099092+00:00",
  "total_movies": 1,
  "movies": [
    {
      "title": "Test Movie",
      "path": "Test Movie",
      "year": "2024",
      "rating": 7.5,
      "poster": "/movies/Test Movie/poster.jpg",
      "fanart": "/movies/Test Movie/fanart.jpg",
      "file": "/movies/Test Movie/movie.mp4",
      "nfo": {}
    }
  ]
}''';

/// JSON com mesmo updated_at — simula índice inalterado.
const _movieIndexSameUpdatedAt = '''{
  "updated_at": "2026-06-27T13:53:47.099092+00:00",
  "total_movies": 1,
  "movies": [
    {
      "title": "Test Movie",
      "path": "Test Movie",
      "year": "2024",
      "rating": 7.5,
      "poster": "/movies/Test Movie/poster.jpg",
      "fanart": "/movies/Test Movie/fanart.jpg",
      "file": "/movies/Test Movie/movie.mp4",
      "nfo": {}
    }
  ]
}''';

/// JSON sem a chave `updated_at` — testa compatibilidade retroativa.
const _movieIndexWithoutUpdatedAt = '''{
  "total_movies": 1,
  "movies": [
    {
      "title": "Legacy Movie",
      "path": "Legacy Movie",
      "year": "2023",
      "rating": 6.0,
      "poster": "/movies/Legacy Movie/poster.jpg",
      "fanart": "/movies/Legacy Movie/fanart.jpg",
      "file": "/movies/Legacy Movie/movie.mp4",
      "nfo": {}
    }
  ]
}''';

void main() {
  late _MockMoviesRepository mockRepo;

  setUp(() {
    mockRepo = _MockMoviesRepository();
    PauloFlixMoviesService.configure(http.Client());
  });

  group('PauloFlixMoviesService.syncContent — updated_at', () {
    test('updated_at diferente → processa (saveBatch é chamado)', () async {
      SharedPreferences.setMockInitialValues({});

      PauloFlixMoviesService.configure(
        MockClient((_) async => http.Response(_movieIndexJson, 200)),
      );

      await PauloFlixMoviesService.syncContent(repository: mockRepo);

      expect(mockRepo.getAllCallCount, greaterThan(0),
          reason: 'getAll deve ser chamado ao processar');
      expect(mockRepo.saveBatchCallCount, greaterThan(0),
          reason: 'updated_at diferente deve processar o JSON');
    });

    test('updated_at igual → PULA processamento (getAll/saveBatch NÃO chamados)',
        () async {
      SharedPreferences.setMockInitialValues({
        _lastUpdatedAtKey: '2026-06-27T13:53:47.099092+00:00',
      });

      PauloFlixMoviesService.configure(
        MockClient((_) async => http.Response(_movieIndexSameUpdatedAt, 200)),
      );

      final result = await PauloFlixMoviesService.syncContent(
        repository: mockRepo,
      );

      expect(result, isTrue,
          reason: 'deve retornar true mesmo quando pula o processamento');
      expect(mockRepo.getAllCallCount, 0,
          reason: 'getAll não deve ser chamado no skip');
      expect(mockRepo.saveBatchCallCount, 0,
          reason: 'updated_at igual → NÃO deve processar o JSON');
    });

    test('sem updated_at no JSON → processa (compatibilidade retroativa)',
        () async {
      SharedPreferences.setMockInitialValues({});

      PauloFlixMoviesService.configure(
        MockClient(
          (_) async => http.Response(_movieIndexWithoutUpdatedAt, 200),
        ),
      );

      await PauloFlixMoviesService.syncContent(repository: mockRepo);

      expect(mockRepo.saveBatchCallCount, greaterThan(0),
          reason: 'sem updated_at no JSON → deve processar normalmente');
    });

    test('primeira sync (sem chave no prefs) → processa', () async {
      SharedPreferences.setMockInitialValues({});

      PauloFlixMoviesService.configure(
        MockClient((_) async => http.Response(_movieIndexJson, 200)),
      );

      await PauloFlixMoviesService.syncContent(repository: mockRepo);

      expect(mockRepo.saveBatchCallCount, greaterThan(0),
          reason: 'primeira sync sem chave no prefs deve processar');
    });

    test(
        'updated_at igual → skip ocorre antes de getAll/saveBatch',
        () async {
      SharedPreferences.setMockInitialValues({
        _lastUpdatedAtKey: '2026-06-27T13:53:47.099092+00:00',
      });

      int httpCallCount = 0;
      PauloFlixMoviesService.configure(
        MockClient((_) {
          httpCallCount++;
          return Future.value(http.Response(_movieIndexSameUpdatedAt, 200));
        }),
      );

      final result = await PauloFlixMoviesService.syncContent(
        repository: mockRepo,
      );

      expect(result, isTrue);
      expect(httpCallCount, 1,
          reason: 'HTTP deve ser chamado para baixar o JSON');
      expect(mockRepo.getAllCallCount, 0,
          reason: 'getAll não deve ser chamado no skip');
      expect(mockRepo.saveBatchCallCount, 0,
          reason: 'saveBatch não deve ser chamado no skip');
    });
  });
}

/// Mock do PauloFlixMoviesRepository que rastreia chamadas a getAll e saveBatch.
class _MockMoviesRepository implements PauloFlixMoviesRepository {
  int getAllCallCount = 0;
  int saveBatchCallCount = 0;

  @override
  Future<List<PauloFlixMovie>> getAll() async {
    getAllCallCount++;
    return [];
  }

  @override
  Future<void> saveBatch(List<PauloFlixMovie> contents) async {
    saveBatchCallCount++;
  }

  @override
  Future<PauloFlixMovie?> getByFolderName(String folderName) async => null;

  @override
  Future<PauloFlixMovie?> getByTmdbId(int tmdbId) async => null;

  @override
  Future<void> saveContent(PauloFlixMovie content) async {}

  @override
  Future<void> markAsUnavailable(String folderName) async {}

  @override
  Future<Map<String, int>> getStats() async => {};

  @override
  Future<List<PauloFlixMovie>> searchByName(String query) async => [];

  @override
  Stream<List<PauloFlixMovie>> watch() => const Stream.empty();
}
