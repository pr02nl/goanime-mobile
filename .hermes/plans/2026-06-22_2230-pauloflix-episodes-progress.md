# PauloFlix — Persistência de Séries, Episódios e Progresso

> **Para Hermes:** Usar a skill `flutter-development` + `test-driven-development` para implementar task-by-task. Cada patch passa pelo triade de validação `flutter analyze` + `dart fix --apply` + `flutter test` antes de seguir.

**Goal:** Persistir, no banco local Drift, as informações de **seasons**, **episódios assistidos**, **tempo assistido** e **flag de temporada completa** para o módulo PauloFlix animes, habilitando "continuar de onde parou" e "temporada concluída" no carrossel/grid de episódios.

**Architecture:** Adicionar 2 tabelas novas ao `AppDatabase` (Drift): `paulo_flix_seasons` e `paulo_flix_episodes`. Cada episódio persiste `positionSeconds` (tempo assistido) e `isCompleted` (≥90% do vídeo). Temporada expõe `isCompleted` agregado. A UI lê do banco reativamente (`Stream.watch`) e o player chama um `EpisodeProgressService` para gravar progresso a cada 5s + ao sair (dispose). Migração v4→v5 (Drift) é puramente aditiva — sem perda de dados.

**Tech Stack:** Drift 2.22.1, Provider 6.1.5, media_kit 1.2.6, `StreamSubscription` para progresso periódico.

---

## Decisões validadas com o usuário

✅ **Decisão 1 (fonte primária):** Sincronização de seasons/episodes acontece no momento em que o usuário abre a tela de episódios — não durante o `syncContent` (que varre shows em batch, é pesado demais para listar episódios de todos). Sync on-demand = tempo assistido só dos shows que o usuário abriu.
✅ **Decisão 2 (granularidade):** Tempo assistido é salvo por **episódio** (1 linha por episódio). Temporada é **flag derivada** (soma: temporada completa = todos os episódios `isCompleted = true`).
✅ **Decisão 3 (heurística de "completo"):** Episódio é considerado completo quando `positionSeconds / durationSeconds >= 0.9` (90%). Marcado no dispose do player se atingido, e mantido no `positionTimer` para gravações periódicas.
✅ **Decisão 4 (não tocar movies):** Apenas animes (PauloFlix). Filmes (PauloFlixMovies) já têm watchlist mas não progresso — fora do escopo desta feature.
✅ **Decisão 5 (frequência de gravação):** Position salva a cada 5s durante reprodução + 1 vez ao sair (dispose) + 1 vez ao completar. Evitar write em cada frame.

✅ **Decisão 6 (reassistir episódio completo):** Heurística **sem dialog** ("Continuar vs Reassistir") — UX direta, sem fricção.
- **Reset para zero** se: `isCompleted = true` **OU** `positionSeconds / durationSeconds < 0.1` (provavelmente fechou sem querer).
- **Retomar de `positionSeconds`** se: 10% ≤ progresso < 90% (parou intencionalmente).
- Aplica-se **no momento do `Media.open`** — antes de abrir, decidir reset vs retomar. Se reset, limpar `positionSeconds=0` + `isCompleted=false` no banco.
- **Side effect crítico:** `resetProgress` **deve** disparar `_recomputeSeasonCompleted(seasonId)`, senão a flag `season.isCompleted` fica stale quando o user reassiste o último episódio completo de uma season.

✅ **Decisão 7 (flag de "anime completo"):** **Sem flag** na tabela `paulo_flix_content`. Computar em runtime via `repo.getStatsForContent(contentId)` que retorna um `PauloFlixProgressStats` (totalEpisodes, completedEpisodes, inProgressEpisodes, progressRatio). Justificativa: derivar de episodes é barato (1 query) e evita inconsistência de 2 flags cascateadas.

✅ **Decisão 8 (seção "Em andamento"):** Carrossel **"Continue assistindo"** no TOPO da home (acima dos carrosséis de gênero) + repetido no topo da `PauloFlixSeeAllScreen`. Lista até 12 animes com pelo menos 1 episódio parcialmente assistido (`positionSeconds > 0 && !isCompleted`), ordenados por `MAX(episode.lastWatched) DESC`. Card mostra capa do anime + barra de progresso global (`completedEpisodes / totalEpisodes`).

---

## Estrutura de arquivos (antes de implementar)

### Novos arquivos

```
lib/
├── core/database/tables/
│   ├── paulo_flix_seasons.dart          # NOVO — tabela de seasons
│   └── paulo_flix_episodes.dart         # NOVO — tabela de episódios + progresso
├── domain/
│   ├── models/
│   │   ├── paulo_flix_season.dart       # NOVO — domain model (sem Drift)
│   │   └── paulo_flix_episode.dart      # NOVO — domain model
│   └── repositories/
│       └── paulo_flix_episode_progress_repository.dart  # NOVO
├── data/
│   ├── repositories/
│   │   └── paulo_flix_episode_progress_repository_impl.dart  # NOVO (Drift)
│   └── services/
│       └── paulo_flix_episode_sync_service.dart  # NOVO — sync on-demand de seasons/episodes
├── ui/pauloflix/view_models/
│   ├── paulo_flix_episode_progress_viewmodel.dart  # NOVO — wrapper de UI
│   └── paulo_flix_continue_watching_viewmodel.dart # NOVO — Home/See All
└── ui/player/services/
└── episode_progress_recorder.dart  # NOVO — grava progresso no player
```

