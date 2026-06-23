import '../../domain/models/pauloflix_content.dart';
import '../../domain/models/paulo_flix_episode_record.dart';
import '../../domain/models/paulo_flix_progress_stats.dart';
import '../../domain/models/paulo_flix_season_record.dart';

/// Contrato de persistência de seasons, episodes e progresso do PauloFlix.
///
/// **Fase 1.2 do plano** `.hermes/plans/2026-06-22_2230-pauloflix-episodes-progress.md`.
///
/// Encapsula Drift (impl em `data/repositories/`) e devolve models de
/// domínio (`PauloFlixSeasonRecord`, `PauloFlixEpisodeRecord`,
/// `PauloFlixProgressStats`). A UI consome Streams reativas para a
/// home "Continue assistindo" atualizar sem polling.
///
/// ## Decisões aplicadas
///
/// - **Decisão 6 (reassistir):** `resetProgress` zera posição + isCompleted
///   E recalcula `season.isCompleted` (cascade).
/// - **Decisão 7 (sem flag de anime):** `getStatsForContent` computa
///   `PauloFlixProgressStats` em runtime via 1 query agregada.
/// - **Decisão 8 (Continue assistindo):** `getInProgressContents` e
///   `watchInProgressContents` filtram animes com episodes parciais.
abstract class PauloFlixEpisodeProgressRepository {
  // ═══════════════════════════════════════════════════════════════════════
  // Progresso de episódio (chamado pelo player a cada 5s + dispose)
  // ═══════════════════════════════════════════════════════════════════════

  /// Grava o progresso atual do episódio e atualiza `lastWatched`.
  ///
  /// Side effects:
  /// - Se `positionSeconds / durationSeconds >= 0.9`: marca
  ///   `episode.isCompleted = true` E recalcula
  ///   `season.isCompleted` (pode virar `true` se todos os episodes
  ///   da season estiverem completos).
  /// - Se ratio < 0.9: não toca em `isCompleted` (preserva o valor
  ///   anterior; o user pode ter parado em 80%, ter saido, e na próxima
  ///   vez o player faz resume — `isCompleted` continua `false`).
  ///
  /// [durationSeconds] pode ser `null` (primeiro save antes do player
  /// descobrir a duração do vídeo). Nesse caso, NÃO marca como completo.
  Future<void> updateProgress({
    required int seasonId,
    required int episodeNumber,
    required int positionSeconds,
    int? durationSeconds,
  });

  /// Limpa o progresso de um episódio (decisão 6 — usado quando o user
  /// reassiste um episódio completo ou que mal começou).
  ///
  /// Zera `positionSeconds=0` E `isCompleted=false`, depois recalcula
  /// `season.isCompleted` (pode virar `false` se este era o último
  /// episode completo da season — bug fix do plano).
  Future<void> resetProgress({
    required int seasonId,
    required int episodeNumber,
  });

  /// Estatísticas agregadas do anime (decisão 7 — sem flag persistida).
  /// Retorna zeros se o anime ainda não tem episodes sincronizados.
  Future<PauloFlixProgressStats> getStatsForContent(int contentId);

  // ═══════════════════════════════════════════════════════════════════════
  // Continue assistindo (decisão 8 — home + see all)
  // ═══════════════════════════════════════════════════════════════════════

  /// Lista animes com progresso em andamento, ordenados por
  /// `MAX(episode.lastWatched) DESC`. Limite 12 por padrão.
  ///
  /// Filtra: `episode.positionSeconds > 0 && !episode.isCompleted`.
  Future<List<PauloFlixContent>> getInProgressContents({int limit = 12});

  /// Stream reativo da lista de animes em andamento. Aciona ao
  /// adicionar/resetar/assistir episódios.
  Stream<List<PauloFlixContent>> watchInProgressContents({int limit = 12});

  // ═══════════════════════════════════════════════════════════════════════
  // CRUD de seasons (lido pela tela de episodes)
  // ═══════════════════════════════════════════════════════════════════════

  /// Lista seasons de um content, ordenadas por `seasonNumber` ASC.
  Future<List<PauloFlixSeasonRecord>> getSeasonsForContent(int contentId);

  /// Stream reativo das seasons de um content.
  Stream<List<PauloFlixSeasonRecord>> watchSeasonsForContent(int contentId);

  // ═══════════════════════════════════════════════════════════════════════
  // CRUD de episodes (lido pela tela de episodes)
  // ═══════════════════════════════════════════════════════════════════════

  /// Lista episodes de uma season, ordenados por `episodeNumber` ASC.
  Future<List<PauloFlixEpisodeRecord>> getEpisodesForSeason(int seasonId);

  /// Stream reativo dos episodes de uma season.
  Stream<List<PauloFlixEpisodeRecord>> watchEpisodesForSeason(int seasonId);

  // ═══════════════════════════════════════════════════════════════════════
  // Sync on-demand (chamado pela tela de episodes ao abrir)
  // ═══════════════════════════════════════════════════════════════════════

  /// Sincroniza seasons + episodes do servidor PauloFlix para o banco.
  ///
  /// Comportamento:
  /// 1. Faz fetch HTTP das seasons via `PauloFlixService.fetchShowSeasons`.
  /// 2. Para cada season: upsert (se já existe, atualiza `displayName`/
  ///    `folderName`/`lastSynced` MAS **preserva** `isCompleted` e
  ///    `episodeCount`).
  /// 3. Para cada season: fetch HTTP dos episodes via
  ///    `PauloFlixService.fetchSeasonEpisodes`.
  /// 4. Para cada episode: upsert (atualiza `title`/`videoUrl`/
  ///    `lastSynced` MAS **preserva** `positionSeconds`/`isCompleted`/
  ///    `lastWatched`/`durationSeconds`).
  /// 5. Atualiza `episodeCount` da season com `episodes.length`.
  ///
  /// Lança exceção se a rede falhar (caller decide se mostra erro ou
  /// usa seasons/episodes já em cache).
  Future<void> syncSeasonEpisodes({
    required int contentId,
    required String contentServerUrl,
  });
}
