import 'package:drift/drift.dart';

import 'connection/connection.dart';
import 'tables/downloads.dart';
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
  tables: [WatchlistItems, Downloads, PauloFlixContent, PauloFlixMovies],
)
class AppDatabase extends _$AppDatabase {
  /// Ctor de produção: abre `pauloflix.db` no diretório de documentos
  /// (com fallback legacy no Android).
  AppDatabase() : super(openConnection());

  /// Ctor de teste: aceita qualquer `QueryExecutor` (em produção ninguém
  /// chama — usado por `test/database/app_database_test.dart` com
  /// `NativeDatabase.memory()`).
  AppDatabase.forTesting(super.executor);

  /// Schema começa em **3** porque cobre todas as instalações 1.x e 2.x
  /// (versões que tinham bancos legados separados).
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // A lógica de importação dos bancos legados roda na Fase 2
          // (ver `docs/DATABASE_REFACTORING.md` §3).
        },
        // Migrations futuras (1.x → 3) implementadas na Fase 2.
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
        },
      );
}
