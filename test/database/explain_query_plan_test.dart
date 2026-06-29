import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';

/// Smoke test que verifica, via `EXPLAIN QUERY PLAN`, se os índices
/// (v14 + v15) estão sendo usados pelo SQLite nas queries principais.
///
/// ## Metodologia
///
/// 1. Abre AppDatabase v15 em memória.
/// 2. Insere dados de amostra (conteúdos, seasons, episodes, progresso).
/// 3. Para cada query principal, roda `EXPLAIN QUERY PLAN <query>`.
/// 4. Verifica que o detail contém o índice esperado.
///
/// ## Índices testados
///
/// - `idx_episodes_in_progress` (v14) — continue assistindo
/// - `idx_episodes_season_completed` (v14) — recompute season
/// - `idx_content_available` (v14) — filtro is_available
/// - `idx_seasons_content` (v15 NOVO) — getSeasonsForContent
/// - `idx_episodes_season_number` (v15 NOVO) — getEpisodesForSeason
/// - `idx_content_search` (v15 NOVO) — searchByName animes
/// - `idx_movies_search` (v15 NOVO) — searchByName filmes
void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  /// Executa EXPLAIN QUERY PLAN e retorna as linhas.
  Future<List<ExplainRow>> explain(AppDatabase db, String sql,
      {List<Variable> variables = const []}) async {
    final rows = await db.customSelect('EXPLAIN QUERY PLAN $sql',
            variables: variables)
        .get();
    return rows
        .map((r) => ExplainRow(
              r.read<int>('id'),
              r.read<int>('parent'),
              r.read<String>('detail'),
            ))
        .toList();
  }

  /// Verifica que pelo menos uma linha do EXPLAIN contém o nome do índice.
  void expectIndexUsed(List<ExplainRow> rows, String indexName) {
    final found = rows.any((r) => r.detail.contains(indexName));
    expect(found, isTrue,
        reason: 'Índice "$indexName" NÃO foi usado no plan:\n'
            '${rows.map((r) => '  id=${r.id} parent=${r.parent} ${r.detail}').join('\n')}');
  }

  /// Verifica que nenhum full scan de tabela ocorreu (SEARCH TABLE ... WITHOUT ROWID)
  void expectNoFullScan(List<ExplainRow> rows, String tableName) {
    final fullScans = rows
        .where((r) =>
            r.detail.contains('SCAN TABLE $tableName') &&
            !r.detail.contains('USING INDEX') &&
            !r.detail.contains('USING COVERING INDEX'))
        .toList();
    expect(fullScans, isEmpty,
        reason: 'Full scan em $tableName detectado no plan:\n'
            '${rows.map((r) => '  id=${r.id} parent=${r.parent} ${r.detail}').join('\n')}');
  }

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());

    // ── Insere 3 animes ──────────────────────────────────────────
    final contentIds = <int>[];
    for (final name in ['Naruto', 'Bleach', 'One Piece']) {
      final id = await db.into(db.pauloFlixContent).insert(
            PauloFlixContentCompanion.insert(
              folderName: name,
              displayName: name,
              serverUrl: 'https://s/$name/',
              lastSynced: DateTime.now(),
            ),
          );
      contentIds.add(id);
    }

    // ── Cada anime: 2 seasons, cada season: 5 episodes ──────────
    for (final cid in contentIds) {
      for (int s = 1; s <= 2; s++) {
        final sid = await db.into(db.pauloFlixSeasons).insert(
              PauloFlixSeasonsCompanion.insert(
                contentId: cid,
                seasonNumber: s,
                displayName: 'Season $s',
                folderName: 'Season_$s',
                lastSynced: DateTime.now(),
              ),
            );
        for (int e = 1; e <= 5; e++) {
          await db.into(db.pauloFlixEpisodes).insert(
                PauloFlixEpisodesCompanion.insert(
                  seasonId: sid,
                  episodeNumber: e,
                  title: 'Episode $e',
                  videoUrl: 'https://v/$cid/s$s/e$e',
                  lastSynced: DateTime.now(),
                  // Marca progresso em alguns episodes
                  positionSeconds: e <= 2 ? Value(e * 60) : const Value(0),
                  isCompleted: e == 1 ? const Value(true) : const Value(false),
                  lastWatched:
                      e <= 2 ? Value(DateTime.now()) : const Value(null),
                ),
              );
        }
      }
    }

    // ── Insere 2 filmes ──────────────────────────────────────────
    for (final name in ['Filme A', 'Filme B']) {
      await db.into(db.pauloFlixMovies).insert(
            PauloFlixMoviesCompanion.insert(
              folderName: name,
              displayName: name,
              serverUrl: 'https://m/$name/',
              lastSynced: DateTime.now(),
            ),
          );
    }
  });

  tearDown(() async {
    await db.close();
  });

  // ═══════════════════════════════════════════════════════════════
  // ÍNDICES V15 (novos)
  // ═══════════════════════════════════════════════════════════════

  test('idx_seasons_content: getSeasonsForContent usa o índice', () async {
    final rows = await explain(
      db,
      'SELECT * FROM paulo_flix_seasons WHERE content_id = ?1 ORDER BY season_number',
      variables: [Variable.withInt(1)],
    );
    expectIndexUsed(rows, 'idx_seasons_content');
    expectNoFullScan(rows, 'paulo_flix_seasons');
  });

  test('idx_episodes_season_number: getEpisodesForSeason usa o índice', () async {
    final rows = await explain(
      db,
      'SELECT * FROM paulo_flix_episodes WHERE season_id = ?1 ORDER BY episode_number',
      variables: [Variable.withInt(1)],
    );
    expectIndexUsed(rows, 'idx_episodes_season_number');
    expectNoFullScan(rows, 'paulo_flix_episodes');
  });

  test('idx_content_search: searchByName em animes usa o índice', () async {
    final rows = await explain(
      db,
      'SELECT * FROM paulo_flix_content '
      "WHERE display_name LIKE ?1 ESCAPE '\\' "
      'AND is_available = 1 '
      'ORDER BY display_name',
      variables: [Variable.withString('%Nar%')],
    );
    expectIndexUsed(rows, 'idx_content_search');
    expectNoFullScan(rows, 'paulo_flix_content');
  });

  test('idx_movies_search: searchByName em filmes usa o índice', () async {
    final rows = await explain(
      db,
      'SELECT * FROM paulo_flix_movies '
      "WHERE display_name LIKE ?1 ESCAPE '\\' "
      'AND is_available = 1 '
      'ORDER BY display_name',
      variables: [Variable.withString('%Filme%')],
    );
    expectIndexUsed(rows, 'idx_movies_search');
    expectNoFullScan(rows, 'paulo_flix_movies');
  });

  // ═══════════════════════════════════════════════════════════════
  // ÍNDICES V14 (existentes) — regressão
  // ═══════════════════════════════════════════════════════════════

  test('idx_episodes_in_progress: watchInProgressContents usa o índice',
      () async {
    final rows = await explain(
      db,
      'SELECT c.* FROM paulo_flix_content c '
      'INNER JOIN paulo_flix_seasons s ON s.content_id = c.id '
      'INNER JOIN paulo_flix_episodes e ON e.season_id = s.id '
      'WHERE e.position_seconds > 0 '
      '  AND e.is_completed = 0 '
      '  AND c.is_available = 1 '
      'GROUP BY c.id '
      'ORDER BY MAX(e.last_watched) DESC '
      'LIMIT ?1',
      variables: [Variable.withInt(12)],
    );
    expectIndexUsed(rows, 'idx_episodes_in_progress');
  });

  test('idx_episodes_season_completed: _recomputeSeasonCompleted usa o índice',
      () async {
    final rows = await explain(
      db,
      'SELECT COUNT(*) FROM paulo_flix_episodes '
      'WHERE season_id = ?1 AND is_completed = 1',
      variables: [Variable.withInt(1)],
    );
    // O índice (season_id, is_completed) cobre esta query perfeitamente
    expectIndexUsed(rows, 'idx_episodes_season_completed');
    expectNoFullScan(rows, 'paulo_flix_episodes');
  });

  test('idx_content_available: filtro de disponibilidade usa o índice',
      () async {
    final rows = await explain(
      db,
      'SELECT * FROM paulo_flix_content WHERE is_available = 1',
    );
    expectIndexUsed(rows, 'idx_content_available');
    expectNoFullScan(rows, 'paulo_flix_content');
  });

  // ═══════════════════════════════════════════════════════════════
  // JOIN composto — verifica que a combinação de índices funciona
  // ═══════════════════════════════════════════════════════════════

  test('getInProgressContents (3-table JOIN) usa índices', () async {
    final rows = await explain(
      db,
      'SELECT c.* FROM paulo_flix_content c '
      'INNER JOIN paulo_flix_seasons s ON s.content_id = c.id '
      'INNER JOIN paulo_flix_episodes e ON e.season_id = s.id '
      'WHERE e.position_seconds > 0 '
      '  AND e.is_completed = 0 '
      '  AND c.is_available = 1 '
      'GROUP BY c.id '
      'ORDER BY MAX(e.last_watched) DESC '
      'LIMIT ?1',
      variables: [Variable.withInt(12)],
    );

    // Verifica que TODAS as 3 tabelas usam índices (sem full scans)
    expectNoFullScan(rows, 'paulo_flix_content');
    expectNoFullScan(rows, 'paulo_flix_seasons');
    expectNoFullScan(rows, 'paulo_flix_episodes');
  });
}

/// Resultado de uma linha do EXPLAIN QUERY PLAN.
class ExplainRow {
  final int id;
  final int parent;
  final String detail;
  const ExplainRow(this.id, this.parent, this.detail);

  @override
  String toString() => 'ExplainRow(id=$id, parent=$parent, detail=$detail)';
}
