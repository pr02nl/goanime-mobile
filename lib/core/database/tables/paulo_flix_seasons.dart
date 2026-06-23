import 'package:drift/drift.dart';

import 'pauloflix_content.dart';

/// Tabela de seasons dos animes PauloFlix (file server local).
///
/// ## Por que uma tabela separada (em vez de JSON em `paulo_flix_content`)
///
/// - Permite queries reativas com `watchSeasonsForContent(contentId)` para a
///   UI acompanhar mudanças (Fase 5 — "Continue assistindo" depende disso).
/// - Foreign key cascade: apagar um content apaga seasons e episodes junto.
/// - Permite indexar `seasonNumber` para `getInProgressContents` ordenado.
///
/// ## `uniqueKeys: [contentId, seasonNumber]`
///
/// O mesmo content pode ter 1 season 1 — chaves compostas impedem duplicatas
/// em re-syncs (mesma temporada scrapeada 2x = mesma linha, atualizada).
///
/// ## `isCompleted` é flag derivada
///
/// Atualizada por `_recomputeSeasonCompleted(seasonId)` dentro do repository
/// sempre que um episódio muda de estado (insert/update/reset). Não é
/// editada diretamente — sempre vai de `false → true` (ou vice-versa) via
/// recompute.
///
/// ## `episodeCount` é denormalizado propositalmente
///
/// Cache de `COUNT(episodes)` para evitar JOIN na UI. Atualizado no
/// `syncSeasonEpisodes` após o upsert dos episodes.
class PauloFlixSeasons extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contentId => integer().references(
        PauloFlixContent,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get seasonNumber => integer()();

  /// Nome legível (ex.: "Season 01", "S01", "Temporada 1").
  TextColumn get displayName => text()();

  /// Nome da pasta como veio do servidor (raw, sem decode).
  /// Preserva o identificador único da season no file server.
  TextColumn get folderName => text()();

  /// Cache de `COUNT(episodes)` — evita JOIN ao listar seasons.
  IntColumn get episodeCount =>
      integer().withDefault(const Constant(0))();

  /// Flag derivada: true quando TODOS os episodes desta season
  /// têm `isCompleted = true`. Mantida por `_recomputeSeasonCompleted`.
  BoolColumn get isCompleted =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get lastSynced => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {contentId, seasonNumber},
      ];
}
