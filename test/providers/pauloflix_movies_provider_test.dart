import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/domain/models/pauloflix_movie.dart';
import 'package:goanime/domain/repositories/pauloflix_movies_repository.dart';
import 'package:goanime/ui/pauloflix_movies/view_models/pauloflix_movies_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake do repository (Fase 3) — retorna dados em memória.
class FakePauloFlixMoviesRepository implements PauloFlixMoviesRepository {
  final List<PauloFlixMovie> fakeData;
  final bool shouldThrow;

  FakePauloFlixMoviesRepository(this.fakeData, {this.shouldThrow = false});

  @override
  Future<List<PauloFlixMovie>> getAll() async {
    if (shouldThrow) throw Exception('DB error');
    return fakeData;
  }

  @override
  Future<List<PauloFlixMovie>> searchByName(String query) async => fakeData;
  @override
  Future<PauloFlixMovie?> getByFolderName(String folderName) async => null;
  @override
  Future<PauloFlixMovie?> getByTmdbId(int tmdbId) async => null;
  @override
  Future<void> saveContent(PauloFlixMovie content) async {}
  @override
  Future<void> saveBatch(List<PauloFlixMovie> contents) async {}
  @override
  Future<void> markAsUnavailable(String folderName) async {}
  @override
  Future<Map<String, int>> getStats() async => {
    'total': 0,
    'available': 0,
    'withMetadata': 0,
    'collections': 0,
  };
  @override
  Stream<List<PauloFlixMovie>> watch() => const Stream.empty();
}

void main() {
  group('PauloFlixMoviesProvider', () {
    final testMovies = [
      PauloFlixMovie(
        folderName: 'Inception',
        displayName: 'Inception',
        serverUrl: 'http://server/inception/',
        imageUrl: 'http://img.com/inception.jpg',
        genres: ['Action', 'Sci-Fi'],
        tmdbId: 27205,
      ),
      PauloFlixMovie(
        folderName: 'Interstellar',
        displayName: 'Interstellar',
        serverUrl: 'http://server/interstellar/',
        genres: ['Adventure', 'Drama'],
        tmdbId: 157336,
      ),
    ];

    test('status inicial deve ser initial', () {
      final provider = PauloFlixMoviesProvider.withServices(
        repository: FakePauloFlixMoviesRepository([]),
      );
      expect(provider.status, PauloFlixMoviesStatus.initial);
      expect(provider.contents, isEmpty);
      expect(provider.errorMessage, isNull);
      expect(provider.isSyncing, false);
    });

    test('loadContents deve carregar dados do banco', () async {
      final provider = PauloFlixMoviesProvider.withServices(
        repository: FakePauloFlixMoviesRepository([testMovies[0]]),
      );
      await provider.loadContents();

      expect(provider.status, PauloFlixMoviesStatus.loaded);
      expect(provider.contents.length, 1);
      expect(provider.contents[0].folderName, 'Inception');
    });

    test('loadContents deve lidar com erro do banco', () async {
      final provider = PauloFlixMoviesProvider.withServices(
        repository: FakePauloFlixMoviesRepository([], shouldThrow: true),
      );
      await provider.loadContents();

      expect(provider.status, PauloFlixMoviesStatus.error);
      expect(provider.errorMessage, contains('Erro ao carregar filmes'));
    });

    test('search deve filtrar por displayName', () async {
      final provider = PauloFlixMoviesProvider.withServices(
        repository: FakePauloFlixMoviesRepository([...testMovies]),
      );
      await provider.loadContents();

      provider.search('inception');
      await Future.delayed(const Duration(milliseconds: 400));
      expect(provider.contents.length, 1);
      expect(provider.contents[0].folderName, 'Inception');

      provider.search('interstellar');
      await Future.delayed(const Duration(milliseconds: 400));
      expect(provider.contents.length, 1);
      expect(provider.contents[0].folderName, 'Interstellar');
    });

    test('search com query vazia deve retornar todos', () async {
      final provider = PauloFlixMoviesProvider.withServices(
        repository: FakePauloFlixMoviesRepository([...testMovies]),
      );
      await provider.loadContents();

      provider.search('');
      await Future.delayed(const Duration(milliseconds: 400));
      expect(provider.contents.length, 2);
    });

    test('clearSearch deve restaurar lista completa', () async {
      final provider = PauloFlixMoviesProvider.withServices(
        repository: FakePauloFlixMoviesRepository([...testMovies]),
      );
      await provider.loadContents();

      provider.search('inception');
      await Future.delayed(const Duration(milliseconds: 400));
      expect(provider.contents.length, 1);

      provider.clearSearch();
      expect(provider.contents.length, 2);
    });

    test(
      'syncContent deve retornar false quando TMDB nao configurado',
      () async {
        SharedPreferences.setMockInitialValues({'tmdb_api_key': ''});

        final provider = PauloFlixMoviesProvider.withServices(
          repository: FakePauloFlixMoviesRepository([]),
        );

        final result = await provider.syncContent();

        expect(result, isFalse);
        expect(provider.status, PauloFlixMoviesStatus.error);
        expect(provider.errorMessage, contains('não configurado'));
      },
    );
  });
}
