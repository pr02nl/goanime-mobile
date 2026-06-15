import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/models/pauloflix_models.dart';

void main() {
  group('PauloFlixShow', () {
    test('deve criar show corretamente', () {
      final show = PauloFlixShow(
        name: 'Naruto',
        url: 'http://server/tvshows/Naruto/',
      );

      expect(show.name, 'Naruto');
      expect(show.url, 'http://server/tvshows/Naruto/');
    });

    test('toString deve retornar name', () {
      final show = PauloFlixShow(name: 'Naruto', url: 'http://server/');
      expect(show.toString(), 'Naruto');
    });

    test('deve comparar por name e url', () {
      final a = PauloFlixShow(name: 'Naruto', url: 'http://a/');
      final b = PauloFlixShow(name: 'Naruto', url: 'http://a/');
      final c = PauloFlixShow(name: 'Naruto', url: 'http://b/');

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });

  group('PauloFlixSeason', () {
    test('deve criar season corretamente', () {
      final season = PauloFlixSeason(
        name: 'Season 1',
        url: 'http://server/Naruto/Season%201/',
        number: 1,
      );

      expect(season.name, 'Season 1');
      expect(season.number, 1);
    });

    test('toString deve retornar Season number', () {
      final season = PauloFlixSeason(
        name: 'Season 2',
        url: 'http://server/',
        number: 2,
      );
      expect(season.toString(), 'Season 2');
    });

    test('deve comparar por name, url e number', () {
      final a = PauloFlixSeason(name: 'S1', url: 'http://a/', number: 1);
      final b = PauloFlixSeason(name: 'S1', url: 'http://a/', number: 1);
      final c = PauloFlixSeason(name: 'S1', url: 'http://a/', number: 2);

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });

  group('PauloFlixEpisode', () {
    test('deve criar episode corretamente', () {
      final episode = PauloFlixEpisode(
        number: 1,
        title: 'Enter: Naruto',
        url: 'http://server/Naruto/S01E01.mkv',
        fileSize: 500000000,
      );

      expect(episode.number, 1);
      expect(episode.title, 'Enter: Naruto');
      expect(episode.fileSize, 500000000);
    });

    test('deve criar sem fileSize', () {
      final episode = PauloFlixEpisode(
        number: 2,
        title: 'My Name is Konohamaru',
        url: 'http://server/Naruto/S01E02.mkv',
      );

      expect(episode.fileSize, isNull);
    });

    test('toString deve retornar informacoes', () {
      final episode = PauloFlixEpisode(
        number: 1,
        title: 'Test Episode',
        url: 'http://server/test.mkv',
      );
      expect(episode.toString(), 'Episode 1: Test Episode');
    });

    test('deve comparar por number, title e url', () {
      final a = PauloFlixEpisode(number: 1, title: 'Ep1', url: 'http://a/');
      final b = PauloFlixEpisode(number: 1, title: 'Ep1', url: 'http://a/');
      final c = PauloFlixEpisode(number: 2, title: 'Ep1', url: 'http://a/');

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });
}
