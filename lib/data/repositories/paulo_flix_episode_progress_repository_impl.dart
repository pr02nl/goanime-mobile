import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/foundation.dart';

import '../../core/database/app_database.dart';
import '../../domain/models/paulo_flix_episode_record.dart';
import '../../domain/models/paulo_flix_progress_stats.dart';
import '../../domain/models/paulo_flix_season_record.dart';
import '../../domain/models/pauloflix_content.dart';
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
    await (_db.update(_db.pauloFlixEpisodes)..where(
          (t) =>
              t.seasonId.equals(seasonId) &
              t.episodeNumber.equals(episodeNumber),
        ))
        .write(
          PauloFlixEpisodesCompanion(
            positionSeconds: Value(positionSeconds),
            durationSeconds: durationSeconds == null
                ? const Value.absent()
                : Value(durationSeconds),
            lastWatched: Value(DateTime.now()),
          ),
        );

    // 2. Se temos duration conhecida, avalia se completou (ratio >= 0.9).
    if (durationSeconds != null && durationSeconds > 0) {
      final ratio = positionSeconds / durationSeconds;
      if (ratio >= 0.9) {
        // Marca episode como completo.
        await (_db.update(_db.pauloFlixEpisodes)..where(
              (t) =>
                  t.seasonId.equals(seasonId) &
                  t.episodeNumber.equals(episodeNumber),
            ))
            .write(const PauloFlixEpisodesCompanion(isCompleted: Value(true)));
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
    await (_db.update(_db.pauloFlixEpisodes)..where(
          (t) =>
              t.seasonId.equals(seasonId) &
              t.episodeNumber.equals(episodeNumber),
        ))
        .write(
          const PauloFlixEpisodesCompanion(
            positionSeconds: Value(0),
            isCompleted: Value(false),
          ),
        );
    // **BUG FIX** (decisão 6): recomputar a flag da season. Sem isso,
    // reassistir o último episode completo de uma season manteria a flag
    // `season.isCompleted = true` (estado inconsistente).
    await _recomputeSeasonCompleted(seasonId);
  }

  @override
  Future<PauloFlixProgressStats> getStatsForContent(int contentId) async {
    // 1 query agregada com COALESCE — SUM retorna NULL em conjunto vazio,
    // e `row.read<int>()` quebra com cast de NULL.
    final row = await _db
        .customSelect(
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
        )
        .getSingle();
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
    final rows = await _db
        .customSelect(
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
        )
        .get();
    return rows
        .map((r) => _toContentDomain(_db.pauloFlixContent.map(r.data)))
        .toList();
  }

  @override
  Stream<List<PauloFlixContent>> watchInProgressContents({int limit = 12}) {
    return _db
        .customSelect(
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
        )
        .watch()
        .map(
          (rows) => rows
              .map((r) => _toContentDomain(_db.pauloFlixContent.map(r.data)))
              .toList(),
        );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CRUD seasons
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Future<List<PauloFlixSeasonRecord>> getSeasonsForContent(
    int contentId,
  ) async {
    final rows =
        await (_db.select(_db.pauloFlixSeasons)
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
  Future<List<PauloFlixEpisodeRecord>> getEpisodesForSeason(
    int seasonId,
  ) async {
    final rows =
        await (_db.select(_db.pauloFlixEpisodes)
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
  // Upserts de baixo nível (usados pelo sync do JSON index)
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Future<int> upsertSeason({
    required int contentId,
    required int seasonNumber,
    required String displayName,
    required String folderName,
    String? seasonDescription,
    String? posterFileName,
    String? fanartFileName,
  }) async {
    // Para o Companion, seasonDescription == null → `Value.absent()`
    // (NÃO mexe na coluna, preserva valor anterior). seasonDescription
    // != null → `Value(seasonDescription)` (sobrescreve com a plot
    // nova). Mesma semântica do `thumbnailUrl` (Fase 5) e `description`
    // (Fase 10) — o enricher pode retornar mapa vazio (sem NFO) e
    // nunca produz `seasonDescription != null`, o que cai no
    // `Value.absent()`. Resultado: rows antigos com description NÃO
    // são sobrescritos com null em re-syncs.
    final descValue = seasonDescription == null
        ? const Value<String?>.absent()
        : Value<String?>(seasonDescription);
    // Mesma semântica para posterFileName e fanartFileName:
    // `null` = preserva valor anterior (não sobrescreve com null);
    // `""` ou valor não-vazio = sobrescreve.
    final posterValue = posterFileName == null
        ? const Value<String?>.absent()
        : Value<String?>(posterFileName);
    final fanartValue = fanartFileName == null
        ? const Value<String?>.absent()
        : Value<String?>(fanartFileName);
    final existing =
        await (_db.select(_db.pauloFlixSeasons)
              ..where(
                (t) =>
                    t.contentId.equals(contentId) &
                    t.seasonNumber.equals(seasonNumber),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      // Preserva `isCompleted` e `episodeCount` (não sobrescreve).
      await (_db.update(
        _db.pauloFlixSeasons,
      )..where((t) => t.id.equals(existing.id))).write(
        PauloFlixSeasonsCompanion(
          displayName: Value(displayName),
          folderName: Value(folderName),
          description: descValue,
          posterFileName: posterValue,
          fanartFileName: fanartValue,
          lastSynced: Value(DateTime.now()),
        ),
      );
      return existing.id;
    }
    return _db
        .into(_db.pauloFlixSeasons)
        .insert(
          PauloFlixSeasonsCompanion.insert(
            contentId: contentId,
            seasonNumber: seasonNumber,
            displayName: displayName,
            folderName: folderName,
            description: descValue,
            posterFileName: posterValue,
            fanartFileName: fanartValue,
            lastSynced: DateTime.now(),
          ),
        );
  }

  @override
  Future<void> upsertEpisode({
    required int seasonId,
    required int episodeNumber,
    required String title,
    required String videoUrl,
    String? thumbnailUrl,
    String? description,
    // Schema V2 (Fase N+7): 5 campos NFO扩idos.
    String? originalTitle,
    String? outline,
    DateTime? aired,
    double? rating,
    int? runtime,
  }) async {
    // Para o Companion, thumbnailUrl == null → `Value.absent()` (NÃO
    // mexe na coluna, preserva valor anterior). thumbnailUrl != null →
    // `Value(thumbnailUrl)` (sobrescreve com a URL nova). Essa
    // semântica é a correta para a Fase 5: o enricher retorna mapa
    // vazio quando não encontra thumb, e mapa vazio nunca produz
    // `thumbs[e.number]`, que é `null`, que cai no `Value.absent()`.
    // Resultado: rows antigos com thumb NÃO são sobrescritos com
    // null em re-syncs.
    final thumbValue = thumbnailUrl == null
        ? const Value<String?>.absent()
        : Value<String?>(thumbnailUrl);
    // Mesma semântica do thumbnailUrl aplicada à description (Fase 10):
    // description == null → Value.absent() (preserva valor anterior);
    // description != null → Value(description) (sobrescreve com a
    // plot nova do JSON index). O caller propaga `null` e cai no
    // `Value.absent()` → row antigo com description NÃO é sobrescrito
    // com null em re-syncs.
    final descValue = description == null
        ? const Value<String?>.absent()
        : Value<String?>(description);
    // Schema V2 (Fase N+7): mesma semântica "null = preserva" para
    // os 5 campos扩idos do NFO. Se o NFO tem `originalTitle`
    // mas o re-sync não trouxe (enricher falhou, NFO removido do
    // servidor, etc), o caller propaga `null` → `Value.absent()`
    // → row antigo com `originalTitle` NÃO é sobrescrito com null.
    final originalTitleValue = originalTitle == null
        ? const Value<String?>.absent()
        : Value<String?>(originalTitle);
    final outlineValue = outline == null
        ? const Value<String?>.absent()
        : Value<String?>(outline);
    final airedValue = aired == null
        ? const Value<DateTime?>.absent()
        : Value<DateTime?>(aired);
    final ratingValue = rating == null
        ? const Value<double?>.absent()
        : Value<double?>(rating);
    final runtimeValue = runtime == null
        ? const Value<int?>.absent()
        : Value<int?>(runtime);
    final existing =
        await (_db.select(_db.pauloFlixEpisodes)
              ..where(
                (t) =>
                    t.seasonId.equals(seasonId) &
                    t.episodeNumber.equals(episodeNumber),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      // **CRÍTICO**: NÃO sobrescrever positionSeconds, isCompleted,
      // lastWatched, durationSeconds — preserva progresso do user.
      await (_db.update(
        _db.pauloFlixEpisodes,
      )..where((t) => t.id.equals(existing.id))).write(
        PauloFlixEpisodesCompanion(
          title: Value(title),
          videoUrl: Value(videoUrl),
          thumbnailUrl: thumbValue,
          description: descValue,
          originalTitle: originalTitleValue,
          outline: outlineValue,
          aired: airedValue,
          rating: ratingValue,
          runtime: runtimeValue,
          lastSynced: Value(DateTime.now()),
        ),
      );
    } else {
      await _db
          .into(_db.pauloFlixEpisodes)
          .insert(
            PauloFlixEpisodesCompanion.insert(
              seasonId: seasonId,
              episodeNumber: episodeNumber,
              title: title,
              videoUrl: videoUrl,
              thumbnailUrl: thumbValue,
              description: descValue,
              originalTitle: originalTitleValue,
              outline: outlineValue,
              aired: airedValue,
              rating: ratingValue,
              runtime: runtimeValue,
              lastSynced: DateTime.now(),
            ),
          );
    }
  }

  @override
  Future<void> updateSeasonCount(int seasonId, int count) async {
    // NÃO sobrescreve isCompleted.
    await (_db.update(
      _db.pauloFlixSeasons,
    )..where((t) => t.id.equals(seasonId))).write(
      PauloFlixSeasonsCompanion(
        episodeCount: Value(count),
        lastSynced: Value(DateTime.now()),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Reconciliação (Fase 2)
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Future<List<int>> removeMissingSeasons({
    required int contentId,
    required Set<int> scrapedSeasonNumbers,
  }) async {
    // Busca seasons existentes (com episodeCount para diagnóstico).
    final existing = await (_db.select(
      _db.pauloFlixSeasons,
    )..where((t) => t.contentId.equals(contentId))).get();
    final removed = <int>[];
    for (final s in existing) {
      if (scrapedSeasonNumbers.contains(s.seasonNumber)) continue;
      // Verifica se tem progresso: se QUALQUER episode da season tem
      // positionSeconds > 0 ou isCompleted = true, MANTÉM.
      final hasProgress =
          await (_db.selectOnly(_db.pauloFlixEpisodes)
                ..addColumns([_db.pauloFlixEpisodes.id.count()])
                ..where(
                  _db.pauloFlixEpisodes.seasonId.equals(s.id) &
                      (_db.pauloFlixEpisodes.positionSeconds.isBiggerThanValue(
                            0,
                          ) |
                          _db.pauloFlixEpisodes.isCompleted.equals(true)),
                ))
              .map((row) => row.read(_db.pauloFlixEpisodes.id.count()) ?? 0)
              .getSingle();
      if (hasProgress > 0) {
        debugPrint(
          '[PauloFlixSync] Season ${s.seasonNumber} (id=${s.id}) '
          'ausente do scrape, mas tem progresso — MANTENDO.',
        );
        continue;
      }
      // Sem progresso — safe delete (cascade apaga os episodes).
      await (_db.delete(
        _db.pauloFlixSeasons,
      )..where((t) => t.id.equals(s.id))).go();
      removed.add(s.id);
      debugPrint(
        '[PauloFlixSync] Season ${s.seasonNumber} (id=${s.id}) '
        'ausente do scrape + sem progresso — REMOVIDA.',
      );
    }
    return removed;
  }

  @override
  Future<List<int>> removeMissingEpisodes({
    required int seasonId,
    required Set<int> scrapedEpisodeNumbers,
  }) async {
    final existing = await (_db.select(
      _db.pauloFlixEpisodes,
    )..where((t) => t.seasonId.equals(seasonId))).get();
    final removed = <int>[];
    for (final e in existing) {
      if (scrapedEpisodeNumbers.contains(e.episodeNumber)) continue;
      // Guarda de progresso: se tem position > 0 OU isCompleted, MANTÉM.
      if (e.positionSeconds > 0 || e.isCompleted) {
        debugPrint(
          '[PauloFlixSync] Episode ${e.episodeNumber} (id=${e.id}) '
          'ausente do scrape, mas tem progresso — MANTENDO.',
        );
        continue;
      }
      await (_db.delete(
        _db.pauloFlixEpisodes,
      )..where((t) => t.id.equals(e.id))).go();
      removed.add(e.id);
      debugPrint(
        '[PauloFlixSync] Episode ${e.episodeNumber} (id=${e.id}) '
        'ausente do scrape + sem progresso — REMOVIDO.',
      );
    }
    return removed;
  }

  @override
  Future<Set<int>> getSeasonNumbersForContent(int contentId) async {
    final rows =
        await (_db.selectOnly(_db.pauloFlixSeasons)
              ..addColumns([_db.pauloFlixSeasons.seasonNumber])
              ..where(_db.pauloFlixSeasons.contentId.equals(contentId)))
            .get();
    return rows.map((r) => r.read(_db.pauloFlixSeasons.seasonNumber)!).toSet();
  }

  @override
  Future<Set<int>> getEpisodeNumbersForSeason(int seasonId) async {
    final rows =
        await (_db.selectOnly(_db.pauloFlixEpisodes)
              ..addColumns([_db.pauloFlixEpisodes.episodeNumber])
              ..where(_db.pauloFlixEpisodes.seasonId.equals(seasonId)))
            .get();
    return rows
        .map((r) => r.read(_db.pauloFlixEpisodes.episodeNumber)!)
        .toSet();
  }

  // ─── Helpers internos ────────────────────────────────────────────────

  /// Recalcula `season.isCompleted` baseado nos episodes da season.
  /// `true` se TODOS os episodes estão completos (e há pelo menos 1).
  /// `false` caso contrário (incluindo season vazia).
  Future<void> _recomputeSeasonCompleted(int seasonId) async {
    final total =
        await (_db.selectOnly(_db.pauloFlixEpisodes)
              ..addColumns([_db.pauloFlixEpisodes.episodeNumber.count()])
              ..where(_db.pauloFlixEpisodes.seasonId.equals(seasonId)))
            .getSingle();
    final completed =
        await (_db.selectOnly(_db.pauloFlixEpisodes)
              ..addColumns([_db.pauloFlixEpisodes.episodeNumber.count()])
              ..where(
                _db.pauloFlixEpisodes.seasonId.equals(seasonId) &
                    _db.pauloFlixEpisodes.isCompleted.equals(true),
              ))
            .getSingle();
    final totalN = total.read(_db.pauloFlixEpisodes.episodeNumber.count()) ?? 0;
    final completedN =
        completed.read(_db.pauloFlixEpisodes.episodeNumber.count()) ?? 0;
    final allCompleted = totalN > 0 && totalN == completedN;
    await (_db.update(_db.pauloFlixSeasons)
          ..where((t) => t.id.equals(seasonId)))
        .write(PauloFlixSeasonsCompanion(isCompleted: Value(allCompleted)));
  }

  // ─── Mappers (DB → domain) ──────────────────────────────────────────

  PauloFlixSeasonRecord _toSeasonDomain(PauloFlixSeason row) {
    return PauloFlixSeasonRecord(
      id: row.id,
      contentId: row.contentId,
      seasonNumber: row.seasonNumber,
      displayName: row.displayName,
      folderName: row.folderName,
      description: row.description,
      posterFileName: row.posterFileName,
      fanartFileName: row.fanartFileName,
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
      description: row.description,
      thumbnailUrl: row.thumbnailUrl,
      durationSeconds: row.durationSeconds,
      positionSeconds: row.positionSeconds,
      isCompleted: row.isCompleted,
      lastWatched: row.lastWatched,
      lastSynced: row.lastSynced,
      // Schema V2 (Fase N+7): 5 campos扩idos.
      originalTitle: row.originalTitle,
      outline: row.outline,
      aired: row.aired,
      rating: row.rating,
      runtime: row.runtime,
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
