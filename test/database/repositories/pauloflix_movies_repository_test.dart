import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/data/repositories/pauloflix_movies_repository_impl.dart';
import 'package:goanime/domain/models/pauloflix_movie.dart';

void main() {
  late AppDatabase db;
  late PauloFlixMoviesRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    repo = PauloFlixMoviesRepositoryImpl(db);
  });

  PauloFlixMovie sample({
    String folderName = 'inception',
    String displayName = 'A Origem',
    int? tmdbId = 27205,
    double? score = 8.8,
    List<String> genres = const ['Action', 'Sci-Fi'],
    int availableMovieCount = 1,
    int? year = 2010,
    String? imageUrl,
  }) {
    return PauloFlixMovie(
      folderName: folderName,
      displayName: displayName,
      serverUrl: 'http://server/$folderName/',
      imageUrl: imageUrl,
      genres: genres,
      tmdbId: tmdbId,
      score: score,
      availableMovieCount: availableMovieCount,
      year: year,
    );
  }

  group('PauloFlixMoviesRepository', () {
    test('saveContent + getAll retorna o filme', () async {
      await repo.saveContent(sample(folderName: 'inception'));
      await repo.saveContent(sample(
        folderName: 'harry_potter',
        displayName: 'Coleção HP',
        availableMovieCount: 8,
        tmdbId: 12445,
      ));

      final all = await repo.getAll();
      expect(all, hasLength(2));
      expect(all.map((m) => m.folderName).toSet(),
          {'inception', 'harry_potter'});
    });

    test('getAll filtra isAvailable = 0', () async {
      await repo.saveContent(sample(folderName: 'a'));
      await repo.saveContent(
        sample(folderName: 'b', displayName: 'B'),
      );
      await repo.markAsUnavailable('b');

      final all = await repo.getAll();
      expect(all, hasLength(1));
      expect(all.first.folderName, 'a');
    });

    test('searchByName usa LIKE ESCAPE (sem falsos positivos com %)', () async {
      await repo.saveContent(sample(
        folderName: 'a',
        displayName: '100% Deadpool',
      ));
      await repo.saveContent(sample(
        folderName: 'b',
        displayName: '100 Normal',
      ));

      final results = await repo.searchByName('100%');
      expect(results, hasLength(1));
      expect(results.first.displayName, '100% Deadpool');
    });

    test('getByTmdbId retorna o filme correto', () async {
      await repo.saveContent(sample(folderName: 'a', tmdbId: 27205));
      await repo.saveContent(sample(folderName: 'b', tmdbId: 12445));

      final found = await repo.getByTmdbId(12445);
      expect(found, isNotNull);
      expect(found!.folderName, 'b');

      final notFound = await repo.getByTmdbId(999);
      expect(notFound, isNull);
    });

    test('getByFolderName retorna o filme correto', () async {
      await repo.saveContent(sample(folderName: 'a'));
      final found = await repo.getByFolderName('a');
      expect(found, isNotNull);
      expect(found!.folderName, 'a');
    });

    test('markAsUnavailable muda isAvailable para false', () async {
      await repo.saveContent(sample(folderName: 'a'));
      await repo.markAsUnavailable('a');
      final found = await repo.getByFolderName('a');
      expect(found, isNotNull);
      expect(found!.isAvailable, isFalse);
    });

    test(
      'saveContent em folderName existente PRESERVA o id (UPSERT real)',
      () async {
        // Mesmo rationale do test em pauloflix_repository_test.dart:
        // `InsertMode.insertOrReplace` antigo fazia DELETE+INSERT,
        // trocava o id e quebrava FKs cascade. Drift `DoUpdate` mantém
        // o id estável em re-syncs.
        await repo.saveContent(sample(folderName: 'inception'));
        final firstId = (await repo.getByFolderName('inception'))!.id;

        await repo.saveContent(
          sample(
            folderName: 'inception',
            displayName: 'A Origem (2010) — TMDB updated',
            score: 9.0,
            imageUrl: 'http://img/inception.jpg',
          ),
        );

        final all = await repo.getAll();
        expect(all, hasLength(1));
        final updated = (await repo.getByFolderName('inception'))!;
        expect(updated.id, equals(firstId), reason: 'id deve ser preservado');
        expect(updated.displayName, 'A Origem (2010) — TMDB updated');
        expect(updated.score, 9.0);
      },
    );

    test('saveBatch insere múltiplos', () async {
      await repo.saveBatch([
        sample(folderName: 'a'),
        sample(folderName: 'b'),
      ]);
      final all = await repo.getAll();
      expect(all, hasLength(2));
    });

    test('getStats inclui total/available/withMetadata/collections',
        () async {
      await repo.saveContent(
        sample(folderName: 'a', imageUrl: 'http://img/a.jpg'),
      );
      await repo.saveContent(
        sample(
          folderName: 'hp',
          availableMovieCount: 8,
          imageUrl: 'http://img/hp.jpg',
        ),
      );
      // Sem imageUrl
      await repo.saveContent(
        sample(folderName: 'noimg'),
      );

      final stats = await repo.getStats();
      expect(stats['total'], 3);
      expect(stats['available'], 3);
      expect(stats['withMetadata'], 2);
    });
  });
}
