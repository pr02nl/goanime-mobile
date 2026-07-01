import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/domain/models/pauloflix_movie.dart';
import 'package:goanime/ui/pauloflix_movies/widgets/pauloflix_movies_home_screen.dart';

void main() {
  group('tmdbIdForMovie — lookup do tmdbId por folderName', () {
    final movies = [
      PauloFlixMovie(
        folderName: 'inception_2010',
        displayName: 'Inception',
        serverUrl: 'http://server/inception/',
        tmdbId: 27205,
      ),
      PauloFlixMovie(
        folderName: 'interstellar_2014',
        displayName: 'Interstellar',
        serverUrl: 'http://server/interstellar/',
        tmdbId: 157336,
      ),
      PauloFlixMovie(
        folderName: 'tenet_2020',
        displayName: 'Tenet',
        serverUrl: 'http://server/tenet/',
        // tmdbId não definido — simula filme sem metadado TMDB.
      ),
    ];

    test(
      'encontra tmdbId quando folderName existe no provider',
      () {
        expect(
          tmdbIdForMovie(movies, 'inception_2010'),
          27205,
        );
      },
    );

    test(
      'retorna tmdbId de outro filme quando folderName difere',
      () {
        expect(
          tmdbIdForMovie(movies, 'interstellar_2014'),
          157336,
        );
      },
    );

    test(
      'retorna null quando folderName não existe no provider',
      () {
        expect(
          tmdbIdForMovie(movies, 'inexistente'),
          isNull,
        );
      },
    );

    test(
      'retorna null quando tmdbId é null no filme encontrado',
      () {
        expect(
          tmdbIdForMovie(movies, 'tenet_2020'),
          isNull,
        );
      },
    );

    test(
      'lista vazia resulta em null (nenhum filme carregado)',
      () {
        expect(
          tmdbIdForMovie(const <PauloFlixMovie>[], 'qualquer'),
          isNull,
        );
      },
    );

    test(
      'folderName com espaços e caracteres especiais',
      () {
        final movie = PauloFlixMovie(
          folderName: 'filme com acentuação 2024',
          displayName: 'Filme Teste',
          serverUrl: 'http://server/filme/',
          tmdbId: 12345,
        );
        expect(
          tmdbIdForMovie([movie], 'filme com acentuação 2024'),
          12345,
        );
      },
    );
  });
}
