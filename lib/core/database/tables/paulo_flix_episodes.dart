import 'package:drift/drift.dart';

import 'paulo_flix_seasons.dart';

/// Tabela de episódios dos animes PauloFlix (file server local).
///
/// ## Por que uma tabela separada (em vez de JSON em `paulo_flix_seasons`)
///
/// Mesma justificativa da season: FK cascade, watch stream reativo,
/// queries eficientes para "Continue assistindo" (busca por
/// `positionSeconds > 0` direto).
///
/// ## `positionSeconds` é a fonte de verdade do "continuar de onde parou"
///
/// - Salvo a cada 5s pelo `EpisodeProgressRecorder` durante playback.
/// - Flush no `dispose` do player (garante último save).
/// - Resetado pelo `prepareResumeOrReset` quando o user reassiste um
///   episódio completo ou que mal começou (heurística 10%/90% — decisão 6).
///
/// ## `isCompleted` é flag derivada
///
/// Marcada `true` quando `positionSeconds / durationSeconds >= 0.9`
/// durante `updateProgress` (com duration conhecida). Resetada junto com
/// `positionSeconds` no `resetProgress`.
///
/// ## `lastWatched` é updated a cada save
///
/// Usado pelo `getInProgressContents` para ordenar a home (mais recente
/// primeiro) e pelo `watchInProgressContents` para emitir quando muda.
///
/// ## `uniqueKeys: [seasonId, episodeNumber]`
///
/// Permite re-sync sem duplicar: scrape do mesmo ep 2x = mesma linha,
/// atualizada (MAS `positionSeconds`/`isCompleted` são preservados —
/// ver `syncSeasonEpisodes` no repository).
class PauloFlixEpisodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get seasonId => integer().references(
        PauloFlixSeasons,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get episodeNumber => integer()();
  TextColumn get title => text()();
  TextColumn get videoUrl => text()();

  /// URL absoluta do thumbnail do episode (servidor PauloFlix).
  /// Populada pelo `PauloFlixNfoEnricher` durante o sync, lendo o
  /// padrão Kodi `S01E001-thumb.jpg` na pasta da season.
  ///
  /// Nullable porque:
  /// 1. Pasta de season pode não ter thumb (mostra placeholder).
  /// 2. Sync antigo não populou este campo (migração v5→v6 adicionou
  ///    a coluna mas rows antigos ficam com null).
  TextColumn get thumbnailUrl => text().nullable()();

  /// Descrição/plot do episode (do `S01E001.nfo`).
  ///
  /// Fase 10 do plano `.hermes/plans/2026-06-23_225500-pauloflix-nfo-enrichment-v2.md`.
  /// Nullable porque nem todo episode tem NFO — quando ausente, o
  /// caller cai no fallback TMDB/Jikan (status quo).
  TextColumn get description => text().nullable()();

  /// Duração total do vídeo em segundos. Populada pelo player em runtime
  /// (vem do `Player.state.duration`). Nullable porque a primeira sync
  /// HTTP não tem essa info (vem do scraping HTML, sem metadata).
  IntColumn get durationSeconds => integer().nullable()();

  /// Posição atual do playback em segundos. Default 0 = nunca assistido.
  IntColumn get positionSeconds =>
      integer().withDefault(const Constant(0))();

  /// Flag derivada: true quando positionSeconds/durationSeconds >= 0.9.
  BoolColumn get isCompleted =>
      boolean().withDefault(const Constant(false))();

  /// Timestamp do último save de progresso. Null = nunca assistido.
  /// Atualizado a cada `updateProgress` e a cada `resetProgress` (vira null).
  DateTimeColumn get lastWatched => dateTime().nullable()();

  DateTimeColumn get lastSynced => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {seasonId, episodeNumber},
      ];
}
