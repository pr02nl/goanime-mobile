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

1. **Um único banco físico** (`goanime.db`) com todas as tabelas, gerenciado por Drift.
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

Cada fase é **independente** e entregável. Se algo travar, dá para parar entre fases
sem deixar o app quebrado (Drift + service antigo rodam lado a lado durante
a migração — Drift lê do banco novo, services leem dos bancos velhos).

### Fase 0 — Preparação (½ dia, sem mudança de comportamento)

**Objetivo:** criar o esqueleto Drift pronto para receber migrations.

**Tarefas:**

1. Adicionar `app_database.g.dart` ao `.gitignore` (padrão Flutter).
2. Criar `lib/core/database/connection/connection.dart` com:
   - `LazyDatabase` apontando para `<docs>/goanime.db` (e fallback legacy `<docs parent>/databases/goanime.db` no Android).
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

### Fase 1 — Limpeza cirúrgica (½ dia, ganha terreno)

**Objetivo:** eliminar código morto antes de migrar.

**Tarefas:**

1. **Remover `DatabaseHelper`** (`lib/core/database/database_helper.dart`).
2. Remover o import e a chamada em `lib/main.dart:5` e `lib/main.dart:60`.
3. Remover o import e a chamada em `lib/ui/search/widgets/anime_search_screen.dart:6,51`. Substituir `addAnimeNames(...)` por uma chamada a `SearchHistoryService.addSearch(query)` (já existe) — mantém a semântica de "lembrar do que o usuário buscou" usando o sistema de histórico que **é** lido de volta.
4. Adicionar `PRAGMA foreign_keys = ON` e `PRAGMA journal_mode = WAL` nos 4 services legados restantes (Watchlist, PauloFlix, PauloFlixMovies, Download).
5. Em `PauloFlixDatabaseService.searchByName` e `PauloFlixMoviesDatabaseService.searchByName`, trocar `'%$query%'` por `LIKE ? ESCAPE '\'` com `query.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')`.
6. Em `PauloFlixContent.toMap` / `fromMap` e `PauloFlixMovie.toMap` / `fromMap`, trocar `genres.join(',')` / `split(',')` por `jsonEncode(genres)` / `jsonDecode`.
7. Padronizar datas: converter `watchlist.addedAt` e `pauloflix_content.lastSynced` de ISO `TEXT` para `INTEGER` epoch ms. Idem `createdAt`/`completedAt` (já são INTEGER em downloads).
8. Corrigir `DownloadService._loadDownloads`: após `copyWith(status: queued)`, chamar `_saveDownload(...)` para persistir a mudança.
9. Em `DownloadService._initDatabase`, replicar a lógica de `_resolveDatabasePath` das outras 3 services (com fallback para `<docs parent>/databases/`).

**Critério de aceite:**

- 5 bancos continuam funcionando, mas `anime.db` deixa de existir.
- `flutter analyze` 0 issues.
- `flutter test` passa (testes existentes + 1 novo: `watchlist_service_test.dart` cobrindo add/remove/clear em banco temp).
- Nenhuma regressão funcional observada manualmente em: busca, watchlist, download, sync PauloFlix animes, sync PauloFlix filmes.

**Riscos:**

- Mudar ISO → epoch ms pode quebrar se algum widget usar `DateTime.parse(addedAt)` esperando string. Mitigação: `flutter analyze` pega os casts, mais um teste manual.
- CSV → JSON nos gêneros: nenhum consumer usa `.split(',')` fora dos próprios `fromMap`; confirmado.

---

### Fase 2 — Migrations: unificar 4 bancos em 1 (1-2 dias, ponto crítico)

**Objetivo:** consolidar watchlist + downloads + pauloflix_content + pauloflix_movies em um único `goanime.db` gerenciado por Drift, **migrando dados dos bancos legados**.

**Tarefas:**

