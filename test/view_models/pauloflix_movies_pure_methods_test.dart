import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/domain/models/pauloflix_movie.dart';
import 'package:goanime/ui/pauloflix_movies/view_models/pauloflix_movies_provider.dart';

PauloFlixMovie _movie({
  required String displayName,
  String folderName = '',
  double? score,
  int? year,
  List<String> genres = const [],
}) {
  return PauloFlixMovie(
    folderName: folderName.isEmpty ? displayName : folderName,
    displayName: displayName,
    serverUrl: 'http://server/$displayName/',
    score: score,
    year: year,
    genres: genres,
  );
}

void main() {
  // ───────────────────────────────────────────────────────────────────────
  // pickFeaturedMovie
  // ───────────────────────────────────────────────────────────────────────

  group('PauloFlixMoviesProvider.pickFeaturedMovie', () {
    test('lista vazia retorna null', () {
      final result = PauloFlixMoviesProvider.pickFeaturedMovie([]);
      expect(result, isNull);
    });

    test('retorna o filme com maior score', () {
      final movies = [
        _movie(displayName: 'A', score: 7.0),
        _movie(displayName: 'B', score: 9.5),
        _movie(displayName: 'C', score: 8.0),
      ];
      final result = PauloFlixMoviesProvider.pickFeaturedMovie(movies);
      expect(result, isNotNull);
      expect(result!.displayName, 'B');
    });

    test('desempata por year desc (mais recente primeiro)', () {
      final movies = [
        _movie(displayName: 'A', score: 8.0, year: 2010),
        _movie(displayName: 'B', score: 8.0, year: 2020),
      ];
      final result = PauloFlixMoviesProvider.pickFeaturedMovie(movies);
      expect(result!.displayName, 'B');
    });

    test('desempata por folderName quando score e year empatam', () {
      final movies = [
        _movie(
          displayName: 'B',
          score: 8.0,
          year: 2020,
        ),
        _movie(
          displayName: 'A',
          score: 8.0,
          year: 2020,
        ),
      ];
      final result = PauloFlixMoviesProvider.pickFeaturedMovie(movies);
      expect(result!.displayName, 'A');
    });

    test('folderName com caracteres especiais (espaço, parênteses, hífen) ordena corretamente', () {
      final movies = [
        _movie(
          folderName: 'Interestelar (2014)',
          displayName: 'Interestelar',
          score: 8.0,
          year: 2020,
        ),
        _movie(
          folderName: 'Homem-Aranha - Longe de Casa (2019)',
          displayName: 'Homem-Aranha',
          score: 8.0,
          year: 2020,
        ),
        _movie(
          folderName: 'Matrix (1999)',
          displayName: 'Matrix',
          score: 8.0,
          year: 2020,
        ),
      ];
      final result = PauloFlixMoviesProvider.pickFeaturedMovie(movies);
      // H < I < M em ordem alfabética
      expect(result!.displayName, 'Homem-Aranha');
      // Verifica que todos os filmes estão na lista original (imutabilidade)
      expect(movies, hasLength(3));
    });

    test('filmes sem score ficam atrás dos com score', () {
      final movies = [
        _movie(displayName: 'NoScore'),
        _movie(displayName: 'WithScore', score: 5.0),
      ];
      final result = PauloFlixMoviesProvider.pickFeaturedMovie(movies);
      expect(result!.displayName, 'WithScore');
    });

    test('não muta a lista original', () {
      final movies = [
        _movie(displayName: 'A', score: 7.0),
        _movie(displayName: 'B', score: 9.0),
      ];
      final originalOrder = movies.map((m) => m.displayName).toList();
      PauloFlixMoviesProvider.pickFeaturedMovie(movies);
      expect(
        movies.map((m) => m.displayName).toList(),
        originalOrder,
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // groupByTopGenres
  // ───────────────────────────────────────────────────────────────────────

  group('PauloFlixMoviesProvider.groupByTopGenres', () {
    test('lista vazia retorna map vazio', () {
      final result = PauloFlixMoviesProvider.groupByTopGenres([]);
      expect(result, isEmpty);
    });

    test('retorna top N gêneros por contagem de filmes', () {
      final movies = [
        _movie(displayName: 'A', genres: ['Action']),
        _movie(displayName: 'B', genres: ['Action']),
        _movie(displayName: 'C', genres: ['Action']),
        _movie(displayName: 'D', genres: ['Drama']),
        _movie(displayName: 'E', genres: ['Drama']),
        _movie(displayName: 'F', genres: ['Comedy']),
        _movie(displayName: 'G', genres: ['Comedy']),
        _movie(displayName: 'H', genres: ['Comedy']),
      ];
      final result = PauloFlixMoviesProvider.groupByTopGenres(
        movies,
        maxGenres: 2,
        minPerGenre: 2,
      );
      // Action (3) e Comedy (3) — Drama (2) excluído pelo top 2.
      expect(result.keys, containsAll(['Action', 'Comedy']));
      expect(result.keys.length, 2);
    });

    test('omite gêneros com menos filmes que minPerGenre', () {
      final movies = [
        _movie(displayName: 'A', genres: ['Action']),
        _movie(displayName: 'B', genres: ['Action']),
        _movie(displayName: 'C', genres: ['Action']),
        _movie(displayName: 'D', genres: ['Horror']),
      ];
      final result = PauloFlixMoviesProvider.groupByTopGenres(
        movies,
        minPerGenre: 3,
      );
      expect(result.keys, ['Action']);
      expect(result['Horror'], isNull);
    });

    test('respeita perGenre limit por gênero', () {
      final movies = List.generate(
        20,
        (i) => _movie(displayName: 'M$i', score: 10.0 - i, genres: ['Action']),
      );
      final result = PauloFlixMoviesProvider.groupByTopGenres(
        movies,
        perGenre: 5,
        minPerGenre: 1,
      );
      expect(result['Action']!.length, 5);
      // Primeiros 5 são os de maior score.
      expect(result['Action']!.first.displayName, 'M0');
      expect(result['Action']!.last.displayName, 'M4');
    });

    test('ranqueia filmes dentro do gênero por score desc', () {
      final movies = [
        _movie(displayName: 'Low', score: 5.0, genres: ['Drama']),
        _movie(displayName: 'High', score: 9.0, genres: ['Drama']),
        _movie(displayName: 'Mid', score: 7.0, genres: ['Drama']),
      ];
      final result = PauloFlixMoviesProvider.groupByTopGenres(
        movies,
        minPerGenre: 1,
      );
      expect(result['Drama']!.map((m) => m.displayName).toList(),
          ['High', 'Mid', 'Low']);
    });

    test('filme com múltiplos gêneros aparece em vários grupos', () {
      final movies = [
        _movie(
          displayName: 'Matrix',
          score: 9.0,
          genres: ['Action', 'Sci-Fi'],
        ),
        _movie(displayName: 'A1', score: 7.0, genres: ['Action']),
        _movie(displayName: 'A2', score: 7.0, genres: ['Action']),
        _movie(displayName: 'A3', score: 7.0, genres: ['Action']),
        _movie(displayName: 'S1', score: 7.0, genres: ['Sci-Fi']),
        _movie(displayName: 'S2', score: 7.0, genres: ['Sci-Fi']),
        _movie(displayName: 'S3', score: 7.0, genres: ['Sci-Fi']),
      ];
      final result = PauloFlixMoviesProvider.groupByTopGenres(
        movies,
        maxGenres: 2,
        minPerGenre: 3,
      );
      expect(result['Action'], isNotNull);
      expect(result['Sci-Fi'], isNotNull);
      // Matrix é o top em ambos (score 9).
      expect(result['Action']!.first.displayName, 'Matrix');
      expect(result['Sci-Fi']!.first.displayName, 'Matrix');
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // genreIcon
  // ───────────────────────────────────────────────────────────────────────

  group('PauloFlixMoviesProvider.genreIcon', () {
    test('Action → flash_on', () {
      expect(PauloFlixMoviesProvider.genreIcon('Action'), 'flash_on');
    });

    test('Science Fiction → rocket_launch', () {
      expect(
        PauloFlixMoviesProvider.genreIcon('Science Fiction'),
        'rocket_launch',
      );
    });

    test('Sci-Fi → rocket_launch (alias)', () {
      expect(PauloFlixMoviesProvider.genreIcon('Sci-Fi'), 'rocket_launch');
    });

    test('gênero desconhecido → movie_outlined (fallback)', () {
      expect(
        PauloFlixMoviesProvider.genreIcon('GêneroInventado'),
        'movie_outlined',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // paginateByLetter
  // ───────────────────────────────────────────────────────────────────────

  group('PauloFlixMoviesProvider.paginateByLetter', () {
    test('lista vazia retorna PaginationResult vazio', () {
      final result = PauloFlixMoviesProvider.paginateByLetter([]);
      expect(result.pages, isEmpty);
      expect(result.letterToPageIndex, isEmpty);
      expect(result.availableLetters, isEmpty);
    });

    test('ordena alfabeticamente case-insensitive', () {
      final movies = [
        _movie(displayName: 'banana'),
        _movie(displayName: 'Apple'),
        _movie(displayName: 'cherry'),
      ];
      final result = PauloFlixMoviesProvider.paginateByLetter(movies);
      final names = result.pages.first.map((m) => m.displayName).toList();
      expect(names, ['Apple', 'banana', 'cherry']);
    });

    test('filmes com número/símbolo no início vão para "#"', () {
      final movies = [
        _movie(displayName: 'Alien'),
        _movie(displayName: '300'),
        _movie(displayName: 'Brazil'),
      ];
      final result = PauloFlixMoviesProvider.paginateByLetter(movies);
      // "#" (300) fica no fim; ordem: A → B → #.
      expect(result.availableLetters, ['A', 'B', '#']);
      // O filme com número fica no fim da última página.
      final lastMovie = result.pages.last.last;
      expect(lastMovie.displayName, '300');
      // letterToPageIndex['#'] aponta para a página onde está o "300".
      expect(result.letterToPageIndex['#'], isNotNull);
    });

    test('perPage=2 em lista de 5 produz 3 páginas (2, 2, 1)', () {
      final movies = List.generate(
        5,
        (i) => _movie(displayName: 'M${i.toString().padLeft(2, '0')}'),
      );
      final result = PauloFlixMoviesProvider.paginateByLetter(
        movies,
        perPage: 2,
      );
      expect(result.pages.length, 3);
      expect(result.pages[0].length, 2);
      expect(result.pages[1].length, 2);
      expect(result.pages[2].length, 1);
    });

    test('letterToPageIndex aponta para a primeira página com a letra', () {
      // 30 filmes: 10 de A, 10 de B, 10 de C — com perPage=8 são 4 páginas.
      final movies = <PauloFlixMovie>[];
      for (final letter in ['A', 'B', 'C']) {
        for (var i = 0; i < 10; i++) {
          movies.add(_movie(displayName: '$letter$i'));
        }
      }
      final result = PauloFlixMoviesProvider.paginateByLetter(
        movies,
        perPage: 8,
      );
      // A0..A7 → página 0; A8..A9, B0..B5 → página 1; B6..B9, C0..C3 → 2; C4..C9 → 3.
      expect(result.letterToPageIndex['A'], 0);
      expect(result.letterToPageIndex['B'], 1);
      expect(result.letterToPageIndex['C'], 2);
    });

    test('availableLetters contém apenas letras com ≥1 filme', () {
      final movies = [
        _movie(displayName: 'Alien'),
        _movie(displayName: 'Avatar'),
        // Buracos propositais: C, D, E, F... não aparecem.
        _movie(displayName: 'Zodiac'),
      ];
      final result = PauloFlixMoviesProvider.paginateByLetter(movies);
      expect(result.availableLetters, ['A', 'Z']);
    });

    test('não muta a lista original (cria cópia)', () {
      final movies = [
        _movie(displayName: 'Z'),
        _movie(displayName: 'A'),
        _movie(displayName: 'M'),
      ];
      final original = movies.map((m) => m.displayName).toList();
      PauloFlixMoviesProvider.paginateByLetter(movies);
      expect(movies.map((m) => m.displayName).toList(), original);
    });
  });
}
