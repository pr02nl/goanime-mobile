import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/data/models/tmdb_models.dart';
import 'package:goanime/domain/models/pauloflix_movie.dart';

void main() {
  group('PauloFlixMovie.fromTmdb', () {
    test(
      'search com genre_ids + genreIdToName → resolve nomes via mapa',
      () {
        // Simula o que vem do TMDB /search/movie: genres=[] e genre_ids=[...]
        final tmdbSearch = TmdbMovie.fromSearchJson({
          'id': 27205,
          'title': 'Inception',
          'genre_ids': [28, 12, 878],
        });
        expect(tmdbSearch.genres, isEmpty);
        expect(tmdbSearch.genreIds, [28, 12, 878]);

        final movie = PauloFlixMovie.fromTmdb(
          folderName: 'Inception',
          serverUrl: 'http://server/inception/',
          tmdb: tmdbSearch,
          genreIdToName: {
            28: 'Ação',
            12: 'Aventura',
            878: 'Ficção Científica',
          },
        );
        expect(movie.genres, ['Ação', 'Aventura', 'Ficção Científica']);
      },
    );

    test(
      'search sem genreIdToName → genres fica vazio (regressão)',
      () {
        // Comportamento legacy: sem o cache, o filme fica sem gêneros.
        // Esse é o caso que existia antes do fix — preservado por
        // compatibilidade.
        final tmdbSearch = TmdbMovie.fromSearchJson({
          'id': 27205,
          'title': 'Inception',
          'genre_ids': [28, 12, 878],
        });
        final movie = PauloFlixMovie.fromTmdb(
          folderName: 'Inception',
          serverUrl: 'http://server/inception/',
          tmdb: tmdbSearch,
        );
        expect(movie.genres, isEmpty);
      },
    );

    test(
      'detalhes com genres populados (endpoint /movie/{id}) → usa direto',
      () {
        // Quando o endpoint /movie/{id} é usado, `tmdb.genres` já vem
        // populado com nomes. O genreIdToName é IGNORADO nesse caminho
        // (não faz sentido misturar).
        final tmdbDetails = TmdbMovie(
          id: 27205,
          title: 'Inception',
          genres: [
            TmdbGenre(id: 28, name: 'Ação'),
            TmdbGenre(id: 12, name: 'Aventura'),
          ],
        );
        final movie = PauloFlixMovie.fromTmdb(
          folderName: 'Inception',
          serverUrl: 'http://server/inception/',
          tmdb: tmdbDetails,
          genreIdToName: const {
            28: 'IGNORADO — genres tem prioridade',
          },
        );
        expect(movie.genres, ['Ação', 'Aventura']);
      },
    );

    test(
      'genreIdToName cobre parcialmente genre_ids → inclui só os conhecidos',
      () {
        // O cache pode estar desatualizado. IDs não cobertos são pulados
        // (whereType<String>() filtra nulls).
        final tmdbSearch = TmdbMovie.fromSearchJson({
          'id': 27205,
          'title': 'Inception',
          'genre_ids': [28, 12, 9999], // 9999 não está no mapa
        });
        final movie = PauloFlixMovie.fromTmdb(
          folderName: 'Inception',
          serverUrl: 'http://server/inception/',
          tmdb: tmdbSearch,
          genreIdToName: {28: 'Ação', 12: 'Aventura'},
        );
        expect(movie.genres, ['Ação', 'Aventura']);
        expect(movie.genres, isNot(contains('9999')));
      },
    );

    test(
      'tmdb.genres vazio + genreIdToName vazio → genres fica vazio',
      () {
        final tmdbSearch = TmdbMovie.fromSearchJson({
          'id': 27205,
          'title': 'Inception',
        });
        final movie = PauloFlixMovie.fromTmdb(
          folderName: 'Inception',
          serverUrl: 'http://server/inception/',
          tmdb: tmdbSearch,
          genreIdToName: const {},
        );
        expect(movie.genres, isEmpty);
      },
    );
  });
}
