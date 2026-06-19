import '../../models/tmdb_models.dart';

/// Conteúdo mapeado do PauloFlix Movies com metadados do TMDB.
///
/// Pode representar tanto um filme individual quanto uma coleção
/// (sub-pastas com filmes do mesmo franchise, ex: "Coleção Harry Potter").
class PauloFlixMovie {
  final int? id;
  final String folderName;
  final String displayName;
  final String serverUrl;
  final String? imageUrl;
  final String? bannerUrl;
  final String? description;
  final double? score;
  final List<String> genres;
  final String? releaseDate;
  final int? runtime;
  final int? year;
  final int? tmdbId;
  final bool isCollection;
  final int availableMovieCount;
  final DateTime lastSynced;
  final bool isAvailable;

  PauloFlixMovie({
    this.id,
    required this.folderName,
    required this.displayName,
    required this.serverUrl,
    this.imageUrl,
    this.bannerUrl,
    this.description,
    this.score,
    this.genres = const [],
    this.releaseDate,
    this.runtime,
    this.year,
    this.tmdbId,
    this.isCollection = false,
    this.availableMovieCount = 0,
    DateTime? lastSynced,
    this.isAvailable = true,
  }) : lastSynced = lastSynced ?? DateTime.now();

  /// Cria a partir de dados do TMDB (filme individual).
  factory PauloFlixMovie.fromTmdb({
    required String folderName,
    required String serverUrl,
    required TmdbMovie tmdb,
  }) {
    return PauloFlixMovie(
      folderName: folderName,
      displayName: tmdb.title,
      serverUrl: serverUrl,
      imageUrl: tmdb.getFullPosterUrl(),
      bannerUrl: tmdb.getFullBackdropUrl(),
      description: tmdb.overview,
      score: tmdb.voteAverage,
      genres: tmdb.genres.map((g) => g.name).toList(),
      releaseDate: tmdb.releaseDate,
      runtime: tmdb.runtime,
      year: tmdb.year,
      tmdbId: tmdb.id,
      isCollection: false,
      availableMovieCount: 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'folderName': folderName,
      'displayName': displayName,
      'serverUrl': serverUrl,
      'imageUrl': imageUrl,
      'bannerUrl': bannerUrl,
      'description': description,
      'score': score,
      'genres': genres.join(','),
      'releaseDate': releaseDate,
      'runtime': runtime,
      'year': year,
      'tmdbId': tmdbId,
      'isCollection': isCollection ? 1 : 0,
      'availableMovieCount': availableMovieCount,
      'lastSynced': lastSynced.toIso8601String(),
      'isAvailable': isAvailable ? 1 : 0,
    };
  }

  factory PauloFlixMovie.fromMap(Map<String, dynamic> map) {
    return PauloFlixMovie(
      id: map['id'] as int?,
      folderName: map['folderName'] as String,
      displayName: map['displayName'] as String,
      serverUrl: map['serverUrl'] as String,
      imageUrl: map['imageUrl'] as String?,
      bannerUrl: map['bannerUrl'] as String?,
      description: map['description'] as String?,
      score: (map['score'] as num?)?.toDouble(),
      genres:
          (map['genres'] as String?)
              ?.split(',')
              .where((g) => g.isNotEmpty)
              .toList() ??
          const [],
      releaseDate: map['releaseDate'] as String?,
      runtime: map['runtime'] as int?,
      year: map['year'] as int?,
      tmdbId: map['tmdbId'] as int?,
      isCollection: (map['isCollection'] as int? ?? 0) == 1,
      availableMovieCount: map['availableMovieCount'] as int? ?? 0,
      lastSynced: DateTime.parse(map['lastSynced'] as String),
      isAvailable: (map['isAvailable'] as int) == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PauloFlixMovie &&
          runtimeType == other.runtimeType &&
          folderName == other.folderName;

  @override
  int get hashCode => folderName.hashCode;

  @override
  String toString() => 'PauloFlixMovie($displayName)';
}
