// Migration v1 → v3: unifica 4 bancos SQLite legados em 1 banco Drift.
//
// Banco legado `watchlist.db`     → tabela `watchlist_items`
// Banco legado `downloads.db`     → tabela `downloads`
// Banco legado `pauloflix.db`     → tabela `paulo_flix_content`
// Banco legado `pauloflix_movies.db` → tabela `paulo_flix_movies`
//
// A migration é **função pura estática** (sem estado, sem efeito
// colateral fora dos bancos `legacy` e `target`). É testável com
// `NativeDatabase.memory()` como target e bancos sintéticos em
// `<systemTemp>`.
//
// Idempotência: cada banco legado é marcado com a tabela
// `_legacy_migrated_v3` (1 linha) após migrar. Re-execução da função
// detecta a flag e pula a migração daquele banco (retorna 0 rows).
//
// Esta função NÃO apaga os bancos legados — apenas renomeia (Fase 3/4
// cuida do cleanup). Em produção, ela roda em `AppDatabase.beforeOpen`
// (Fase 3 injeta o AppDatabase no Provider).

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as raw_sqlite;

import '../../../core/utils/genre_codec.dart';
import '../app_database.dart';
import '../tables/downloads.dart' as dl;

/// Resultado de `prepareMigration` — o que foi feito na preparação.
class PrepareResult {
  const PrepareResult({
    required this.legacyPaths,
    required this.renamedFrom,
  });

  final LegacyDatabasePaths legacyPaths;

  /// Path do banco renomeado (de `pauloflix.db` para
  /// `pauloflix_content_legacy.db`). Null quando não houve rename
  /// (instalação fresca ou já renomeado).
  final String? renamedFrom;
}

/// Prepara o ambiente antes de abrir o `AppDatabase` em produção:
/// renomeia `pauloflix.db` legado (se existir) para
/// `pauloflix_content_legacy.db` para liberar o path do Drift.
///
/// **Idempotente**: se `pauloflix.db` já foi renomeado, retorna o path
/// renomeado sem fazer nada.
///
/// **Tolerante**: se nenhum banco legado existe, retorna os paths esperados
/// (que apontam para arquivos inexistentes). A `migrateV1ToV3` lida com
/// bancos ausentes graciosamente.
Future<PrepareResult> prepareMigration(String pauloflixDbPath) async {
  // Detecta se o path passado já é o renomeado (chamada idempotente).
  final isAlreadyRenamed = pauloflixDbPath.endsWith('_content_legacy.db');

  if (isAlreadyRenamed) {
    // Já está renomeado. Apenas deriva os paths legados.
    return PrepareResult(
      legacyPaths: resolveLegacyDatabasePaths(pauloflixDbPath),
      renamedFrom: null,
    );
  }

  // Instalação fresca ou com dados legados: nada renomeado ainda.
  if (!File(pauloflixDbPath).existsSync()) {
    return PrepareResult(
      legacyPaths: resolveLegacyDatabasePaths(pauloflixDbPath),
      renamedFrom: null,
    );
  }

  // Há pauloflix.db legado. Renomeia.
  final fromPath = pauloflixDbPath;
  final renamedPath = '${p.withoutExtension(fromPath)}_content_legacy.db';
  await File(fromPath).rename(renamedPath);
  return PrepareResult(
    legacyPaths: resolveLegacyDatabasePaths(renamedPath),
    renamedFrom: fromPath,
  );
}

