import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/models/anime.dart';
import 'package:goanime/models/jikan_models.dart';
import 'package:goanime/models/anilist_models.dart';

void main() {
  group('Anime Model', () {
    test('deve criar anime com dados obrigatórios', () {
      final anime = Anime(
        name: 'Test Anime',
        url: 'https://example.com/anime',
      );

      expect(anime.name, 'Test Anime');
      expect(anime.url, 'https://example.com/anime');
      expect(anime.source, AnimeSource.animeFire);
      expect(anime.allAnimeId, isNull);
      expect(anime.aniListData, isNull);
    });

    test('deve retornar fallbackImageUrl quando não há aniListData', () {
      final anime = Anime(
        name: 'Test Anime',
        url: 'https://example.com/anime',
        fallbackImageUrl: 'https://example.com/image.jpg',
      );

      expect(anime.imageUrl, 'https://example.com/image.jpg');
      expect(anime.bannerUrl, '');
      expect(anime.description, '');
    });

    test('deve usar dados do AniList quando disponíveis', () {
      final mediaDetails = MediaDetails(
        id: 1,
        idMal: 12345,
        title: MediaTitle(
          romaji: 'Test Anime',
          english: 'Test Anime English',
          native: 'テストアニメ',
        ),
        coverImage: CoverImage(
          extraLarge: 'https://example.com/cover_extra.jpg',
          large: 'https://example.com/cover_large.jpg',
          medium: 'https://example.com/cover_medium.jpg',
        ),
        bannerImage: 'https://example.com/banner.jpg',
        description: 'Uma descrição de teste',
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
      expect(anime.description, 'Uma descrição de teste');
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

      final allAnime = Anime(
        name: 'Anime 2',
        url: 'https://example.com',
        source: AnimeSource.allAnime,
      );

      expect(animeFire.sourceName, 'AnimeFire');
      expect(allAnime.sourceName, 'AllAnime');
    });

    test('toString deve retornar o nome do anime', () {
      final anime = Anime(
        name: 'Meu Anime',
        url: 'https://example.com',
      );

      expect(anime.toString(), 'Meu Anime');
    });
  });

  group('JikanAnime Model', () {
    test('deve criar JikanAnime a partir de JSON', () {
      final json = {
        'mal_id': 12345,
        'title': 'Test Anime',
        'title_english': 'Test Anime English',
        'title_japanese': 'テストアニメ',
        'images': {
          'jpg': {
            'image_url': 'https://example.com/image.jpg',
            'large_image_url': 'https://example.com/large.jpg',
          },
          'webp': {
            'image_url': 'https://example.com/image.webp',
            'large_image_url': 'https://example.com/large.webp',
          },
        },
        'synopsis': 'Uma sinopse de teste',
        'score': 8.5,
        'episodes': 12,
        'status': 'Finished Airing',
        'rating': 'PG-13',
        'genres': [
          {'mal_id': 1, 'name': 'Action', 'type': 'anime'},
          {'mal_id': 2, 'name': 'Adventure', 'type': 'anime'},
        ],
        'year': 2024,
        'season': 'spring',
      };

      final anime = JikanAnime.fromJson(json);

      expect(anime.malId, 12345);
      expect(anime.title, 'Test Anime');
      expect(anime.titleEnglish, 'Test Anime English');
      expect(anime.titleJapanese, 'テストアニメ');
      expect(anime.imageUrl, 'https://example.com/image.webp');
      expect(anime.largImageUrl, 'https://example.com/large.webp');
      expect(anime.synopsis, 'Uma sinopse de teste');
      expect(anime.score, 8.5);
      expect(anime.episodes, 12);
      expect(anime.status, 'Finished Airing');
      expect(anime.rating, 'PG-13');
      expect(anime.genres.length, 2);
      expect(anime.year, 2024);
      expect(anime.season, 'spring');
    });

    test('deve usar JPG quando WebP não disponível', () {
      final json = {
        'mal_id': 12345,
        'title': 'Test Anime',
        'images': {
          'jpg': {
            'image_url': 'https://example.com/image.jpg',
            'large_image_url': 'https://example.com/large.jpg',
          },
        },
        'genres': [],
      };

      final anime = JikanAnime.fromJson(json);

      expect(anime.imageUrl, 'https://example.com/image.jpg');
      expect(anime.largImageUrl, 'https://example.com/large.jpg');
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