### Arquivos modificados

```
lib/
├── core/database/app_database.dart       # Add tabelas + bump schemaVersion para 5
├── data/services/pauloflix_service.dart  # Adicionar fetchSeasonsAndEpisodes para sync on-demand
├── ui/player/widgets/video_player_screen.dart  # Wire EpisodeProgressRecorder
├── ui/pauloflix/view_models/pauloflix_episode_list_viewmodel.dart  # Carregar do banco
├── ui/pauloflix/widgets/pauloflix_episode_list_screen.dart  # Mostrar status (assistido/continuar/temporada completa)
├── ui/pauloflix/widgets/pauloflix_episode_card.dart  # Indicador de progresso
├── ui/pauloflix/widgets/pauloflix_season_selector.dart  # Badge de temporada completa
├── app.dart  # Provider novo
├── ui/pauloflix/widgets/pauloflix_continue_watching_section.dart  # NOVO — carrossel
├── ui/home/widgets/home_screen.dart  # Adicionar carrossel "Continue assistindo" no topo
└── ui/pauloflix/widgets/pauloflix_see_all_screen.dart  # Adicionar carrossel no topo
```

### Novos testes

```
test/
├── core/database/tables/
│   ├── paulo_flix_seasons_test.dart
│   └── paulo_flix_episodes_test.dart
├── data/repositories/
│   └── paulo_flix_episode_progress_repository_test.dart
├── data/services/
│   └── paulo_flix_episode_sync_service_test.dart
├── ui/pauloflix/view_models/
│   └── paulo_flix_episode_progress_viewmodel_test.dart
├── ui/player/services/
│   └── episode_progress_recorder_test.dart
├── ui/pauloflix/widgets/
│   ├── paulo_flix_continue_watching_section_test.dart  # NOVO
│   ├── paulo_flix_episode_card_test.dart
│   └── paulo_flix_season_selector_test.dart
└── domain/models/
    └── paulo_flix_progress_stats_test.dart  # NOVO
```

---

## Algoritmos críticos

### 1. Schema Drift v5

```dart
// lib/core/database/tables/paulo_flix_seasons.dart
class PauloFlixSeasons extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contentId =>
      integer().references(PauloFlixContent, #id, onDelete: KeyAction.cascade)();
  IntColumn get seasonNumber => integer()();
  TextColumn get displayName => text()();
  TextColumn get folderName => text()();
  IntColumn get episodeCount => integer().withDefault(const Constant(0))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSynced => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {contentId, seasonNumber},
      ];
}

// lib/core/database/tables/paulo_flix_episodes.dart
class PauloFlixEpisodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get seasonId =>
      integer().references(PauloFlixSeasons, #id, onDelete: KeyAction.cascade)();
  IntColumn get episodeNumber => integer()();
  TextColumn get title => text()();
  TextColumn get videoUrl => text()();
  IntColumn get durationSeconds => integer().nullable()();
  IntColumn get positionSeconds => integer().withDefault(const Constant(0))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastWatched => dateTime().nullable()();
  DateTimeColumn get lastSynced => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {seasonId, episodeNumber},
      ];
}
```

```dart
// lib/core/database/app_database.dart — adicionar às tables
@DriftDatabase(
  tables: [
    WatchlistItems,
    Downloads,
    PauloFlixContent,
    PauloFlixMovies,
    PauloFlixSeasons,    // NOVO
    PauloFlixEpisodes,   // NOVO
    TmdbGenres,
  ],
)

@override
int get schemaVersion => 5;  // 4 → 5

// v4 → v5: criar as 2 tabelas novas
onUpgrade: (m, from, to) async {
  if (from < 4) {
    final db = m.database as AppDatabase;
    await m.createTable(db.tmdbGenres);
  }
  if (from < 5) {
    final db = m.database as AppDatabase;
    await m.createTable(db.pauloFlixSeasons);
    await m.createTable(db.pauloFlixEpisodes);
  }
},
```

### 2. Repository — operação chave: `updateProgress`

```dart
// lib/domain/models/paulo_flix_progress_stats.dart
class PauloFlixProgressStats {
  final int totalEpisodes;
  final int completedEpisodes;
  final int inProgressEpisodes;

  const PauloFlixProgressStats({
    required this.totalEpisodes,
    required this.completedEpisodes,
    required this.inProgressEpisodes,
  });

  /// 0.0 (nenhum) a 1.0 (todos completos).
  double get progressRatio =>
      totalEpisodes == 0 ? 0.0 : completedEpisodes / totalEpisodes;

  /// Anime inteiro visto (todos episódios com isCompleted=true).
  bool get isAnimeCompleted =>
      totalEpisodes > 0 && completedEpisodes == totalEpisodes;

  /// Anime tem pelo menos 1 episódio em andamento.
  bool get isAnimeInProgress => inProgressEpisodes > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PauloFlixProgressStats &&
          totalEpisodes == other.totalEpisodes &&
          completedEpisodes == other.completedEpisodes &&
          inProgressEpisodes == other.inProgressEpisodes;

  @override
  int get hashCode => Object.hash(totalEpisodes, completedEpisodes, inProgressEpisodes);
}
```

