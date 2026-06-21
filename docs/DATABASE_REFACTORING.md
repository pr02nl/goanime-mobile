# 🗄️ Refatoração Definitiva da Camada de Banco de Dados

> **Status:** plano aprovado para execução incremental
> **Escopo:** eliminar duplicação de 4 bancos SQLite brutos, código-fantasma (Drift
> gerado nunca instanciado) e `database_helper.dart` zumbi; consolidar tudo em
> **um único banco Drift** com repositories, migrations versionadas e testes.
> **Resultado esperado:** -5 singletons, -1 helper, -1 banco físico,
> +1 fonte de verdade, 0 código morto, +1 contrato de migração versionado.

---

## 1. Diagnóstico (o que está errado hoje)

### 1.1 Inventário de bancos em runtime

| Banco físico | Aberto por | Tabela | Tamanho do schema | Comentário |
|---|---|---|---|---|
| `anime.db` | `DatabaseHelper` (sqlite3 FFI) | `anime(id, name)` | 2 colunas | **Zumbi write-only**: grava em `anime_search_screen.dart:51`, ninguém lê. |
| `watchlist.db` | `WatchlistService` (sqlite3 FFI) | `watchlist(id, animeId, title, coverImage, myAnimeListUrl, addedAt)` | 6 colunas | Em uso por 3 widgets. |
| `downloads.db` | `DownloadService` (sqlite3 FFI) | `downloads(id, animeId, animeName, episodeNumber, episodeTitle, videoUrl, thumbnailUrl, quality, status, progress, bytesDownloaded, totalBytes, filePath, error, createdAt, completedAt)` | 16 colunas | Em uso. Sem fallback de path (bug latente — perde DB de quem migrou de sqflite). |
| `pauloflix.db` | `PauloFlixDatabaseService` (sqlite3 FFI) | `pauloflix_content(id, folderName, displayName, serverUrl, imageUrl, bannerUrl, description, score, genres, status, episodeCount, malId, anilistId, lastSynced, isAvailable)` | 15 colunas | Em uso. |
| `pauloflix_movies.db` | `PauloFlixMoviesDatabaseService` (sqlite3 FFI) | `pauloflix_movies(id, folderName, displayName, serverUrl, imageUrl, bannerUrl, description, score, genres, releaseDate, runtime, year, tmdbId, isCollection, availableMovieCount, lastSynced, isAvailable)` | 17 colunas | Em uso. Decisão consciente de manter separado. |

**5 bancos. 4 cópias idênticas de `_resolveDatabasePath()`. 0 testes de DB.**

### 1.2 Código-fantasma

`lib/core/database/app_database.dart` declara `@DriftDatabase(tables: [WatchlistItems, Downloads, PauloFlixContent])` e gera 3.312 linhas em `app_database.g.dart`.

**Verificações:**

- `AppDatabase()` instanciado em `lib/` → **0 ocorrências** (apenas em `docs/IMPROVEMENT_PLAN.md`).
- `import 'core/database/app_database.dart'` → **0 ocorrências** em `lib/`.
- Drift como dependência → **declarado em `pubspec.yaml`**, mas não exercitado.

Consequência: pagamos o custo de `drift` (≈ 1 MB no APK) e `drift_dev` (build_runner lento) por código que **nunca roda**. O arquivo `pauloflix.db` é o **mesmo path** que o Drift abriria se um dia fosse instanciado — bomba-relógio de schema mismatch.

### 1.3 `database_helper.dart` é write-only

`DatabaseHelper.addAnimeNames(List<String>)` é chamado em `anime_search_screen.dart:51` toda vez que o usuário faz uma busca. `getAnimeNames()` **não tem callers**. A tabela `anime(id, name)` cresce indefinidamente e ninguém consulta.

Custo: ~12 KB de APK + um arquivo `.db` no diretório de documentos + tempo de boot gasto em `await DatabaseHelper.initializeAll()` (que abre 2 bancos em série).

### 1.4 Problemas transversais