1. Criar `lib/core/database/connection/migration_v1_to_v3.dart` com:
   - Detecção de bancos legados: `watchlist.db`, `downloads.db`, `pauloflix.db`, `pauloflix_movies.db` (no `<docs>` ou no legacy `<docs parent>/databases/`).
   - Para cada banco legado existente:
     - Abrir com `sqlite3.open(path)`.
     - `SELECT *` de cada tabela legada.
     - Para cada linha, fazer `INSERT OR REPLACE` no novo `goanime.db` via Drift.
     - **Cuidado com tipos**: se a fase 1 já padronizou para epoch ms, é direto. Senão, converter ISO → epoch ms aqui.
     - **Cuidado com `genres`**: se a fase 1 já converteu para JSON, é direto. Senão, parsear CSV → JSON aqui.
     - Marcar o banco legado com uma tabela `_legacy_migrated_v3` para não migrar duas vezes.
   - Após migração bem-sucedida, opcionalmente renomear `<file>.db` para `<file>.db.migrated_v3` (não apagar — segurança).
2. No `MigrationStrategy.onCreate` de `AppDatabase`, chamar a mesma função de migração (caso o usuário esteja com bancos legados e Drift precise criar a estrutura nova).
3. Adicionar teste em `test/database/migration_v1_to_v3_test.dart` que:
   - Cria 4 bancos SQLite temporários (sqlite3 puro) com schema legacy.
   - Popula com dados representativos (incluindo `genres` com vírgula, datas ISO).
   - Instancia `AppDatabase` apontando para o mesmo path (ou `NativeDatabase.memory()`).
   - Roda migration.
   - Verifica que os dados foram migrados com tipos corretos.

**Critério de aceite:**

- Instalação fresca: app cria `goanime.db` único.
- Atualização de 1.x: app migra os 4 bancos legados para o novo, sem perda de dados, sem duplicar.
- Se migration falhar no meio: banco novo fica intacto, dados legados preservados, usuário pode re-tentar.
- `flutter analyze` + `flutter test` passam.
- App não é injetado com `AppDatabase` ainda — Drift **só** roda a migration na primeira vez que for instanciado, mas como ninguém instancia, **não roda em produção ainda**. Esta fase é puramente teste/validação.

**Riscos (CRÍTICOS):**

- **Perda de dados** se migration tem bug. Mitigação: nunca apagar bancos legados automaticamente; renomear para `.migrated_v3`; logs explícitos; testes de migração com dados reais (snapshot anônimo).
- **Migration durante boot async**: rodar no `onCreate` do Drift pode segurar o `main()` por segundos em devices lentos. Mitigação: mostrar splash/loading; considerar mover para background isolado (`compute()`) se demorar mais de 500 ms.
- **Schema drift entre legado e novo**: se a fase 1 não foi feita, CSV/ISO precisam ser tratados aqui. **Recomendação forte: não pular a fase 1**.

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
- Apenas 1 banco físico (`goanime.db`) é tocado em runtime.
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
8. Atualizar `docs/README.md` (raiz) e `docs/README.md` (docs/): seção "Persistência Local" deve listar **1 banco** (`goanime.db`) com 4 tabelas e Drift.
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

## 4. Resumo de impacto

| Item | Antes | Depois |
|---|---|---|
| Bancos físicos | 5 | 1 |
| Helpers / services de DB | 5 singletons + 1 helper | 4 repositories + 1 `AppDatabase` |
| Linhas de SQL/boilerplate de DB | ~900 | ~200 (tabelas + 4 repositories) |
| Código-fantasma | 3.312 linhas geradas nunca usadas | 0 |
| Acoplamento widget↔service | Direto (3 widgets × `WatchlistService()`) | Via Provider + repository |
| Reatividade | `ChangeNotifier` manual | `Stream` reativo do Drift + Provider |
| Testes de DB | 0 | 8+ (smoke + migration + 4 repos + 2 integration) |
| Migrations versionadas | Não | Sim (`schemaVersion: 3`, cresce incrementalmente) |
| PRAGMAs seguros | Não (defaults) | WAL + foreign_keys |
| `anime.db` write-only | Existe, cresce, ninguém lê | Removido |
| Datas consistentes | ISO + epoch misturados | epoch ms em tudo |
| Gêneros | CSV com ambiguidade | JSON, sem ambiguidade |
| `LIKE` injection de `%`/`_` | Bug latente | `ESCAPE` explícito |

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
