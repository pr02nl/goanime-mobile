import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';

/// Testes smoke da tabela `paulo_flix_episodes` (Fase 0 do plano
/// `.hermes/plans/2026-06-22_2230-pauloflix-episodes-progress.md`).
///
/// Foco: shape da tabela, defaults e FK com `paulo_flix_seasons`.
/// Lógica de progresso (`updateProgress`, `resetProgress`,
/// `_recomputeSeasonCompleted`) é testada no repositório
/// (Fase 1.3 do plano).
void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  // Helper: cria content+season e devolve (contentId, seasonId).
  Future<(int, int)> createContentAndSeason(AppDatabase db) async {
    final contentId = await db.into(db.pauloFlixContent).insert(
          PauloFlixContentCompanion.insert(
            folderName: 'Naruto',
            displayName: 'Naruto',
            serverUrl: 'https://server/Naruto/',
            lastSynced: DateTime.now(),
          ),
        );
    final seasonId = await db.into(db.pauloFlixSeasons).insert(
          PauloFlixSeasonsCompanion.insert(
            contentId: contentId,
            seasonNumber: 1,
            displayName: 'Season 01',
            folderName: 'Season 01',
            lastSynced: DateTime.now(),
          ),
        );
    return (contentId, seasonId);
  }

  group('PauloFlixEpisodes — schema', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'cria episódio com defaults (positionSeconds=0, isCompleted=false, '
      'lastWatched=null)',
      () async {
        final (_, seasonId) = await createContentAndSeason(db);

        final epId = await db.into(db.pauloFlixEpisodes).insert(
              PauloFlixEpisodesCompanion.insert(
                seasonId: seasonId,
                episodeNumber: 1,
                title: 'Enter: Naruto Uzumaki!',
                videoUrl: 'https://server/Naruto/Season 01/S01E01.mkv',
                lastSynced: DateTime.now(),
              ),
            );

        final row = await (db.select(db.pauloFlixEpisodes)
              ..where((t) => t.id.equals(epId)))
            .getSingle();
        expect(row.positionSeconds, 0); // default
        expect(row.isCompleted, false); // default
        expect(row.lastWatched, isNull); // default
        expect(row.durationSeconds, isNull); // nullable, default null
      },
    );

    test('unique key (seasonId, episodeNumber) impede duplicatas', () async {
      final (_, seasonId) = await createContentAndSeason(db);

      await db.into(db.pauloFlixEpisodes).insert(
            PauloFlixEpisodesCompanion.insert(
              seasonId: seasonId,
              episodeNumber: 5,
              title: 'ep 5',
              videoUrl: 'https://server/S01E05.mkv',
              lastSynced: DateTime.now(),
            ),
          );

      expect(
        () => db.into(db.pauloFlixEpisodes).insert(
          PauloFlixEpisodesCompanion.insert(
            seasonId: seasonId,
            episodeNumber: 5,
            title: 'ep 5 duplicado',
            videoUrl: 'https://server/S01E05-dup.mkv',
            lastSynced: DateTime.now(),
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('FK cascade: apagar season apaga episodes', () async {
      final (_, seasonId) = await createContentAndSeason(db);

      await db.into(db.pauloFlixEpisodes).insert(
            PauloFlixEpisodesCompanion.insert(
              seasonId: seasonId,
              episodeNumber: 1,
              title: 'ep 1',
              videoUrl: 'https://server/S01E01.mkv',
              lastSynced: DateTime.now(),
            ),
          );
      await db.into(db.pauloFlixEpisodes).insert(
            PauloFlixEpisodesCompanion.insert(
              seasonId: seasonId,
              episodeNumber: 2,
              title: 'ep 2',
              videoUrl: 'https://server/S01E02.mkv',
              lastSynced: DateTime.now(),
            ),
          );

      // Apaga season → cascade apaga episodes.
      await (db.delete(db.pauloFlixSeasons)
            ..where((t) => t.id.equals(seasonId)))
          .go();

      expect(
        await (db.select(db.pauloFlixEpisodes)
              ..where((t) => t.seasonId.equals(seasonId)))
            .get(),
        isEmpty,
      );
    });

    test('updateProgress manual: positionSeconds e lastWatched gravam', () async {
      final (_, seasonId) = await createContentAndSeason(db);

      final epId = await db.into(db.pauloFlixEpisodes).insert(
            PauloFlixEpisodesCompanion.insert(
              seasonId: seasonId,
              episodeNumber: 1,
              title: 'ep 1',
              videoUrl: 'https://server/S01E01.mkv',
              lastSynced: DateTime.now(),
            ),
          );

      // Simula o que EpisodeProgressRecorder faz a cada 5s.
      final watchedAt = DateTime.now();
      await (db.update(db.pauloFlixEpisodes)
            ..where((t) => t.id.equals(epId)))
          .write(PauloFlixEpisodesCompanion(
        positionSeconds: const Value(150),
        durationSeconds: const Value(1440), // 24min
        lastWatched: Value(watchedAt),
      ));

      final row = await (db.select(db.pauloFlixEpisodes)
            ..where((t) => t.id.equals(epId)))
          .getSingle();
      expect(row.positionSeconds, 150);
      expect(row.durationSeconds, 1440);
      // Compara até o segundo (Drift perde ms em DateTime INTEGER).
      expect(
        row.lastWatched?.millisecondsSinceEpoch,
        (watchedAt.millisecondsSinceEpoch ~/ 1000) * 1000,
      );
    });
  });
}