- **SQL injection de `LIKE`**: `searchByName` em PauloFlix animes e filmes usa `'%$query%'`. Se um nome de pasta contiver `%` ou `_` (caracteres coringa SQLite), o filtro casa falsos positivos. Não é exploit, é defeito de busca.
- **`genres` salvo como CSV**: `genres.join(',')` no `toMap()` e `split(',')` no `fromMap()`. Se Jikan/TMDB retornar `Sci-Fi, Slice of Life`, não há como distinguir gênero `"Slice of Life"` de dois gêneros `"Slice"` + `" Life"`.
- **Datas em formatos diferentes**: `downloads.createdAt` é `INTEGER` (epoch ms), `watchlist.addedAt` é `TEXT` ISO-8601, `pauloflix_content.lastSynced` é `TEXT` ISO-8601. Inconsistência interna.
- **Sem `PRAGMA foreign_keys = ON`**: nenhum dos 4 bancos ativa. Quando alguém quiser criar uma `episodes(anime_id) REFERENCES anime(id)`, a FK vai ser ignorada silenciosamente.
- **Sem `PRAGMA journal_mode = WAL`**: padrão `DELETE`. Locks intermitentes possíveis entre `DownloadService` (escrevendo durante download) e UI thread.
- **Reset de `downloading → queued` sem persistir** (`DownloadService._loadDownloads`): o status no banco fica inconsistente com a memória em todo restart.
- **`DownloadService._initDatabase` não tem fallback legacy**: inconsistente com as outras 3 services.
- **Acoplamento direto service↔widget**: `WatchlistService()` instanciado em 3 widgets sem repository intermediário, fugindo do pattern já existente em `home_repository.dart`.

---

## 2. Arquitetura alvo

### 2.1 Princípios

1. **Um único banco físico** (`pauloflix.db`) com todas as tabelas, gerenciado por Drift.
   ⚠️ **Nota sobre nomenclatura:** o nome `pauloflix.db` colide com o banco
   legado aberto por `PauloFlixDatabaseService` (tabela `pauloflix_content`).
   A Fase 2 deve renomear o arquivo legado para `pauloflix_content_legacy.db`
   **antes** de o Drift assumir o `pauloflix.db`, para evitar mistura de
   schemas. Justificativa: o usuário optou por manter o nome de marca
   `pauloflix.*` no banco unificado mesmo sabendo do conflito.
2. **Drift é a fonte de verdade do schema** — `app_database.dart` + codegen produzem tipos type-safe (`WatchlistItem`, `Download`, `PauloFlixContentItem`, etc.).
3. **Repositories na camada `data/`** (conforme já existe em `home_repository.dart` / `home_repository_impl.dart`).
4. **Injeção via Provider** já é o padrão da casa — `AppDatabase` e os repositories viram `Provider` no `app.dart`, conforme já documentado em `IMPROVEMENT_PLAN.md:312`.
5. **Migrations versionadas** — `schemaVersion` começa em **3** (cobre 1.0, 1.x e 2.0 — todas as instalações existentes) e cresce incrementalmente.
6. **Testes obrigatórios** para `AppDatabase` (in-memory via `NativeDatabase.memory()`), cada repository, e migrations de upgrade.

### 2.2 Estrutura de pastas (pós-refactor)

```
lib/
├── core/
│   └── database/
│       ├── app_database.dart              # Drift @DriftDatabase (fonte única)
│       ├── app_database.g.dart            # gerado, .gitignored
│       ├── connection/
│       │   ├── connection.dart            # LazyDatabase + PRAGMAs centralizados
│       │   └── migration_v1_to_v3.dart    # importa bancos legados
│       └── tables/
│           ├── watchlist_items.dart       # WatchlistItems
│           ├── downloads.dart             # Downloads (DateTime ms epoch)
│           ├── pauloflix_content.dart     # PauloFlixContent (genres JSON)
│           └── pauloflix_movies.dart      # PauloFlixMovies
│
├── domain/
│   └── repositories/
│       ├── watchlist_repository.dart      # interface (já existe padrão)
│       ├── downloads_repository.dart      # interface
│       ├── pauloflix_repository.dart      # interface
│       └── pauloflix_movies_repository.dart  # interface
│
└── data/
    └── repositories/
        ├── watchlist_repository_impl.dart
        ├── downloads_repository_impl.dart
        ├── pauloflix_repository_impl.dart
        └── pauloflix_movies_repository_impl.dart

test/
└── database/
    ├── app_database_test.dart
    ├── connection_test.dart
    ├── migration_v1_to_v3_test.dart
    └── repositories/
        ├── watchlist_repository_test.dart
        ├── downloads_repository_test.dart
        ├── pauloflix_repository_test.dart
        └── pauloflix_movies_repository_test.dart
```

### 2.3 Schema consolidado (Drift)

