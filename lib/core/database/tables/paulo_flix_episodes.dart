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
///  /// ## `uniqueKeys: [seasonId, episodeNumber]`
  ///
  /// Permite re-sync sem duplicar: scrape do mesmo ep 2x = mesma linha,
  /// atualizada (MAS `positionSeconds`/`isCompleted` são preservados —
  /// ver `PauloFlixService.syncContent` no repository).
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
  /// Populada pelo `PauloFlixService.syncContent` durante o sync,
  /// lendo o campo `thumb` do JSON index.
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

  /// Título original do episode (idioma da produção).
  ///
  /// **Fase N+7 —扩e schema NFO V2:** vem de `<originaltitle>` no
  /// `S\d+E\d+\.nfo`. Útil para animes dublados — o `title` pode
  /// ser a versão PT-BR e o `originalTitle` o japonês.
  ///
  /// Migração v8→v9 adicionou a coluna mas rows antigos ficam
  /// com `null` (não re-raspamos retroativamente).
  TextColumn get originalTitle => text().nullable()();

  /// Resumo curto do episode (1-2 frases).
  ///
  /// **Fase N+7 —扩e schema NFO V2:** vem de `<outline>` no
  /// `S\d+E\d+\.nfo`. Usado em cards/listas quando `description`
  /// (plot completo) é longo demais.
  ///
  /// Migração v8→v9 adicionou a coluna mas rows antigos ficam
  /// com `null`.
  TextColumn get outline => text().nullable()();

  /// Data de estreia do episode.
  ///
  /// **Fase N+7 —扩e schema NFO V2:** vem de `<aired>` no
  /// `S\d+E\d+\.nfo` (formato `YYYY-MM-DD`). Nullable porque
  /// NFOs antigos não têm e séries em produção podem não ter
  /// data final. Armazenado como epoch seconds (INTEGER no
  /// SQLite, conversão automática via Drift).
  ///
  /// Migração v8→v9 adicionou a coluna mas rows antigos ficam
  /// com `null`.
  DateTimeColumn get aired => dateTime().nullable()();

  /// Rating / nota do episode (0.0-10.0).
  ///
  /// **Fase N+7 —扩e:** vem do campo `nfo.rating` no JSON index.
  /// Diferente do rating da série inteira — este é a nota do episode
  /// específico.
  ///
  /// Migração v8→v9 adicionou a coluna mas rows antigos ficam
  /// com `null`.
  RealColumn get rating => real().nullable()();

  /// Duração do episode em minutos (NFO usa minutos, não segundos).
  ///
  /// **Fase N+7 —扩e schema NFO V2:** vem de `<runtime>` no
  /// `S\d+E\d+\.nfo` (ex: `47` = 47 min). Complementa
  /// `durationSeconds` (que é populado em runtime pelo player)
  /// — este é a duração do NFO (sem precisar abrir o vídeo).
  ///
  /// Migração v8→v9 adicionou a coluna mas rows antigos ficam
  /// com `null`.
  IntColumn get runtime => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {seasonId, episodeNumber},
      ];
}