```dart
// lib/data/repositories/paulo_flix_episode_progress_repository_impl.dart
class PauloFlixEpisodeProgressRepositoryImpl
    implements PauloFlixEpisodeProgressRepository {
  final AppDatabase _db;
  PauloFlixEpisodeProgressRepositoryImpl(this._db);
  @override
  Future<void> updateProgress({
    required int seasonId,
    required int episodeNumber,
    required int positionSeconds,
    int? durationSeconds,
  }) async {
    // 1. UPDATE posição + lastWatched
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

    // 2. Avaliar isCompleted (se duration conhecida e ratio >= 0.9)
    if (durationSeconds != null && durationSeconds > 0) {
      final ratio = positionSeconds / durationSeconds;
      if (ratio >= 0.9) {
        await (_db.update(_db.pauloFlixEpisodes)
              ..where((t) =>
                  t.seasonId.equals(seasonId) &
                  t.episodeNumber.equals(episodeNumber)))
            .write(const PauloFlixEpisodesCompanion(
          isCompleted: Value(true),
        ));
      // 3. Recalcular isCompleted da temporada (todos os episódios completos?)
      await _recomputeSeasonCompleted(seasonId);
    }
  }

  /// Limpa o progresso de um episódio (decisão 6: usado quando o user
  /// reassiste um episódio completo ou que mal começou). Também
  /// recalcula o `isCompleted` da season — sem isso, a flag fica stale.
  @override
  Future<void> resetProgress({
    required int seasonId,
    required int episodeNumber,
  }) async {
    await (_db.update(_db.pauloFlixEpisodes)
          ..where((t) =>
              t.seasonId.equals(seasonId) &
              t.episodeNumber.equals(episodeNumber)))
        .write(const PauloFlixEpisodesCompanion(
      positionSeconds: Value(0),
      isCompleted: Value(false),
    ));
    await _recomputeSeasonCompleted(seasonId);
  }

  /// Estatísticas agregadas de progresso de um anime. **Computado em
  /// runtime** (decisão 7) — 1 query COUNT com CASE WHEN, retorna
  /// `PauloFlixProgressStats` com totais, completados, em andamento
  /// e ratio (0.0–1.0). Não há flag persistida em `paulo_flix_content`.
  @override
  Future<PauloFlixProgressStats> getStatsForContent(int contentId) async {
    final row = await _db.customSelect(
      'SELECT '
      '  COUNT(*) AS total, '
      '  SUM(CASE WHEN e.is_completed = 1 THEN 1 ELSE 0 END) AS completed, '
      '  SUM(CASE WHEN e.position_seconds > 0 AND e.is_completed = 0 '
      '           THEN 1 ELSE 0 END) AS in_progress '
      'FROM paulo_flix_episodes e '
      'INNER JOIN paulo_flix_seasons s ON e.season_id = s.id '
      'WHERE s.content_id = ?1',
      variables: [Variable.withInt(contentId)],
      readsFrom: {_db.pauloFlixEpisodes, _db.pauloFlixSeasons},
    ).getSingle();
    final total = row.read<int>('total') ?? 0;
    final completed = row.read<int>('completed') ?? 0;
    final inProgress = row.read<int>('in_progress') ?? 0;
    return PauloFlixProgressStats(
      totalEpisodes: total,
      completedEpisodes: completed,
      inProgressEpisodes: inProgress,
    );
  }

  /// Lista animes com progresso em andamento (decisão 8 — "Continue
  /// assistindo"). Filtra: tem pelo menos 1 episódio com
  /// `positionSeconds > 0 && !isCompleted`. Ordena por último
  /// `lastWatched` descendente. Limite 12 por padrão.
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
    return rows.map((r) => _toDomain(_db.pauloFlixContent.map(r.data))).toList();
  }

  /// Stream reativo da lista de animes em andamento. Aciona ao
  /// adicionar/resetar/assistir episódios.
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
              .map((r) => _toDomain(_db.pauloFlixContent.map(r.data)))
              .toList(),
        );
  }

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

  @override
  Future<List<PauloFlixEpisode>> getEpisodesForSeason(int seasonId) async {
    final rows = await (_db.select(_db.pauloFlixEpisodes)
          ..where((t) => t.seasonId.equals(seasonId))
          ..orderBy([(t) => OrderingTerm(expression: t.episodeNumber)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Stream<List<PauloFlixEpisode>> watchEpisodesForSeason(int seasonId) {
    return (_db.select(_db.pauloFlixEpisodes)
          ..where((t) => t.seasonId.equals(seasonId))
          ..orderBy([(t) => OrderingTerm(expression: t.episodeNumber)]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<List<PauloFlixSeason>> getSeasonsForContent(int contentId) async {
    final rows = await (_db.select(_db.pauloFlixSeasons)
          ..where((t) => t.contentId.equals(contentId))
          ..orderBy([(t) => OrderingTerm(expression: t.seasonNumber)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Stream<List<PauloFlixSeason>> watchSeasonsForContent(int contentId) {
    return (_db.select(_db.pauloFlixSeasons)
          ..where((t) => t.contentId.equals(contentId))
          ..orderBy([(t) => OrderingTerm(expression: t.seasonNumber)]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  // --- sync on-demand (chamado pela PauloFlixEpisodeListViewModel) ---
  @override
  Future<void> syncSeasonEpisodes({
    required int contentId,
    required String contentServerUrl,
  }) async {
    // Fetch seasons via service HTTP
    final seasons = await PauloFlixService.fetchShowSeasons(contentServerUrl);
    for (final s in seasons) {
      // Upsert season (UNIQUE contentId+seasonNumber)
      final seasonId = await _upsertSeason(
        contentId: contentId,
        seasonNumber: s.number,
        displayName: s.name,
        folderName: s.name,
      );
      // Fetch episodes
      final episodes =
          await PauloFlixService.fetchSeasonEpisodes(s.url);
      for (final e in episodes) {
        await _upsertEpisode(
          seasonId: seasonId,
          episodeNumber: e.number,
          title: e.title,
          videoUrl: e.url,
        );
      }
      // Atualiza episodeCount da season
      await (_db.update(_db.pauloFlixSeasons)
            ..where((t) => t.id.equals(seasonId)))
          .write(PauloFlixSeasonsCompanion(
        episodeCount: Value(episodes.length),
        lastSynced: Value(DateTime.now()),
      ));
    }
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
      // NÃO sobrescrever positionSeconds/isCompleted — preserva progresso!
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

  PauloFlixSeason _toDomain(PauloFlixSeasonData row) => PauloFlixSeason(
        id: row.id,
        contentId: row.contentId,
        seasonNumber: row.seasonNumber,
        displayName: row.displayName,
        folderName: row.folderName,
        episodeCount: row.episodeCount,
        isCompleted: row.isCompleted,
        lastSynced: row.lastSynced,
      );

  PauloFlixEpisode _toDomain(PauloFlixEpisodeData row) => PauloFlixEpisode(
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
```