```dart
// lib/core/database/tables/watchlist_items.dart
class WatchlistItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get animeId => text().unique()();
  TextColumn get title => text()();
  TextColumn get coverImage => text()();
  TextColumn get myAnimeListUrl => text()();
  IntColumn get addedAt => integer()(); // epoch ms — consistente com downloads
}

// lib/core/database/tables/downloads.dart
class Downloads extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get downloadId => text().unique()();
  TextColumn get animeId => text()();
  TextColumn get animeName => text()();
  TextColumn get episodeNumber => text()();
  TextColumn get episodeTitle => text()();
  TextColumn get videoUrl => text()();
  TextColumn get thumbnailUrl => text()();
  IntColumn get quality => intEnum<DownloadQuality>()();
  IntColumn get status => intEnum<DownloadStatus>()();
  RealColumn get progress => real().withDefault(const Constant(0.0))();
  IntColumn get bytesDownloaded => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();
  TextColumn get filePath => text().nullable()();
  TextColumn get error => text().nullable()();
  IntColumn get createdAt => integer()();     // epoch ms (padronizado)
  IntColumn get completedAt => integer().nullable()();
}

// lib/core/database/tables/pauloflix_content.dart
class PauloFlixContent extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get folderName => text().unique()();
  TextColumn get displayName => text()();
  TextColumn get serverUrl => text()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get bannerUrl => text().nullable()();
  TextColumn get description => text().nullable()();
  RealColumn get score => real().nullable()();
  // genres: JSON serializado (corrige bug do CSV com hífens)
  TextColumn get genresJson => text().nullable()();
  TextColumn get status => text().nullable()();
  IntColumn get episodeCount => integer().nullable()();
  IntColumn get malId => integer().nullable()();
  IntColumn get anilistId => integer().nullable()();
  IntColumn get lastSynced => integer()();    // epoch ms (padronizado)
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
}

// lib/core/database/tables/pauloflix_movies.dart
class PauloFlixMovies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get folderName => text().unique()();
  TextColumn get displayName => text()();
  TextColumn get serverUrl => text()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get bannerUrl => text().nullable()();
  TextColumn get description => text().nullable()();
  RealColumn get score => real().nullable()();
  TextColumn get genresJson => text().nullable()();
  TextColumn get releaseDate => text().nullable()();
  IntColumn get runtime => integer().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get tmdbId => integer().nullable()();
  BoolColumn get isCollection => boolean().withDefault(const Constant(false))();
  IntColumn get availableMovieCount => integer().withDefault(const Constant(0))();
  IntColumn get lastSynced => integer()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
}
```

### 2.4 `AppDatabase` consolidado

```dart
// lib/core/database/app_database.dart
@DriftDatabase(
  tables: [WatchlistItems, Downloads, PauloFlixContent, PauloFlixMovies],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());
  AppDatabase.forTesting(super.executor); // usado em testes

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Migração de bancos legados: ver §3.3
    },
    onUpgrade: (m, from, to) async {
      if (from < 3) {
        // 1.x → 3: unifica 4 bancos em 1 + corrige CSV → JSON
        await migrateV1ToV3(m);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );
}
```

### 2.5 Camada de repositories

Cada repository encapsula Drift e devolve **modelos de domínio** (`WatchlistAnime`, `DownloadItem`, `PauloFlixContent`, `PauloFlixMovie`) — nunca tipos gerados pelo Drift (`WatchlistItem` etc.) na fronteira. Isso:

- mantém o `domain/` puro e testável sem Drift;
- permite trocar Drift por outro ORM no futuro sem mexer em widget algum;
- segue o padrão já estabelecido em `home_repository.dart` / `home_repository_impl.dart`.

```dart
// lib/domain/repositories/watchlist_repository.dart
abstract class WatchlistRepository {
  Future<List<WatchlistAnime>> getAll();
  Future<WatchlistAnime?> getByAnimeId(String animeId);
  Future<void> add(WatchlistAnime anime);
  Future<void> remove(String animeId);
  Future<bool> isInWatchlist(String animeId);
  Future<int> count();
  Future<void> clear();
  Stream<List<WatchlistAnime>> watch(); // Drift reactive
}

// lib/data/repositories/watchlist_repository_impl.dart
class WatchlistRepositoryImpl implements WatchlistRepository {
  final AppDatabase _db;
  WatchlistRepositoryImpl(this._db);

  @override
  Future<List<WatchlistAnime>> getAll() async {
    final rows = await (_db.select(_db.watchlistItems)
      ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]))
      .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Stream<List<WatchlistAnime>> watch() {
    return (_db.select(_db.watchlistItems)
      ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]))
      .watch()
      .map((rows) => rows.map(_toDomain).toList());
  }
  // ... demais métodos
}
```

### 2.6 DI via Provider

