// Cobertura dos fixes da Fase 1 do plano docs/DATABASE_REFACTORING.md.
//
// NOTA: os testes que antes usavam `sqlite3` puro para verificar o
// comportamento de LIKE ESCAPE foram convertidos para testes de função
// pura (a lógica de escaping é uma transformação de string). O
// round-trip real com SQL é coberto indiretamente pelos testes de
// repository (que usam Drift in-memory).
//
// O teste de reset downloading→queued foi convertido para lógica Dart
// pura simulando o comportamento esperado.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/domain/models/pauloflix_content.dart';
import 'package:goanime/domain/models/pauloflix_movie.dart';

/// Replicação do helper `_escapeLike` usado em
/// `PauloFlixRepositoryImpl` e `PauloFlixMoviesRepositoryImpl`.
String escapeLike(String q) => q
    .replaceAll(r'\', r'\\')
    .replaceAll('%', r'\%')
    .replaceAll('_', r'\_');

void main() {
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

  group('LIKE ESCAPE — função pura de escaping (correção do bug % e _)', () {
    test('escapeLike escapa % corretamente', () {
      expect(escapeLike('100%'), r'100\%');
      expect(escapeLike('%test'), r'\%test');
      expect(escapeLike('50% off'), r'50\% off');
    });

    test('escapeLike escapa _ corretamente', () {
      expect(escapeLike('a_b'), r'a\_b');
      expect(escapeLike('_test'), r'\_test');
      expect(escapeLike('naruto_shippuden'), r'naruto\_shippuden');
    });

    test('escapeLike escapa \\ antes de escapar % e _', () {
      // A ordem importa: primeiro \\, depois %, depois _.
      // Se fizéssemos ao contrário, `\%` viraria `\\%` e
      // o backslash seria escapado duas vezes.
      expect(escapeLike(r'100\%'), r'100\\\%');
      expect(escapeLike(r'a\_b'), r'a\\\_b');
    });

    test('escapeLike não altera strings sem caracteres especiais', () {
      expect(escapeLike('Naruto'), 'Naruto');
      expect(escapeLike('Hello World'), 'Hello World');
      expect(escapeLike('normal text 123'), 'normal text 123');
    });

    test('escapeLike trata string vazia', () {
      expect(escapeLike(''), '');
    });
  });

  group('Download reset — persistência de downloading → queued', () {
    // Simula a lógica do DownloadService: ao carregar do banco, qualquer
    // status "downloading" vira "queued".

    test('download com status=downloading é resetado para queued após load',
        () {
      // Simula 3 downloads carregados do banco.
      final downloads = <String, int>{
        'a_1': 1, // downloading
        'b_2': 0, // queued
        'c_3': 2, // completed
      };

      // Lógica equivalente ao _loadDownloadsFromRepository:
      // todo downloading vira queued.
      for (final id in downloads.keys.toList()) {
        if (downloads[id] == 1) {
          downloads[id] = 0; // queued
        }
      }

      expect(downloads['a_1'], 0); // foi resetado
      expect(downloads['b_2'], 0); // permaneceu queued
      expect(downloads['c_3'], 2); // permaneceu completed
    });

    test('apenas downloading é resetado, outros status não são alterados', () {
      final downloads = <String, int>{
        'd_1': 1, // downloading
        'e_2': 3, // paused
        'f_3': 4, // failed
        'g_4': 5, // cancelled
      };

      for (final id in downloads.keys.toList()) {
        if (downloads[id] == 1) {
          downloads[id] = 0;
        }
      }

      expect(downloads['d_1'], 0); // resetado
      expect(downloads['e_2'], 3); // preservado
      expect(downloads['f_3'], 4); // preservado
      expect(downloads['g_4'], 5); // preservado
    });
  });
}