### 3. Recorder no player

```dart
// lib/ui/player/services/episode_progress_recorder.dart
class EpisodeProgressRecorder {
  final PauloFlixEpisodeProgressRepository _repository;
  final int seasonId;
  final int episodeNumber;

  Timer? _timer;
  static const Duration _saveInterval = Duration(seconds: 5);
  int _lastSavedPosition = -1;

  /// Função pura (testável diretamente) que decide se o player deve
  /// começar do zero (reset) ou retomar de `positionSeconds` antes do
  /// `Media.open`. Ver Decisão 6 do plano.
  ///
  /// Reset quando:
  /// - `isCompleted == true` (usuário quer reassistir)
  /// - `positionSeconds / durationSeconds < 0.1` (provavelmente fechou sem querer)
  ///
  /// Retomar caso contrário (parou intencionalmente entre 10% e 90%).
  @visibleForTesting
  static bool shouldResetForResume({
    required bool isCompleted,
    required int positionSeconds,
    required int durationSeconds,
  }) {
    if (isCompleted) return true;
    if (durationSeconds <= 0) return false;  // sem info, retoma do que tem
    final ratio = positionSeconds / durationSeconds;
    return ratio < 0.1;
  }

  EpisodeProgressRecorder({
    required this._repository,
    required this.seasonId,
    required this.episodeNumber,
  });

  /// Chamado ANTES de `Media.open`. Se retornar `true`, o caller
  /// deve abrir do zero (sem seek). Se retornar `false`, o caller
  /// deve abrir normal e depois fazer `player.seek(positionSeconds)`.
  Future<bool> prepareResumeOrReset({
    required bool isCompleted,
    required int positionSeconds,
    required int durationSeconds,
  }) async {
    final shouldReset = shouldResetForResume(
      isCompleted: isCompleted,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
    );
    if (shouldReset) {
      await _repository.resetProgress(
        seasonId: seasonId,
        episodeNumber: episodeNumber,
      );
      _lastSavedPosition = -1; // força próximo save
    }
    return shouldReset;
  }

  void start(
    Duration Function() getCurrentPosition,
    Duration Function() getDuration,
  ) {
    _timer?.cancel();
    _timer = Timer.periodic(
      _saveInterval,
      (_) => _save(getCurrentPosition, getDuration),
    );
  }

  Future<void> _save(
    Duration Function() getCurrentPosition,
    Duration Function() getDuration,
  ) async {
    final pos = getCurrentPosition();
    final dur = getDuration();
    if (pos.inSeconds == _lastSavedPosition) return;
    _lastSavedPosition = pos.inSeconds;
    await _repository.updateProgress(
      seasonId: seasonId,
      episodeNumber: episodeNumber,
      positionSeconds: pos.inSeconds,
      durationSeconds: dur.inSeconds > 0 ? dur.inSeconds : null,
    );
  }

  /// Chamado em dispose. Garante último save.
  Future<void> flush(
    Duration Function() getCurrentPosition,
    Duration Function() getDuration,
  ) async {
    _timer?.cancel();
    _timer = null;
    await _save(getCurrentPosition, getDuration);
  }
}
```

### 4. ViewModel da tela de episódios — carregar do banco

