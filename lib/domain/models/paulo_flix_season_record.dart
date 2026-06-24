/// Record de banco de uma season PauloFlix.
///
/// **Por que `PauloFlixSeasonRecord` (e não `PauloFlixSeason`)?**
///
/// Já existe um `PauloFlixSeason` em `lib/domain/models/pauloflix_models.dart`
/// que é o **model de scraping HTTP** (campos: `name`, `url`, `number`).
/// O `PauloFlixSeasonRecord` é o **model de persistência** (campos: `id`,
/// `contentId`, `seasonNumber`, `episodeCount`, `isCompleted`, etc).
///
/// Manter nomes distintos evita imports ambíguos e reflete a semântica:
/// - `PauloFlixSeason` (em `pauloflix_models.dart`) = "dados que vierem do
///   servidor HTTP"
/// - `PauloFlixSeasonRecord` (neste arquivo) = "linha persistida no banco"
///
/// Os 2 models são convertidos pelo repository (Fase 1.3 do plano
/// `.hermes/plans/2026-06-22_2230-pauloflix-episodes-progress.md`).
class PauloFlixSeasonRecord {
  /// PK no banco (Drift autoIncrement). Null quando o record ainda não
  /// foi inserido (uso futuro pelo service para "preparar" antes de
  /// inserir).
  final int? id;

  /// FK para `paulo_flix_content.id`. Cascade on delete: apagar o anime
  /// apaga as seasons (e episodes por cascata em chain).
  final int contentId;

  /// Número da temporada (1, 2, 3...). Único dentro de um mesmo content
  /// (`uniqueKeys: [contentId, seasonNumber]`).
  final int seasonNumber;

  /// Nome legível (ex.: "Season 01", "S01 - East Blue", "Temporada 1").
  final String displayName;

  /// Nome da pasta como veio do servidor. Preserva o identificador único
  /// da season no file server (raw, sem decode HTML).
  final String folderName;

  /// Descrição / plot da season. Vem de `season.nfo` (Fase 10 do
  /// plano NFO enrichment V2). Nullable porque:
  /// 1. Nem toda season tem `season.nfo` (cair em fallback TMDB/Jikan).
  /// 2. Migração v6→v7 adicionou a coluna, mas rows antigos ficam
  ///    com `null` (não re-raspamos retroativamente).
  final String? description;

  /// Cache de `COUNT(episodes)` — atualizado pelo
  /// `syncSeasonEpisodes` após o upsert dos episodes.
  /// Default 0 (season recém-inserida ainda sem episodes).
  final int episodeCount;

  /// Flag **derivada**: `true` quando TODOS os episodes desta season
  /// têm `isCompleted = true`. Mantida por `_recomputeSeasonCompleted`
  /// no repositório, **nunca** editada diretamente.
  /// Default `false` (season nova = nenhum episode completo).
  final bool isCompleted;

  /// Timestamp do último sync HTTP (scraping das seasons + episodes).
  final DateTime lastSynced;

  PauloFlixSeasonRecord({
    this.id,
    required this.contentId,
    required this.seasonNumber,
    required this.displayName,
    required this.folderName,
    this.description,
    this.episodeCount = 0,
    this.isCompleted = false,
    required this.lastSynced,
  });

  /// Equality por chave de negócio `(contentId, seasonNumber)` — não por
  /// `id`. Justificativa: o mesmo `id` pode mudar entre syncs (mesma
  /// season re-scrapada = mesma linha atualizada). Mas (content, season)
  /// é a identidade semântica.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PauloFlixSeasonRecord &&
          contentId == other.contentId &&
          seasonNumber == other.seasonNumber;

  @override
  int get hashCode => Object.hash(contentId, seasonNumber);

  @override
  String toString() =>
      'PauloFlixSeasonRecord(id: $id, contentId: $contentId, '
      'seasonNumber: $seasonNumber, displayName: $displayName, '
      'episodeCount: $episodeCount, isCompleted: $isCompleted)';
}
