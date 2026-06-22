import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

/// Wrapper sobre a tabela `tmdb_genres` do Drift para o cache do
/// mapeamento `genreId → nome` do TMDB.
///
/// Escopado por idioma: cada instância lê/escreve apenas linhas com o
/// `locale` informado. Isso permite coexistir `pt-BR`, `en-US`, etc. na
/// mesma tabela sem conflito.
///
/// Estratégia de uso (chamada pelo `TmdbService.getGenres`):
/// 1. Verifica `hasAny` — se vazio para o locale, força fetch do TMDB.
/// 2. Se populado, lê via `asMap()` (cache hit).
/// 3. Após fetch do TMDB, chama `replaceAll(map, locale)` — apaga e
///    reinsere o idioma inteiro (idempotente, ~19 rows).
class TmdbGenreCache {
  final AppDatabase _db;
  final String language;

  TmdbGenreCache({
    required AppDatabase db,
    required this.language,
  }) : _db = db;

  /// True se há ≥1 linha para o idioma.
  Future<bool> get hasAny async {
    final count = await (_db.selectOnly(_db.tmdbGenres)
          ..addColumns([_db.tmdbGenres.id.count()])
          ..where(_db.tmdbGenres.locale.equals(language)))
        .getSingle();
    return (count.read(_db.tmdbGenres.id.count()) ?? 0) > 0;
  }

  /// Retorna o mapeamento completo `id → name` para o idioma.
  ///
  /// Retorna mapa vazio se nada estiver cacheado. NÃO consulta o TMDB —
  /// isso é responsabilidade do `TmdbService.getGenres`.
  Future<Map<int, String>> asMap() async {
    final rows = await (_db.select(_db.tmdbGenres)
          ..where((t) => t.locale.equals(language)))
        .get();
    return {for (final r in rows) r.id: r.name};
  }

  /// Apaga todas as linhas do idioma e reinsere o [map] fornecido.
  ///
  /// Idempotente: chamar 2x seguidas resulta no mesmo estado final.
  /// Chamado pelo `TmdbService.getGenres` após buscar do TMDB.
  Future<void> replaceAll(Map<int, String> map) async {
    if (map.isEmpty) return;
    await _db.transaction(() async {
      await (_db.delete(_db.tmdbGenres)
            ..where((t) => t.locale.equals(language)))
          .go();
      final now = DateTime.now();
      await _db.batch((batch) {
        for (final entry in map.entries) {
          batch.insert(
            _db.tmdbGenres,
            TmdbGenresCompanion.insert(
              id: entry.key,
              name: entry.value,
              locale: language,
              fetchedAt: now,
            ),
          );
        }
      });
    });
  }

  /// Apaga todas as linhas do idioma. Útil se o usuário pedir "limpar cache"
  /// nas Configurações.
  Future<void> clear() async {
    await (_db.delete(_db.tmdbGenres)
          ..where((t) => t.locale.equals(language)))
        .go();
  }
}