```dart
// Modificação em PauloFlixEpisodeListViewModel
// (substituir o _episodesCache in-memory por leitura do banco)

class PauloFlixEpisodeListViewModel extends ChangeNotifier {
  final PauloFlixContent content;
  final PauloFlixEpisodeProgressRepository _progressRepo;
  final int? contentDbId;  // vindo do PauloFlixContent.id

  // ...

  Future<void> loadSeasons() async {
    _status = PauloFlixEpisodeStatus.loading;
    _safeNotify();

    try {
      // 1. Sync on-demand: busca seasons/episodes do servidor
      await _progressRepo.syncSeasonEpisodes(
        contentId: contentDbId!,
        contentServerUrl: content.serverUrl,
      );

      // 2. Lê seasons do banco (reativo)
      // ...watch no banco, atualiza _seasons
    }
  }
}
```

---

## Ordem de implementação

### Fase 0 — Schema (1 patch)

**Task 0.1: Adicionar tabelas Drift + bump schema para 5**
- Files: `lib/core/database/tables/paulo_flix_seasons.dart` (novo), `lib/core/database/tables/paulo_flix_episodes.dart` (novo), `lib/core/database/app_database.dart` (modificar)
- Sem teste novo aqui — coberto pelos testes de repositório abaixo.
- Verificação: `dart run build_runner build --delete-conflicting-outputs` regenera `app_database.g.dart`. Confirmar que o arquivo gerado tem `PauloFlixSeasonsTable` e `PauloFlixEpisodesTable`.

### Fase 1 — Models + Repositório (4 patches TDD)

**Task 1.1: Domain models puros**
- Files: `lib/domain/models/paulo_flix_season.dart`, `lib/domain/models/paulo_flix_episode.dart`
- Test: `test/domain/models/paulo_flix_season_test.dart`, `test/domain/models/paulo_flix_episode_test.dart`
- TDD: criar classe com campos básicos + equality por `(contentId, seasonNumber)` / `(seasonId, episodeNumber)`. Verificar `copyWith`.

**Task 1.2: Contrato do repositório**
- Files: `lib/domain/repositories/paulo_flix_episode_progress_repository.dart` (novo)
- Métodos:
  - `updateProgress({seasonId, episodeNumber, positionSeconds, durationSeconds})`
  - `resetProgress({seasonId, episodeNumber})` ← NOVO (decisão 6)
  - `getStatsForContent(contentId) → PauloFlixProgressStats` ← NOVO (decisão 7)
  - `getInProgressContents({limit = 12}) → List<PauloFlixContent>` ← NOVO (decisão 8)
  - `watchInProgressContents({limit = 12}) → Stream<List<PauloFlixContent>>` ← NOVO (decisão 8)
  - `getEpisodesForSeason(seasonId)`, `watchEpisodesForSeason(seasonId)`
  - `getSeasonsForContent(contentId)`, `watchSeasonsForContent(contentId)`
  - `syncSeasonEpisodes({contentId, contentServerUrl})`
- Sem teste — interface.

**Task 1.3: Implementação do repositório (Drift)**
- Files: `lib/data/repositories/paulo_flix_episode_progress_repository_impl.dart` (novo)
- Test: `test/data/repositories/paulo_flix_episode_progress_repository_test.dart` (com `AppDatabase.forTesting(NativeDatabase.memory())`)
- TDD casos:
  - `updateProgress` grava posição + lastWatched
  - `updateProgress` com ratio ≥ 0.9 marca `isCompleted = true`
  - `_recomputeSeasonCompleted` seta `isCompleted = true` quando todos os episódios estão completos
  - `_recomputeSeasonCompleted` seta `isCompleted = false` quando nem todos estão completos
  - **`resetProgress` zera `positionSeconds` e `isCompleted` do episódio** ← NOVO
  - **`resetProgress` chama `_recomputeSeasonCompleted` (flag da season atualizada)** ← NOVO
  - **`getStatsForContent` retorna totais corretos (total, completed, inProgress)** ← NOVO
  - **`getStatsForContent` em content sem episodes retorna zeros (não null)** ← NOVO
  - **`getInProgressContents` filtra animes com episodes parciais** ← NOVO
  - **`getInProgressContents` ordena por `MAX(lastWatched) DESC`** ← NOVO
  - **`getInProgressContents` exclui `isAvailable = false`** ← NOVO
  - **`watchInProgressContents` emite ao inserir episódio parcial** ← NOVO
  - `syncSeasonEpisodes` faz upsert sem sobrescrever `positionSeconds`/`isCompleted`
  - `syncSeasonEpisodes` faz insert de novos episódios com defaults
  - `watchSeasonsForContent` emite ao inserir season
  - `watchEpisodesForSeason` emite ao atualizar posição
  - `getEpisodesForSeason` ordenado por `episodeNumber`

**Task 1.4: Sync service HTTP wrapper**
- Files: `lib/data/services/paulo_flix_episode_sync_service.dart` (novo)
- Função: `Future<List<PauloFlixEpisode>> syncFromServer({required int contentId, required String serverUrl})` — orquestra fetch HTTP + upsert no repo. Separado do `PauloFlixRepositoryImpl` para manter o repo focado em persistência e o service focado em HTTP+orquestração.
- Test: `test/data/services/paulo_flix_episode_sync_service_test.dart` (mock `http.Client` + mock repo)

### Fase 2 — Recorder no player (2 patches TDD)

