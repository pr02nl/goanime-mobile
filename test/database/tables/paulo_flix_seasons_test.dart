import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';

/// Testes smoke da tabela `paulo_flix_seasons` (Fase 0 do plano
/// `.hermes/plans/2026-06-22_2230-pauloflix-episodes-progress.md`).
///
/// Foco: validar shape da tabela, defaults e FK com `paulo_flix_content` —
/// a lógica de negócio (`isCompleted` derivado) é testada no repositório.
void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('PauloFlixSeasons — schema', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'cria tabela com colunas esperadas e defaults (episodeCount=0, '
      'isCompleted=false)',
      () async {
        // Insere um content primeiro (FK parent obrigatório).
        final contentId = await db.into(db.pauloFlixContent).insert(
              PauloFlixContentCompanion.insert(
                folderName: 'Naruto',
                displayName: 'Naruto',
                serverUrl: 'https://server/Naruto/',
                lastSynced: DateTime.now(),
              ),
            );

        // Insere season sem passar episodeCount/isCompleted (defaults).
        final seasonId = await db.into(db.pauloFlixSeasons).insert(
              PauloFlixSeasonsCompanion.insert(
                contentId: contentId,
                seasonNumber: 1,
                displayName: 'Season 01',
                folderName: 'Season 01',
                lastSynced: DateTime.now(),
              ),
            );

        final row = await (db.select(db.pauloFlixSeasons)
              ..where((t) => t.id.equals(seasonId)))
            .getSingle();
        expect(row.seasonNumber, 1);
        expect(row.displayName, 'Season 01');
        expect(row.episodeCount, 0); // default
        expect(row.isCompleted, false); // default
      },
    );

    test('unique key (contentId, seasonNumber) impede duplicatas', () async {
      final contentId = await db.into(db.pauloFlixContent).insert(
            PauloFlixContentCompanion.insert(
              folderName: 'Bleach',
              displayName: 'Bleach',
              serverUrl: 'https://server/Bleach/',
              lastSynced: DateTime.now(),
            ),
          );

      // Primeira inserção: OK.
      await db.into(db.pauloFlixSeasons).insert(
            PauloFlixSeasonsCompanion.insert(
              contentId: contentId,
              seasonNumber: 1,
              displayName: 'S01',
              folderName: 'S01',
              lastSynced: DateTime.now(),
            ),
          );

      // Segunda inserção do mesmo (contentId, seasonNumber): deve falhar.
      expect(
        () => db.into(db.pauloFlixSeasons).insert(
          PauloFlixSeasonsCompanion.insert(
            contentId: contentId,
            seasonNumber: 1,
            displayName: 'S01 - outra',
            folderName: 'S01 - outra',
            lastSynced: DateTime.now(),
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test(
      'FK cascade: apagar content apaga seasons e episodes',
      () async {
        final contentId = await db.into(db.pauloFlixContent).insert(
              PauloFlixContentCompanion.insert(
                folderName: 'OnePiece',
                displayName: 'One Piece',
                serverUrl: 'https://server/OnePiece/',
                lastSynced: DateTime.now(),
              ),
            );

        // Cria season + 2 episodes.
        final seasonId = await db.into(db.pauloFlixSeasons).insert(
              PauloFlixSeasonsCompanion.insert(
                contentId: contentId,
                seasonNumber: 1,
                displayName: 'East Blue',
                folderName: 'East Blue',
                lastSynced: DateTime.now(),
              ),
            );
        await db.into(db.pauloFlixEpisodes).insert(
              PauloFlixEpisodesCompanion.insert(
                seasonId: seasonId,
                episodeNumber: 1,
                title: 'ep 1',
                videoUrl: 'https://server/OnePiece/S01/ep1.mkv',
                lastSynced: DateTime.now(),
              ),
            );
        await db.into(db.pauloFlixEpisodes).insert(
              PauloFlixEpisodesCompanion.insert(
                seasonId: seasonId,
                episodeNumber: 2,
                title: 'ep 2',
                videoUrl: 'https://server/OnePiece/S01/ep2.mkv',
                lastSynced: DateTime.now(),
              ),
            );

        // Confirma 2 episodes antes do cascade.
        expect(
          await (db.select(db.pauloFlixEpisodes)
                ..where((t) => t.seasonId.equals(seasonId)))
              .get(),
          hasLength(2),
        );

        // Apaga content → cascade apaga season → cascade apaga episodes.
        await (db.delete(db.pauloFlixContent)
              ..where((t) => t.id.equals(contentId)))
            .go();

        expect(
          await (db.select(db.pauloFlixSeasons)
                ..where((t) => t.contentId.equals(contentId)))
              .get(),
          isEmpty,
        );
        expect(
          await (db.select(db.pauloFlixEpisodes)
                ..where((t) => t.seasonId.equals(seasonId)))
              .get(),
          isEmpty,
        );
      },
    );

    test('episodeCount pode ser atualizado manualmente (denormalizado)', () async {
      final contentId = await db.into(db.pauloFlixContent).insert(
            PauloFlixContentCompanion.insert(
              folderName: 'HxH',
              displayName: 'Hunter x Hunter',
              serverUrl: 'https://server/HxH/',
              lastSynced: DateTime.now(),
            ),
          );

      final seasonId = await db.into(db.pauloFlixSeasons).insert(
            PauloFlixSeasonsCompanion.insert(
              contentId: contentId,
              seasonNumber: 1,
              displayName: 'S01',
              folderName: 'S01',
              lastSynced: DateTime.now(),
            ),
          );

      // Atualiza o cache.
      await (db.update(db.pauloFlixSeasons)
            ..where((t) => t.id.equals(seasonId)))
          .write(const PauloFlixSeasonsCompanion(episodeCount: Value(62)));

      final row = await (db.select(db.pauloFlixSeasons)
            ..where((t) => t.id.equals(seasonId)))
          .getSingle();
      expect(row.episodeCount, 62);
    });
  });
}