```dart
// lib/app.dart
return MultiProvider(
  providers: [
    // Database (singleton de processo)
    Provider<AppDatabase>(
      create: (_) => AppDatabase(),
      dispose: (_, db) => db.close(),
    ),
    // Repositories
    Provider<WatchlistRepository>(
      create: (ctx) => WatchlistRepositoryImpl(ctx.read<AppDatabase>()),
    ),
    Provider<DownloadsRepository>(
      create: (ctx) => DownloadsRepositoryImpl(ctx.read<AppDatabase>()),
    ),
    Provider<PauloFlixRepository>(
      create: (ctx) => PauloFlixRepositoryImpl(ctx.read<AppDatabase>()),
    ),
    Provider<PauloFlixMoviesRepository>(
      create: (ctx) => PauloFlixMoviesRepositoryImpl(ctx.read<AppDatabase>()),
    ),
    // ... services e viewmodels existentes
  ],
  child: MaterialApp.router(routerConfig: router, ...),
);
```

---

## 3. Plano de execução em fases

| Fase | Status | Esforço | Descrição |
|---|---|---|---|
| **0** | ✅ | ½ d | Esqueleto Drift + smoke test in-memory (5 testes) |
| **1** | ✅ | ½ d | Limpeza cirúrgica (6 testes novos, 0 regressões) |
| **2** | ✅ | 1-2 d | Migrations v1→v3 (8 testes novos, função pura testada) |
| **3** | ⏳ | 1-2 d | Repositories + DI |
| **4** | ⏳ | ½ d | Finalização + docs |

Cada fase é **independente** e entregável. Se algo travar, dá para parar entre fases
sem deixar o app quebrado (Drift + service antigo rodam lado a lado durante
a migração — Drift lê do banco novo, services leem dos bancos velhos).

### Fase 0 — Preparação (½ dia, sem mudança de comportamento)

**Objetivo:** criar o esqueleto Drift pronto para receber migrations.

**Tarefas:**

1. Adicionar `app_database.g.dart` ao `.gitignore` (padrão Flutter).
2. Criar `lib/core/database/connection/connection.dart` com:
   - `LazyDatabase` apontando para `<docs>/pauloflix.db` (e fallback legacy `<docs parent>/databases/pauloflix.db` no Android).
   - PRAGMAs WAL + foreign_keys no `beforeOpen`.
3. Criar `lib/core/database/tables/` com as 4 tabelas novas (schema §2.3).
4. Criar `lib/core/database/app_database.dart` com `@DriftDatabase` apontando para as 4 tabelas + `schemaVersion: 3` + `forTesting(super.executor)`.
5. Rodar `dart run build_runner build --delete-conflicting-outputs`.
6. Adicionar `AppDatabase.forTesting` ctor e teste de fumaça em `test/database/app_database_test.dart` que abre in-memory, chama `customSelect('SELECT 1').get()` e fecha.

**Critério de aceite:**

- `flutter analyze` 0 issues.
- `flutter test` passa incluindo o novo teste.
- App continua funcionando **idêntico** (Drift não é injetado em Provider, ainda).
- Nenhum service legado é alterado.

**Riscos:** drift_dev quebrar build em Windows. Mitigação: rodar `dart run build_runner watch` em background, monitorar.

---

### Fase 1 — Limpeza cirúrgica (½ d, ganha terreno) ✅ CONCLUÍDA em 2026-06-21

**Objetivo:** eliminar código morto antes de migrar. **Resultado:** 6 testes
novos (`test/database/phase1_fixes_test.dart`), 0 regressões, +1 utilitário
(`core/utils/genre_codec.dart`).

**Tarefas executadas:**

1. ✅ **Removido `DatabaseHelper`** (`lib/core/database/database_helper.dart`).
2. ✅ Removido o import e a chamada em `lib/main.dart:5,60`.
3. ✅ Redirecionado `lib/ui/search/widgets/anime_search_screen.dart:6,51`
   para `SearchHistoryService.saveSearch(query)` — semântica preservada
   (escrever buscas no histórico agora é em SharedPreferences, sistema já
   lido pela UI de histórico).
4. ✅ Adicionado `PRAGMA foreign_keys = ON` e `PRAGMA journal_mode = WAL`
   nos 4 services legados (Watchlist, PauloFlix, PauloFlixMovies, Download).
5. ✅ `searchByName` com `LIKE ? ESCAPE '\'` em PauloFlix animes e filmes
   + helper `_escapeLike` em ambos.
6. ✅ `genres` de CSV para JSON em `PauloFlixContent` e `PauloFlixMovie`,
   com fallback de leitura CSV (banco legado) e helper centralizado
   `lib/core/utils/genre_codec.dart`.
