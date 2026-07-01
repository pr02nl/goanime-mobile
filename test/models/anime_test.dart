import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/data/models/anilist_models.dart';
import 'package:goanime/domain/models/anime.dart';

void main() {
  group('Anime Model', () {
    test('deve criar anime com dados obrigatorios', () {
      final anime = Anime(name: 'Test Anime', url: 'https://example.com/anime');

      expect(anime.name, 'Test Anime');
      expect(anime.url, 'https://example.com/anime');
      expect(anime.source, AnimeSource.animeFire);
      expect(anime.aniListData, isNull);
    });

    test('deve retornar fallbackImageUrl quando nao ha aniListData', () {
      final anime = Anime(
        name: 'Test Anime',
        url: 'https://example.com/anime',
        fallbackImageUrl: 'https://example.com/image.jpg',
      );

      expect(anime.imageUrl, 'https://example.com/image.jpg');
      expect(anime.bannerUrl, '');
      expect(anime.description, '');
    });

    test('deve usar dados do AniList quando disponiveis', () {
      final mediaDetails = MediaDetails(
        id: 1,
        idMal: 12345,
        title: MediaTitle(romaji: 'Test Anime', english: 'Test Anime English'),
        coverImage: CoverImage(
          extraLarge: 'https://example.com/cover_extra.jpg',
          large: 'https://example.com/cover_large.jpg',
          medium: 'https://example.com/cover_medium.jpg',
        ),
        bannerImage: 'https://example.com/banner.jpg',
        description: 'Uma descricao de teste',
        episodes: 12,
        status: 'FINISHED',
        season: 'SPRING',
        seasonYear: 2024,
        averageScore: 85.5,
        popularity: 1000,
        genres: ['Action', 'Adventure'],
        format: MediaFormat.tv,
      );

      final anime = Anime(
        name: 'Test Anime',
        url: 'https://example.com/anime',
        aniListData: mediaDetails,
      );

      expect(anime.imageUrl, 'https://example.com/cover_extra.jpg');
      expect(anime.bannerUrl, 'https://example.com/banner.jpg');
      expect(anime.description, 'Uma descricao de teste');
      expect(anime.malId, 12345);
      expect(anime.anilistId, 1);
      expect(anime.genres, ['Action', 'Adventure']);
      expect(anime.status, 'FINISHED');
      expect(anime.episodeCount, 12);
      expect(anime.averageScore, 85.5);
    });

    test('deve retornar sourceName correto', () {
      final animeFire = Anime(
        name: 'Anime 1',
        url: 'https://example.com',
        source: AnimeSource.animeFire,
      );

      expect(animeFire.sourceName, 'AnimeFire');
    });

    test('toString deve retornar o nome do anime', () {
      final anime = Anime(name: 'Meu Anime', url: 'https://example.com');

      expect(anime.toString(), 'Meu Anime');
    });
  });

  group('MediaTitle Model', () {
    test('deve retornar preferred title em ordem correta', () {
      final titleWithEnglish = MediaTitle(
        romaji: 'Romaji Title',
        english: 'English Title',
        native: '日本語タイトル',
      );

      final titleWithRomaji = MediaTitle(
        romaji: 'Romaji Title',
        english: null,
        native: '日本語タイトル',
      );

      final titleWithNative = MediaTitle(
        romaji: null,
        english: null,
        native: '日本語タイトル',
      );

      final titleEmpty = MediaTitle();

      expect(titleWithEnglish.preferred, 'English Title');
      expect(titleWithRomaji.preferred, 'Romaji Title');
      expect(titleWithNative.preferred, '日本語タイトル');
      expect(titleEmpty.preferred, 'Unknown');
    });
  });

  group('CoverImage Model', () {
    test('deve retornar best image em ordem correta', () {
      final coverWithExtra = CoverImage(
        extraLarge: 'https://example.com/extra.jpg',
        large: 'https://example.com/large.jpg',
        medium: 'https://example.com/medium.jpg',
      );

      final coverWithLarge = CoverImage(
        extraLarge: null,
        large: 'https://example.com/large.jpg',
        medium: 'https://example.com/medium.jpg',
      );

      final coverEmpty = CoverImage();

      expect(coverWithExtra.best, 'https://example.com/extra.jpg');
      expect(coverWithLarge.best, 'https://example.com/large.jpg');
      expect(coverEmpty.best, '');
    });
  });
}
