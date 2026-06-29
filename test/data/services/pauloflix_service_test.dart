// Testes de integração do `PauloFlixService.syncContent()`.
//
// Estratégia: HTTP mockado com `MockClient` + banco Drift em memória
// (`AppDatabase.forTesting(NativeDatabase.memory())`).
//
// Cobre:
//   - sync bem-sucedido com tv_index.json real (2 shows)
//   - sync popula seasons + episódios (quando episodeRepository é fornecido)
//   - callbacks onProgress/onError disparam
//   - HTTP 404 → false + onError
//   - shows array vazio → false + onError
//   - chave 'shows' ausente → false
//   - re-sync preserva ids dos shows (UPSERT)
//   - marca shows removidos como isAvailable=false
//   - sem episodeRepository → seasons/episódios NÃO são populados

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/data/repositories/paulo_flix_episode_progress_repository_impl.dart';
import 'package:goanime/data/repositories/pauloflix_repository_impl.dart';
import 'package:goanime/data/services/pauloflix_service.dart';
import 'package:goanime/domain/repositories/paulo_flix_episode_progress_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// JSON index real de exemplo (estilo tv_index.json),
/// com 2 shows, cada um com seasons e episódios.
const _tvIndexJson = '''{
  "updated_at": "2026-06-27T13:53:47.099092+00:00",
  "total_shows": 2,
  "shows": [
    {
      "title": "Dan Da Dan",
      "original_title": "Dan Da Dan",
      "path": "Dan Da Dan",
      "year": "2024",
      "poster": "/tvshows/Dan Da Dan/poster.jpg",
      "fanart": "/tvshows/Dan Da Dan/fanart.jpg",
      "seasons": [
        {
          "season": 1,
          "folderName": "Season 01",
          "episodes": [
            {
              "episode": 1,
              "title": "É assim que o amor começa, tá ligado?",
              "plot": "Momo Ayase acha ridículo...",
              "aired": "2024-10-04",
              "rating": 8.462,
              "file": "/tvshows/Dan Da Dan/Season%2001/S01E01.mkv",
              "thumb": "/tvshows/Dan Da Dan/Season%2001/S01E01-thumb.jpg",
              "nfo": {
                "title": "É assim que o amor começa, tá ligado?",
                "plot": "Momo Ayase acha ridículo...",
                "aired": "2024-10-04",
                "rating": "8.462",
                "runtime": "24"
              }
            },
            {
              "episode": 2,
              "title": "Lutando contra extraterrestres",
              "plot": "Momo enfrenta os alienígenas...",
              "aired": "2024-10-11",
              "rating": 8.1,
              "file": "/tvshows/Dan Da Dan/Season%2001/S01E02.mkv",
              "thumb": "/tvshows/Dan Da Dan/Season%2001/S01E02-thumb.jpg",
              "nfo": {
                "title": "Lutando contra extraterrestres",
                "rating": "8.1",
                "runtime": "24"
              }
            }
          ]
        },
        {
          "season": 2,
          "folderName": "Season 02",
          "episodes": [
            {
              "episode": 1,
              "title": "Novo arco começa",
              "file": "/tvshows/Dan Da Dan/Season%2002/S02E01.mkv",
              "nfo": {}
            }
          ]
        }
      ]
    },
    {
      "title": "One Piece",
      "original_title": "One Piece",
      "path": "One Piece",
      "year": "1999",
      "poster": "/tvshows/One Piece/poster.jpg",
      "fanart": "/tvshows/One Piece/fanart.jpg",
      "seasons": [
        {
          "season": 1,
          "folderName": "Season 01",
          "episodes": [
            {
              "episode": 1,
              "title": "Eu sou Luffy",
              "file": "/tvshows/One Piece/Season%2001/S01E01.mkv",
              "nfo": {}
            },
            {
              "episode": 2,
              "title": "O grande espadachim",
              "file": "/tvshows/One Piece/Season%2001/S01E02.mkv",
              "nfo": {}
            }
          ]
        }
      ]
    }
  ]
}''';