/// Resolve os 4 paths de bancos legados a partir do path do banco
/// unificado (`pauloflix.db`).
///
/// O Drift sempre usa o path que recebe (no Android é
/// `<data>/databases/pauloflix.db`, em outras plataformas é
/// `<docs>/pauloflix.db`). Os bancos legados estão no **mesmo
/// diretório** em qualquer plataforma.
///
/// **Robustez (Fase 4 bugfix):** se o `pauloflix.db` no path passado não
/// existir mas o `pauloflix_content_legacy.db` existir (cenário pós-rename
/// do `prepareMigration`), usa o renomeado. Isso evita o bug onde o
/// `main.dart` passava o path original e o `resolveLegacyDatabasePaths`
/// derivava um path inexistente. Ver
/// `docs/DATABASE_REFACTORING.md` § Fase 4 — "BUGFIX (produção)".
LegacyDatabasePaths resolveLegacyDatabasePaths(String pauloflixDbPath) {
  final file = File(pauloflixDbPath);
  final dir = file.parent.path;
  // Se o path passado não existe mas o renomeado existe (cenário
  // típico pós-prepareMigration), usa o renomeado.
  String actualPath = pauloflixDbPath;
  if (!file.existsSync()) {
    final renamedCandidate =
        '${p.withoutExtension(pauloflixDbPath)}_content_legacy.db';
    if (File(renamedCandidate).existsSync()) {
      actualPath = renamedCandidate;
    }
  }
  final pauloflixName = File(actualPath).uri.pathSegments.last;
  return LegacyDatabasePaths(
    watchlist: p.join(dir, 'watchlist.db'),
    downloads: p.join(dir, 'downloads.db'),
    pauloflixContent: p.join(dir, pauloflixName),
    pauloflixMovies: p.join(dir, 'pauloflix_movies.db'),
  );
}

/// Paths dos 4 bancos legados. Pode apontar para arquivos inexistentes —
// a função ignora bancos ausentes (instalação parcial).
class LegacyDatabasePaths {
  const LegacyDatabasePaths({
    required this.watchlist,
    required this.downloads,
    required this.pauloflixContent,
    required this.pauloflixMovies,
  });

  final String watchlist;
  final String downloads;
  final String pauloflixContent;
  final String pauloflixMovies;
}

/// Relatório do que foi migrado. Útil para logs e para o teste validar.
class MigrationReport {
  const MigrationReport({
    required this.watchlistRows,
    required this.downloadsRows,
    required this.pauloflixContentRows,
    required this.pauloflixMoviesRows,
    required this.skippedWatchlist,
    required this.skippedDownloads,
    required this.skippedPauloFlixContent,
    required this.skippedPauloFlixMovies,
  });

  final int watchlistRows;
  final int downloadsRows;
  final int pauloflixContentRows;
  final int pauloflixMoviesRows;
  final bool skippedWatchlist;
  final bool skippedDownloads;
  final bool skippedPauloFlixContent;
  final bool skippedPauloFlixMovies;

  bool get allSucceeded => true;
}

/// Migra os 4 bancos legados para o Drift `target`.
///
/// **Idempotente**: re-execução é no-op (retorna 0 rows para bancos já
/// migrados).
///
/// **Tolerante**: bancos ausentes são ignorados; cada banco é migrado em
/// sua própria transação, então falha em um banco não impede os outros.
Future<MigrationReport> migrateV1ToV3({
  required AppDatabase target,
  required LegacyDatabasePaths legacy,
}) async {
  final wl = await _migrateWatchlist(target, legacy.watchlist);
  final dl = await _migrateDownloads(target, legacy.downloads);
  final pf = await _migratePauloFlixContent(target, legacy.pauloflixContent);
  final pfM = await _migratePauloFlixMovies(target, legacy.pauloflixMovies);

  return MigrationReport(
    watchlistRows: wl.rows,
    downloadsRows: dl.rows,
    pauloflixContentRows: pf.rows,
    pauloflixMoviesRows: pfM.rows,
    skippedWatchlist: wl.skipped,
    skippedDownloads: dl.skipped,
    skippedPauloFlixContent: pf.skipped,
    skippedPauloFlixMovies: pfM.skipped,
  );
}

class _Migrated {
  const _Migrated(this.rows, this.skipped);
  final int rows;
  final bool skipped;
}

