import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/data/repositories/paulo_flix_episode_progress_repository_impl.dart';
import 'package:goanime/domain/repositories/paulo_flix_episode_progress_repository.dart';

/// Testes da reconciliação de seasons/episodes no
/// `PauloFlixEpisodeProgressRepository` (Fase 2).
///
/// Cenários cobertos:
/// - Season ausente do scrape + sem progresso → REMOVIDA
/// - Season ausente do scrape + COM progresso → MANTIDA
/// - Episode ausente do scrape + sem progresso → REMOVIDO
/// - Episode ausente do scrape + COM progresso (position > 0) → MANTIDO
/// - Episode ausente do scrape + COM progresso (isCompleted) → MANTIDO
/// - getSeasonNumbersForContent / getEpisodeNumbersForSeason retornam
///   os números corretos
void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('PauloFlixEpisodeProgressRepository — reconciliação (Fase 2)', () {
    late AppDatabase db;
    late PauloFlixEpisodeProgressRepository repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = PauloFlixEpisodeProgressRepositoryImpl(db);
    });

    tearDown(() async => db.close());

    /// Helper: cria um content + N seasons + M episodes, opcionalmente
    /// com progresso (positionSeconds ou isCompleted) em alguns episodes.
    Future<int> setupContent({
      String folder = 'Naruto',
      List<
            ({
              int number,
              String name,
              List<
                ({
                  int number,
                  String title,
                  String url,
                  int? position,
                  bool completed,
                })
              >
              episodes,
            })
          >
          seasons =
          const [],
    }) async {
      final contentId = await db
          .into(db.pauloFlixContent)
          .insert(
            PauloFlixContentCompanion.insert(
              folderName: folder,
              displayName: folder,
              serverUrl: 'https://server/$folder/',
              lastSynced: DateTime.now(),
            ),
          );
      for (final s in seasons) {
        final seasonId = await db
            .into(db.pauloFlixSeasons)
            .insert(
              PauloFlixSeasonsCompanion.insert(
                contentId: contentId,
                seasonNumber: s.number,
                displayName: s.name,
                folderName: s.name,
                lastSynced: DateTime.now(),
              ),
            );
        for (final e in s.episodes) {
          await db
              .into(db.pauloFlixEpisodes)
              .insert(
                PauloFlixEpisodesCompanion.insert(
                  seasonId: seasonId,
                  episodeNumber: e.number,
                  title: e.title,
                  videoUrl: e.url,
                  positionSeconds: Value(e.position ?? 0),
                  isCompleted: Value(e.completed),
                  lastSynced: DateTime.now(),
                ),
              );
        }
      }
      return contentId;
    }

    test(
      'removeMissingSeasons: season ausente do scrape + sem progresso → REMOVIDA',
      () async {
        final contentId = await setupContent(
          seasons: [
            (
              number: 1,
              name: 'S01',
              episodes: [
                (
                  number: 1,
                  title: 'ep 1',
                  url: 'a.mkv',
                  position: 0,
                  completed: false,
                ),
              ],
            ),
            (
              number: 2,
              name: 'S02',
              episodes: [
                (
                  number: 1,
                  title: 'ep 1',
                  url: 'a.mkv',
                  position: 0,
                  completed: false,
                ),
              ],
            ),
          ],
        );

        // Servidor só tem season 1 — season 2 sumiu.
        final removed = await repo.removeMissingSeasons(
          contentId: contentId,
          scrapedSeasonNumbers: {1},
        );

        expect(removed, hasLength(1));
        final seasons = await (db.select(
          db.pauloFlixSeasons,
        )..where((t) => t.contentId.equals(contentId))).get();
        expect(seasons, hasLength(1));
        expect(seasons.first.seasonNumber, 1);
      },
    );

    test(
      'removeMissingSeasons: season ausente + COM progresso → MANTIDA',
      () async {
        final contentId = await setupContent(
          seasons: [
            (
              number: 1,
              name: 'S01',
              episodes: [
                (
                  number: 1,
                  title: 'ep 1',
                  url: 'a.mkv',
                  position: 600,
                  completed: false,
                ),
              ],
            ),
            (
              number: 2,
              name: 'S02',
              episodes: [
                (
                  number: 1,
                  title: 'ep 1',
                  url: 'a.mkv',
                  position: 0,
                  completed: false,
                ),
              ],
            ),
          ],
        );

        final removed = await repo.removeMissingSeasons(
          contentId: contentId,
          scrapedSeasonNumbers: {1}, // S02 sumiu
        );

        // S01 (com progresso) mantida; S02 (sem progresso) removida.
        expect(removed, hasLength(1));
        final seasons =
            await (db.select(db.pauloFlixSeasons)
                  ..where((t) => t.contentId.equals(contentId))
                  ..orderBy([(t) => OrderingTerm(expression: t.seasonNumber)]))
                .get();
        expect(seasons, hasLength(1));
        expect(
          seasons.first.seasonNumber,
          1,
          reason: 'S01 (com progresso) mantida; S02 removida',
        );
      },
    );

    test('removeMissingSeasons: season com isCompleted → MANTIDA', () async {
      final contentId = await setupContent(
        seasons: [
          (
            number: 1,
            name: 'S01',
            episodes: [
              (
                number: 1,
                title: 'ep 1',
                url: 'a.mkv',
                position: 0,
                completed: true,
              ),
            ],
          ),
          (
            number: 2,
            name: 'S02',
            episodes: [
              (
                number: 1,
                title: 'ep 1',
                url: 'a.mkv',
                position: 0,
                completed: false,
              ),
            ],
          ),
        ],
      );

      final removed = await repo.removeMissingSeasons(
        contentId: contentId,
        scrapedSeasonNumbers: {1}, // S02 sumiu
      );

      expect(
        removed,
        hasLength(1),
        reason: 'S01 mantida (isCompleted); S02 removida',
      );
      final seasons = await (db.select(
        db.pauloFlixSeasons,
      )..where((t) => t.contentId.equals(contentId))).get();
      expect(seasons, hasLength(1));
      expect(seasons.first.seasonNumber, 1);
    });

    test(
      'removeMissingEpisodes: episode ausente + sem progresso → REMOVIDO',
      () async {
        await setupContent(
          seasons: [
            (
              number: 1,
              name: 'S01',
              episodes: [
                (
                  number: 1,
                  title: 'ep 1',
                  url: 'a.mkv',
                  position: 0,
                  completed: false,
                ),
                (
                  number: 2,
                  title: 'ep 2',
                  url: 'b.mkv',
                  position: 0,
                  completed: false,
                ),
                (
                  number: 3,
                  title: 'ep 3',
                  url: 'c.mkv',
                  position: 0,
                  completed: false,
                ),
              ],
            ),
          ],
        );

        // Servidor só tem episodes 1 e 3 — ep 2 sumiu.
        final removed = await repo.removeMissingEpisodes(
          seasonId: (await (db.select(db.pauloFlixSeasons)).getSingle()).id,
          scrapedEpisodeNumbers: {1, 3},
        );

        expect(removed, hasLength(1));
        final eps = await (db.select(
          db.pauloFlixEpisodes,
        )..orderBy([(t) => OrderingTerm(expression: t.episodeNumber)])).get();
        expect(eps, hasLength(2));
        expect(eps.map((e) => e.episodeNumber), [1, 3]);
      },
    );

    test(
      'removeMissingEpisodes: episode ausente + com positionSeconds > 0 → MANTIDO',
      () async {
        await setupContent(
          seasons: [
            (
              number: 1,
              name: 'S01',
              episodes: [
                (
                  number: 1,
                  title: 'ep 1',
                  url: 'a.mkv',
                  position: 600,
                  completed: false,
                ),
              ],
            ),
          ],
        );

        final season = await (db.select(db.pauloFlixSeasons)).getSingle();
        final removed = await repo.removeMissingEpisodes(
          seasonId: season.id,
          scrapedEpisodeNumbers: {}, // ep 1 sumiu
        );

        expect(removed, isEmpty, reason: 'ep 1 tem progresso — mantido');
      },
    );

    test(
      'removeMissingEpisodes: episode ausente + isCompleted → MANTIDO',
      () async {
        await setupContent(
          seasons: [
            (
              number: 1,
              name: 'S01',
              episodes: [
                (
                  number: 1,
                  title: 'ep 1',
                  url: 'a.mkv',
                  position: 0,
                  completed: true,
                ),
              ],
            ),
          ],
        );

        final season = await (db.select(db.pauloFlixSeasons)).getSingle();
        final removed = await repo.removeMissingEpisodes(
          seasonId: season.id,
          scrapedEpisodeNumbers: {},
        );

        expect(removed, isEmpty, reason: 'ep 1 está completed — mantido');
      },
    );

    test('removeMissingEpisodes: mistura progresso/no-progresso', () async {
      await setupContent(
        seasons: [
          (
            number: 1,
            name: 'S01',
            episodes: [
              (
                number: 1,
                title: 'ep 1',
                url: 'a.mkv',
                position: 0,
                completed: false,
              ),
              (
                number: 2,
                title: 'ep 2',
                url: 'b.mkv',
                position: 300,
                completed: false,
              ),
              (
                number: 3,
                title: 'ep 3',
                url: 'c.mkv',
                position: 0,
                completed: false,
              ),
            ],
          ),
        ],
      );

      final season = await (db.select(db.pauloFlixSeasons)).getSingle();
      final removed = await repo.removeMissingEpisodes(
        seasonId: season.id,
        scrapedEpisodeNumbers: {}, // todos sumiram do servidor
      );

      expect(
        removed,
        hasLength(2),
        reason: 'ep 1 e ep 3 removidos; ep 2 mantido (tem progresso)',
      );
    });

    test(
      'getSeasonNumbersForContent retorna os seasonNumbers corretos',
      () async {
        final contentId = await setupContent(
          seasons: [
            (number: 1, name: 'S01', episodes: const []),
            (number: 3, name: 'S03', episodes: const []),
            (number: 5, name: 'S05', episodes: const []),
          ],
        );

        final numbers = await repo.getSeasonNumbersForContent(contentId);
        expect(numbers, {1, 3, 5});
      },
    );

    test(
      'getEpisodeNumbersForSeason retorna os episodeNumbers corretos',
      () async {
        await setupContent(
          seasons: [
            (
              number: 1,
              name: 'S01',
              episodes: [
                (
                  number: 2,
                  title: 'ep 2',
                  url: 'a.mkv',
                  position: 0,
                  completed: false,
                ),
                (
                  number: 5,
                  title: 'ep 5',
                  url: 'b.mkv',
                  position: 0,
                  completed: false,
                ),
              ],
            ),
          ],
        );

        final season = await (db.select(db.pauloFlixSeasons)).getSingle();
        final numbers = await repo.getEpisodeNumbersForSeason(season.id);
        expect(numbers, {2, 5});
      },
    );

    test('reconciliação: cascade — remover season apaga episodes', () async {
      final contentId = await setupContent(
        seasons: [
          (
            number: 1,
            name: 'S01',
            episodes: [
              (
                number: 1,
                title: 'ep 1',
                url: 'a.mkv',
                position: 0,
                completed: false,
              ),
            ],
          ),
          (
            number: 2,
            name: 'S02',
            episodes: [
              (
                number: 1,
                title: 'ep 1',
                url: 'a.mkv',
                position: 0,
                completed: false,
              ),
            ],
          ),
        ],
      );

      await repo.removeMissingSeasons(
        contentId: contentId,
        scrapedSeasonNumbers: {1}, // S02 some
      );

      final eps = await db.select(db.pauloFlixEpisodes).get();
      // S02 episode (sem FK match) deve ter sido removido pelo cascade.
      expect(eps, hasLength(1));
      expect(eps.first.episodeNumber, 1);
      final seasons = await db.select(db.pauloFlixSeasons).get();
      expect(seasons, hasLength(1));
      expect(seasons.first.seasonNumber, 1);
    });
  });
}
