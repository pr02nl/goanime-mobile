import 'package:drift/drift.dart';

import 'connection/connection.dart';
import 'tables/downloads.dart';
import 'tables/paulo_flix_episodes.dart';
import 'tables/paulo_flix_seasons.dart';
import 'tables/pauloflix_content.dart';
import 'tables/pauloflix_movies.dart';
import 'tables/tmdb_genres.dart';
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
    TmdbGenres,
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

  /// Schema começa em **5**:
  /// * v1-v3: cobre todas as instalações 1.x e 2.x (versões que tinham
  ///   bancos legados separados).
  /// * v4 (2026-06-22): adiciona tabela `tmdb_genres` para cache do
  ///   mapeamento `genreId → nome` da API TMDB (resolvido em pt-BR/en-US).
  /// * v5 (2026-06-22): adiciona tabelas `paulo_flix_seasons` e
  ///   `paulo_flix_episodes` para persistir seasons, episódios assistidos,
  ///   tempo assistido e flag de temporada completa. Ver plano
  ///   `.hermes/plans/2026-06-22_2230-pauloflix-episodes-progress.md`.
  /// * v6 (2026-06-23): adiciona coluna `thumbnailUrl` em
  ///   `paulo_flix_episodes` para suportar o padrão Kodi de thumb de
  ///   episode. Ver plano
  ///   `.hermes/plans/2026-06-23_224213-pauloflix-nfo-enrichment.md`.
  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // A lógica de importação dos bancos legados roda na Fase 2
          // (ver `docs/DATABASE_REFACTORING.md` §3).
        },
        // Migrations futuras (1.x → 3) implementadas na Fase 2.
        onUpgrade: (m, from, to) async {
          // v3 → v4: adiciona tabela tmdb_genres.
          if (from < 4) {
            // `Migrator.database` é tipado como `GeneratedDatabase` (base),
            // mas em runtime é a nossa `AppDatabase`. Cast para acessar
            // os getters gerados.
            final db = m.database as AppDatabase;
            await m.createTable(db.tmdbGenres);
          }
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
