import '../../data/models/tmdb_models.dart';
import '../../data/services/kodi/kodi_nfo_models.dart';
import '../../data/services/kodi/pauloflix_nfo_enricher.dart';
import '../../core/utils/genre_codec.dart';

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
  ///
  /// **Heurística de resolução de gêneros:**
  /// 1. Se [tmdb.genres] está populado (endpoint `/movie/{id}`),
  ///    usa os nomes diretamente.
  /// 2. Se [tmdb.genres] está vazio (endpoint `/search/movie`, que só
  ///    retorna `genre_ids`) e [genreIdToName] é fornecido, traduz
  ///    cada `genre_id` em nome via o mapa.
  /// 3. Caso contrário, `genres` fica vazio.
  ///
  /// O [genreIdToName] é populado pelo [TmdbService.getGenres] a partir
  /// do endpoint `/genre/movie/list` (cacheado na tabela `tmdb_genres`).
  /// Sem ele, filmes vindos do search ficam sem gêneros.
  factory PauloFlixMovie.fromTmdb({
    required String folderName,
    required String serverUrl,
    required TmdbMovie tmdb,
    Map<int, String>? genreIdToName,
  }) {
    final List<String> resolvedGenres;
    if (tmdb.genres.isNotEmpty) {
      resolvedGenres = tmdb.genres.map((g) => g.name).toList();
    } else if (genreIdToName != null && tmdb.genreIds.isNotEmpty) {
      resolvedGenres = tmdb.genreIds
          .map((id) => genreIdToName[id])
          .whereType<String>()
          .toList();
    } else {
      resolvedGenres = const [];
    }

    return PauloFlixMovie(
      folderName: folderName,
      displayName: tmdb.title,
      serverUrl: serverUrl,
      imageUrl: tmdb.getFullPosterUrl(),
      bannerUrl: tmdb.getFullBackdropUrl(),
      description: tmdb.overview,
      score: tmdb.voteAverage,
      genres: resolvedGenres,
      releaseDate: tmdb.releaseDate,
      runtime: tmdb.runtime,
      year: tmdb.year,
      tmdbId: tmdb.id,
      isCollection: false,
      availableMovieCount: 1,
    );
  }

  /// Cria a partir de um `KodiShowNfo` parseado de `movie.nfo` (Fase 4 do
  /// plano NFO enrichment). É a fonte **primária** de metadados quando o
  /// servidor PauloFlix tem `movie.nfo` na pasta do filme — nesse caso,
  /// o fallback TMDB **não** é chamado.
  ///
  /// **Campos não disponíveis no NFO:** `releaseDate` (NFO de movie tem
  /// `<premiered>` mas não estamos parseando nesta versão), `runtime`,
  /// `tmdbId` (vínculo com TMDB não está no NFO). Esses campos ficam
  /// `null` — se o caller quiser, pode enriquecer com TMDB depois.
  ///
  /// **Resolução de URLs de imagem:** [nfo] pode conter URLs absolutas
  /// (`http://...`) ou paths relativos (`poster.jpg`). O
  /// `PauloFlixNfoEnricher.resolveThumbUrl` cuida de juntar com
  /// [serverUrl] (e aplicar URL-encoding nos paths relativos).
  factory PauloFlixMovie.fromNfo({
    required String folderName,
    required String serverUrl,
    required KodiShowNfo nfo,
  }) {
    return PauloFlixMovie(
      folderName: folderName,
      displayName: nfo.title ?? folderName,
      serverUrl: serverUrl,
      imageUrl: nfo.posterThumb != null
          ? PauloFlixNfoEnricher.resolveThumbUrl(serverUrl, nfo.posterThumb!)
          : null,
      bannerUrl: nfo.fanartThumb != null
          ? PauloFlixNfoEnricher.resolveThumbUrl(serverUrl, nfo.fanartThumb!)
          : null,
      description: nfo.plot,
      score: nfo.rating,
      genres: nfo.genres,
      // Campos que NFO não cobre nesta versão — ficam null.
      releaseDate: null,
      runtime: null,
      year: nfo.year,
      tmdbId: null,
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
      // JSON (não CSV): preserva vírgulas dentro de nomes de gênero.
      'genres': encodeGenres(genres),
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
      // Mesma estratégia do PauloFlixContent: tenta JSON, fallback CSV.
      genres: decodeGenresOrFallback(map['genres']),
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

  /// Cria uma cópia deste filme substituindo os campos fornecidos.
  /// Campos não fornecidos mantêm o valor original.
  ///
  /// Usado pela migração leve em `_repopulateMissingGenres` para
  /// atualizar apenas `genres` mantendo todo o resto.
  PauloFlixMovie copyWith({
    String? folderName,
    String? displayName,
    String? serverUrl,
    String? imageUrl,
    String? bannerUrl,
    String? description,
    double? score,
    List<String>? genres,
    String? releaseDate,
    int? runtime,
    int? year,
    int? tmdbId,
    bool? isCollection,
    int? availableMovieCount,
    DateTime? lastSynced,
    bool? isAvailable,
  }) {
    return PauloFlixMovie(
      id: id,
      folderName: folderName ?? this.folderName,
      displayName: displayName ?? this.displayName,
      serverUrl: serverUrl ?? this.serverUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      description: description ?? this.description,
      score: score ?? this.score,
      genres: genres ?? this.genres,
      releaseDate: releaseDate ?? this.releaseDate,
      runtime: runtime ?? this.runtime,
      year: year ?? this.year,
      tmdbId: tmdbId ?? this.tmdbId,
      isCollection: isCollection ?? this.isCollection,
      availableMovieCount: availableMovieCount ?? this.availableMovieCount,
      lastSynced: lastSynced ?? this.lastSynced,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}
