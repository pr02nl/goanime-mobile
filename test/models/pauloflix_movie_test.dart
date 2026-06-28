import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/data/models/tmdb_models.dart';
import 'package:goanime/domain/models/pauloflix_movie.dart';

void main() {
  group('PauloFlixMovie', () {
    const baseHost = 'https://media.oliveira.braga.nom.br';

    test('deve criar com valores padrao', () {
      final movie = PauloFlixMovie(
        folderName: 'Inception',
        displayName: 'Inception',
        serverUrl: 'http://server/inception/',
      );

      expect(movie.folderName, 'Inception');
      expect(movie.imageUrl, isNull);
      expect(movie.genres, isEmpty);
      expect(movie.videoUrl, isNull);
      expect(movie.subtitles, isNull);
      expect(movie.isCollection, false);
      expect(movie.availableMovieCount, 0);
      expect(movie.isAvailable, true);
    });

    test('deve criar a partir de TmdbMovie via fromTmdb', () {
      final tmdb = TmdbMovie(
        id: 27205,
        title: 'Inception',
        overview: 'A thief who steals corporate secrets...',
        posterPath: '/poster.jpg',
        backdropPath: '/backdrop.jpg',
        voteAverage: 8.4,
        releaseDate: '2010-07-16',
        runtime: 148,
        genres: [
          TmdbGenre(id: 1, name: 'Action'),
          TmdbGenre(id: 2, name: 'Sci-Fi'),
        ],
      );

      final movie = PauloFlixMovie.fromTmdb(
        folderName: 'Inception',
        serverUrl: 'http://server/inception/',
        tmdb: tmdb,
      );

      expect(movie.displayName, 'Inception');
      expect(movie.imageUrl, 'https://image.tmdb.org/t/p/w500/poster.jpg');
      expect(movie.bannerUrl, 'https://image.tmdb.org/t/p/w1280/backdrop.jpg');
      expect(movie.description, 'A thief who steals corporate secrets...');
      expect(movie.score, 8.4);
      expect(movie.releaseDate, '2010-07-16');
      expect(movie.runtime, 148);
      expect(movie.year, 2010);
      expect(movie.tmdbId, 27205);
      expect(movie.videoUrl, isNull);
      expect(movie.subtitles, isNull);
      expect(movie.isCollection, false);
      expect(movie.availableMovieCount, 1);
      expect(movie.genres, ['Action', 'Sci-Fi']);
    });

    test('toMap e fromMap devem ser consistentes', () {
      final original = PauloFlixMovie(
        id: 1,
        folderName: 'Inception',
        displayName: 'Inception',
        serverUrl: 'http://server/inception/',
        imageUrl: 'http://image.com/inception.jpg',
        bannerUrl: 'http://image.com/inception_banner.jpg',
        description: 'A mind-bending thriller',
        score: 8.8,
        genres: ['Action', 'Thriller'],
        releaseDate: '2010-07-16',
        runtime: 148,
        year: 2010,
        tmdbId: 27205,
        isCollection: false,
        availableMovieCount: 1,
        isAvailable: true,
      );

      final map = original.toMap();
      final restored = PauloFlixMovie.fromMap(map);

      expect(restored.folderName, original.folderName);
      expect(restored.displayName, original.displayName);
      expect(restored.serverUrl, original.serverUrl);
      expect(restored.imageUrl, original.imageUrl);
      expect(restored.bannerUrl, original.bannerUrl);
      expect(restored.description, original.description);
      expect(restored.score, original.score);
      expect(restored.genres, original.genres);
      expect(restored.releaseDate, original.releaseDate);
      expect(restored.runtime, original.runtime);
      expect(restored.year, original.year);
      expect(restored.tmdbId, original.tmdbId);
      expect(restored.videoUrl, isNull);
      expect(restored.subtitles, isNull);
      expect(restored.isCollection, original.isCollection);
      expect(restored.availableMovieCount, original.availableMovieCount);
      expect(restored.isAvailable, original.isAvailable);
    });

    test('fromMap deve tratar score como num para aceitar int', () {
      final map = {
        'folderName': 'Test',
        'displayName': 'Test',
        'serverUrl': 'http://server/',
        'genres': 'Action,Comedy',
        'lastSynced': '2024-01-01T00:00:00.000',
        'isAvailable': 1,
        'isCollection': 0,
        'availableMovieCount': 1,
      };
      final movie = PauloFlixMovie.fromMap(map);
      expect(movie.genres, ['Action', 'Comedy']);
      expect(movie.score, isNull);
      expect(movie.videoUrl, isNull);
      expect(movie.subtitles, isNull);
    });

    test('deve representar colecao corretamente', () {
      final movie = PauloFlixMovie(
        folderName: 'Harry Potter Collection',
        displayName: 'Coleção Harry Potter',
        serverUrl: 'http://server/hp/',
        isCollection: true,
        availableMovieCount: 8,
      );

      expect(movie.isCollection, true);
      expect(movie.availableMovieCount, 8);
    });

    test('toString deve retornar displayName', () {
      final movie = PauloFlixMovie(
        folderName: 'Test',
        displayName: 'Test Movie',
        serverUrl: 'http://server/',
      );
      expect(movie.toString(), 'PauloFlixMovie(Test Movie)');
    });

    group('fromMovieIndex com file e subtitles', () {
      test('deve parsear file e resolver para URL absoluta', () async {
        final json = <String, dynamic>{
          'path': '2012 (2009)',
          'title': '2012',
          'file': '/movies/2012 (2009)/2012.2009.1080p.mp4',
        };

        final movie = PauloFlixMovie.fromMovieIndex(
          json: json,
          baseHost: baseHost,
        );

        expect(
          movie.videoUrl,
          '$baseHost/movies/2012 (2009)/2012.2009.1080p.mp4',
        );
        expect(movie.folderName, '2012 (2009)');
        expect(movie.displayName, '2012');
        expect(movie.subtitles, isNull);
      });

      test('deve parsear subtitles e resolver caminhos', () async {
        final json = <String, dynamic>{
          'path': '2012 (2009)',
          'title': '2012',
          'file': '/movies/2012 (2009)/2012.2009.1080p.mp4',
          'subtitles': [
            {
              'file': '/movies/2012 (2009)/sub.srt',
              'lang': 'pob',
              'name': 'sub.srt',
            },
            {
              'file': '/movies/2012 (2009)/eng.srt',
              'lang': 'eng',
              'name': 'eng.srt',
            },
          ],
        };

        final movie = PauloFlixMovie.fromMovieIndex(
          json: json,
          baseHost: baseHost,
        );

        expect(
          movie.videoUrl,
          '$baseHost/movies/2012 (2009)/2012.2009.1080p.mp4',
        );
        expect(movie.subtitles, isNotNull);
        expect(movie.subtitles!.length, 2);

        expect(
          movie.subtitles![0].file,
          '$baseHost/movies/2012 (2009)/sub.srt',
        );
        expect(movie.subtitles![0].lang, 'pob');
        expect(movie.subtitles![0].name, 'sub.srt');

        expect(
          movie.subtitles![1].file,
          '$baseHost/movies/2012 (2009)/eng.srt',
        );
        expect(movie.subtitles![1].lang, 'eng');
        expect(movie.subtitles![1].name, 'eng.srt');
      });

      test('deve manter file null quando ausente', () async {
        final json = <String, dynamic>{
          'path': 'Inception',
          'title': 'Inception',
        };

        final movie = PauloFlixMovie.fromMovieIndex(
          json: json,
          baseHost: baseHost,
        );

        expect(movie.videoUrl, isNull);
        expect(movie.subtitles, isNull);
      });

      test('deve manter subtitles null quando lista vazia', () async {
        final json = <String, dynamic>{
          'path': 'Inception',
          'title': 'Inception',
          'file': '/movies/Inception/Inception.mkv',
          'subtitles': <Map<String, dynamic>>[],
        };

        final movie = PauloFlixMovie.fromMovieIndex(
          json: json,
          baseHost: baseHost,
        );

        expect(movie.videoUrl, '$baseHost/movies/Inception/Inception.mkv');
        expect(movie.subtitles, isNull);
      });

      test('deve manter subtitles como null quando campo ausente', () async {
        final json = <String, dynamic>{
          'path': 'Inception',
          'title': 'Inception',
          'file': '/movies/Inception/Inception.mkv',
        };

        final movie = PauloFlixMovie.fromMovieIndex(
          json: json,
          baseHost: baseHost,
        );

        expect(movie.videoUrl, '$baseHost/movies/Inception/Inception.mkv');
        expect(movie.subtitles, isNull);
      });

      test('nao deve modificar file quando ja e URL absoluta', () async {
        final json = <String, dynamic>{
          'path': 'Inception',
          'title': 'Inception',
          'file': 'https://cdn.example.com/movies/Inception.mkv',
        };

        final movie = PauloFlixMovie.fromMovieIndex(
          json: json,
          baseHost: baseHost,
        );

        expect(movie.videoUrl, 'https://cdn.example.com/movies/Inception.mkv');
      });

      test('toMap/fromMap round-trip com videoUrl e subtitles', () async {
        final json = <String, dynamic>{
          'path': '2012 (2009)',
          'title': '2012',
          'file': '/movies/2012 (2009)/2012.2009.1080p.mp4',
          'subtitles': [
            {
              'file': '/movies/2012 (2009)/sub.srt',
              'lang': 'pob',
              'name': 'sub.srt',
            },
          ],
        };

        final original = PauloFlixMovie.fromMovieIndex(
          json: json,
          baseHost: baseHost,
        );

        final map = original.toMap();
        final restored = PauloFlixMovie.fromMap(map);

        expect(restored.videoUrl, original.videoUrl);
        expect(restored.subtitles, isNotNull);
        expect(restored.subtitles!.length, 1);
        expect(restored.subtitles![0].file, original.subtitles![0].file);
        expect(restored.subtitles![0].lang, original.subtitles![0].lang);
        expect(restored.subtitles![0].name, original.subtitles![0].name);
      });

      test('toMap deve serializar subtitles como JSON string', () async {
        final json = <String, dynamic>{
          'path': '2012 (2009)',
          'title': '2012',
          'file': '/movies/2012 (2009)/2012.2009.1080p.mp4',
          'subtitles': [
            {
              'file': '/movies/2012 (2009)/sub.srt',
              'lang': 'pob',
              'name': 'sub.srt',
            },
          ],
        };

        final movie = PauloFlixMovie.fromMovieIndex(
          json: json,
          baseHost: baseHost,
        );

        final map = movie.toMap();
        expect(map['subtitles'], isA<String>());
        final decoded = jsonDecode(map['subtitles'] as String) as List;
        expect(decoded.length, 1);
        expect(decoded[0]['lang'], 'pob');
      });
    });
  });
}
