// Data models for The Movie Database (TMDB) API v3
//
// More info: https://developer.themoviedb.org/reference/intro/getting-started

class TmdbMovie {
  final int id;
  final String title;
  final String? originalTitle;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate; // YYYY-MM-DD
  final double? voteAverage;
  final int? voteCount;
  final int? runtime; // minutos
  final String? tagline;
  final String? status;
  final List<TmdbGenre> genres;

  TmdbMovie({
    required this.id,
    required this.title,
    this.originalTitle,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.voteAverage,
    this.voteCount,
    this.runtime,
    this.tagline,
    this.status,
    this.genres = const [],
  });

  /// Extrai ano (int) de releaseDate
  int? get year {
    if (releaseDate == null || releaseDate!.isEmpty) return null;
    final match = RegExp(r'^(\d{4})').firstMatch(releaseDate!);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// Imagem completa para poster (default w500)
  String getFullPosterUrl({String size = 'w500'}) {
    if (posterPath == null || posterPath!.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/$size$posterPath';
  }

  /// Imagem completa para backdrop (default w1280)
  String getFullBackdropUrl({String size = 'w1280'}) {
    if (backdropPath == null || backdropPath!.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/$size$backdropPath';
  }

  factory TmdbMovie.fromJson(Map<String, dynamic> json) {
    return TmdbMovie(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Sem título',
      originalTitle: json['original_title'],
      overview: json['overview'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      releaseDate: json['release_date'],
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      voteCount: json['vote_count'] as int?,
      runtime: json['runtime'] as int?,
      tagline: json['tagline'],
      status: json['status'],
      genres: (json['genres'] as List<dynamic>?)
              ?.map((g) => TmdbGenre.fromJson(g as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  factory TmdbMovie.fromSearchJson(Map<String, dynamic> json) {
    return TmdbMovie(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Sem título',
      originalTitle: json['original_title'],
      overview: json['overview'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      releaseDate: json['release_date'],
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      voteCount: json['vote_count'] as int?,
      runtime: null, // não vem em search results
      tagline: null,
      status: null,
      genres: const [], // não vem em search results
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

/// Resposta paginada de /search/movie
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