**Task 2.1: `EpisodeProgressRecorder`**
- Files: `lib/ui/player/services/episode_progress_recorder.dart` (novo)
- Test: `test/ui/player/services/episode_progress_recorder_test.dart` (mock repo)
- TDD casos:
  - **`shouldResetForResume` (função pura — cobrir todos os 6 cenários da Decisão 6):**
    - `isCompleted=true, position=95, duration=100` → `true` (reassistir)
    - `isCompleted=true, position=0, duration=100` → `true` (consistente)
    - `isCompleted=false, position=5, duration=100` → `true` (< 10%, fechou sem querer)
    - `isCompleted=false, position=30, duration=100` → `false` (retomar)
    - `isCompleted=false, position=89, duration=100` → `false` (retomar, perto do fim)
    - `isCompleted=false, position=0, duration=0` → `false` (sem info de duração, retoma do zero)
  - `prepareResumeOrReset(reset=true)` chama `repo.resetProgress(...)` e retorna `true`
  - `prepareResumeOrReset(reset=false)` NÃO chama `repo.resetProgress` e retorna `false`
  - `start()` agenda Timer.periodic de 5s
  - Cada tick chama `updateProgress` com posição atual
  - Não chama `updateProgress` se posição não mudou desde o último save
  - `flush()` faz último save + cancela timer
  - `flush()` é idempotente (chamar 2x não duplica save)

**Task 2.2: Integrar no `ModernVideoPlayerScreen`**
- Files: `lib/ui/player/widgets/video_player_screen.dart` (modificar), `lib/routing/route_data.dart` (modificar)
- Mudanças:
  - `PlayerRouteData` ganha `seasonId: int?` e `episodeNumber: String?` (nullable — outros fluxos que não sejam PauloFlix passam null)
  - Instanciar `EpisodeProgressRecorder` no `_initializeVideoPlayer` SE for PauloFlix (i.e., `widget.anime?.source == AnimeSource.pauloFlix && seasonId != null`)
  - **ANTES do `Media.open`:** ler `positionSeconds`/`durationSeconds`/`isCompleted` do banco, chamar `_recorder.prepareResumeOrReset(...)`. Se reset → abrir do zero. Se retomar → abrir normal e, **após `Media.open` completar**, fazer `await _player!.seek(Duration(seconds: positionSeconds))` (libmpv exige seek pós-open).
  - **APÓS `Media.open` bem-sucedido**: chamar `_recorder.start(getPos, getDur)` para iniciar o timer de 5s.
  - No `dispose` e na troca de episódio (`_replaceEpisode`): chamar `await _recorder.flush(getPos, getDur)` ANTES de trocar (garante último save).
  - **Não** chamar `requestFocus` ou hooks de focus — não impacta TV navigation.
- Test: smoke test manual via `flutter run` (não automatizável por `flutter test`)

### Fase 3 — UI (3 patches TDD)

**Task 3.1: `PauloFlixEpisodeProgressViewModel` (wrapper de UI)**
- Files: `lib/ui/pauloflix/view_models/paulo_flix_episode_progress_viewmodel.dart` (novo)
- Função: estende a lógica do `PauloFlixEpisodeListViewModel` para usar `watchSeasonsForContent` + `watchEpisodesForSeason` do banco em vez de cache in-memory.
- Test: `test/ui/pauloflix/view_models/paulo_flix_episode_progress_viewmodel_test.dart`

**Task 3.2: Card de episódio com indicador de progresso**
- Files: `lib/ui/pauloflix/widgets/pauloflix_episode_card.dart` (modificar)
- Mudanças:
  - Aceitar `positionSeconds`, `durationSeconds`, `isCompleted` no construtor
  - Renderizar barra de progresso horizontal (LinearProgressIndicator) se `positionSeconds > 0` && `!isCompleted`
  - Renderizar ícone `Icons.check_circle` verde se `isCompleted`
  - Renderizar tempo restante ("X min restantes") se `positionSeconds > 0` && `!isCompleted`
- Test: widget test com pumpWidget em `test/ui/pauloflix/widgets/pauloflix_episode_card_test.dart`

**Task 3.3: Seletor de temporada com badge de completa**
- Files: `lib/ui/pauloflix/widgets/pauloflix_season_selector.dart` (modificar)
- Mudanças:
  - Aceitar `isCompleted` por season
  - Renderizar badge verde "✓ Completa" ao lado do nome da temporada
- Test: widget test simples

### Fase 4 — Limpar imports + provider wire-up (3 patches)

**Task 4.1: Remover referência quebrada no `app_database.dart`**
- Files: `lib/core/database/app_database.dart` (linha 14)
- O arquivo `lib/core/database/connection/migration_v1_to_v3.dart` referenciado no JSDoc não existe. Decidir:
  - (a) Criar o arquivo stub com comentário "Fase 2 pendente"
  - (b) Remover a referência do JSDoc
- Decisão recomendada: (b) — JSDoc precisa estar correto. Limpar.

**Task 4.2: Registrar repositório no `MultiProvider`**
- Files: `lib/app.dart` (modificar)
- Adicionar:
  ```dart
  Provider<PauloFlixEpisodeProgressRepository>(
    create: (_) => PauloFlixEpisodeProgressRepositoryImpl(appDatabase),
  ),
  ```
