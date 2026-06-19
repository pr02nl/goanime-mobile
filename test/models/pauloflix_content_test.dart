import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/data/models/jikan_models.dart';
import 'package:goanime/domain/models/pauloflix_content.dart';

void main() {
  group('PauloFlixContent', () {
    test('deve criar com valores padrao', () {
      final content = PauloFlixContent(
        folderName: 'Naruto',
        displayName: 'Naruto',
        serverUrl: 'http://server/naruto/',
      );

      expect(content.folderName, 'Naruto');
      expect(content.displayName, 'Naruto');
      expect(content.serverUrl, 'http://server/naruto/');
      expect(content.imageUrl, isNull);
      expect(content.genres, isEmpty);
      expect(content.isAvailable, true);
      expect(content.id, isNull);
    });

    test('deve criar a partir de JikanAnime via fromJikan', () {
      final jikan = JikanAnime(
        malId: 123,
        title: 'Naruto',
        imageUrl: 'http://image.com/naruto.jpg',
        largImageUrl: 'http://image.com/naruto_large.jpg',
        synopsis: 'Um anime sobre ninjas',
        score: 8.5,
        episodes: 220,
        status: 'Finished Airing',
        genres: [
          JikanGenre(malId: 1, name: 'Action', type: 'anime'),
          JikanGenre(malId: 10, name: 'Fantasy', type: 'anime'),
        ],
      );

      final content = PauloFlixContent.fromJikan(
        folderName: 'Naruto',
        serverUrl: 'http://server/naruto/',
        jikanAnime: jikan,
      );

      expect(content.displayName, 'Naruto');
      expect(content.imageUrl, 'http://image.com/naruto.jpg');
      expect(content.bannerUrl, 'http://image.com/naruto_large.jpg');
      expect(content.description, 'Um anime sobre ninjas');
      expect(content.score, 8.5);
      expect(content.episodeCount, 220);
      expect(content.status, 'Finished Airing');
      expect(content.malId, 123);
      expect(content.genres, ['Action', 'Fantasy']);
    });

    test('toMap e fromMap devem ser consistentes', () {
      final original = PauloFlixContent(
        id: 1,
        folderName: 'One Piece',
        displayName: 'One Piece',
        serverUrl: 'http://server/onepiece/',
        imageUrl: 'http://image.com/op.jpg',
        bannerUrl: 'http://image.com/op_banner.jpg',
        description: 'Pirate adventure',
        score: 9.0,
        genres: ['Action', 'Adventure'],
        status: 'Airing',
        episodeCount: 1000,
        malId: 456,
        anilistId: 789,
        isAvailable: true,
      );

      final map = original.toMap();
      final restored = PauloFlixContent.fromMap(map);

      expect(restored.folderName, original.folderName);
      expect(restored.displayName, original.displayName);
      expect(restored.serverUrl, original.serverUrl);
      expect(restored.imageUrl, original.imageUrl);
      expect(restored.bannerUrl, original.bannerUrl);
      expect(restored.description, original.description);
      expect(restored.score, original.score);
      expect(restored.genres, original.genres);
      expect(restored.status, original.status);
      expect(restored.episodeCount, original.episodeCount);
      expect(restored.malId, original.malId);
      expect(restored.anilistId, original.anilistId);
      expect(restored.isAvailable, original.isAvailable);
    });

    test('fromMap deve aceitar generos vazios', () {
      final map = {
        'folderName': 'Test',
        'displayName': 'Test',
        'serverUrl': 'http://server/',
        'genres': '',
        'lastSynced': '2024-01-01T00:00:00.000',
        'isAvailable': 1,
      };
      final content = PauloFlixContent.fromMap(map);
      expect(content.genres, isEmpty);
    });

    test('deve comparar por folderName', () {
      final a = PauloFlixContent(
        folderName: 'Naruto',
        displayName: 'Naruto',
        serverUrl: 'http://a/',
      );
      final b = PauloFlixContent(
        folderName: 'Naruto',
        displayName: 'Naruto Shippuden',
        serverUrl: 'http://b/',
      );
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('toString deve retornar displayName', () {
      final content = PauloFlixContent(
        folderName: 'Test',
        displayName: 'Test Anime',
        serverUrl: 'http://server/',
      );
      expect(content.toString(), 'PauloFlixContent(Test Anime)');
    });

    test('lastSynced deve usar DateTime.now() quando nao fornecido', () {
      final before = DateTime.now();
      final content = PauloFlixContent(
        folderName: 'Test',
        displayName: 'Test',
        serverUrl: 'http://server/',
      );
      final after = DateTime.now();
      expect(
        content.lastSynced.isAfter(before) || content.lastSynced == before,
        isTrue,
      );
      expect(
        content.lastSynced.isBefore(after) || content.lastSynced == after,
        isTrue,
      );
    });
  });
}
