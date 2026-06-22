import 'package:drift/drift.dart';

/// Tabela de cache do mapeamento `genreId → nome` da API TMDB.
///
/// ## Por que existe
///
/// O endpoint `/search/movie` do TMDB retorna apenas `genre_ids` (lista de
/// IDs), não os nomes. O endpoint `/movie/{id}` (detalhes) retorna os
/// nomes completos, mas custaria 1 request por filme. A solução é
/// cachear a lista oficial de gêneros via `/genre/movie/list` e traduzir
/// os IDs em nomes no momento do sync.
///
/// ## Por que `id + locale` como PK composta
///
/// O TMDB suporta traduções por idioma. Para coexistir `pt-BR`, `en-US`,
/// etc. sem conflito, a chave primária inclui o locale. Cada linha é
/// "este ID de gênero, neste idioma, tem este nome".
///
/// ## Heurística de refresh
///
/// O TMDB raramente adiciona novos gêneros (estável desde 2024 com ~19
/// entradas). O `TmdbService.getGenres()` chama o endpoint apenas:
/// 1. Na primeira vez (banco vazio para aquele locale);
/// 2. Quando `ensureGenresCover` detecta um `genre_id` desconhecido.
class TmdbGenres extends Table {
  /// TMDB genre id (e.g. 28 = Action).
  IntColumn get id => integer()();

  /// Nome traduzido (e.g. "Ação" em pt-BR, "Action" em en-US).
  TextColumn get name => text()();

  /// Locale TMDB (e.g. "pt-BR", "en-US"). NÃO é o `Locale.languageCode`
  /// do Flutter — é o formato que a API espera.
  TextColumn get locale => text()();

  /// Quando essa linha foi buscada pela última vez do TMDB.
  /// Útil para futuro TTL ou auditoria.
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id, locale};
}