- Adicionar `PauloFlixEpisodeProgressRepository` no import.

**Task 4.3: Modificar `PauloFlixEpisodeListScreen` para usar o novo VM**
- Files: `lib/ui/pauloflix/widgets/pauloflix_episode_list_screen.dart` (modificar)
- Mudanças:
  - Trocar `PauloFlixEpisodeListViewModel` por `PauloFlixEpisodeProgressViewModel` na criação do `ChangeNotifierProvider`
  - Passar `contentId` (do `PauloFlixContent.id`) para o VM
  - Usar o `_playEpisode` existente mas incluir `seasonId` e `episodeNumber` no `PlayerRouteData`
- Modificar `lib/routing/route_data.dart`:
  - Adicionar `seasonId: int?` e `episodeNumber: String?` em `PlayerRouteData`

### Fase 5 — UI Home + See All: "Continue assistindo" (3 patches TDD)

**Task 5.1: `PauloFlixContinueWatchingViewModel`**
- Files: `lib/ui/pauloflix/view_models/paulo_flix_continue_watching_viewmodel.dart` (novo)
- Função: `ChangeNotifier` que assina `repo.watchInProgressContents(limit: 12)` e expõe a lista + loading state.
- Test: `test/ui/pauloflix/view_models/paulo_flix_continue_watching_viewmodel_test.dart` (mock repo com stream controlado)
- TDD casos:
  - Inicia com `loading = true` antes do primeiro evento do stream
  - Após primeiro evento, `loading = false` + `contents = [...]`
  - Stream emite nova lista → `contents` atualiza + `notifyListeners`
  - Stream emite lista vazia → `contents = []`, `isEmpty = true`
  - `dispose()` cancela subscription do stream (não vaza)

