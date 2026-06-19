import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/models/episode.dart';

void main() {
  group('Episode', () {
    test('deve criar episode corretamente', () {
      final episode = Episode(
        number: '1',
        url: 'http://server/ep1.mp4',
        thumbnail: 'http://server/thumb.jpg',
        title: 'Episode 1',
        description: 'The first episode',
      );

      expect(episode.number, '1');
      expect(episode.url, 'http://server/ep1.mp4');
      expect(episode.thumbnail, 'http://server/thumb.jpg');
      expect(episode.title, 'Episode 1');
      expect(episode.description, 'The first episode');
    });

    test('subtitleUrl deve retornar null quando sem legendas', () {
      final episode = Episode(number: '1', url: 'http://server/ep1.mp4');
      expect(episode.subtitleUrl, isNull);
      expect(episode.subtitleLanguage, isNull);
    });

    test('getImageUrl deve retornar thumbnail', () {
      final episode = Episode(
        number: '1',
        url: 'http://server/ep1.mp4',
        thumbnail: 'http://server/thumb.jpg',
      );
      expect(episode.getImageUrl(), 'http://server/thumb.jpg');
    });

    test('toString deve retornar number', () {
      final episode = Episode(number: '5', url: 'http://server/ep5.mp4');
      expect(episode.toString(), '5');
    });
  });

  group('EpisodeSubtitleTrack', () {
    test('deve criar track de legenda', () {
      const track = EpisodeSubtitleTrack(
        url: 'http://server/sub.pt.srt',
        language: 'pt-BR',
        displayName: 'Português',
        forced: false,
      );

      expect(track.url, 'http://server/sub.pt.srt');
      expect(track.language, 'pt-BR');
      expect(track.displayName, 'Português');
      expect(track.forced, false);
    });

    test('deve criar track forced', () {
      const track = EpisodeSubtitleTrack(
        language: 'en',
        displayName: 'English',
        forced: true,
      );

      expect(track.forced, true);
      expect(track.url, isNull);
    });

    test('toString deve incluir language e forced', () {
      const track = EpisodeSubtitleTrack(
        url: 'http://server/sub.srt',
        language: 'en',
        displayName: 'English',
      );
      expect(track.toString(), 'EpisodeSubtitleTrack(en, http://server/sub.srt)');
    });
  });

  group('StreamEpisodeListItem', () {
    test('deve criar a partir de JSON', () {
      final json = {
        'episodeNumber': '1',
        'thumbnail': 'http://server/thumb.jpg',
        'title': 'Episode 1',
        'description': 'Desc',
        'url': 'http://server/ep1.mp4',
        'duration': 1500,
        'airDate': '2024-01-01T00:00:00.000',
      };

      final item = StreamEpisodeListItem.fromJson(json);
      expect(item.episodeNumber, '1');
      expect(item.thumbnailUrl, 'http://server/thumb.jpg');
      expect(item.title, 'Episode 1');
      expect(item.description, 'Desc');
      expect(item.url, 'http://server/ep1.mp4');
      expect(item.duration, const Duration(seconds: 1500));
      expect(item.airDate, DateTime(2024, 1, 1));
    });

    test('fromJson deve usar fallback keys', () {
      final json = {
        'number': '2',
        'image': 'http://server/thumb2.jpg',
        'name': 'Episode 2',
        'synopsis': 'Synopsis',
      };

      final item = StreamEpisodeListItem.fromJson(json);
      expect(item.episodeNumber, '2');
      expect(item.thumbnailUrl, 'http://server/thumb2.jpg');
      expect(item.title, 'Episode 2');
      expect(item.description, 'Synopsis');
    });

    test('toEpisode deve converter corretamente', () {
      final item = StreamEpisodeListItem(
        episodeNumber: '3',
        thumbnailUrl: 'http://server/thumb.jpg',
        title: 'Episode 3',
        description: 'Desc',
        url: 'http://server/ep3.mp4',
      );

      final episode = item.toEpisode();
      expect(episode.number, '3');
      expect(episode.thumbnail, 'http://server/thumb.jpg');
      expect(episode.title, 'Episode 3');
      expect(episode.description, 'Desc');
      expect(episode.url, 'http://server/ep3.mp4');
    });

    test('getImageUrl deve retornar thumbnailUrl', () {
      final item = StreamEpisodeListItem(
        episodeNumber: '1',
        thumbnailUrl: 'http://server/thumb.jpg',
      );
      expect(item.getImageUrl(), 'http://server/thumb.jpg');
    });
  });
}