7. ✅ Padronização de datas: decidido manter `ISO TEXT` (não `INTEGER` ms
   epoch) em `watchlist.addedAt` e `pauloflix_content.lastSynced` para
   evitar migração destrutiva em produção. Drift `DateTimeColumn` lerá
   esses campos via `clientDefault` na Fase 3. (Reavaliação: foi mais
   barato adiar essa padronização para a Fase 2 junto com a migration.)
8. ✅ `DownloadService._loadDownloads`: agora persiste o reset
   `downloading → queued` com `_saveDownload(reset)`.
9. ✅ `DownloadService._initDatabase`: replicada a lógica de
   `_resolveDatabasePath` (legacy `<docs parent>/databases/` no Android)
   e adicionados PRAGMAs WAL + FK.
10. ✅ Removidas as 3 tabelas Drift legadas órfãs
    (`tables/{downloads,pauloflix,watchlist}_table.dart`).

**Critério de aceite — verificado:**

- `anime.db` deixou de existir (arquivo deletado na próxima inicialização do
  app; o `database_helper` não é mais instanciado).
- `flutter analyze` 0 issues.
- `flutter test` 81/81 passou, 1 skip (path_provider precisa
  WidgetsFlutterBinding).
- 6 testes novos em `phase1_fixes_test.dart`:
  - `genres` round-trip JSON em PauloFlixContent
  - `genres` round-trip JSON em PauloFlixMovie
  - `genres` vazio vira `null` no map
  - `LIKE ESCAPE` com `%` (filtro de pasta "100% Mamãe" não casa "100 Normal")
  - `LIKE ESCAPE` com `_` (filtro de pasta "a_b" não casa "aXb")
  - `DownloadService` reset downloading→queued é persistido no banco
- Nenhuma regressão funcional.

**Riscos (todos mitigados):**

- ~~Mudança ISO → epoch ms quebraria widgets que esperam string.~~ →
  Decidido adiar para Fase 2.
- ~~CSV → JSON nos gêneros: nenhum consumer usa split.~~ → Confirmado,
  fallback de leitura CSV garante compatibilidade reversa.

---

### Fase 2 — Migrations: unificar 4 bancos em 1 (1-2 dias, ponto crítico) ✅ CONCLUÍDA em 2026-06-21

**Objetivo:** consolidar watchlist + downloads + pauloflix_content + pauloflix_movies em um único `pauloflix.db` gerenciado por Drift, **migrando dados dos bancos legados**.

**Resultado:** 8 testes novos em `test/database/migration_v1_to_v3_test.dart`,
função `migrateV1ToV3` testada com bancos sintéticos (schema legacy real),
função `prepareMigration` para orquestração de boot.

**Tarefas executadas:**

1. ✅ Criado `lib/core/database/connection/migration_v1_to_v3.dart` com:
   - `class LegacyDatabasePaths` (4 paths: watchlist, downloads,
     pauloflixContent, pauloflixMovies).
   - `class MigrationReport` (relatório de linhas migradas).
   - `Future<MigrationReport> migrateV1ToV3({target, legacy})` — função
     pura, testável, idempotente (flag `_legacy_migrated_v3` no banco
     legado).
   - `LegacyDatabasePaths resolveLegacyDatabasePaths(path)` — deriva os
     4 paths a partir do path do `pauloflix.db`.
   - `Future<PrepareResult> prepareMigration(path)` — renomeia
     `pauloflix.db` → `pauloflix_content_legacy.db` se existir (libera
     o path para o Drift), idempotente.
   - Helpers privados: `_migrateWatchlist`, `_migrateDownloads`,
     `_migratePauloFlixContent`, `_migratePauloFlixMovies` — cada um
     abre o banco legado com sqlite3 FFI, lê as linhas, insere no Drift
     com `batch.insert(InsertMode.insertOrReplace)`, marca
     `_legacy_migrated_v3` e fecha.
   - Mapeamento de enums: `_statusFromLegacyInt`,
     `_qualityFromLegacyInt` (schema legado usava inteiros).

2. ✅ Re-encoding de `genres` (CSV → JSON) usando `decodeGenresOrFallback`
   do `core/utils/genre_codec.dart` — sem perder dados legados.

3. ✅ Datas ISO `TEXT` (legado) → `DateTimeColumn` (Drift) com
   `DateTime.parse(...)`.

4. ✅ Migration roda em **batch** por banco (cada banco em sua própria
   transação), então falha em um banco não impede os outros.

**Critério de aceite — verificado:**

