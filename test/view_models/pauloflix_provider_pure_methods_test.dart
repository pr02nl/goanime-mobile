import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/domain/models/pauloflix_content.dart';
import 'package:goanime/ui/pauloflix/view_models/pauloflix_provider.dart';

PauloFlixContent _anime({
  required String displayName,
  String folderName = '',
  double? score,
  List<String> genres = const [],
  int? malId,
}) {
  return PauloFlixContent(
    folderName: folderName.isEmpty ? displayName : folderName,
    displayName: displayName,
    serverUrl: 'http://server/$displayName/',
    score: score,
    genres: genres,
    malId: malId,
  );
}

void main() {
  // ───────────────────────────────────────────────────────────────────────
  // pickFeaturedContent
  // ───────────────────────────────────────────────────────────────────────

  group('PauloFlixProvider.pickFeaturedContent', () {
    test('lista vazia retorna null', () {
      expect(PauloFlixProvider.pickFeaturedContent([]), isNull);
    });

    test('retorna o anime com maior score', () {
      final contents = [
        _anime(displayName: 'A', score: 7.0),
        _anime(displayName: 'B', score: 9.5),
        _anime(displayName: 'C', score: 8.0),
      ];
      final result = PauloFlixProvider.pickFeaturedContent(contents);
      expect(result!.displayName, 'B');
    });

    test('desempata por displayName alfabético (case-insensitive)', () {
      final contents = [
        _anime(displayName: 'Zeta', score: 8.0),
        _anime(displayName: 'alfa', score: 8.0),
      ];
      final result = PauloFlixProvider.pickFeaturedContent(contents);
      // 'alfa' < 'zeta' alfabeticamente
      expect(result!.displayName, 'alfa');
    });

    test('animes sem score ficam atrás dos com score', () {
      final contents = [
        _anime(displayName: 'NoScore'),
        _anime(displayName: 'WithScore', score: 5.0),
      ];
      final result = PauloFlixProvider.pickFeaturedContent(contents);
      expect(result!.displayName, 'WithScore');
    });

    test('não muta a lista original', () {
      final contents = [
        _anime(displayName: 'A', score: 7.0),
        _anime(displayName: 'B', score: 9.0),
      ];
      final originalOrder = contents.map((c) => c.displayName).toList();
      PauloFlixProvider.pickFeaturedContent(contents);
      expect(contents.map((c) => c.displayName).toList(), originalOrder);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // groupByTopGenres
  // ───────────────────────────────────────────────────────────────────────

  group('PauloFlixProvider.groupByTopGenres', () {
    test('lista vazia retorna map vazio', () {
      expect(PauloFlixProvider.groupByTopGenres([]), isEmpty);
    });

    test('retorna top N gêneros por contagem de animes', () {
      final contents = [
        _anime(displayName: 'A', genres: ['Action']),
        _anime(displayName: 'B', genres: ['Action']),
        _anime(displayName: 'C', genres: ['Action']),
        _anime(displayName: 'D', genres: ['Drama']),
        _anime(displayName: 'E', genres: ['Drama']),
        _anime(displayName: 'F', genres: ['Comedy']),
        _anime(displayName: 'G', genres: ['Comedy']),
        _anime(displayName: 'H', genres: ['Comedy']),
      ];
      final result = PauloFlixProvider.groupByTopGenres(
        contents,
        minPerGenre: 2,
      );
      expect(result.keys, containsAll(['Action', 'Comedy']));
      expect(result.keys.length, 2);
    });

    test('omite gêneros com menos animes que minPerGenre', () {
      final contents = [
        _anime(displayName: 'A', genres: ['Action']),
        _anime(displayName: 'B', genres: ['Action']),
        _anime(displayName: 'C', genres: ['Action']),
        _anime(displayName: 'D', genres: ['Horror']),
      ];
      final result = PauloFlixProvider.groupByTopGenres(
        contents,
        minPerGenre: 3,
      );
      expect(result.keys, ['Action']);
      expect(result['Horror'], isNull);
    });

    test('respeita perGenre limit por gênero', () {
      final contents = List.generate(
        20,
        (i) => _anime(displayName: 'M$i', score: 10.0 - i, genres: ['Action']),
      );
      final result = PauloFlixProvider.groupByTopGenres(
        contents,
        perGenre: 5,
        minPerGenre: 1,
      );
      expect(result['Action']!.length, 5);
      expect(result['Action']!.first.displayName, 'M0');
    });

    test('ranqueia animes dentro do gênero por score desc', () {
      final contents = [
        _anime(displayName: 'Low', score: 5.0, genres: ['Drama']),
        _anime(displayName: 'High', score: 9.0, genres: ['Drama']),
        _anime(displayName: 'Mid', score: 7.0, genres: ['Drama']),
      ];
      final result = PauloFlixProvider.groupByTopGenres(
        contents,
        minPerGenre: 1,
      );
      expect(result['Drama']!.map((c) => c.displayName).toList(), [
        'High',
        'Mid',
        'Low',
      ]);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // paginateByLetter
  // ───────────────────────────────────────────────────────────────────────

  group('PauloFlixProvider.paginateByLetter', () {
    test('lista vazia retorna PaginationResult vazio', () {
      final result = PauloFlixProvider.paginateByLetter([]);
      expect(result.pages, isEmpty);
      expect(result.letterToPageIndex, isEmpty);
      expect(result.availableLetters, isEmpty);
    });

    test('ordena alfabeticamente case-insensitive', () {
      final contents = [
        _anime(displayName: 'banana'),
        _anime(displayName: 'Apple'),
        _anime(displayName: 'cherry'),
      ];
      final result = PauloFlixProvider.paginateByLetter(contents);
      final names = result.pages.first.map((c) => c.displayName).toList();
      expect(names, ['Apple', 'banana', 'cherry']);
    });

    test('animes com número/símbolo no início vão para "#"', () {
      final contents = [
        _anime(displayName: 'Alien'),
        _anime(displayName: '300'),
        _anime(displayName: 'Brazil'),
      ];
      final result = PauloFlixProvider.paginateByLetter(contents);
      expect(result.availableLetters, ['A', 'B', '#']);
      // O anime com número fica no fim da última página.
      final last = result.pages.last.last;
      expect(last.displayName, '300');
    });

    test('perPage=2 em lista de 5 produz 3 páginas (2, 2, 1)', () {
      final contents = List.generate(
        5,
        (i) => _anime(displayName: 'M${i.toString().padLeft(2, '0')}'),
      );
      final result = PauloFlixProvider.paginateByLetter(contents, perPage: 2);
      expect(result.pages.length, 3);
      expect(result.pages[0].length, 2);
      expect(result.pages[1].length, 2);
      expect(result.pages[2].length, 1);
    });

    test('letterToPageIndex aponta para a primeira página com a letra', () {
      // 30 animes: 10 de A, 10 de B, 10 de C — com perPage=8 são 4 páginas.
      final contents = <PauloFlixContent>[];
      for (final letter in ['A', 'B', 'C']) {
        for (var i = 0; i < 10; i++) {
          contents.add(_anime(displayName: '$letter$i'));
        }
      }
      final result = PauloFlixProvider.paginateByLetter(contents, perPage: 8);
      expect(result.letterToPageIndex['A'], 0);
      expect(result.letterToPageIndex['B'], 1);
      expect(result.letterToPageIndex['C'], 2);
    });

    test('availableLetters contém apenas letras com ≥1 anime', () {
      final contents = [
        _anime(displayName: 'Alien'),
        _anime(displayName: 'Avatar'),
        _anime(displayName: 'Zodiac'),
      ];
      final result = PauloFlixProvider.paginateByLetter(contents);
      expect(result.availableLetters, ['A', 'Z']);
    });

    test('não muta a lista original', () {
      final contents = [
        _anime(displayName: 'Z'),
        _anime(displayName: 'A'),
        _anime(displayName: 'M'),
      ];
      final original = contents.map((c) => c.displayName).toList();
      PauloFlixProvider.paginateByLetter(contents);
      expect(contents.map((c) => c.displayName).toList(), original);
    });
  });
}
