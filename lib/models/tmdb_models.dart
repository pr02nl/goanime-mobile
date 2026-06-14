// Data models para The Movie Database (TMDB) API v3.
//
// Documentação oficial:
//   https://developer.themoviedb.org/reference/intro/getting-started
//
// Observações:
// - A doc oficial usa autenticação via Bearer Token (v4) OU api_key v3 em
//   query/header. Estes models funcionam para ambos.
// - Campos marcados como nullable são realmente opcionais em algumas
//   respostas (ex: `runtime` só vem em /details, não em /search).

/// Coleção à qual o filme pertence (vinda do TMDB).
///
/// A doc oficial mostra o objeto `belongs_to_collection` em /movie/{id}.
/// Notavelmente, ele tem seu próprio `poster_path` e `backdrop_path`,
/// úteis para preencher coleções.
class TmdbCollection {
  final int id;
  final String name;
  final String? posterPath;
  final String? backdropPath;

  TmdbCollection({
    required this.id,
    required this.name,
    this.posterPath,
    this.backdropPath,
  });

  factory TmdbCollection.fromJson(Map<String, dynamic> json) {
    return TmdbCollection(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
    );
  }
}

class TmdbMovie {
  final int id;
  final String title;
  final String? originalTitle;
  final String? originalLanguage;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate; // YYYY-MM-DD

  // Métricas
  final double? voteAverage;
  final int? voteCount;
  final double? popularity;

  // Detalhes (só em /movie/{id})
  final int? runtime; // minutos
  final String? tagline;
  final String? status; // "Released", "In Production"...
  final String? imdbId;
  final String? homepage;
  final List<TmdbGenre> genres;
  final TmdbCollection? collection;

  // Search-only
  final List<int> genreIds;

  const TmdbMovie({
    required this.id,
    required this.title,
    this.originalTitle,
    this.originalLanguage,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.voteAverage,
    this.voteCount,
    this.popularity,
    this.runtime,
    this.tagline,
    this.status,
    this.imdbId,
    this.homepage,
    this.genres = const [],
    this.collection,
    this.genreIds = const [],
  });

  /// Extrai ano (int) de releaseDate.
  int? get year {
    if (releaseDate == null || releaseDate!.isEmpty) return null;
    final match = RegExp(r'^(\d{4})').firstMatch(releaseDate!);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  String getFullPosterUrl({String size = 'w500'}) {
    if (posterPath == null || posterPath!.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/$size$posterPath';
  }

  String getFullBackdropUrl({String size = 'w1280'}) {
    if (backdropPath == null || backdropPath!.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/$size$backdropPath';
  }

  /// Factory para /movie/{id} (detalhes completos).
  factory TmdbMovie.fromJson(Map<String, dynamic> json) {
    return TmdbMovie(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Sem título',
      originalTitle: json['original_title'],
      originalLanguage: json['original_language'],
      overview: json['overview'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      releaseDate: json['release_date'],
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      voteCount: json['vote_count'] as int?,
      popularity: (json['popularity'] as num?)?.toDouble(),
      runtime: json['runtime'] as int?,
      tagline: json['tagline'],
      status: json['status'],
      imdbId: json['imdb_id'],
      homepage: json['homepage'],
      genres: (json['genres'] as List<dynamic>?)
              ?.map((g) => TmdbGenre.fromJson(g as Map<String, dynamic>))
              .toList() ??
          const [],
      collection: json['belongs_to_collection'] != null
          ? TmdbCollection.fromJson(
              json['belongs_to_collection'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// Factory para /search/movie (campos reduzidos — sem runtime/genres
  /// explícitos, mas com `genre_ids` que é seu equivalente).
  factory TmdbMovie.fromSearchJson(Map<String, dynamic> json) {
    return TmdbMovie(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Sem título',
      originalTitle: json['original_title'],
      originalLanguage: json['original_language'],
      overview: json['overview'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      releaseDate: json['release_date'],
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      voteCount: json['vote_count'] as int?,
      popularity: (json['popularity'] as num?)?.toDouble(),
      genreIds:
          (json['genre_ids'] as List<dynamic>?)?.cast<int>() ?? const [],
    );
  }

  @override
  String toString() => 'TmdbMovie($id: $title)';
}

class TmdbGenre {
  final int id;
  final String name;

  TmdbGenre({required this.id, required this.name});

  factory TmdbGenre.fromJson(Map<String, dynamic> json) {
    return TmdbGenre(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Desconhecido',
    );
  }

  @override
  String toString() => name;
}

/// Resposta paginada de /search/movie.
class TmdbSearchResponse {
  final int page;
  final List<TmdbMovie> results;
  final int totalPages;
  final int totalResults;

  TmdbSearchResponse({
    required this.page,
    required this.results,
    required this.totalPages,
    required this.totalResults,
  });

  factory TmdbSearchResponse.fromJson(Map<String, dynamic> json) {
    return TmdbSearchResponse(
      page: json['page'] ?? 1,
      results: (json['results'] as List<dynamic>? ?? [])
          .map((j) => TmdbMovie.fromSearchJson(j as Map<String, dynamic>))
          .toList(),
      totalPages: json['total_pages'] ?? 1,
      totalResults: json['total_results'] ?? 0,
    );
  }
}

/// Exceções específicas do TMDB, para permitir tratamento granular.
sealed class TmdbException implements Exception {
  final String message;
  const TmdbException(this.message);
  @override
  String toString() => '$runtimeType: $message';
}

/// 401 Unauthorized — chave inválida.
class TmdbAuthException extends TmdbException {
  const TmdbAuthException(super.message);
}

/// 429 Too Many Requests — rate limit.
class TmdbRateLimitException extends TmdbException {
  const TmdbRateLimitException(super.message);
}

/// Outros erros do servidor (5xx) ou de rede.
class TmdbRequestException extends TmdbException {
  final int? statusCode;
  const TmdbRequestException(super.message, {this.statusCode});
}

/// API não está configurada (sem api key).
class TmdbNotConfiguredException extends TmdbException {
  const TmdbNotConfiguredException() : super('TMDB API não configurada');
}