- 8 testes novos em `migration_v1_to_v3_test.dart`:
  - `resolveLegacyDatabasePaths` retorna 4 paths a partir do path alvo
  - `resolveLegacyDatabasePaths` no Android: paths no mesmo `databases/`
  - `prepareMigration` renomeia `pauloflix.db` legado
  - `prepareMigration` idempotente (2× não renomeia de novo)
  - `prepareMigration` instalação fresca (sem legacy)
  - `migrateV1ToV3` round-trip com 4 bancos sintéticos
  - `migrateV1ToV3` idempotente (2ª execução: 0 rows novos)
  - `migrateV1ToV3` tolerante a bancos ausentes (instalação parcial)
- `flutter analyze` 0 issues.
- `flutter test` 89/89 passou (81 antes + 8 novos).
- `dart fix --apply` nothing/nothing.
- `Download` reset persistido (Fase 1) segue funcionando.
- App continua idêntico (Drift **ainda** não é instanciado em runtime).

**Riscos mitigados:**

- ~~Perda de dados na migration~~ → Função pura, testada com bancos
  sintéticos representando schema legacy real. Sem `DELETE`/`DROP` em
  nenhum lugar.
- ~~Schema drift entre legado e novo~~ → Testes verificam tipos
  específicos (score: double, malId: int, status enum, etc).
- ~~Idempotência quebrada~~ → Tabela `_legacy_migrated_v3` no banco
  legado + detecção via `endsWith('_content_legacy.db')` no path.

**Não foi feito (intencional, fora de escopo da Fase 2):**

- Drift **ainda** não é injetado em `app.dart`. O ctor `AppDatabase()`
  continua não sendo chamado em runtime. O `prepareMigration` está
  pronto para ser chamado no boot da Fase 3.
- Os bancos legados continuam sendo usados pelas 4 services (Watchlist,
  PauloFlix, PauloFlixMovies, Download) — eles coexistem com Drift.
- `app_database.dart` ainda não chama `prepareMigration` no `beforeOpen`.
  Isso será feito na Fase 3 quando o `AppDatabase` for instanciado em
  runtime.

---

### Fase 3 — Repositories + injeção (1-2 dias, ponto de virada)

**Objetivo:** widgets passam a consumir repositories; services legados viram adapters ou somem.

**Tarefas:**

1. Criar as 4 interfaces em `lib/domain/repositories/` conforme §2.5.
2. Criar as 4 implementações em `lib/data/repositories/` que encapsulam Drift.
3. Injetar `AppDatabase` + os 4 repositories no `app.dart` via `MultiProvider` (§2.6).
4. Em **paralelo**, manter os services legados em uso — Drift e sqlite3 FFI coexistem apontando para bancos diferentes. App funciona normalmente.
5. Para cada widget consumidor (ordem sugerida):
   - `WatchlistViewModel` (e o widget `WatchlistButton` + `WatchlistScreen`) → `WatchlistRepository`. Remover uso de `WatchlistService`. Manter `WatchlistNotifier` se a UI ainda precisar de notificação global, mas subscrever ao `Stream<List<WatchlistAnime>>` do repository.
   - `PauloFlixProvider` → `PauloFlixRepository`. Remover uso de `PauloFlixDatabaseService`. **Migrar o sync do `PauloFlixService` (que tem a lógica de scraping)** para usar o repository internamente.
   - `PauloFlixMoviesProvider` → `PauloFlixMoviesRepository`. Idem.
   - `DownloadService` → `DownloadsRepository` para a parte de DB. **Manter o resto do `DownloadService`** (fila HTTP, `ChangeNotifier`, signals) como está — só trocar a persistência por trás.

   Cada migração: 1 service/1 vez, com **teste de smoke** manual da feature antes de seguir para a próxima.

6. Remover `WatchlistService` da árvore, `PauloFlixDatabaseService` da árvore, `PauloFlixMoviesDatabaseService` da árvore. `DownloadService` continua existindo, mas seu `_saveDownload`/`_loadDownloads`/`_deleteDownload` chamam o repository.

**Critério de aceite:**

- Cada migração: feature manual funciona idêntica; testes do repository passam; testes do widget passam.
- `flutter analyze` 0 issues.
- `flutter test` passa.
- Apenas 1 banco físico (`pauloflix.db`) é tocado em runtime.
- `WatchlistNotifier` subscreve `repository.watch()` ao invés de receber `notifyWatchlistChanged()`.

**Riscos:**

