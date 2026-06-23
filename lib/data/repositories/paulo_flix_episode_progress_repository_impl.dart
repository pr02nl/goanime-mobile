import 'package:drift/drift.dart' hide isNotNull, isNull;

import '../../core/database/app_database.dart';
import '../../domain/models/pauloflix_content.dart';
import '../../domain/models/paulo_flix_episode_record.dart';
import '../../domain/models/paulo_flix_progress_stats.dart';
import '../../domain/models/paulo_flix_season_record.dart';
import '../../domain/repositories/paulo_flix_episode_progress_repository.dart';

/// Implementação Drift do `PauloFlixEpisodeProgressRepository`.
///
/// **Fase 1.3 do plano**
/// `.hermes/plans/2026-06-22_2230-pauloflix-episodes-progress.md`.
///
/// Persiste seasons, episodes e progresso de playback. A lógica de
/// `_recomputeSeasonCompleted` mantém a flag `season.isCompleted`
/// consistente — atualizada em **todo** `updateProgress` que muda
/// `episode.isCompleted` e em **todo** `resetProgress` (bug fix:
/// re-assistir o último episode completo de uma season deve reverter
/// a flag).
class PauloFlixEpisodeProgressRepositoryImpl
    implements PauloFlixEpisodeProgressRepository {
  final AppDatabase _db;
  PauloFlixEpisodeProgressRepositoryImpl(this._db);

  // ═══════════════════════════════════════════════════════════════════════
  // Progresso de episódio
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Future<void> updateProgress({
    required int seasonId,
    required int episodeNumber,
    required int positionSeconds,
    int? durationSeconds,
  }) async {
    // 1. Atualiza posição + duration + lastWatched.
    await (_db.update(_db.pauloFlixEpisodes)
          ..where((t) =>
              t.seasonId.equals(seasonId) &
              t.episodeNumber.equals(episodeNumber)))
        .write(PauloFlixEpisodesCompanion(
      positionSeconds: Value(positionSeconds),
      durationSeconds: durationSeconds == null
          ? const Value.absent()
          : Value(durationSeconds),
      lastWatched: Value(DateTime.now()),
    ));

    // 2. Se temos duration conhecida, avalia se completou (ratio >= 0.9).
    if (durationSeconds != null && durationSeconds > 0) {
      final ratio = positionSeconds / durationSeconds;
      if (ratio >= 0.9) {
        // Marca episode como completo.
        await (_db.update(_db.pauloFlixEpisodes)
              ..where((t) =>
                  t.seasonId.equals(seasonId) &
                  t.episodeNumber.equals(episodeNumber)))
            .write(const PauloFlixEpisodesCompanion(
          isCompleted: Value(true),
        ));
        // 3. Recalcula season.isCompleted (todos os episodes completos?).
        await _recomputeSeasonCompleted(seasonId);
      }
    }
  }

  @override
  Future<void> resetProgress({
    required int seasonId,
    required int episodeNumber,
  }) async {
    // Zera posição + isCompleted do episode.
    await (_db.update(_db.pauloFlixEpisodes)
          ..where((t) =>
              t.seasonId.equals(seasonId) &
              t.episodeNumber.equals(episodeNumber)))
        .write(const PauloFlixEpisodesCompanion(
      positionSeconds: Value(0),
      isCompleted: Value(false),
    ));
    // **BUG FIX** (decisão 6): recomputar a flag da season. Sem isso,
    // reassistir o último episode completo de uma season manteria a flag
    // `season.isCompleted = true` (estado inconsistente).
    await _recomputeSeasonCompleted(seasonId);
  }

  @override
  Future<PauloFlixProgressStats> getStatsForContent(int contentId) async {
    // 1 query agregada com COALESCE — SUM retorna NULL em conjunto vazio,
    // e `row.read<int>()` quebra com cast de NULL.
    final row = await _db.customSelect(
      'SELECT '
      '  COUNT(*) AS total, '
      '  COALESCE(SUM(CASE WHEN e.is_completed = 1 THEN 1 ELSE 0 END), 0) '
      '    AS completed, '
      '  COALESCE(SUM(CASE WHEN e.position_seconds > 0 AND e.is_completed = 0 '
      '           THEN 1 ELSE 0 END), 0) AS in_progress '
      'FROM paulo_flix_episodes e '
      'INNER JOIN paulo_flix_seasons s ON e.season_id = s.id '
      'WHERE s.content_id = ?1',
      variables: [Variable.withInt(contentId)],
      readsFrom: {_db.pauloFlixEpisodes, _db.pauloFlixSeasons},
    ).getSingle();
    return PauloFlixProgressStats(
      totalEpisodes: row.read<int>('total'),
      completedEpisodes: row.read<int>('completed'),
      inProgressEpisodes: row.read<int>('in_progress'),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Continue assistindo
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Future<List<PauloFlixContent>> getInProgressContents({int limit = 12}) async {
    final rows = await _db.customSelect(
      'SELECT c.* FROM paulo_flix_content c '
      'INNER JOIN paulo_flix_seasons s ON s.content_id = c.id '
      'INNER JOIN paulo_flix_episodes e ON e.season_id = s.id '
      'WHERE e.position_seconds > 0 '
      '  AND e.is_completed = 0 '
      '  AND c.is_available = 1 '
      'GROUP BY c.id '
      'ORDER BY MAX(e.last_watched) DESC '
      'LIMIT ?1',
      variables: [Variable.withInt(limit)],
      readsFrom: {
        _db.pauloFlixContent,
        _db.pauloFlixSeasons,
        _db.pauloFlixEpisodes,
      },
    ).get();
    return rows
        .map((r) => _toContentDomain(_db.pauloFlixContent.map(r.data)))
        .toList();
  }

  @override
  Stream<List<PauloFlixContent>> watchInProgressContents({int limit = 12}) {
    return _db.customSelect(
      'SELECT c.* FROM paulo_flix_content c '
      'INNER JOIN paulo_flix_seasons s ON s.content_id = c.id '
      'INNER JOIN paulo_flix_episodes e ON e.season_id = s.id '
      'WHERE e.position_seconds > 0 '
      '  AND e.is_completed = 0 '
      '  AND c.is_available = 1 '
      'GROUP BY c.id '
      'ORDER BY MAX(e.last_watched) DESC '
      'LIMIT ?1',
      variables: [Variable.withInt(limit)],
      readsFrom: {
        _db.pauloFlixContent,
        _db.pauloFlixSeasons,
        _db.pauloFlixEpisodes,
      },
    ).watch().map(
          (rows) => rows
              .map(
                (r) => _toContentDomain(_db.pauloFlixContent.map(r.data)),
              )
              .toList(),
        );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CRUD seasons
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Future<List<PauloFlixSeasonRecord>> getSeasonsForContent(int contentId) async {
    final rows = await (_db.select(_db.pauloFlixSeasons)
          ..where((t) => t.contentId.equals(contentId))
          ..orderBy([(t) => OrderingTerm(expression: t.seasonNumber)]))
        .get();
    return rows.map(_toSeasonDomain).toList();
  }

  @override
  Stream<List<PauloFlixSeasonRecord>> watchSeasonsForContent(int contentId) {
    return (_db.select(_db.pauloFlixSeasons)
          ..where((t) => t.contentId.equals(contentId))
          ..orderBy([(t) => OrderingTerm(expression: t.seasonNumber)]))
        .watch()
        .map((rows) => rows.map(_toSeasonDomain).toList());
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CRUD episodes
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Future<List<PauloFlixEpisodeRecord>> getEpisodesForSeason(int seasonId) async {
    final rows = await (_db.select(_db.pauloFlixEpisodes)
          ..where((t) => t.seasonId.equals(seasonId))
          ..orderBy([(t) => OrderingTerm(expression: t.episodeNumber)]))
        .get();
    return rows.map(_toEpisodeDomain).toList();
  }

  @override
  Stream<List<PauloFlixEpisodeRecord>> watchEpisodesForSeason(int seasonId) {
    return (_db.select(_db.pauloFlixEpisodes)
          ..where((t) => t.seasonId.equals(seasonId))
          ..orderBy([(t) => OrderingTerm(expression: t.episodeNumber)]))
        .watch()
        .map((rows) => rows.map(_toEpisodeDomain).toList());
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Sync on-demand
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Future<void> syncSeasonEpisodes({
    required int contentId,
    required String contentServerUrl,
  }) async {
    // 1. Fetch seasons do servidor.
    final seasons =
        await _PauloFlixServiceShim.fetchShowSeasons(contentServerUrl);

    for (final s in seasons) {
      // 2. Upsert season — preserva `isCompleted` e `episodeCount` se já
      // existirem.
      final seasonId = await _upsertSeason(
        contentId: contentId,
        seasonNumber: s.number,
        displayName: s.name,
        folderName: s.name,
      );

      // 3. Fetch episodes desta season.
      final episodes = await _PauloFlixServiceShim.fetchSeasonEpisodes(s.url);

      // 4. Upsert cada episode — preserva `positionSeconds`,
      // `isCompleted`, `lastWatched` e `durationSeconds` se já existirem.
      for (final e in episodes) {
        await _upsertEpisode(
          seasonId: seasonId,
          episodeNumber: e.number,
          title: e.title,
          videoUrl: e.url,
        );
      }

      // 5. Atualiza episodeCount com o total descoberto no scrape.
      await (_db.update(_db.pauloFlixSeasons)
            ..where((t) => t.id.equals(seasonId)))
          .write(PauloFlixSeasonsCompanion(
        episodeCount: Value(episodes.length),
        lastSynced: Value(DateTime.now()),
      ));
    }
  }

  // ─── Helpers internos ────────────────────────────────────────────────

  /// Recalcula `season.isCompleted` baseado nos episodes da season.
  /// `true` se TODOS os episodes estão completos (e há pelo menos 1).
  /// `false` caso contrário (incluindo season vazia).
  Future<void> _recomputeSeasonCompleted(int seasonId) async {
    final total = await (_db.selectOnly(_db.pauloFlixEpisodes)
          ..addColumns([_db.pauloFlixEpisodes.episodeNumber.count()])
          ..where(_db.pauloFlixEpisodes.seasonId.equals(seasonId)))
        .getSingle();
    final completed = await (_db.selectOnly(_db.pauloFlixEpisodes)
          ..addColumns([_db.pauloFlixEpisodes.episodeNumber.count()])
          ..where(_db.pauloFlixEpisodes.seasonId.equals(seasonId) &
              _db.pauloFlixEpisodes.isCompleted.equals(true)))
        .getSingle();
    final totalN = total.read(_db.pauloFlixEpisodes.episodeNumber.count()) ?? 0;
    final completedN =
        completed.read(_db.pauloFlixEpisodes.episodeNumber.count()) ?? 0;
    final allCompleted = totalN > 0 && totalN == completedN;
    await (_db.update(_db.pauloFlixSeasons)
          ..where((t) => t.id.equals(seasonId)))
        .write(PauloFlixSeasonsCompanion(
      isCompleted: Value(allCompleted),
    ));
  }

  Future<int> _upsertSeason({
    required int contentId,
    required int seasonNumber,
    required String displayName,
    required String folderName,
  }) async {
    final existing = await (_db.select(_db.pauloFlixSeasons)
          ..where((t) =>
              t.contentId.equals(contentId) &
              t.seasonNumber.equals(seasonNumber))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) {
      // Preserva `isCompleted` e `episodeCount` (não sobrescreve).
      await (_db.update(_db.pauloFlixSeasons)
            ..where((t) => t.id.equals(existing.id)))
          .write(PauloFlixSeasonsCompanion(
        displayName: Value(displayName),
        folderName: Value(folderName),
        lastSynced: Value(DateTime.now()),
      ));
      return existing.id;
    }
    return _db.into(_db.pauloFlixSeasons).insert(
          PauloFlixSeasonsCompanion.insert(
            contentId: contentId,
            seasonNumber: seasonNumber,
            displayName: displayName,
            folderName: folderName,
            lastSynced: DateTime.now(),
          ),
        );
  }

  Future<void> _upsertEpisode({
    required int seasonId,
    required int episodeNumber,
    required String title,
    required String videoUrl,
  }) async {
    final existing = await (_db.select(_db.pauloFlixEpisodes)
          ..where((t) =>
              t.seasonId.equals(seasonId) &
              t.episodeNumber.equals(episodeNumber))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) {
      // **CRÍTICO**: NÃO sobrescrever positionSeconds, isCompleted,
      // lastWatched, durationSeconds — preserva progresso do user.
      await (_db.update(_db.pauloFlixEpisodes)
            ..where((t) => t.id.equals(existing.id)))
          .write(PauloFlixEpisodesCompanion(
        title: Value(title),
        videoUrl: Value(videoUrl),
        lastSynced: Value(DateTime.now()),
      ));
    } else {
      await _db.into(_db.pauloFlixEpisodes).insert(
            PauloFlixEpisodesCompanion.insert(
              seasonId: seasonId,
              episodeNumber: episodeNumber,
              title: title,
              videoUrl: videoUrl,
              lastSynced: DateTime.now(),
            ),
          );
    }
  }

  // ─── Mappers (DB → domain) ──────────────────────────────────────────

  PauloFlixSeasonRecord _toSeasonDomain(PauloFlixSeason row) {
    return PauloFlixSeasonRecord(
      id: row.id,
      contentId: row.contentId,
      seasonNumber: row.seasonNumber,
      displayName: row.displayName,
      folderName: row.folderName,
      episodeCount: row.episodeCount,
      isCompleted: row.isCompleted,
      lastSynced: row.lastSynced,
    );
  }

  PauloFlixEpisodeRecord _toEpisodeDomain(PauloFlixEpisode row) {
    return PauloFlixEpisodeRecord(
      id: row.id,
      seasonId: row.seasonId,
      episodeNumber: row.episodeNumber,
      title: row.title,
      videoUrl: row.videoUrl,
      durationSeconds: row.durationSeconds,
      positionSeconds: row.positionSeconds,
      isCompleted: row.isCompleted,
      lastWatched: row.lastWatched,
      lastSynced: row.lastSynced,
    );
  }

  PauloFlixContent _toContentDomain(PauloFlixContentData row) {
    return PauloFlixContent(
      id: row.id,
      folderName: row.folderName,
      displayName: row.displayName,
      serverUrl: row.serverUrl,
      imageUrl: row.imageUrl,
      bannerUrl: row.bannerUrl,
      description: row.description,
      score: row.score,
      // Note: `genres` precisa de decode JSON/CSV. Para o carrossel
      // "Continue assistindo" não exibimos gêneros no card, então
      // passamos lista vazia. Se a UI precisar, ler via outro método.
      genres: const [],
      status: row.status,
      episodeCount: row.episodeCount,
      malId: row.malId,
      anilistId: row.anilistId,
      lastSynced: row.lastSynced,
      isAvailable: row.isAvailable,
    );
  }
}

/// Shim que encapsula as chamadas HTTP do `PauloFlixService`.
///
/// Por que um shim?
/// - Permite mockar o HTTP em testes futuros (Fase 1.4 — sync service).
/// - Mantém o `PauloFlixEpisodeProgressRepositoryImpl` focado em
///   persistência; a parte de "como buscar seasons/episodes" fica
///   no `PauloFlixService` (scraping HTML).
/// - O `_` no nome marca como detalhe de implementação — **não**
///   exportar.
class _PauloFlixServiceShim {
  static Future<List<_SeasonStub>> fetchShowSeasons(String showUrl) async {
    // Implementação real vem no service de sync (Fase 1.4). Por enquanto
    // este método é o ponto de injeção — testes podem substituí-lo via
    // uma versão com override. No caminho de produção, a Fase 1.4 vai
    // trocar este shim por uma chamada ao `PauloFlixService` real.
    throw UnimplementedError(
      'syncSeasonEpisodes requer PauloFlixEpisodeSyncService (Fase 1.4). '
      'Esta impl é provisória.',
    );
  }

  static Future<List<_EpisodeStub>> fetchSeasonEpisodes(String seasonUrl) async {
    throw UnimplementedError(
      'syncSeasonEpisodes requer PauloFlixEpisodeSyncService (Fase 1.4).',
    );
  }
}

class _SeasonStub {
  final String name;
  final String url;
  final int number;
  const _SeasonStub(this.name, this.url, this.number);
}

class _EpisodeStub {
  final int number;
  final String title;
  final String url;
  const _EpisodeStub(this.number, this.title, this.url);
}