**Task 5.2: `PauloFlixContinueWatchingSection` (widget reutilizável)**
- Files: `lib/ui/pauloflix/widgets/paulo_flix_continue_watching_section.dart` (novo)
- Função: section que renderiza um `NetflixCarousel` (do core) com os animes em andamento. Se vazio, **NÃO** renderiza nada (esconde a section inteira). Cada card é um `NetflixCard` + barra de progresso no overlay (computed por `repo.getStatsForContent(content.id)`).
- Cada card é `FocusableWidget` (skill `flutter-reactivity-gotchas` #14) com `onSelect` que navega para `PauloFlixEpisodeListScreen(content)`.
- Test: `test/ui/pauloflix/widgets/paulo_flix_continue_watching_section_test.dart`
- TDD casos:
  - Lista vazia → renderiza `SizedBox.shrink()` (sem section)
  - Lista com 3 animes → renderiza carousel com 3 cards
  - Cada card mostra barra de progresso (LinearProgressIndicator) com `value = completed/total`
  - Tap no card chama callback `onContentTap` com o `PauloFlixContent`

**Task 5.3: Integrar no `HomeScreen` e `PauloFlixSeeAllScreen`**
- Files: `lib/ui/home/widgets/home_screen.dart` (modificar), `lib/ui/pauloflix/widgets/pauloflix_see_all_screen.dart` (modificar)
- Mudanças:
  - **HomeScreen:** no topo do `CustomScrollView` (acima do hero card + carrosséis por gênero), adicionar `PauloFlixContinueWatchingSection()` dentro de um `ChangeNotifierProvider<PauloFlixContinueWatchingViewModel>`. Seção some automaticamente quando vazia.
  - **PauloFlixSeeAllScreen:** idem, no topo do `CustomScrollView`, antes do grid paginado A-Z.
- **Atenção** (skill `flutter-reactivity-gotchas` #18, #19): essas telas estão sob o `FocusScope(node: _contentScopeNode)` persistente do `MainNavigationScreen`. **NÃO** usar `autofocus: true` em nenhum card. O shell gerencia o foco inicial.
- Test: smoke test manual via `flutter run` (não automatizável; dependem do `MultiProvider` do app)

### Fase 6 — Validação final (~200 testes incluindo os novos)

```bash
cd "C:/Users/pr02n/developer/goanime-mobile"
flutter analyze
dart fix --apply
flutter test
```

Critérios de aceitação:
- `flutter analyze` 0 issues
- `dart fix --apply` nada para arrumar
- `flutter test` 100% pass (testes novos + 192 existentes = ~200 testes)
- App roda, abre PauloFlix → escolhe anime → tela de episódios lista seasons/episódios
- Player grava progresso a cada 5s + 1x ao sair
- Próxima abertura do mesmo episódio retoma de onde parou
- Temporada com todos os episódios assistidos mostra badge "Completa"

---

## Verificação manual (smoke test)

1. **Sincronização inicial:**
   - Abrir app → PauloFlix → escolher anime "Naruto"
   - Primeira carga: tela mostra "Carregando..." (sync HTTP + banco)
   - Segunda carga: carrega instantaneamente do banco

2. **Gravar progresso:**
   - Tocar episódio 1
   - Aguardar 10 segundos
   - Fechar player (back)
   - Verificar via `adb shell sqlite3 pauloflix.db "SELECT * FROM paulo_flix_episodes"` (se Android) ou via debug print no app que `positionSeconds > 0`

3. **Retomar progresso:**
   - Reabrir PauloFlix → Naruto → Episódio 1
   - Player deve retomar a partir de `positionSeconds` (≥ 5s, < 10s)
   - Barra de progresso no card do episódio 1 deve mostrar avanço

4. **Temporada completa:**
   - Assistir todos os episódios de uma temporada até o final (≥ 90% cada)
   - Verificar que `paulo_flix_seasons.is_completed = 1` para essa temporada
   - UI do `PauloFlixSeasonSelector` deve mostrar badge "✓ Completa"

5. **Sync sem sobrescrever progresso:**
   - Assistir episódio 1 até 30s
   - Forçar re-sync (chamar `syncSeasonEpisodes` novamente)
   - Verificar que `positionSeconds` continua 30 (não foi sobrescrito por 0)

---

## Riscos & Mitigações

| Risco | Impacto | Mitigação |
|-------|---------|-----------|
| Sync HTTP falha mid-way | Tela de episódios vazia | Try/catch em `syncSeasonEpisodes`; fallback para seasons já no banco (não faz wipe) |
| Drift migration v4→v5 corrompe DB existente | Perda de shows PauloFlix | Migration é puramente aditiva (`createTable`); Drift gerencia atomicamente. Smoke test em instalação limpa + upgrade |
| `positionTimer` no player conflita com timer já existente (`positionTimer` no AniSkip mixin) | Timer leak | Recorder usa **field próprio** `_progressTimer`, não compartilha com mixin. Cancelado em `dispose` antes do mixin |
| Sync on-demand para todos os animes deixa o primeiro `loadContents()` lento | UX ruim no home | NÃO chamar sync de episodes no home — só na `EpisodeListScreen`. Home continua usando só `paulo_flix_content` (já existe) |
| `Episode.number` é String (no domain `Episode`) mas Int no banco | Type mismatch | Converte no `_toDomain` (já feito) + no `_buildEpisodeKey` (já feito no player) |
| FK cascade apaga season ao apagar content | Perda de progresso se user apaga show | Desejado: se user apaga show (`markAsUnavailable`), progresso some junto. Comportamento OK |
| `_recomputeSeasonCompleted` chamado em loop durante bulk watch | Performance | Disparar apenas dentro de `updateProgress` (não é chamado em loops de bulk) — OK |
| `player.seek` chamado ANTES de `Media.open` (libmpv é no-op nesse caso) | Não retoma | Sempre chamar `seek` **depois** de `Media.open` retornar OK. Heurística de reset é **antes** do open, mas o `seek` é **depois** |
| Usuário reassiste episódio completo: player recomeça do zero (perde referência da última posição) | UX ruim, mas aceitável | Reset intencional — é o que ele pediu ao reassistir. `_lastSavedPosition = -1` no recorder força próximo save |
| Heurística < 10% reseta episódio pausado em 8% (ex: fechou 1min de 12min) | Posição perdida | Aceitável — provavelmente fechou sem querer. Pior seria retomar de 1min num anime de 12min |
| `autofocus: true` no card do "Continue assistindo" causa assertion `Focused child does not have the same idea of its enclosing scope` (skill #19) | Crash ao navegar para HomeScreen | **NUNCA** usar `autofocus: true` em descendentes do `FocusScope(node: _contentScopeNode)` do `MainNavigationScreen`. O shell gerencia foco. Section é só visual |
| Stream `watchInProgressContents` re-emit toda vez que `lastWatched` muda (a cada 5s) | Lista "pisca" na home | Aceitável — reatividade é o objetivo. Drift deduplica inserts/idempotentes. Se UX ruim, debounce no VM |

---

## Notas de arquitetura

1. **Por que tabela `paulo_flix_seasons` separada e não JSON na `paulo_flix_content`?**
   - Permite queries eficientes (`WHERE seasonId = X`), watch streams, FK cascade.
   - JSON column seria anti-pattern para dados estruturados com semântica de FK.

2. **Por que sync on-demand em vez de no `syncContent`?**
   - `syncContent` varre TODOS os shows do servidor (pode ser 200+). Adicionar fetch de episodes para cada = 200+ chamadas HTTP adicionais = minutos.
   - Sync on-demand só busca episodes dos shows que o usuário ABRE = média 5-10 shows = segundos.
   - Trade-off: o primeiro `open` é mais lento. Aceitável.

3. **Por que `isCompleted` na season e não computado em runtime?**
   - Performance: query `WHERE is_completed = 1` é O(1) com índice. Computar em runtime = COUNT + comparação a cada build.
   - Reatividade: Stream emite ao mudar, UI atualiza sem polling.
   - Trade-off: precisa manter consistência (feito por `_recomputeSeasonCompleted`).

4. **Por que `IntColumn positionSeconds` e não `Duration`?**
   - Drift tem `DateTimeColumn` mas não `DurationColumn`. `IntColumn` com `inSeconds` é o padrão e suficiente.

5. **Por que NÃO salvar `fileSize` no banco?**
   - `fileSize` é uma propriedade do `<a>` HTML, não persistente. A `PauloFlixEpisode` domain já tem `fileSize: int?` mas ele é populado pelo scrape HTTP e nunca salvo. Para a feature de progresso, é desnecessário.
