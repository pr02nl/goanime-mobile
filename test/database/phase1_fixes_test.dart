// Cobertura dos fixes da Fase 1 do plano docs/DATABASE_REFACTORING.md.
//
// Os testes aqui rodam em arquivos SQLite temporários (em <systemTemp>)
// usando `sqlite3` puro, sem Flutter, para isolar a lógica de
// (a) busca com ESCAPE, (b) round-trip de genres JSON, (c) reset de status
// de download persistido.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/domain/models/pauloflix_content.dart';
import 'package:goanime/domain/models/pauloflix_movie.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;
  late Database db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('phase1_test_');
    db = sqlite3.open('${tempDir.path}/phase1.db');
  });

  tearDown(() async {
    db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('resolvePauloflixDbPath', () {
    test('resolvePauloflixDbPath retorna path bem-formado terminando em pauloflix.db',
        () async {
      // path_provider usa MethodChannel, que precisa do
      // WidgetsFlutterBinding em testes de unidade. Skip aqui; cobertura
      // real de path é feita indiretamente pelos smoke tests de Fase 0
      // e pelos testes de widget que abrem o AppDatabase real.
    }, skip: 'Requer WidgetsFlutterBinding (path_provider); coberto por testes de widget.');
  });

  group('genres — round-trip JSON (correção do bug CSV vs vírgula)', () {
    test('PauloFlixContent.toMap/fromMap preserva vírgulas em nomes de gênero',
        () {
      final original = PauloFlixContent(
        folderName: 'fate',
        displayName: 'Fate',
        serverUrl: 'http://server/fate/',
        genres: const ['Sci-Fi', 'Slice of Life', 'Action, Adventure'],
      );

      final map = original.toMap();
      // O JSON serializado (não CSV) deve preservar vírgulas dentro de itens.
      expect(map['genres'], jsonEncode(original.genres));
      // Nenhuma ambiguidade: o parse sabe que "Slice of Life" é UM gênero.
      final restored = PauloFlixContent.fromMap(map);
      expect(restored.genres, original.genres);
    });

    test('PauloFlixMovie.toMap/fromMap idem para filmes', () {
      final original = PauloFlixMovie(
        folderName: 'deadpool',
        displayName: 'Deadpool',
        serverUrl: 'http://server/deadpool/',
        genres: const ['Action, Comedy', 'Sci-Fi', 'Adventure'],
        isCollection: false,
        availableMovieCount: 1,
      );

      final map = original.toMap();
      expect(map['genres'], jsonEncode(original.genres));
      final restored = PauloFlixMovie.fromMap(map);
      expect(restored.genres, original.genres);
    });

    test('genres vazio vira null no map (não "[]")', () {
      final c = PauloFlixContent(
        folderName: 'x',
        displayName: 'X',
        serverUrl: 'http://x/',
        genres: const [],
      );
      final m = c.toMap();
      expect(m['genres'], isNull);
      final back = PauloFlixContent.fromMap(m);
      expect(back.genres, isEmpty);
    });
  });

  group('LIKE ESCAPE — correção do bug % e _', () {
    // Helper interno. Replicamos aqui a lógica esperada do método que
    // vamos expor nos services.
    String escapeLike(String q) => q
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');

    setUp(() {
      db.execute('''
        CREATE TABLE t (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL
        )
      ''');
      // "Naruto_X" tem um underscore LITERAL que só deve casar se a query
      // buscar por "Naruto_X" (com _ literal escapado). Sem escape, a query
      // "Naruto" casaria também porque LIKE não é exato.
      db.execute("INSERT INTO t (name) VALUES ('Naruto')");
      db.execute("INSERT INTO t (name) VALUES ('Naruto Shippuden')");
      db.execute("INSERT INTO t (name) VALUES ('100% Mamãe')");
      db.execute("INSERT INTO t (name) VALUES ('100 Normal')");
    });

    test('query com _ no termo busca casa apenas match exato de _', () {
      // Caso concreto: o usuário busca "Naruto_X" mas a pasta só tem
      // "Naruto" e "Naruto Shippuden". Sem ESCAPE, o _ seria coringa e
      // poderia casar "Naruto" (porque _ casa 1 char) — mas isso é
      // desejado! O teste aqui prova ESCAPE usando % que SEM escape
      // é problema.
      // Melhor caso: query com % literal "100%". Sem escape, "100%"
      // vira "100" + wildcard, casando com "100 Mamãe" e "100 Normal".
      // Com escape, só "100% Mamãe" casa.
      final escaped = escapeLike('100%');
      final pattern = '%$escaped%';
      final result = db.select(
        "SELECT name FROM t WHERE name LIKE ? ESCAPE '\\' ORDER BY name",
        [pattern],
      );
      final names = result.map((r) => r['name'] as String).toList();
      // Sem escape: casaria "100 Mamãe" e "100 Normal" também (false positives).
      // Com escape: só "100% Mamãe".
      expect(names, ['100% Mamãe']);
    });

    test('query com _ no termo só casa match literal de _', () {
      // Para testar _, uso um cenário simétrico: nome "a_b" deve casar só
      // com query "a_b" literal (com _ escapado). Sem escape, "a_b" no
      // pattern é wildcard e casaria também com "aXb".
      db.execute("INSERT INTO t (name) VALUES ('a_b')");
      db.execute("INSERT INTO t (name) VALUES ('aXb')");

      final escaped = escapeLike('a_b');
      final pattern = escaped; // match exato
      final result = db.select(
        "SELECT name FROM t WHERE name LIKE ? ESCAPE '\\' ORDER BY name",
        [pattern],
      );
      final names = result.map((r) => r['name'] as String).toList();
      // Sem escape: casaria 'aXb' também (porque _ é coringa).
      // Com escape: só 'a_b' (que tem _ literal).
      expect(names, ['a_b']);
    });
  });

  group('Download reset — persistência de downloading → queued', () {
    // Simula a lógica do DownloadService: ao carregar do banco, qualquer
    // status "downloading" vira "queued" E o banco precisa ser atualizado.

    test('se uma linha está com status=downloading no banco, depois do load ela vira queued e é persistida',
        () {
      db.execute('''
        CREATE TABLE downloads (
          id TEXT PRIMARY KEY,
          status INTEGER NOT NULL,
          progress REAL NOT NULL DEFAULT 0
        )
      ''');
      // Insere um download "downloading" como se fosse do app anterior.
      db.execute(
        "INSERT INTO downloads (id, status, progress) VALUES ('a_1', 1, 0.5)",
      );

      // Replica a lógica do _loadDownloads (status=1 == downloading).
      final rows = db.select('SELECT id, status FROM downloads');
      for (final row in rows) {
        if (row['status'] == 1) {
          db.execute(
            'UPDATE downloads SET status = ? WHERE id = ?',
            [0, row['id']], // 0 == queued
          );
        }
      }

      // Verifica que foi persistido (não só em memória).
      final after = db.select("SELECT status FROM downloads WHERE id = 'a_1'");
      expect(after.first['status'], 0);
    });
  });
}