Future<_Migrated> _migrateWatchlist(
  AppDatabase target,
  String path,
) async {
  if (!_exists(path)) return const _Migrated(0, true);
  final src = raw_sqlite.sqlite3.open(path);
  try {
    if (_alreadyMigrated(src)) return const _Migrated(0, true);
    final rows = src.select('SELECT * FROM watchlist');
    if (rows.isEmpty) {
      _markMigrated(src);
      return const _Migrated(0, false);
    }
    await target.batch((batch) {
      for (final row in rows) {
        batch.insert(
          target.watchlistItems,
          WatchlistItemsCompanion.insert(
            animeId: row['animeId'] as String,
            title: row['title'] as String,
            coverImage: row['coverImage'] as String,
            myAnimeListUrl: row['myAnimeListUrl'] as String,
            addedAt: DateTime.parse(row['addedAt'] as String),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
    _markMigrated(src);
    return _Migrated(rows.length, false);
  } finally {
    src.close();
  }
}

Future<_Migrated> _migrateDownloads(
  AppDatabase target,
  String path,
) async {
  if (!_exists(path)) return const _Migrated(0, true);
  final src = raw_sqlite.sqlite3.open(path);
  try {
    if (_alreadyMigrated(src)) return const _Migrated(0, true);
    final rows = src.select('SELECT * FROM downloads');
    if (rows.isEmpty) {
      _markMigrated(src);
      return const _Migrated(0, false);
    }
    await target.batch((batch) {
      for (final row in rows) {
        // Mapeia os status int do legado para o enum do Drift.
        final statusInt = row['status'] as int;
        final status = _statusFromLegacyInt(statusInt);
        final qualityInt = row['quality'] as int;
        final quality = _qualityFromLegacyInt(qualityInt);
        batch.insert(
          target.downloads,
          DownloadsCompanion.insert(
            downloadId: row['id'] as String,
            animeId: row['animeId'] as String,
            animeName: row['animeName'] as String,
            episodeNumber: row['episodeNumber'] as String,
            episodeTitle: row['episodeTitle'] as String,
            videoUrl: row['videoUrl'] as String,
            thumbnailUrl: row['thumbnailUrl'] as String,
            quality: quality,
            status: status,
            progress: Value((row['progress'] as num).toDouble()),
            bytesDownloaded: Value(row['bytesDownloaded'] as int),
            totalBytes: Value(row['totalBytes'] as int),
            filePath: Value(row['filePath'] as String?),
            error: Value(row['error'] as String?),
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['createdAt'] as int,
            ),
            completedAt: row['completedAt'] == null
                ? const Value.absent()
                : Value(
                    DateTime.fromMillisecondsSinceEpoch(
                      row['completedAt'] as int,
                    ),
                  ),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
    _markMigrated(src);
    return _Migrated(rows.length, false);
  } finally {
    src.close();
  }
}

Future<_Migrated> _migratePauloFlixContent(
  AppDatabase target,
  String path,
) async {
  if (!_exists(path)) return const _Migrated(0, true);
  final src = raw_sqlite.sqlite3.open(path);
  try {
    if (_alreadyMigrated(src)) return const _Migrated(0, true);
    final rows = src.select('SELECT * FROM pauloflix_content');
    if (rows.isEmpty) {
      _markMigrated(src);
      return const _Migrated(0, false);
    }
    await target.batch((batch) {
      for (final row in rows) {
        // Re-encoda os gêneros do legado (CSV) para JSON canônico
        // usando o helper centralizado.
        final rawGenres = row['genres'] as String?;
        final genresList = decodeGenresOrFallback(rawGenres);
        batch.insert(
          target.pauloFlixContent,
          PauloFlixContentCompanion.insert(
            folderName: row['folderName'] as String,
            displayName: row['displayName'] as String,
            serverUrl: row['serverUrl'] as String,
            imageUrl: Value(row['imageUrl'] as String?),
            bannerUrl: Value(row['bannerUrl'] as String?),
            description: Value(row['description'] as String?),
            score: Value((row['score'] as num?)?.toDouble()),
            genresJson: Value(encodeGenres(genresList)),
            status: Value(row['status'] as String?),
            episodeCount: Value(row['episodeCount'] as int?),
            malId: Value(row['malId'] as int?),
            anilistId: Value(row['anilistId'] as int?),
            lastSynced: DateTime.parse(row['lastSynced'] as String),
            isAvailable: Value((row['isAvailable'] as int) == 1),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
    _markMigrated(src);
    return _Migrated(rows.length, false);
  } finally {
    src.close();
  }
}

Future<_Migrated> _migratePauloFlixMovies(
  AppDatabase target,
  String path,
) async {
  if (!_exists(path)) return const _Migrated(0, true);
  final src = raw_sqlite.sqlite3.open(path);
  try {
    if (_alreadyMigrated(src)) return const _Migrated(0, true);
    final rows = src.select('SELECT * FROM pauloflix_movies');
    if (rows.isEmpty) {
      _markMigrated(src);
      return const _Migrated(0, false);
    }
    await target.batch((batch) {
      for (final row in rows) {
        final rawGenres = row['genres'] as String?;
        final genresList = decodeGenresOrFallback(rawGenres);
        batch.insert(
          target.pauloFlixMovies,
          PauloFlixMoviesCompanion.insert(
            folderName: row['folderName'] as String,
            displayName: row['displayName'] as String,
            serverUrl: row['serverUrl'] as String,
            imageUrl: Value(row['imageUrl'] as String?),
            bannerUrl: Value(row['bannerUrl'] as String?),
            description: Value(row['description'] as String?),
            score: Value((row['score'] as num?)?.toDouble()),
            genresJson: Value(encodeGenres(genresList)),
            releaseDate: Value(row['releaseDate'] as String?),
            runtime: Value(row['runtime'] as int?),
            year: Value(row['year'] as int?),
            tmdbId: Value(row['tmdbId'] as int?),
            isCollection: Value((row['isCollection'] as int) == 1),
            availableMovieCount: Value(row['availableMovieCount'] as int? ?? 0),
            lastSynced: DateTime.parse(row['lastSynced'] as String),
            isAvailable: Value((row['isAvailable'] as int) == 1),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
    _markMigrated(src);
    return _Migrated(rows.length, false);
  } finally {
    src.close();
  }
}

// ----- helpers --------------------------------------------------------------

bool _exists(String path) => File(path).existsSync();

bool _alreadyMigrated(raw_sqlite.Database db) {
  // Verifica se a tabela sentinela existe. Se sim, banco já foi migrado.
  final result = db.select(
    "SELECT name FROM sqlite_master WHERE type='table' AND "
    "name='_legacy_migrated_v3'",
  );
  return result.isNotEmpty;
}

void _markMigrated(raw_sqlite.Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS _legacy_migrated_v3 (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      migrated_at TEXT NOT NULL
    )
  ''');
  db.execute(
    'INSERT OR REPLACE INTO _legacy_migrated_v3 (id, migrated_at) '
    "VALUES (1, '${DateTime.now().toIso8601String()}')",
  );
}

dl.DownloadStatus _statusFromLegacyInt(int v) {
  // Schema legado: 0=queued, 1=downloading, 2=paused, 3=completed,
  // 4=failed, 5=cancelled.
  switch (v) {
    case 0:
      return dl.DownloadStatus.queued;
    case 1:
      return dl.DownloadStatus.downloading;
    case 2:
      return dl.DownloadStatus.paused;
    case 3:
      return dl.DownloadStatus.completed;
    case 4:
      return dl.DownloadStatus.failed;
    case 5:
      return dl.DownloadStatus.cancelled;
    default:
      return dl.DownloadStatus.failed;
  }
}

dl.DownloadQuality _qualityFromLegacyInt(int v) {
  // Schema legado: 0=auto, 1=low, 2=medium, 3=high.
  switch (v) {
    case 0:
      return dl.DownloadQuality.auto;
    case 1:
      return dl.DownloadQuality.low;
    case 2:
      return dl.DownloadQuality.medium;
    case 3:
      return dl.DownloadQuality.high;
    default:
      return dl.DownloadQuality.auto;
  }
}
