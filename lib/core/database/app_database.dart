import 'package:drift/drift.dart';

import 'connection/connection.dart';
import 'tables/downloads.dart';
import 'tables/paulo_flix_episodes.dart';
import 'tables/paulo_flix_seasons.dart';
import 'tables/paulo_flix_movie_progress.dart';
import 'tables/pauloflix_content.dart';
import 'tables/pauloflix_movies.dart';
import 'tables/watchlist_items.dart';

part 'app_database.g.dart';

/// Banco unificado do PauloFlix (Fase 0 da refatoração descrita em
/// `docs/DATABASE_REFACTORING.md`).
///
/// Substitui a coexistência de 4 bancos SQLite brutos
/// (`watchlist.db`, `downloads.db`, `pauloflix.db`, `pauloflix_movies.db`)
/// e 1 banco Drift-fantasma por uma única fonte de verdade.
///
/// **Estado atual (Fase 0):** o `AppDatabase` está pronto para uso mas
/// **não é instanciado em runtime**. Os services legados (Watchlist,
/// PauloFlix, PauloFlixMovies, Download) continuam usando sqlite3 FFI até a
/// Fase 3.
@DriftDatabase(
  tables: [
    WatchlistItems,
    Downloads,
    PauloFlixContent,
    PauloFlixMovies,
    PauloFlixSeasons,
    PauloFlixEpisodes,
    PauloFlixMovieProgress,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Ctor de produção: abre `pauloflix.db` no diretório de documentos
  /// (com fallback legacy no Android).
  AppDatabase() : super(openConnection());

  /// Ctor de teste: aceita qualquer `QueryExecutor` (em produção ninguém
  /// chama — usado por `test/database/app_database_test.dart` com
  /// `NativeDatabase.memory()`).
  AppDatabase.forTesting(super.executor);

  /// Schema começa em **8**:
  /// * v1-v3: cobre todas as instalações 1.x e 2.x (versões que tinham
  ///   bancos legados separados).
  /// * v4 (2026-06-22): adiciona tabela `tmdb_genres` para cache do
  ///   mapeamento `genreId → nome` da API TMDB (resolvido em pt-BR/en-US).
  /// * v5 (2026-06-22): adiciona tabelas `paulo_flix_seasons` e
  ///   `paulo_flix_episodes` para persistir seasons, episódios assistidos,
  ///   tempo assistido e flag de temporada completa. Ver plano
  ///   `.hermes/plans/2026-06-22_2230-pauloflix-episodes-progress.md`.
  /// * v6 (2026-06-23): adiciona `thumbnailUrl` em `paulo_flix_episodes`
  ///   (Fase 0 do plano NFO enrichment V1). Ver plano
  ///   `.hermes/plans/2026-06-23_224213-pauloflix-nfo-enrichment.md`.
  /// * v7 (2026-06-23): adiciona `description` em
  ///   `paulo_flix_seasons` e `paulo_flix_episodes` para popular
  ///   plot/description de `season.nfo` e `S01E{nnn}.nfo`. Ver plano
  ///   `.hermes/plans/2026-06-23_225500-pauloflix-nfo-enrichment-v2.md`.
  /// * v8 (2026-06-23): adiciona `posterFileName`/`fanartFileName` em
  ///   `paulo_flix_seasons` para popular imagens de season via
  ///   fallback em `poster.jpg`/`fanart.jpg` (análogo ao que
  ///   `PauloFlixMovieRaw` faz para filmes).
  /// * v9 (Fase N+7 — schema NFO V2): adiciona 5 colunas em
  ///   `paulo_flix_episodes` para persistir os campos do NFO V2
  ///   que o parser leu no commit `d486800`:
  ///   - `original_title` (TextColumn?) — `<originaltitle>`
  ///   - `outline` (TextColumn?) — `<outline>`
  ///   - `aired` (DateTimeColumn?) — `<aired>` (formato YYYY-MM-DD)
  ///   - `rating` (RealColumn?) — `<rating>`
  ///   - `runtime` (IntColumn?) — `<runtime>` (em minutos)
  ///   Sem migration data — o próximo sync repopula em background.
  /// * v10 (2026-06-27): adiciona `original_title`, `year`, `tmdb_id` em
  ///   `paulo_flix_content` para persistir metadados do JSON index
  ///   (`tv_index.json` / `movie_index.json`). Sem migration data — o
  ///   próximo sync repopula em background.
  /// * v11 (2026-06-27): adiciona tabela `paulo_flix_movie_progress`
  ///   para persistir progresso de playback de filmes (P1 do módulo
  ///   de filmes). Sem migration data — preenchida pelo player.
  /// * v12 (2026-06-27): adiciona `video_url` e `subtitles_json` em
  ///   `paulo_flix_movies` para persistir URL direta do vídeo e
  ///   legendas externas vindas do `movie_index.json` (campos `file`
  ///   e `subtitles`). Elimina scraping on-demand para filmes com
  ///   índice atualizado. Sem migration data — o próximo sync
  ///   popula em background.
  /// * v13 (2026-06-27): remove a coluna `is_collection` de
  ///   `paulo_flix_movies` — coleções foram eliminadas, cada filme
  ///   tem entrada própria no JSON index. A coluna orfã existente
  ///   em bancos legados é removida via `ALTER TABLE ... DROP COLUMN`.
  ///   Sem migration data — a coluna não era mais usada pelo código.
  /// * v14 (2026-06-29): adiciona 3 índices no banco para otimizar
  ///   as queries identificadas na auditoria de performance:
  ///   - `idx_episodes_in_progress` em `paulo_flix_episodes`
  ///     (`is_completed`, `position_seconds`, `last_watched`)
  ///     → cobre a query "Continue assistindo" (full scan evitado).
  ///   - `idx_episodes_season_completed` em `paulo_flix_episodes`
  ///     (`season_id`, `is_completed`)
  ///     → cobre `_recomputeSeasonCompleted` (2 full scans evitados).
  ///   - `idx_content_available` em `paulo_flix_content`
  ///     (`is_available`)
  ///     → cobre o filtro de disponibilidade nos JOINs da home.
  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Cria os índices customizados que não fazem parte das definições
      // de tabela Drift (@Index). Novas instalações também precisam
      // deles — só m.createAll() não é suficiente.
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_episodes_in_progress '
        'ON paulo_flix_episodes('
        'is_completed, position_seconds, last_watched)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_episodes_season_completed '
        'ON paulo_flix_episodes(season_id, is_completed)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_content_available '
        'ON paulo_flix_content(is_available)',
      );
      // A lógica de importação dos bancos legados roda na Fase 2
      // (ver `docs/DATABASE_REFACTORING.md` §3).
    },
    // Migrations futuras (1.x → 3) implementadas na Fase 2.
    onUpgrade: (m, from, to) async {
      // v4 → v5: adiciona tabelas paulo_flix_seasons e paulo_flix_episodes
      // (Fase 0 do plano de progresso). Cria seasons PRIMEIRO porque
      // episodes tem FK para seasons.
      if (from < 5) {
        final db = m.database as AppDatabase;
        await m.createTable(db.pauloFlixSeasons);
        await m.createTable(db.pauloFlixEpisodes);
      }
      // v5 → v6: adiciona coluna thumbnailUrl em paulo_flix_episodes
      // (Fase 0 do plano NFO enrichment). Sem migration data — o
      // sync vai popular em background nas próximas horas.
      if (from < 6) {
        // Cast necessário: `Migrator.database` é tipado como
        // `GeneratedDatabase` (base), mas em runtime é a nossa
        // `AppDatabase`. Mesmo padrão usado em v3→v4 e v4→v5 acima.
        final db = m.database as AppDatabase;
        await m.addColumn(
          db.pauloFlixEpisodes,
          db.pauloFlixEpisodes.thumbnailUrl,
        );
      }
      // v6 → v7: adiciona coluna `description` em paulo_flix_seasons
      // e paulo_flix_episodes (Fase 10 do plano NFO enrichment V2).
      // Sem migration data — o sync vai popular em background nas
      // próximas horas (lê de season.nfo e S01E{nnn}.nfo).
      //
      // NOTA: usamos `customStatement` (raw SQL) em vez de
      // `m.addColumn(db.pauloFlixSeasons, db.pauloFlixSeasons.description)`
      // porque o getter `description` ainda não está gerado em
      // `app_database.g.dart` (Fase 11 é owner do .g.dart e
      // adiciona o getter em paralelo). O raw SQL tem o mesmo
      // efeito (ALTER TABLE ADD COLUMN) e não depende do codegen.
      if (from < 7) {
        final db = m.database as AppDatabase;
        await db.customStatement(
          'ALTER TABLE paulo_flix_seasons ADD COLUMN description TEXT',
        );
        await db.customStatement(
          'ALTER TABLE paulo_flix_episodes ADD COLUMN description TEXT',
        );
      }
      // v7 → v8: adiciona posterFileName/fanartFileName em
      // paulo_flix_seasons para popular imagens de season via
      // fallback em `poster.jpg`/`fanart.jpg` (análogo ao que
      // `PauloFlixMovieRaw` faz para filmes). Mesma técnica
      // raw-SQL do v6→v7 (customStatement) para não depender
      // do codegen — o .g.dart é patcheado em paralelo.
      if (from < 8) {
        final db = m.database as AppDatabase;
        await db.customStatement(
          'ALTER TABLE paulo_flix_seasons '
          'ADD COLUMN poster_file_name TEXT',
        );
        await db.customStatement(
          'ALTER TABLE paulo_flix_seasons '
          'ADD COLUMN fanart_file_name TEXT',
        );
      }
      // v8 → v9: adiciona 5 colunas V2 (Fase N+7) em
      // paulo_flix_episodes: original_title, outline, aired,
      // rating, runtime. Mesma técnica raw-SQL do v6→v7 e v7→v8
      // (customStatement) para não depender do codegen — o
      // .g.dart é patcheado em paralelo na mesma task. Sem
      // migration data — o sync repopula em background.
      if (from < 9) {
        final db = m.database as AppDatabase;
        await db.customStatement(
          'ALTER TABLE paulo_flix_episodes '
          'ADD COLUMN original_title TEXT',
        );
        await db.customStatement(
          'ALTER TABLE paulo_flix_episodes '
          'ADD COLUMN outline TEXT',
        );
        await db.customStatement(
          'ALTER TABLE paulo_flix_episodes '
          'ADD COLUMN aired INTEGER',
        );
        await db.customStatement(
          'ALTER TABLE paulo_flix_episodes '
          'ADD COLUMN rating REAL',
        );
        await db.customStatement(
          'ALTER TABLE paulo_flix_episodes '
          'ADD COLUMN runtime INTEGER',
        );
      }
      // v9 → v10: adiciona colunas original_title, year, tmdb_id em
      // paulo_flix_content para persistir metadados do JSON index.
      // Sem migration data — o próximo sync repopula em background.
      // v10 → v11: adiciona tabela paulo_flix_movie_progress
    // para persistir progresso de playback de filmes.
    if (from < 11) {
      final db = m.database as AppDatabase;
      await m.createTable(db.pauloFlixMovieProgress);
    }

    // v11 → v12: adiciona colunas video_url e subtitles_json em
    // paulo_flix_movies para persistir URL direta do vídeo e
    // legendas externas do movie_index.json. Sem migration data —
    // o próximo sync popula em background.
    if (from < 12) {
      final db = m.database as AppDatabase;
      await db.customStatement(
        'ALTER TABLE paulo_flix_movies ADD COLUMN video_url TEXT',
      );
      await db.customStatement(
        'ALTER TABLE paulo_flix_movies ADD COLUMN subtitles_json TEXT',
      );
    }

    // v12 → v13: remove coluna is_collection de paulo_flix_movies.
    // SQLite DROP COLUMN é suportado desde 3.35.0 (2021-03-12).
    // A coluna já está removida do código (modelo, repositório,
    // widgets); esta migration limpa o schema físico.
    if (from < 13) {
      final db = m.database as AppDatabase;
      await db.customStatement(
        'ALTER TABLE paulo_flix_movies DROP COLUMN is_collection',
      );
    }

    // v13 → v14: adiciona 3 índices para otimizar queries.
    // `CREATE INDEX IF NOT EXISTS` é seguro para re-execução
    // (caso a migration interrompa no meio).
    if (from < 14) {
      final db = m.database as AppDatabase;
      await db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_episodes_in_progress '
        'ON paulo_flix_episodes('
        'is_completed, position_seconds, last_watched)',
      );
      await db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_episodes_season_completed '
        'ON paulo_flix_episodes(season_id, is_completed)',
      );
      await db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_content_available '
        'ON paulo_flix_content(is_available)',
      );
    }

    if (from < 10) {
        final db = m.database as AppDatabase;
        await db.customStatement(
          'ALTER TABLE paulo_flix_content '
          'ADD COLUMN original_title TEXT',
        );
        await db.customStatement(
          'ALTER TABLE paulo_flix_content '
          'ADD COLUMN year INTEGER',
        );
        await db.customStatement(
          'ALTER TABLE paulo_flix_content '
          'ADD COLUMN tmdb_id INTEGER',
        );
      }
    },
    // CRÍTICO: configurar `busy_timeout` ANTES de qualquer operação
    // de migration. Sem isso, qualquer DDL em uma instalação que
    // ficou em estado inconsistente (lock órfão do SQLite após crash
    // do app) falha com `SQLITE_BUSY (5) — database is locked`.
    //
    // O padrão SQLite é 0ms (falha imediata). 5s dá tempo suficiente
    // para outra conexão liberar o lock (ex: hot-reload do debug
    // segurando handle antigo).
    beforeOpen: (details) async {
      // CRÍTICO: `busy_timeout = 5000` evita `SQLITE_BUSY (5)` em
      // DDL quando o banco ficou em estado inconsistente (lock órfão
      // do SQLite após crash do app ou hot-reload do debug segurando
      // handle antigo). Padrão SQLite é 0ms (falha imediata).
      await customStatement('PRAGMA busy_timeout = 5000');
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );
}