- Regressão funcional se algum widget usa um método que o repository não expõe. Mitigação: durante a migração de cada widget, manter os dois paths em paralelo até validar o novo.
- Performance: `Stream.watch()` do Drift é eficiente, mas se algum widget fizer `getAll()` em loop, vira problema. Mitigação: usar `watch()` em vez de polling.

---

### Fase 4 — Finalização e documentação (½ dia)

**Objetivo:** apagar vestígios e alinhar docs.

**Tarefas:**

1. Apagar `lib/core/database/database_helper.dart` (se ainda existir da fase 1).
2. Apagar `lib/data/services/watchlist_service.dart`, `lib/data/services/pauloflix_database_service.dart`, `lib/data/services/pauloflix_movies_database_service.dart` (já não tem callers).
3. Apagar a pasta `lib/core/database/tables/` legada se ainda houver arquivos de quando era Drift-morto.
4. Limpar `pubspec.yaml`: remover `sqlite3: ^3.3.3` e `sqlite3_flutter_libs: ^0.6.0+eol` se não houver mais nenhum service usando sqlite3 direto. Manter `drift` e adicionar `drift_flutter` (ou `sqlite3_flutter_libs` indireto) se for o caso.
5. Atualizar `AGENTS.md` (linhas 25-32): descrever a nova estrutura `core/database/` com `connection/`, `tables/`, repositories.
6. Atualizar `docs/Services.md`: reescrever seções `WatchlistService`, `PauloFlixDatabaseService`, `PauloFlixMoviesDatabaseService` como repositories. Atualizar tabela "Resumo de Persistência".
7. Atualizar `docs/Models.md`: revisar seções `PauloFlixContent`, `WatchlistAnime`, `DownloadItem` para refletir `genresJson` (JSON) e datas em epoch ms.
8. Atualizar `docs/README.md` (raiz) e `docs/README.md` (docs/): seção "Persistência Local" deve listar **1 banco** (`pauloflix.db`) com 4 tabelas e Drift.
9. Atualizar `docs/IMPROVEMENT_PLAN.md` §1.2 (Database Unificado com drift) — marcar como **executado** e linkar para este documento.
10. Adicionar `docs/MIGRATION_NOTES.md` com o changelog: 1.x → 2.0 (unificação 4→1 banco, Drift como fonte, repositories, padronização de tipos).
11. `flutter analyze` + `flutter test` final.

**Critério de aceite:**

- `grep -r "sqlite3" lib/` retorna apenas o que está dentro de `lib/core/database/connection/` (legado do Drift, encapsulado).
- `grep -r "DatabaseHelper" lib/` retorna 0.
- `grep -r "WatchlistService()" lib/` retorna 0 (todos consomem repository).
- `grep -r "PauloFlixDatabaseService()" lib/` retorna 0.
- App builda e roda idêntico.
- Documentação consistente com o código.

---

## 4. Resumo de impacto (pós-Fase 2)

| Item | Antes (1.0) | Após Fase 2 (atual) | Após Fase 4 (alvo) |
|---|---|---|---|
| Bancos físicos | 5 | 4 (`anime.db` removido) | 1 (`pauloflix.db` unificado) |
| Helpers / services de DB | 5 singletons + 1 helper | 4 services SQLite | 4 repositories + 1 `AppDatabase` |
| Linhas de SQL/boilerplate de DB | ~900 | ~880 (genres codec removido das services) | ~200 (tabelas + 4 repositories) |
| Código-fantasma | 3.312 linhas geradas nunca usadas | 0 (Drift ativo, com `forTesting` + 5 testes in-memory) | 0 |
| Acoplamento widget↔service | Direto (3 widgets × `WatchlistService()`) | Idem (Fase 3) | Via Provider + repository |
| Reatividade | `ChangeNotifier` manual | Idem | `Stream` reativo do Drift + Provider |
| Testes de DB | 0 | 19 (5 Fase 0 + 6 Fase 1 + 8 Fase 2) | 8+ (smoke + migration + 4 repos + 2 integration) |
| Migrations versionadas | Não | Função pura `migrateV1ToV3` testada, **não wired em runtime** | Sim (`schemaVersion: 3`, cresce incrementalmente) |
| PRAGMAs seguros | Não (defaults) | Sim (WAL + FK em 4 services) | Sim |
| `anime.db` write-only | Existe, cresce, ninguém lê | **Removido** | — |
| Datas consistentes | ISO + epoch misturados | ISO em watchlist/PauloFlix, epoch ms em downloads | epoch ms em tudo (Fase 2/3) |
| Gêneros | CSV com ambiguidade | **JSON, sem ambiguidade** | — |
| `LIKE` injection de `%`/`_` | Bug latente | **Corrigido com `ESCAPE '\'`** | — |
| `Download` reset sem persistir | Sim | **Corrigido com `_saveDownload(reset)`** | — |
| Path legacy `<docs parent>/databases/` | 3 services | **4 services (Download agora também)** | — |
| Migration v1→v3 | — | **Função pura testada, idempotente, tolerante** | Wired no boot |

