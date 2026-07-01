/// Record de banco de um episódio PauloFlix.
///
/// **Por que `PauloFlixEpisodeRecord` (e não `PauloFlixEpisode`)?**
///
/// Mesma justificativa do `PauloFlixSeasonRecord`: já existe um
/// `PauloFlixEpisode` em `lib/domain/models/pauloflix_models.dart` que é
/// o **model de scraping HTTP** (campos: `number`, `title`, `url`,
/// `fileSize`). O `PauloFlixEpisodeRecord` é o **model de persistência**
/// (campos: `id`, `seasonId`, `positionSeconds`, `isCompleted`,
/// `lastWatched`).
///
/// São modelos com **propósitos** diferentes:
/// - `PauloFlixEpisode` (em `pauloflix_models.dart`) = "dados que vierem
///   do servidor HTTP no scraping de uma season"
/// - `PauloFlixEpisodeRecord` (neste arquivo) = "linha persistida no banco
///   com o histórico de progresso do usuário"
///
/// Os 2 são convertidos pelo repository (Fase 1.3 do plano
/// `.hermes/plans/2026-06-22_2230-pauloflix-episodes-progress.md`).
class PauloFlixEpisodeRecord {
  /// PK no banco (Drift autoIncrement). Null quando o record ainda não
  /// foi inserido.
  final int? id;

  /// FK para `paulo_flix_seasons.id`. Cascade on delete: apagar a season
  /// apaga os episodes.
  final int seasonId;

  /// Número do episódio dentro da season (1, 2, 3...).
  /// Único dentro de uma mesma season (`uniqueKeys: [seasonId, episodeNumber]`).
  final int episodeNumber;

  /// Título do episódio (exibido na UI).
  final String title;

  /// URL absoluta do vídeo no file server PauloFlix.
  final String videoUrl;

  /// Descrição / plot do episode. Vem de `S01E{nnn}.nfo` (Fase 10 do
  /// plano NFO enrichment V2). Nullable porque:
  /// 1. Nem todo episode tem NFO individual (cair em fallback TMDB).
  /// 2. Migração v6→v7 adicionou a coluna, mas rows antigos ficam
  ///    com `null` (não re-raspamos retroativamente).
  final String? description;

  /// URL absoluta do thumbnail do episode (servidor PauloFlix).
  /// Populada pelo `PauloFlixService.syncContent` durante o sync,
  /// lendo o campo `thumb` do JSON index.
  ///
  /// **Nullable** porque:
  /// 1. Pasta de season pode não ter thumb (mostra placeholder na UI).
  /// 2. Sync antigo não populou este campo (migração v5→v6 adicionou
  ///    a coluna, mas rows antigos ficam com `null`).
  final String? thumbnailUrl;

  /// Duração total do vídeo em segundos. **Nullable** porque a primeira
  /// sync HTTP não tem essa info (vem do scraping HTML, sem metadata).
  /// É populada pelo player em runtime via `Player.state.duration`.
  final int? durationSeconds;

  /// Posição atual do playback em segundos. Default 0 (nunca assistido).
  ///
  /// - Salvo a cada 5s pelo `EpisodeProgressRecorder` durante playback.
  /// - Flush no `dispose` do player (garante último save).
  /// - Resetado pelo `prepareResumeOrReset` quando o user reassiste
  ///   (decisão 6: `isCompleted=true` ou `position/duration < 0.1`).
  final int positionSeconds;

  /// Flag **derivada**: `true` quando `positionSeconds / durationSeconds >= 0.9`.
  /// Mantida por `updateProgress` no repository. Resetada junto com
  /// `positionSeconds` no `resetProgress`.
  final bool isCompleted;

  /// Timestamp do último save de progresso. Null = nunca assistido.
  /// Usado pelo `getInProgressContents` para ordenar a home por
  /// "mais recente primeiro" (decisão 8).
  final DateTime? lastWatched;

  /// Timestamp do último sync HTTP (scraping do episode).
  final DateTime lastSynced;

  /// Título original do episode (idioma da produção).
  ///
  /// **Fase N+7 —扩e schema NFO V2:** vem de `<originaltitle>` no
  /// `S\d+E\d+\.nfo`. Nullable porque NFOs antigos não têm.
  final String? originalTitle;

  /// Resumo curto do episode (1-2 frases).
  ///
  /// **Fase N+7 —扩e schema NFO V2:** vem de `<outline>` no
  /// `S\d+E\d+\.nfo`. Nullable porque NFOs antigos não têm.
  final String? outline;

  /// Data de estreia do episode.
  ///
  /// **Fase N+7 —扩e schema NFO V2:** vem de `<aired>` no
  /// `S\d+E\d+\.nfo` (formato `YYYY-MM-DD`). Nullable porque
  /// NFOs antigos não têm.
  final DateTime? aired;

  /// Rating / nota do episode (0.0-10.0).
  ///
  /// **Fase N+7 —扩e schema NFO V2:** vem de `<rating>` no
  /// `S\d+E\d+\.nfo`. Nullable porque NFOs antigos não têm.
  final double? rating;

  /// Duração do episode em minutos (NFO usa minutos).
  ///
  /// **Fase N+7 —扩e schema NFO V2:** vem de `<runtime>` no
  /// `S\d+E\d+\.nfo`. Nullable porque NFOs antigos não têm.
  final int? runtime;

  PauloFlixEpisodeRecord({
    this.id,
    required this.seasonId,
    required this.episodeNumber,
    required this.title,
    required this.videoUrl,
    this.description,
    this.thumbnailUrl,
    this.durationSeconds,
    this.positionSeconds = 0,
    this.isCompleted = false,
    this.lastWatched,
    required this.lastSynced,
    this.originalTitle,
    this.outline,
    this.aired,
    this.rating,
    this.runtime,
  });

  /// Progresso do episódio como fração 0.0 (nenhum) a 1.0 (completo).
  ///
  /// Retorna 0.0 quando:
  /// - `durationSeconds` é null (ainda não foi descoberto pelo player)
  /// - `durationSeconds` é 0 (divisão por zero → defensivo)
  /// - `positionSeconds` é 0
  ///
  /// **NUNCA** retorna valor > 1.0: se `position >= duration` (clock
  /// drift, seek manual, ou save após fim), clamp para 1.0 para não
  /// quebrar a heurística de 90% na UI.
  double get progressRatio {
    final dur = durationSeconds;
    if (dur == null || dur <= 0) return 0.0;
    final ratio = positionSeconds / dur;
    return ratio > 1.0 ? 1.0 : ratio;
  }

  /// Equality por chave de negócio `(seasonId, episodeNumber)` — não por
  /// `id`. Justificativa: o mesmo id pode mudar entre syncs (mesmo
  /// episode re-scrapado = mesma linha atualizada). Mas (season,
  /// episode) é a identidade semântica.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PauloFlixEpisodeRecord &&
          seasonId == other.seasonId &&
          episodeNumber == other.episodeNumber;

  @override
  int get hashCode => Object.hash(seasonId, episodeNumber);

  @override
  String toString() =>
      'PauloFlixEpisodeRecord(id: $id, seasonId: $seasonId, '
      'episodeNumber: $episodeNumber, title: $title, '
      'positionSeconds: $positionSeconds, isCompleted: $isCompleted)';
}
