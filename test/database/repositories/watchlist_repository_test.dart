// Cobertura do WatchlistRepository (Fase 3 do plano docs/DATABASE_REFACTORING.md).
//
// O repository encapsula Drift e devolve modelos de domínio
// (WatchlistAnime) — nunca tipos gerados pelo Drift na fronteira.
// Esta é a primeira das 4 implementações de repository; o teste prova
// o contrato que as outras 3 (PauloFlix, PauloFlixMovies, Downloads)
// devem seguir.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/data/repositories/watchlist_repository_impl.dart';
import 'package:goanime/domain/models/watchlist_anime.dart';

void main() {
  late AppDatabase db;
  late WatchlistRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    repo = WatchlistRepositoryImpl(db);
  });

  group('WatchlistRepository — CRUD básico', () {
    test('add + getAll retorna o anime inserido', () async {
      final anime = WatchlistAnime(
        animeId: 'mal:20',
        title: 'Naruto',
        coverImage: 'http://img/n.jpg',
        myAnimeListUrl: 'https://mal/20',
        addedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      await repo.add(anime);

      final all = await repo.getAll();
      expect(all, hasLength(1));
      expect(all.first.title, 'Naruto');
      expect(all.first.animeId, 'mal:20');
    });

    test('getAll retorna lista vazia para banco vazio', () async {
      final all = await repo.getAll();
      expect(all, isEmpty);
    });

    test('add é idempotente via animeId UNIQUE (insertOrReplace)', () async {
      final anime = WatchlistAnime(
        animeId: 'mal:1',
        title: 'Original',
        coverImage: 'http://img/1.jpg',
        myAnimeListUrl: 'https://mal/1',
        addedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      await repo.add(anime);

      final updated = WatchlistAnime(
        animeId: 'mal:1', // mesmo id
        title: 'Atualizado',
        coverImage: 'http://img/1-v2.jpg',
        myAnimeListUrl: 'https://mal/1',
        addedAt: DateTime.fromMillisecondsSinceEpoch(1800000000000),
      );
      await repo.add(updated);

      final all = await repo.getAll();
      expect(all, hasLength(1),
          reason: 'Não deve duplicar por animeId UNIQUE');
      expect(all.first.title, 'Atualizado');
    });

    test('remove deleta o anime por animeId', () async {
      await repo.add(WatchlistAnime(
        animeId: 'mal:1',
        title: 'A',
        coverImage: '',
        myAnimeListUrl: '',
        addedAt: DateTime.fromMillisecondsSinceEpoch(1),
      ));
      await repo.add(WatchlistAnime(
        animeId: 'mal:2',
        title: 'B',
        coverImage: '',
        myAnimeListUrl: '',
        addedAt: DateTime.fromMillisecondsSinceEpoch(2),
      ));

      await repo.remove('mal:1');

      final all = await repo.getAll();
      expect(all, hasLength(1));
      expect(all.first.animeId, 'mal:2');
    });

    test('isInWatchlist retorna true se existe', () async {
      await repo.add(WatchlistAnime(
        animeId: 'mal:1',
        title: 'A',
        coverImage: '',
        myAnimeListUrl: '',
        addedAt: DateTime.fromMillisecondsSinceEpoch(1),
      ));
      expect(await repo.isInWatchlist('mal:1'), isTrue);
      expect(await repo.isInWatchlist('mal:999'), isFalse);
    });

    test('count retorna quantidade', () async {
      expect(await repo.count(), 0);
      await repo.add(WatchlistAnime(
        animeId: 'a',
        title: 'A',
        coverImage: '',
        myAnimeListUrl: '',
        addedAt: DateTime.fromMillisecondsSinceEpoch(1),
      ));
      await repo.add(WatchlistAnime(
        animeId: 'b',
        title: 'B',
        coverImage: '',
        myAnimeListUrl: '',
        addedAt: DateTime.fromMillisecondsSinceEpoch(2),
      ));
      expect(await repo.count(), 2);
    });

    test('clear remove todos', () async {
      await repo.add(WatchlistAnime(
        animeId: 'a',
        title: 'A',
        coverImage: '',
        myAnimeListUrl: '',
        addedAt: DateTime.fromMillisecondsSinceEpoch(1),
      ));
      await repo.add(WatchlistAnime(
        animeId: 'b',
        title: 'B',
        coverImage: '',
        myAnimeListUrl: '',
        addedAt: DateTime.fromMillisecondsSinceEpoch(2),
      ));
      await repo.clear();
      expect(await repo.getAll(), isEmpty);
    });
  });

  group('WatchlistRepository — getByAnimeId e watch', () {
    test('getByAnimeId retorna o anime correto ou null', () async {
      await repo.add(WatchlistAnime(
        animeId: 'mal:1',
        title: 'A',
        coverImage: 'http://i',
        myAnimeListUrl: 'https://m',
        addedAt: DateTime.fromMillisecondsSinceEpoch(1),
      ));

      final found = await repo.getByAnimeId('mal:1');
      expect(found, isNotNull);
      expect(found!.title, 'A');

      final notFound = await repo.getByAnimeId('mal:999');
      expect(notFound, isNull);
    });

    test('getAll ordena por addedAt DESC (mais recente primeiro)', () async {
      await repo.add(WatchlistAnime(
        animeId: 'a',
        title: 'A',
        coverImage: '',
        myAnimeListUrl: '',
        addedAt: DateTime.fromMillisecondsSinceEpoch(1000),
      ));
      await repo.add(WatchlistAnime(
        animeId: 'b',
        title: 'B',
        coverImage: '',
        myAnimeListUrl: '',
        addedAt: DateTime.fromMillisecondsSinceEpoch(3000),
      ));
      await repo.add(WatchlistAnime(
        animeId: 'c',
        title: 'C',
        coverImage: '',
        myAnimeListUrl: '',
        addedAt: DateTime.fromMillisecondsSinceEpoch(2000),
      ));

      final all = await repo.getAll();
      expect(all.map((a) => a.animeId).toList(), ['b', 'c', 'a']);
    });
  });
}
