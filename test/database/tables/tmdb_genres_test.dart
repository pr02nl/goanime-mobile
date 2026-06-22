import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/data/services/tmdb_genre_cache.dart';

void main() {
  // Mesmo padrão do `app_database_test.dart` — múltiplas instâncias
  // em memória, suprime warning de múltiplos databases.
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('TmdbGenreCache', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('hasAny é false em banco vazio', () async {
      final cache = TmdbGenreCache(db: db, language: 'pt-BR');
      expect(await cache.hasAny, isFalse);
      expect(await cache.asMap(), isEmpty);
    });

    test('replaceAll persiste e asMap lê corretamente', () async {
      final cache = TmdbGenreCache(db: db, language: 'pt-BR');
      await cache.replaceAll({28: 'Ação', 12: 'Aventura'});
      expect(await cache.hasAny, isTrue);
      expect(await cache.asMap(), {28: 'Ação', 12: 'Aventura'});
    });

    test('replaceAll é idempotente (chamar 2x mantém estado final)', () async {
      final cache = TmdbGenreCache(db: db, language: 'pt-BR');
      await cache.replaceAll({28: 'Ação'});
      await cache.replaceAll({28: 'Ação', 12: 'Aventura'});
      expect((await cache.asMap()).length, 2);
    });

    test('cache é escopado por locale (pt-BR não afeta en-US)', () async {
      final ptCache = TmdbGenreCache(db: db, language: 'pt-BR');
      final enCache = TmdbGenreCache(db: db, language: 'en-US');
      await ptCache.replaceAll({28: 'Ação'});
      await enCache.replaceAll({28: 'Action'});
      expect((await ptCache.asMap())[28], 'Ação');
      expect((await enCache.asMap())[28], 'Action');
    });

    test('clear remove só o idioma especificado', () async {
      final cache = TmdbGenreCache(db: db, language: 'pt-BR');
      await cache.replaceAll({28: 'Ação'});
      await TmdbGenreCache(db: db, language: 'en-US')
          .replaceAll({28: 'Action'});
      await cache.clear();
      expect(
        await TmdbGenreCache(db: db, language: 'pt-BR').hasAny,
        isFalse,
      );
      expect(
        await TmdbGenreCache(db: db, language: 'en-US').hasAny,
        isTrue,
      );
    });

    test('replaceAll com mapa vazio é no-op (não apaga dados)', () async {
      // Edge case: se TMDB retornar [] (improvável mas possível em
      // rate-limit), NÃO devemos apagar o cache existente.
      // Por isso replaceAll([]) é no-op.
      final cache = TmdbGenreCache(db: db, language: 'pt-BR');
      await cache.replaceAll({28: 'Ação', 12: 'Aventura'});
      await cache.replaceAll(const {});
      expect(await cache.asMap(), {28: 'Ação', 12: 'Aventura'});
    });
  });
}