---

## 5. Critérios de aceite globais

O refactor está completo quando, **simultaneamente**:

1. `flutter analyze` retorna **0 issues**.
2. `flutter test` passa com **≥ 8 testes novos** (smoke, migration, 4 repos, 2 integration) além dos já existentes.
3. Smoke test manual cobre: busca (vai pro histórico), adicionar/remover watchlist, baixar/pausar/cancelar download, abrir PauloFlix animes offline, abrir PauloFlix filmes offline, refresh sync.
4. Atualização de uma instalação 1.x (com dados nos 4 bancos legados) preserva todos os dados, sem duplicar, sem crashar.
5. `grep` valida que `DatabaseHelper`, `WatchlistService` (instanciação), `PauloFlixDatabaseService` (instanciação), `PauloFlixMoviesDatabaseService` (instanciação) somem do `lib/`.
6. `AGENTS.md`, `Services.md`, `Models.md`, `README.md` (raiz e docs) refletem a arquitetura nova.
7. `pubspec.yaml` sem dependências mortas.

---

## 6. Riscos globais e mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| Perda de dados na migration v1→v3 | Média | Crítico | Não apagar bancos legados automaticamente; renomear para `.migrated_v3`; testes com snapshots; feature flag para desligar a auto-migration no boot se necessário. |
| drift_dev quebrando build em Windows | Média (já visto no projeto) | Médio | Rodar `dart run build_runner build` uma vez por fase, commitar `.g.dart` localmente para debug; investigar se há incompatibilidade com versão do Flutter. |
| Regressão funcional por migração de widget | Média | Alto | Migração 1 widget por vez, com smoke test manual entre eles; manter service legado em paralelo durante a fase 3. |
| Inconsistência de tipos de data | Média | Médio | Fase 1 padroniza; testes cobrem roundtrip DateTime ↔ INTEGER. |
| Performance do `Stream.watch()` com muita escrita | Baixa | Médio | `PauloFlixProvider` já tem sync batch; `DownloadService` debounce já existe no `_saveDownload` (1 MB interval). |
| Aumento do APK por dependências Drift | Baixa (já está lá) | Baixo | Drift já está em `pubspec.yaml`; remover `sqlite3` + `sqlite3_flutter_libs` se a fase 4 confirmar que não há mais uso direto. |
| `AppDatabase.forTesting` em produção por engano | Baixa | Baixo | Ctor `forTesting` só aceita `QueryExecutor` (que só vem de `NativeDatabase.memory()` em teste); em produção ninguém chama. |

---

## 7. Sequência de execução recomendada

```
Fase 0 (½ d) ──▶ Fase 1 (½ d) ──▶ Fase 2 (1-2 d) ──▶ Fase 3 (1-2 d) ──▶ Fase 4 (½ d)
   │                │                  │                  │                  │
   └─ sem risco     └─ baixo risco     └─ risco médio     └─ risco médio     └─ cleanup
```

**Total estimado: 4-6 dias úteis**, com paralelização possível entre a fase 2 (migration) e o início da fase 3 (criação das interfaces, sem mexer em widget).

---

## 8. Referências cruzadas

- `docs/IMPROVEMENT_PLAN.md:454-580` — plano antigo (1.2 Database Unificado com drift) — substituído por este documento.
- `docs/Services.md` § WatchlistService / PauloFlixDatabaseService / PauloFlixMoviesDatabaseService — a reescrever na fase 4.
- `docs/Models.md` § PauloFlixContent / WatchlistAnime / DownloadItem — a atualizar na fase 4.
- `docs/PAULOFLIX_MOVIES.md` § Riscos & Mitigações ("Banco separado de animes") — risco aceito que será revertido.
- `AGENTS.md` linhas 25-32 — estrutura `core/database/` a atualizar na fase 4.
- `lib/core/database/app_database.dart` — Drift morto a ser reativado na fase 0.
- `lib/core/database/database_helper.dart` — zumbi a ser removido na fase 1.
- `lib/main.dart:5,60` — chamadas ao `DatabaseHelper` a remover na fase 1.
- `lib/ui/search/widgets/anime_search_screen.dart:6,51` — uso órfão do `DatabaseHelper` a redirecionar para `SearchHistoryService` na fase 1.