/// JSON de re-sync com apenas 1 show (simula remoção do outro).
const _reducedIndexJson = '''{
  "updated_at": "2026-06-27T14:00:00.000+00:00",
  "total_shows": 1,
  "shows": [
    {
      "title": "Dan Da Dan",
      "path": "Dan Da Dan",
      "poster": "/tvshows/Dan Da Dan/poster.jpg",
      "fanart": "/tvshows/Dan Da Dan/fanart.jpg",
      "seasons": [
        {
          "season": 1,
          "folderName": "Season 01",
          "episodes": []
        }
      ]
    }
  ]
}''';

/// JSON sem a chave 'shows'.
const _jsonWithoutShows = '''{
  "updated_at": "2026-06-27T13:53:47.099092+00:00",
  "total_shows": 0
}''';

/// JSON com campo `nfo` ausente ou com tipo inválido.
const _jsonWithInvalidNfo = '''{
  "updated_at": "2026-06-27T13:53:47.099092+00:00",
  "total_shows": 1,
  "shows": [
    {
      "title": "Invalid NFO",
      "path": "Invalid NFO",
      "poster": "/tvshows/Invalid NFO/poster.jpg",
      "fanart": "/tvshows/Invalid NFO/fanart.jpg",
      "seasons": [
        {
          "season": 1,
          "folderName": "Season 01",
          "episodes": [
            {
              "episode": 1,
              "title": "Episode 1",
              "file": "/tvshows/Invalid NFO/Season%2001/S01E01.mkv",
              "nfo": "not-a-map"
            },
            {
              "episode": 2,
              "title": "Episode 2",
              "file": "/tvshows/Invalid NFO/Season%2001/S01E02.mkv"
            }
          ]
        }
      ]
    }
  ]
}''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late PauloFlixRepositoryImpl repo;
  late PauloFlixEpisodeProgressRepository episodeRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    repo = PauloFlixRepositoryImpl(db);
    episodeRepo = PauloFlixEpisodeProgressRepositoryImpl(db);
  });

  tearDown(() async {
    // Restaura o client default para não vazar mock entre testes
    PauloFlixService.configure(http.Client());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_tv_index_updated_at');
  });

  group('PauloFlixService.syncContent — shows', () {
    test('sync bem-sucedido com tv_index.json (2 shows)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          _tvIndexJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      PauloFlixService.configure(mockClient);

      final progressMessages = <String>[];
      final errorMessages = <String>[];
      final result = await PauloFlixService.syncContent(
        repository: repo,
        onProgress: (msg) => progressMessages.add(msg),
        onError: (msg) => errorMessages.add(msg),
      );

      expect(result, isTrue);
      expect(errorMessages, isEmpty);

      // Callbacks de progresso disparam
      expect(progressMessages, isNotEmpty);
      expect(progressMessages.first, contains('Baixando índice JSON'));
      expect(progressMessages.last, contains('Sincronização completa'));

      // Verifica shows no banco
      final all = await repo.getAll();
      expect(all, hasLength(2));

      // --- Show 1: "Dan Da Dan" ---
      final show1 = all.firstWhere((s) => s.folderName == 'Dan Da Dan');
      expect(show1.displayName, 'Dan Da Dan');
      expect(
        show1.imageUrl,
        'https://media.oliveira.braga.nom.br/tvshows/Dan Da Dan/poster.jpg',
      );
      expect(
        show1.bannerUrl,
        'https://media.oliveira.braga.nom.br/tvshows/Dan Da Dan/fanart.jpg',
      );
      expect(show1.isAvailable, isTrue);

      // --- Show 2: "One Piece" ---
      final show2 = all.firstWhere((s) => s.folderName == 'One Piece');
      expect(show2.displayName, 'One Piece');
      expect(
        show2.imageUrl,
        'https://media.oliveira.braga.nom.br/tvshows/One Piece/poster.jpg',
      );
      expect(show2.isAvailable, isTrue);
    });

    test(
      'sync popula seasons + episódios (quando episodeRepository é fornecido)',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            _tvIndexJson,
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        PauloFlixService.configure(mockClient);

        final result = await PauloFlixService.syncContent(
          repository: repo,
          episodeRepository: episodeRepo,
        );

        expect(result, isTrue);

        // Verifica shows no banco
        final all = await repo.getAll();
        expect(all, hasLength(2));

        // --- Dan Da Dan: 2 seasons ---
        final ddd = all.firstWhere((s) => s.folderName == 'Dan Da Dan');
        final dddSeasons = await episodeRepo.getSeasonsForContent(ddd.id!);
        expect(dddSeasons, hasLength(2));
        expect(dddSeasons[0].seasonNumber, 1);
        expect(dddSeasons[0].displayName, 'Season 01');
        expect(dddSeasons[1].seasonNumber, 2);
        expect(dddSeasons[1].displayName, 'Season 02');

        // Episódios da Season 1 do Dan Da Dan
        final s1Eps = await episodeRepo.getEpisodesForSeason(dddSeasons[0].id!);
        expect(s1Eps, hasLength(2));
        expect(s1Eps[0].episodeNumber, 1);
        expect(s1Eps[0].title, 'É assim que o amor começa, tá ligado?');
        expect(
          s1Eps[0].videoUrl,
          'https://media.oliveira.braga.nom.br/tvshows/Dan Da Dan/Season%2001/S01E01.mkv',
        );
        expect(
          s1Eps[0].thumbnailUrl,
          'https://media.oliveira.braga.nom.br/tvshows/Dan Da Dan/Season%2001/S01E01-thumb.jpg',
        );
        expect(s1Eps[0].description, 'Momo Ayase acha ridículo...');
        expect(s1Eps[0].rating, closeTo(8.462, 0.001));
        expect(s1Eps[1].episodeNumber, 2);
        expect(s1Eps[1].title, 'Lutando contra extraterrestres');
        expect(s1Eps[1].rating, closeTo(8.1, 0.001));

        // Episódios da Season 2 do Dan Da Dan (1 ep, sem metadata)
        final s2Eps = await episodeRepo.getEpisodesForSeason(dddSeasons[1].id!);
        expect(s2Eps, hasLength(1));
        expect(s2Eps[0].episodeNumber, 1);
        expect(s2Eps[0].title, 'Novo arco começa');
        expect(s2Eps[0].description, isNull);
        expect(s2Eps[0].thumbnailUrl, isNull);

        // --- One Piece: 1 season, 2 episódios ---
        final op = all.firstWhere((s) => s.folderName == 'One Piece');
        final opSeasons = await episodeRepo.getSeasonsForContent(op.id!);
        expect(opSeasons, hasLength(1));
        expect(opSeasons[0].seasonNumber, 1);

        final opEps = await episodeRepo.getEpisodesForSeason(opSeasons[0].id!);
        expect(opEps, hasLength(2));
        expect(opEps[0].episodeNumber, 1);
        expect(opEps[0].title, 'Eu sou Luffy');
        expect(opEps[1].episodeNumber, 2);
        expect(opEps[1].title, 'O grande espadachim');
      },
    );

    test('sem episodeRepository → NÃO popula seasons/episódios', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          _tvIndexJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      PauloFlixService.configure(mockClient);

      // Sync SEM episodeRepository
      final result = await PauloFlixService.syncContent(repository: repo);

      expect(result, isTrue);

      final all = await repo.getAll();
      expect(all, hasLength(2));

      // Nenhuma season/episódio foi criada
      final ddd = all.firstWhere((s) => s.folderName == 'Dan Da Dan');
      final seasons = await episodeRepo.getSeasonsForContent(ddd.id!);
      expect(seasons, isEmpty);
    });

    test('nfo ausente ou com tipo inválido não quebra o sync', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          _jsonWithInvalidNfo,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      PauloFlixService.configure(mockClient);

      final result = await PauloFlixService.syncContent(
        repository: repo,
        episodeRepository: episodeRepo,
      );

      expect(result, isTrue);

      final all = await repo.getAll();
      expect(all, hasLength(1));

      final show = all.first;
      final seasons = await episodeRepo.getSeasonsForContent(show.id!);
      expect(seasons, hasLength(1));

      final episodes = await episodeRepo.getEpisodesForSeason(
        seasons.first.id!,
      );
      expect(episodes, hasLength(2));
      expect(episodes.first.originalTitle, isNull);
      expect(episodes.first.runtime, isNull);
      expect(episodes.last.originalTitle, isNull);
      expect(episodes.last.runtime, isNull);
    });

    test('HTTP 404 retorna false e chama onError', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });
      PauloFlixService.configure(mockClient);

      final errorMessages = <String>[];
      final result = await PauloFlixService.syncContent(
        repository: repo,
        onError: (msg) => errorMessages.add(msg),
      );

      expect(result, isFalse);
      expect(errorMessages, isNotEmpty);
      expect(errorMessages.first, contains('HTTP 404'));
    });

    test('shows array vazio retorna false e chama onError', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"shows": []}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      PauloFlixService.configure(mockClient);

      final errorMessages = <String>[];
      final result = await PauloFlixService.syncContent(
        repository: repo,
        onError: (msg) => errorMessages.add(msg),
      );

      expect(result, isFalse);
      expect(errorMessages, isNotEmpty);
      expect(errorMessages.first, contains('Nenhum show'));
    });

    test('JSON sem chave shows retorna false', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          _jsonWithoutShows,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      PauloFlixService.configure(mockClient);

      final result = await PauloFlixService.syncContent(repository: repo);

      expect(result, isFalse);
    });

    test('re-sync preserva ids dos shows (UPSERT)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          _tvIndexJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      PauloFlixService.configure(mockClient);

      // Primeiro sync
      await PauloFlixService.syncContent(repository: repo);
      final firstId = (await repo.getByFolderName('Dan Da Dan'))!.id;

      // Segundo sync (mesmo JSON)
      await PauloFlixService.syncContent(repository: repo);

      final all = await repo.getAll();
      expect(all, hasLength(2), reason: 're-sync não deve duplicar');
      final updated = await repo.getByFolderName('Dan Da Dan');
      expect(
        updated!.id,
        equals(firstId),
        reason: 'id deve ser preservado no re-sync (UPSERT)',
      );
    });

    test('marca shows removidos como isAvailable=false', () async {
      // Primeiro sync: insere 2 shows
      final mockClient1 = MockClient((request) async {
        return http.Response(
          _tvIndexJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      PauloFlixService.configure(mockClient1);
      await PauloFlixService.syncContent(repository: repo);

      // Segundo sync: só 1 show (One Piece foi removido)
      final mockClient2 = MockClient((request) async {
        return http.Response(
          _reducedIndexJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      PauloFlixService.configure(mockClient2);
      final progressMessages = <String>[];
      await PauloFlixService.syncContent(
        repository: repo,
        onProgress: (msg) => progressMessages.add(msg),
      );

      // Dan Da Dan continua disponível
      final show1 = await repo.getByFolderName('Dan Da Dan');
      expect(show1, isNotNull);
      expect(show1!.isAvailable, isTrue);

      // One Piece foi marcado como indisponível
      final show2 = await repo.getByFolderName('One Piece');
      expect(show2, isNotNull);
      expect(show2!.isAvailable, isFalse);

      // getAll filtra isAvailable=false
      final all = await repo.getAll();
      expect(all, hasLength(1));

      // Callback de progresso menciona shows removidos
      expect(progressMessages.any((m) => m.contains('removidos')), isTrue);
    });
  });
}
