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
  // Upserts de baixo nível (usados pelo PauloFlixEpisodeSyncService)
  // ═══════════════════════════════════════════════════════════════════════

  /// Insere ou atualiza uma season. Se já existir (mesmo
  /// `contentId+seasonNumber`), atualiza `displayName`/`folderName`/
  /// `description`/`lastSynced` mas **preserva** `isCompleted` e
  /// `episodeCount`.
  ///
  /// [seasonDescription] é o plot lido de `season.nfo` (Fase 10 do
  /// plano NFO enrichment V2). Quando `null`, o campo `description`
  /// no banco NÃO é tocado (preserva valor anterior). Para sobrescrever
  /// com null explícito, ver [PauloFlixEpisodeProgressRepositoryImpl].
  ///
  /// Chamado por `PauloFlixEpisodeSyncService` durante o sync on-demand.
  Future<int> upsertSeason({
    required int contentId,
    required int seasonNumber,
    required String displayName,
    required String folderName,
    String? seasonDescription,
    /// Nome do arquivo `poster.jpg` (ou similar) na pasta da
    /// season. Nullable = sem NFO/JPG detectado. Usado como fallback
    /// no `PauloFlixContent.bannerUrl` quando o `season.nfo` não
    /// tem `<thumb>`.
    String? posterFileName,
    /// Nome do arquivo `fanart.jpg` (ou `banner.jpg`) na pasta.
    /// Mesmo rationale do [posterFileName].
    String? fanartFileName,
  });

  /// Insere ou atualiza um episode. Se já existir (mesmo
  /// `seasonId+episodeNumber`), atualiza `title`/`videoUrl`/
  /// `thumbnailUrl` (quando fornecido)/`description` (quando
  /// fornecido)/`lastSynced` mas **preserva** `positionSeconds`/
  /// `isCompleted`/`lastWatched`/`durationSeconds`.
  ///
  /// **Semântica de [thumbnailUrl]:**
  /// - `null` (default) = NÃO atualiza a coluna (preserva valor
  ///   anterior). Use este valor quando o enricher não tem info de
  ///   thumb (HTTP 404, listing vazio, enricher não injetado).
  /// - Valor não-nulo = sobrescreve a coluna com a URL informada.
  ///   Se o server tinha thumb e foi removido, o enricher reportará
  ///   a ausência via mapa vazio e o repo não tocará na coluna.
  ///
  /// **Semântica de [description] (Fase 10 do NFO enrichment V2):**
  /// - `null` (default) = NÃO atualiza a coluna (preserva valor
  ///   anterior). Use este valor quando o enricher não tem info de
  ///   NFO (HTTP 404, parser fail, enricher não injetado).
  /// - Valor não-nulo = sobrescreve a coluna com a plot informada.
  ///   Se o server tinha NFO e foi removido, o enricher reportará
  ///   a ausência via mapa com `plot = null` e o repo não tocará
  ///   na coluna.
  ///
  /// Chamado por `PauloFlixEpisodeSyncService` durante o sync on-demand.
  Future<void> upsertEpisode({
    required int seasonId,
    required int episodeNumber,
    required String title,
    required String videoUrl,
    String? thumbnailUrl,
    String? description,
  });

  /// Atualiza `episodeCount` e `lastSynced` da season.
  ///
  /// **NÃO** sobrescreve `isCompleted` (preservado).
  /// Chamado por `PauloFlixEpisodeSyncService` após o upsert dos
  /// episodes para persistir o total descoberto.
  Future<void> updateSeasonCount(int seasonId, int count);

  // ═══════════════════════════════════════════════════════════════════════
  // Reconciliação (chamado pelo sync geral — Fase 2)
  // ═══════════════════════════════════════════════════════════════════════

  /// Remove seasons que **não** estão em [scrapedSeasonNumbers] (lista
  /// de seasonNumbers raspadas do servidor).
  ///
  /// **Política de segurança**: só remove seasons **sem episodes com
  /// progresso** (`positionSeconds > 0 || isCompleted`). Se a season
  /// tem progresso, ela é **mantida** com `episodeCount=0` e removida
  /// do "scrape atual" — o usuário pode recuperá-la em sincronizações
  /// futuras se o servidor trouxer de volta.
  ///
  /// Retorna a lista de seasonIds efetivamente removidos (para log).
  Future<List<int>> removeMissingSeasons({
    required int contentId,
    required Set<int> scrapedSeasonNumbers,
  });

  /// Remove episodes que **não** estão em [scrapedEpisodeNumbers]
  /// (lista de episodeNumbers raspados do servidor).
  ///
  /// **Política de segurança**: só remove episodes com
  /// `positionSeconds == 0 && isCompleted == false`. Se o episode tem
  /// qualquer progresso do usuário, é mantido — o servidor pode ter
  /// tido hiccup e o episode voltar na próxima sync.
  ///
  /// Retorna a lista de episodeIds efetivamente removidos (para log).
  Future<List<int>> removeMissingEpisodes({
    required int seasonId,
    required Set<int> scrapedEpisodeNumbers,
  });

  /// Lista os `seasonNumber` existentes para um content (sem HTTP).
  /// Usado pelo sync geral para construir o diff.
  Future<Set<int>> getSeasonNumbersForContent(int contentId);

  /// Lista os `episodeNumber` existentes para uma season (sem HTTP).
  /// Usado pelo sync geral para construir o diff.
  Future<Set<int>> getEpisodeNumbersForSeason(int seasonId);
}
