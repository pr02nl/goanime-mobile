import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/data/repositories/pauloflix_repository_impl.dart';
import 'package:goanime/domain/models/pauloflix_content.dart';

void main() {
  late AppDatabase db;
  late PauloFlixRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    repo = PauloFlixRepositoryImpl(db);
  });

  PauloFlixContent sample({
    String folderName = 'naruto',
    String displayName = 'Naruto',
    double? score = 7.8,
    List<String> genres = const ['Action', 'Adventure'],
    bool isAvailable = true,
    String? imageUrl,
  }) {
    return PauloFlixContent(
      folderName: folderName,
      displayName: displayName,
      serverUrl: 'http://server/$folderName/',
      imageUrl: imageUrl,
      genres: genres,
      score: score,
      isAvailable: isAvailable,
    );
  }

  group('PauloFlixRepository — animes', () {
    test('saveContent + getAll retorna o conteúdo', () async {
      await repo.saveContent(sample(folderName: 'naruto'));
      await repo.saveContent(sample(
        folderName: 'onepiece',
        displayName: 'One Piece',
      ));

      final all = await repo.getAll();
      expect(all, hasLength(2));
      expect(all.map((c) => c.folderName).toSet(), {'naruto', 'onepiece'});
    });

    test('getAll filtra isAvailable = 0', () async {
      await repo.saveContent(sample(folderName: 'a'));
      await repo.saveContent(
        sample(folderName: 'b', displayName: 'B', isAvailable: false),
      );

      final all = await repo.getAll();
      expect(all, hasLength(1));
      expect(all.first.folderName, 'a');
    });

    test('getAll ordena por displayName', () async {
      await repo.saveContent(sample(folderName: 'c', displayName: 'C'));
      await repo.saveContent(sample(folderName: 'a', displayName: 'A'));
      await repo.saveContent(sample(folderName: 'b', displayName: 'B'));

      final all = await repo.getAll();
      expect(all.map((c) => c.displayName).toList(), ['A', 'B', 'C']);
    });

    test('searchByName usa LIKE ESCAPE (sem falsos positivos com %)', () async {
      await repo.saveContent(sample(
        folderName: 'a',
        displayName: '100% Mamãe',
      ));
      await repo.saveContent(sample(
        folderName: 'b',
        displayName: '100 Normal',
      ));

      final results = await repo.searchByName('100%');
      // Com ESCAPE, '%' é literal — só '100% Mamãe' casa.
      expect(results, hasLength(1));
      expect(results.first.displayName, '100% Mamãe');
    });

    test('getByFolderName retorna o conteúdo correto', () async {
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

    test('saveBatch insere múltiplos em transação', () async {
      await repo.saveBatch([
        sample(folderName: 'a'),
        sample(folderName: 'b'),
        sample(folderName: 'c'),
      ]);
      final all = await repo.getAll();
      expect(all, hasLength(3));
    });

    test(
      'saveContent em folderName existente PRESERVA o id (UPSERT real)',
      () async {
        // Re-sincronização do mesmo content (mesmo folderName) NÃO pode
        // trocar o id. O bug antigo usava InsertMode.insertOrReplace
        // que faz DELETE+INSERT, gerando um id novo e quebrando as FKs
        // de paulo_flix_seasons (cascade apagava as seasons + progresso
        // do user). Drift deve usar ON CONFLICT DO UPDATE para manter
        // o id estável.
        await repo.saveContent(
          sample(folderName: 'naruto', displayName: 'Naruto v1'),
        );
        final firstId = (await repo.getByFolderName('naruto'))!.id;

        // Re-sincroniza o mesmo folderName com metadados novos.
        await repo.saveContent(
          sample(
            folderName: 'naruto',
            displayName: 'Naruto v2 — Jikan updated score',
            score: 8.5,
            imageUrl: 'http://img/naruto.jpg',
          ),
        );

        final all = await repo.getAll();
        expect(all, hasLength(1), reason: 'não pode duplicar');
        final updated = (await repo.getByFolderName('naruto'))!;
        expect(updated.id, equals(firstId), reason: 'id deve ser preservado');
        expect(updated.displayName, 'Naruto v2 — Jikan updated score');
        expect(updated.score, 8.5);
        expect(updated.imageUrl, 'http://img/naruto.jpg');
      },
    );

    test(
      'saveBatch em folderNames existentes preserva os ids (UPSERT real)',
      () async {
        await repo.saveBatch([
          sample(folderName: 'a'),
          sample(folderName: 'b'),
        ]);
        final idA = (await repo.getByFolderName('a'))!.id;
        final idB = (await repo.getByFolderName('b'))!.id;

        // Re-sincroniza com metadados novos.
        await repo.saveBatch([
          sample(folderName: 'a', displayName: 'A v2', score: 9.0),
          sample(folderName: 'b', displayName: 'B v2', score: 9.1),
        ]);

        final all = await repo.getAll();
        expect(all, hasLength(2));
        expect((await repo.getByFolderName('a'))!.id, equals(idA));
        expect((await repo.getByFolderName('b'))!.id, equals(idB));
        expect((await repo.getByFolderName('a'))!.displayName, 'A v2');
        expect((await repo.getByFolderName('b'))!.displayName, 'B v2');
      },
    );

    test('getStats retorna contagens', () async {
      await repo.saveContent(
        sample(folderName: 'a', imageUrl: 'http://img/a.jpg'),
      );
      await repo.saveContent(
        sample(folderName: 'b', imageUrl: 'http://img/b.jpg'),
      );
      // Sem imageUrl: não conta como "withMetadata".
      await repo.saveContent(sample(folderName: 'noimg'));
      // Indisponível: não conta como "available".
      await repo.saveContent(
        sample(folderName: 'd', isAvailable: false, imageUrl: 'http://img/d.jpg'),
      );

      final stats = await repo.getStats();
      expect(stats['total'], 4);
      expect(stats['available'], 3);
      expect(stats['withMetadata'], 2);
    });
  });
}
