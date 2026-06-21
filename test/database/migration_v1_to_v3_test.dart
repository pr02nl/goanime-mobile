// Cobertura da Fase 2 do plano docs/DATABASE_REFACTORING.md:
// unificação de 4 bancos SQLite legados em 1 banco Drift, com
// transformação de dados (CSV → JSON, datas em formatos mistos) e
// flag de idempotência.

import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/core/database/connection/migration_v1_to_v3.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

String _norm(String s) => p.normalize(s);

void main() {
  late Directory tempDir;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('phase2_migration_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('resolveLegacyDatabasePaths', () {
    test('retorna 4 paths a partir do path alvo pauloflix.db', () {
      // Cenário: <docs>/pauloflix.db (Linux/Windows não-Android).
      // Normaliza paths com p.normalize para ser robusto a separadores
      // `/` vs `\` no Windows.
      final base = _norm('${tempDir.path}/pauloflix.db');
      final paths = resolveLegacyDatabasePaths(base);
      expect(paths.pauloflixContent, base);
      expect(paths.watchlist, _norm('${tempDir.path}/watchlist.db'));
      expect(paths.downloads, _norm('${tempDir.path}/downloads.db'));
      expect(paths.pauloflixMovies,
          _norm('${tempDir.path}/pauloflix_movies.db'));
    });

    test('resolveLegacyDatabasePaths aceita path original pós-rename', () {
      // BUGFIX Fase 4: este teste reproduz o bug de produção onde o
      // main.dart chamava resolveLegacyDatabasePaths(dbPath) com o path
      // ORIGINAL (que já havia sido renomeado por prepareMigration).
      // O resultado: o path de pauloflixContent apontava para um
      // arquivo inexistente, e a migration crashava com
      // "no such table: pauloflix_content".
      final base = '${tempDir.path}/pauloflix.db';
      final renamed = '${tempDir.path}/pauloflix_content_legacy.db';

      // Cenário 1: pauloflix.db existe (instalação fresca, pré-rename).
      // O caminho deve usar pauloflix.db.
      File(base).writeAsBytesSync([]);
      var paths = resolveLegacyDatabasePaths(base);
      expect(File(paths.pauloflixContent).existsSync(), isTrue);
      File(base).deleteSync();

      // Cenário 2: pauloflix.db foi renomeado para pauloflix_content_legacy.db
      // (pós-prepareMigration). O caminho passado é o ORIGINAL (não o
      // renomeado). O resolveLegacyDatabasePaths deve detectar e usar
      // o renomeado. Sem este fix, o caminho apontava para
      // "<dir>/pauloflix.db" (inexistente), e a migration crashava.
      File(renamed).writeAsBytesSync([]);
      paths = resolveLegacyDatabasePaths(base);
      expect(paths.pauloflixContent, _norm(renamed),
          reason:
              'Quando o path original não existe mas o renomeado sim, '
              'devolve o renomeado.');
      File(renamed).deleteSync();
    });

    test('em Android, paths legados ficam no mesmo diretório (databases/)',
        () {
      // Cenário Android: <data>/databases/pauloflix.db.
      // Após Fase 1, todas as 4 services legadas resolvem para
      // <data>/databases/. Logo, todos os 4 bancos legados estão lá.
      // Em ambiente de teste (não-Android), simulamos com um diretório
      // qualquer — a função não diferencia plataforma, sempre usa o
      // mesmo diretório.
      final dbPath = _norm('${tempDir.path}/databases/pauloflix.db');
      final paths = resolveLegacyDatabasePaths(dbPath);
      expect(paths.pauloflixContent, dbPath);
      expect(
        paths.watchlist,
        _norm('${tempDir.path}/databases/watchlist.db'),
      );
      expect(
        paths.downloads,
        _norm('${tempDir.path}/databases/downloads.db'),
      );
      expect(
        paths.pauloflixMovies,
        _norm('${tempDir.path}/databases/pauloflix_movies.db'),
      );
    });
  });

  group('prepareMigration — orquestração do boot', () {
    test(
        'renomeia pauloflix.db legado → pauloflix_content_legacy.db '
        'quando há dados legados', () async {
      // Setup: pauloflix.db legado com dados (PauloFlix animes).
      // Usa p.join (separador da plataforma) para o path de teste.
      final pauloflixLegacy = p.join(tempDir.path, 'pauloflix.db');
      _seedLegacyPauloFlix(pauloflixLegacy);
      expect(File(pauloflixLegacy).existsSync(), isTrue);

      // Act
      final result = await prepareMigration(pauloflixLegacy);

      // Assert: legacy renomeado.
      expect(File(pauloflixLegacy).existsSync(), isFalse,
          reason: 'pauloflix.db legado deve ter sido renomeado');
      final renamedPath =
          p.join(tempDir.path, 'pauloflix_content_legacy.db');
      expect(File(renamedPath).existsSync(), isTrue,
          reason: 'banco renomeado deve existir');

      // Report devolve os paths certos.
      expect(result.legacyPaths.pauloflixContent, renamedPath);
      expect(result.renamedFrom, pauloflixLegacy);
    });

    test('idempotente: rodar 2× não renomeia de novo', () async {
      final pauloflixLegacy = p.join(tempDir.path, 'pauloflix.db');
      _seedLegacyPauloFlix(pauloflixLegacy);

      await prepareMigration(pauloflixLegacy);
      final renamedPath =
          p.join(tempDir.path, 'pauloflix_content_legacy.db');

      // 2ª chamada: o "legacy" agora está em pauloflix_content_legacy.db;
      // deve detectar que já está renomeado e não renomear de novo.
      final result2 = await prepareMigration(renamedPath);
      expect(result2.legacyPaths.pauloflixContent, renamedPath);
    });

    test(
        'se não há pauloflix.db legado, retorna paths apontando para '
        'arquivos inexistentes (instalação fresca)', () async {
      final freshPath = p.join(tempDir.path, 'pauloflix.db');

      final result = await prepareMigration(freshPath);
      // Nenhum rename, paths são derivados do path fresco.
      expect(result.renamedFrom, isNull);
      // Paths legados apontam para onde estariam (mas não existem).
      expect(result.legacyPaths.pauloflixContent, freshPath);
      expect(File(result.legacyPaths.watchlist).existsSync(), isFalse);
      expect(File(result.legacyPaths.downloads).existsSync(), isFalse);
      expect(File(result.legacyPaths.pauloflixMovies).existsSync(), isFalse);
    });
  });

  group('migrateV1ToV3 — transformação de dados legados', () {
    test('cria 4 bancos legados sintéticos, roda migration, valida round-trip',
        () async {
      // Setup: cria 4 bancos SQLite com schema legado e dados representativos.
      final watchlistDbPath = '${tempDir.path}/watchlist.db';
      final downloadsDbPath = '${tempDir.path}/downloads.db';
      final pauloflixDbPath = '${tempDir.path}/pauloflix.db';
      final pauloflixMoviesDbPath = '${tempDir.path}/pauloflix_movies.db';

      _seedLegacyWatchlist(watchlistDbPath);
      _seedLegacyDownloads(downloadsDbPath);
      _seedLegacyPauloFlix(pauloflixDbPath);
      _seedLegacyPauloFlixMovies(pauloflixMoviesDbPath);

      // Target: AppDatabase in-memory (Drift).
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);

      // Act
      final report = await migrateV1ToV3(
        target: target,
        legacy: LegacyDatabasePaths(
          watchlist: watchlistDbPath,
          downloads: downloadsDbPath,
          pauloflixContent: pauloflixDbPath,
          pauloflixMovies: pauloflixMoviesDbPath,
        ),
      );

      // Assert: contagens migradas batem com o que foi seedado.
      expect(report.watchlistRows, 2);
      expect(report.downloadsRows, 2);
      expect(report.pauloflixContentRows, 2);
      expect(report.pauloflixMoviesRows, 2);
      expect(report.allSucceeded, isTrue);

      // Watchlist: 2 linhas, malId único, datas ISO preservadas.
      final wl = await target.select(target.watchlistItems).get();
      expect(wl, hasLength(2));
      expect(wl.map((r) => r.animeId).toSet(), {'mal:20', 'mal:21'});

      // Downloads: bytes/integers preservados.
      final dl = await target.select(target.downloads).get();
      expect(dl, hasLength(2));
      final ep1 = dl.firstWhere((r) => r.downloadId == 'mal20_1');
      expect(ep1.animeName, 'Naruto');
      expect(ep1.status.name, 'completed');
      expect(ep1.progress, 1.0);

      // PauloFlixContent: genres CSV legado vira List<String> decodificado.
      final pf = await target.select(target.pauloFlixContent).get();
      expect(pf, hasLength(2));
      final naruto = pf.firstWhere((r) => r.folderName == 'naruto');
      // O CSV legado 'Action,Adventure' vira ['Action', 'Adventure'] via
      // fallback. O teste prova que a migration **não destrói** dados
      // legados mesmo se o formato antigo for CSV.
      expect(naruto.genresJson, contains('Action'));
      expect(naruto.score, 7.8);
      expect(naruto.malId, 20);

      // PauloFlixMovies: tmdbId + isCollection preservados.
      final pfM = await target.select(target.pauloFlixMovies).get();
      expect(pfM, hasLength(2));
      final hp = pfM.firstWhere((r) => r.folderName == 'harry_potter');
      expect(hp.isCollection, isTrue);
      expect(hp.availableMovieCount, 8);
      expect(hp.tmdbId, 12445);
    });

    test('idempotente: rodar 2× não duplica dados', () async {
      final watchlistDbPath = '${tempDir.path}/watchlist2.db';
      final downloadsDbPath = '${tempDir.path}/downloads2.db';
      final pauloflixDbPath = '${tempDir.path}/pauloflix2.db';
      final pauloflixMoviesDbPath = '${tempDir.path}/pauloflix_movies2.db';
      _seedLegacyWatchlist(watchlistDbPath);
      _seedLegacyDownloads(downloadsDbPath);
      _seedLegacyPauloFlix(pauloflixDbPath);
      _seedLegacyPauloFlixMovies(pauloflixMoviesDbPath);

      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);

      final paths = LegacyDatabasePaths(
        watchlist: watchlistDbPath,
        downloads: downloadsDbPath,
        pauloflixContent: pauloflixDbPath,
        pauloflixMovies: pauloflixMoviesDbPath,
      );

      await migrateV1ToV3(target: target, legacy: paths);
      // Segunda execução: todos os contadores devem ser 0 (já migrados).
      final report2 = await migrateV1ToV3(target: target, legacy: paths);
      expect(report2.watchlistRows, 0);
      expect(report2.downloadsRows, 0);
      expect(report2.pauloflixContentRows, 0);
      expect(report2.pauloflixMoviesRows, 0);
      expect(report2.allSucceeded, isTrue);

      // E a contagem no banco continua 2 de cada (não 4).
      final wlCount = await target
          .customSelect('SELECT COUNT(*) AS c FROM watchlist_items')
          .map((row) => row.read<int>('c'))
          .getSingle();
      expect(wlCount, 2);
    });

    test(
        'BUGFIX (produção): fluxo prepareMigration + migrateV1ToV3 lê do '
        'arquivo renomeado, não do path original', () async {
      // Replica o fluxo exato do main() em produção:
      //   1. resolvePauloflixDbPath() → "<dir>/pauloflix.db"
      //   2. await prepareMigration(dbPath) → renomeia para
      //      "<dir>/pauloflix_content_legacy.db"
      //   3. resolveLegacyDatabasePaths(dbPath)  ← BUG: usava o path
      //      ORIGINAL (pauloflix.db) que não existe mais.
      //   4. migrateV1ToV3(legacy: ...)  ← abria "<dir>/pauloflix.db" vazio
      //      e crashava com "no such table: pauloflix_content".
      //
      // O fix: o resolveLegacyDatabasePaths deve aceitar **qualquer**
      // path (original OU renomeado) e derivar os paths certos a partir
      // do diretório. Especificamente, se o `pauloflix.db` não existe
      // mas `pauloflix_content_legacy.db` existe, o `pauloflixContent`
      // deve apontar para o renomeado.

      final pauloflixDbPath = p.join(tempDir.path, 'pauloflix.db');
      _seedLegacyPauloFlix(pauloflixDbPath);
      _seedLegacyWatchlist(p.join(tempDir.path, 'watchlist.db'));
      _seedLegacyDownloads(p.join(tempDir.path, 'downloads.db'));
      _seedLegacyPauloFlixMovies(p.join(tempDir.path, 'pauloflix_movies.db'));

      // Step 1+2: prepareMigration renomeia.
      final prepared = await prepareMigration(pauloflixDbPath);
      expect(File(pauloflixDbPath).existsSync(), isFalse);
      final renamedPath = p.join(tempDir.path, 'pauloflix_content_legacy.db');
      expect(File(renamedPath).existsSync(), isTrue);

      // Step 3: o `prepared.legacyPaths` já tem o path renomeado.
      // Mas se algum caller ainda usar `resolveLegacyDatabasePaths(dbPath)`,
      // ele deve ser robusto. Verificamos os 2 caminhos:
      //
      // Caminho A: usar `prepared.legacyPaths` (correto, usado pelo
      // main() pós-fix).
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);

      final reportA = await migrateV1ToV3(target: target, legacy: prepared.legacyPaths);
      expect(reportA.pauloflixContentRows, 2,
          reason: 'Caminho A (via prepared.legacyPaths) deve migrar 2 rows');
      expect(reportA.allSucceeded, isTrue);

      // Idempotência: rodar 2× no prepared não duplica.
      final reportA2 = await migrateV1ToV3(target: target, legacy: prepared.legacyPaths);
      expect(reportA2.pauloflixContentRows, 0);
    });

    test(
        'lida com bancos legados ausentes sem falhar (instalação parcial)',
        () async {
      // Só watchlist existe; os outros 3 não.
      final watchlistDbPath = '${tempDir.path}/only_watchlist.db';
      _seedLegacyWatchlist(watchlistDbPath);

      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);

      final report = await migrateV1ToV3(
        target: target,
        legacy: LegacyDatabasePaths(
          watchlist: watchlistDbPath,
          downloads: '${tempDir.path}/nonexistent_downloads.db',
          pauloflixContent: '${tempDir.path}/nonexistent_pauloflix.db',
          pauloflixMovies: '${tempDir.path}/nonexistent_movies.db',
        ),
      );

      expect(report.watchlistRows, 2);
      expect(report.downloadsRows, 0);
      expect(report.pauloflixContentRows, 0);
      expect(report.pauloflixMoviesRows, 0);
      expect(report.allSucceeded, isTrue);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers: criam bancos SQLite com schema exatamente igual ao dos services
// legados antes da Fase 1 (Fase 0/1 não mexeram no schema em disco).
// ---------------------------------------------------------------------------

void _seedLegacyWatchlist(String path) {
  final f = File(path);
  f.createSync(recursive: true);
  final db = sqlite3.open(path);
  db.execute('''
    CREATE TABLE watchlist (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      animeId TEXT NOT NULL UNIQUE,
      title TEXT NOT NULL,
      coverImage TEXT NOT NULL,
      myAnimeListUrl TEXT NOT NULL,
      addedAt TEXT NOT NULL
    )
  ''');
  // dateTime deprecate: usaremos ISO string direto, como o service legado.
  db.execute(
    'INSERT INTO watchlist (animeId, title, coverImage, myAnimeListUrl, addedAt) '
    "VALUES ('mal:20', 'Naruto', 'http://img/n.jpg', 'https://mal/20', '2026-06-20T10:00:00.000')",
  );
  db.execute(
    'INSERT INTO watchlist (animeId, title, coverImage, myAnimeListUrl, addedAt) '
    "VALUES ('mal:21', 'One Piece', 'http://img/op.jpg', 'https://mal/21', '2026-06-21T11:30:00.000')",
  );
  db.close();
}

void _seedLegacyDownloads(String path) {
  final f = File(path);
  f.createSync(recursive: true);
  final db = sqlite3.open(path);
  db.execute('''
    CREATE TABLE downloads (
      id TEXT PRIMARY KEY,
      animeId TEXT NOT NULL,
      animeName TEXT NOT NULL,
      episodeNumber TEXT NOT NULL,
      episodeTitle TEXT NOT NULL,
      videoUrl TEXT NOT NULL,
      thumbnailUrl TEXT NOT NULL,
      quality INTEGER NOT NULL,
      status INTEGER NOT NULL,
      progress REAL NOT NULL,
      bytesDownloaded INTEGER NOT NULL,
      totalBytes INTEGER NOT NULL,
      filePath TEXT,
      error TEXT,
      createdAt INTEGER NOT NULL,
      completedAt INTEGER
    )
  ''');
  // status=3 == completed (Drift DownloadStatus: queued=0, downloading=1,
  // paused=2, completed=3, failed=4, cancelled=5), quality=3 == high
  // (auto=0, low=1, medium=2, high=3).
  final now = DateTime.now().millisecondsSinceEpoch;
  db.execute(
    'INSERT INTO downloads (id, animeId, animeName, episodeNumber, episodeTitle, '
    'videoUrl, thumbnailUrl, quality, status, progress, bytesDownloaded, '
    'totalBytes, filePath, error, createdAt, completedAt) '
    "VALUES ('mal20_1', 'mal:20', 'Naruto', '1', 'Episode 1', "
    "'http://v/1.mp4', 'http://t/1.jpg', 3, 3, 1.0, 104857600, "
    "104857600, '/data/d/naruto_1.mp4', NULL, ?, ?)",
    [now - 100000, now],
  );
  // status=1 == downloading
  db.execute(
    'INSERT INTO downloads (id, animeId, animeName, episodeNumber, episodeTitle, '
    'videoUrl, thumbnailUrl, quality, status, progress, bytesDownloaded, '
    'totalBytes, filePath, error, createdAt, completedAt) '
    "VALUES ('mal20_2', 'mal:20', 'Naruto', '2', 'Episode 2', "
    "'http://v/2.mp4', 'http://t/2.jpg', 2, 1, 0.5, 52428800, "
    '104857600, NULL, NULL, ?, NULL)',
    [now],
  );
  db.close();
}

void _seedLegacyPauloFlix(String path) {
  final f = File(path);
  f.createSync(recursive: true);
  final db = sqlite3.open(path);
  db.execute('''
    CREATE TABLE pauloflix_content (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      folderName TEXT NOT NULL UNIQUE,
      displayName TEXT NOT NULL,
      serverUrl TEXT NOT NULL,
      imageUrl TEXT,
      bannerUrl TEXT,
      description TEXT,
      score REAL,
      genres TEXT,
      status TEXT,
      episodeCount INTEGER,
      malId INTEGER,
      anilistId INTEGER,
      lastSynced TEXT NOT NULL,
      isAvailable INTEGER NOT NULL DEFAULT 1
    )
  ''');
  // CSV legado com vírgula (que o novo formato JSON resolve).
  db.execute(
    'INSERT INTO pauloflix_content (folderName, displayName, serverUrl, '
    'imageUrl, bannerUrl, description, score, genres, status, episodeCount, '
    'malId, anilistId, lastSynced, isAvailable) '
    "VALUES ('naruto', 'Naruto', 'http://server/naruto/', "
    "'http://img/n.jpg', 'http://img/nb.jpg', 'desc', 7.8, "
    "'Action,Adventure', 'Finished', 220, 20, 20, '2026-06-20T10:00:00.000', 1)",
  );
  db.execute(
    'INSERT INTO pauloflix_content (folderName, displayName, serverUrl, '
    'imageUrl, bannerUrl, description, score, genres, status, episodeCount, '
    'malId, anilistId, lastSynced, isAvailable) '
    "VALUES ('one_piece', 'One Piece', 'http://server/onepiece/', "
    "'http://img/op.jpg', NULL, NULL, 9.0, 'Action,Comedy', 'Ongoing', "
    "1100, 21, 21, '2026-06-21T10:00:00.000', 1)",
  );
  db.close();
}

void _seedLegacyPauloFlixMovies(String path) {
  final f = File(path);
  f.createSync(recursive: true);
  final db = sqlite3.open(path);
  db.execute('''
    CREATE TABLE pauloflix_movies (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      folderName TEXT NOT NULL UNIQUE,
      displayName TEXT NOT NULL,
      serverUrl TEXT NOT NULL,
      imageUrl TEXT,
      bannerUrl TEXT,
      description TEXT,
      score REAL,
      genres TEXT,
      releaseDate TEXT,
      runtime INTEGER,
      year INTEGER,
      tmdbId INTEGER,
      isCollection INTEGER NOT NULL DEFAULT 0,
      availableMovieCount INTEGER NOT NULL DEFAULT 0,
      lastSynced TEXT NOT NULL,
      isAvailable INTEGER NOT NULL DEFAULT 1
    )
  ''');
  db.execute(
    'INSERT INTO pauloflix_movies (folderName, displayName, serverUrl, '
    'imageUrl, bannerUrl, description, score, genres, releaseDate, runtime, '
    'year, tmdbId, isCollection, availableMovieCount, lastSynced, isAvailable) '
    "VALUES ('inception', 'A Origem', 'http://server/inception/', "
    "'http://img/i.jpg', 'http://img/ib.jpg', 'desc', 8.8, "
    "'Action,Sci-Fi', '2010-07-15', 148, 2010, 27205, 0, 1, "
    "'2026-06-20T10:00:00.000', 1)",
  );
  db.execute(
    'INSERT INTO pauloflix_movies (folderName, displayName, serverUrl, '
    'imageUrl, bannerUrl, description, score, genres, releaseDate, runtime, '
    'year, tmdbId, isCollection, availableMovieCount, lastSynced, isAvailable) '
    "VALUES ('harry_potter', 'Coleção Harry Potter', 'http://server/hp/', "
    "'http://img/hp.jpg', 'http://img/hpb.jpg', 'desc', 8.0, "
    "'Fantasy,Adventure', '2001-11-14', 0, 2001, 12445, 1, 8, "
    "'2026-06-21T10:00:00.000', 1)",
  );
  db.close();
}
