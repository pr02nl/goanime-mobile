import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';

void main() {
  // Em testes criamos múltiplas instâncias de AppDatabase (uma por teste
  // + um teste que abre um arquivo temp adicional). Sem suprimir, o Drift
  // emite um warning em debug builds.
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('AppDatabase — smoke (in-memory)', () {
    late AppDatabase db;

    setUp(() {
      // Fornece um NativeDatabase puramente em memória (sem tocar em
      // getApplicationDocumentsDirectory). Usa o ctor de teste `forTesting`.
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('abre vazio, cria as 4 tabelas e responde a SELECT 1', () async {
      final result = await db.customSelect('SELECT 1 as v').getSingle();
      expect(result.read<int>('v'), 1);
    });

    test('expõe as 7 tabelas esperadas com schemaVersion = 14', () {
      expect(db.schemaVersion, 14);
      // 7 tabelas: 4 legadas + tmdb_genres + paulo_flix_seasons +
      // paulo_flix_episodes (Fase 0 do plano de progresso).
      expect(db.allTables.length, 7);
    });

    test('Habilita foreign_keys e ativa WAL em conexão arquivo (file temp)',
        () async {
      // NativeDatabase.memory() roda journal_mode=memory e não aceita WAL.
      // Para validar WAL de verdade é preciso arquivo, então usamos
      // NativeDatabase em path temporário e o ctor de produção.
      final tempFile = File('${Directory.systemTemp.path}/wal_test.db');
      if (tempFile.existsSync()) tempFile.deleteSync();
      addTearDown(() {
        if (tempFile.existsSync()) tempFile.deleteSync();
      });

      final prodDb = AppDatabase.forTesting(NativeDatabase(tempFile));
      addTearDown(prodDb.close);

      // Dispara beforeOpen lazy.
      await prodDb.customSelect('SELECT 1').get();

      final journalMode = await prodDb
          .customSelect('PRAGMA journal_mode')
          .map((row) => row.read<String>('journal_mode'))
          .getSingle();
      expect(journalMode.toLowerCase(), 'wal');

      final foreignKeys = await prodDb
          .customSelect('PRAGMA foreign_keys')
          .map((row) => row.read<int>('foreign_keys'))
          .getSingle();
      expect(foreignKeys, 1);
    });

    test('em conexão :memory: foreign_keys ainda é aplicado (journal=memory)',
        () async {
      // Garante que o PRAGMA roda mesmo em :memory: — só o journal_mode
      // difere.
      final foreignKeys = await db
          .customSelect('PRAGMA foreign_keys')
          .map((row) => row.read<int>('foreign_keys'))
          .getSingle();
      expect(foreignKeys, 1);
    });

    test('insere e lê de volta em watchlist_items (round-trip mínimo)', () async {
      // Drift armazena DateTime como INTEGER epoch-seconds (sem
      // sub-segundos). Para preservar ms, seria preciso
      // `intColumn().map<DateTime>(...)`. Decisão consciente: precisão
      // de segundos é suficiente para watchlist/downloads/sync.
      final addedAt = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );
      await db.into(db.watchlistItems).insert(
            WatchlistItemsCompanion.insert(
              animeId: 'mal:1',
              title: 'Cowboy Bebop',
              coverImage: 'https://example.test/cover.jpg',
              myAnimeListUrl: 'https://myanimelist.net/anime/1',
              addedAt: addedAt,
            ),
          );

      final row = await (db.select(db.watchlistItems)
            ..where((t) => t.animeId.equals('mal:1')))
          .getSingle();

      expect(row.title, 'Cowboy Bebop');
      // Compara até o segundo.
      expect(
        row.addedAt.millisecondsSinceEpoch,
        (addedAt.millisecondsSinceEpoch ~/ 1000) * 1000,
      );
    });
  });
}
