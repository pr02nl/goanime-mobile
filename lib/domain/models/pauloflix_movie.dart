import 'dart:convert';

import '../../data/models/tmdb_models.dart';
import '../../data/services/kodi/kodi_nfo_models.dart';
import '../../data/services/kodi/pauloflix_nfo_enricher.dart';
import '../../core/utils/genre_codec.dart';
import 'pauloflix_movie_item.dart';

/// Conteúdo mapeado do PauloFlix Movies com metadados do TMDB.
///
/// Representa um filme individual com metadados do JSON index
/// (`movie_index.json`). Cada filme tem URL direta do vídeo (`file`)
/// e legendas externas opcionais (`subtitles`).
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
  final int availableMovieCount;
  final DateTime lastSynced;
  /// URL direta do arquivo de vídeo, vinda do campo `file` do
  /// `movie_index.json`. `null` para filmes que ainda dependem de
  /// scraping on-demand (`fetchMovieFile`).
  final String? videoUrl;

  /// Legendas externas vindas do campo `subtitles` do `movie_index.json`.
  /// `null` para filmes que não têm subtitles no JSON index.
  /// Cada [ExternalSubtitleEntry] já tem [file] como URL absoluta.
  final List<ExternalSubtitleEntry>? subtitles;

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
    this.videoUrl,
    this.subtitles,
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
    String? fallbackPosterUrl,
    String? fallbackFanartUrl,
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
      imageUrl: tmdb.getFullPosterUrl().isNotEmpty
          ? tmdb.getFullPosterUrl()
          : fallbackPosterUrl,
      bannerUrl: tmdb.getFullBackdropUrl().isNotEmpty
          ? tmdb.getFullBackdropUrl()
          : fallbackFanartUrl,
      description: tmdb.overview,
      score: tmdb.voteAverage,
      genres: resolvedGenres,
      releaseDate: tmdb.releaseDate,
      runtime: tmdb.runtime,
      year: tmdb.year,
      tmdbId: tmdb.id,
      availableMovieCount: 1,
    );
  }

  /// Cria a partir do JSON index do servidor PauloFlix
  /// (`movie_index.json`).
  ///
  /// O JSON já contém todos os metadados disponíveis (título, ano,
  /// descrição, poster, fanart, gêneros, etc.), eliminando a
  /// necessidade de scraping HTML + chamadas à TMDB.
  ///
  /// [baseHost] é o host sem path (ex: `https://media.oliveira.braga.nom.br`).
  /// Os paths relativos do JSON (`/movies/.../poster.jpg`) são
  /// resolvidos para URLs absolutas automaticamente.
  factory PauloFlixMovie.fromMovieIndex({
    required Map<String, dynamic> json,
    required String baseHost,
  }) {
    final path = json['path'] as String;
    final encodedPath = Uri.encodeComponent(path);
    final serverUrl = '$baseHost/movies/$encodedPath/';

    String? resolveUrl(String? relative) {
      if (relative == null || relative.isEmpty) return null;
      return relative.startsWith('http') ? relative : '$baseHost$relative';
    }

    // Parse `file` — URL direta do vídeo
    final file = json['file'] as String?;
    final videoUrl = file != null ? resolveUrl(file) : null;

    // Parse `subtitles` — legendas externas
    List<ExternalSubtitleEntry>? subtitles;
    if (json['subtitles'] != null && (json['subtitles'] as List).isNotEmpty) {
      subtitles = (json['subtitles'] as List)
          .map((s) => ExternalSubtitleEntry.fromJson(s as Map<String, dynamic>))
          .toList();
      // Resolve paths relativos para URLs absolutas
      for (var i = 0; i < subtitles.length; i++) {
        final entry = subtitles[i];
        final resolvedFile = resolveUrl(entry.file);
        if (resolvedFile != null && resolvedFile != entry.file) {
          subtitles[i] = ExternalSubtitleEntry(
            file: resolvedFile,
            lang: entry.lang,
            name: entry.name,
          );
        }
      }
    }

    return PauloFlixMovie(
      folderName: path,
      displayName: (json['title'] as String?) ?? path,
      serverUrl: serverUrl,
      imageUrl: resolveUrl(json['poster'] as String?),
      bannerUrl: resolveUrl(json['fanart'] as String?),
      description: json['description'] as String?,
      score: (json['rating'] as num?)?.toDouble(),
      genres: json['genres'] != null
          ? List<String>.from(json['genres'] as List)
          : [],
      releaseDate: json['release_date'] as String?,
      runtime: json['runtime'] as int?,
      year: json['year'] as int?,
      tmdbId: json['tmdb_id'] as int?,
      videoUrl: videoUrl,
      subtitles: subtitles,
      availableMovieCount: (json['available_movie_count'] as int?) ?? 1,
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
    String? fallbackPosterUrl,
    String? fallbackFanartUrl,
  }) {
    return PauloFlixMovie(
      folderName: folderName,
      displayName: nfo.title ?? folderName,
      serverUrl: serverUrl,
      imageUrl: nfo.posterThumb != null
          ? PauloFlixNfoEnricher.resolveThumbUrl(serverUrl, nfo.posterThumb!)
          : fallbackPosterUrl,
      bannerUrl: nfo.fanartThumb != null
          ? PauloFlixNfoEnricher.resolveThumbUrl(serverUrl, nfo.fanartThumb!)
          : fallbackFanartUrl,
      description: nfo.plot,
      score: nfo.rating,
      genres: nfo.genres,
      // Campos que NFO não cobre nesta versão — ficam null.
      releaseDate: null,
      runtime: null,
      year: nfo.year,
      tmdbId: null,
      videoUrl: null, // NFO não tem URL de vídeo
      subtitles: null, // NFO não tem subtitles
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
      'videoUrl': videoUrl,
      'subtitles': subtitles != null && subtitles!.isNotEmpty
          ? jsonEncode(subtitles!.map((s) => s.toJson()).toList())
          : null,
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
      videoUrl: map['videoUrl'] as String?,
      subtitles: map['subtitles'] != null
          ? (jsonDecode(map['subtitles'] as String) as List)
              .map((s) => ExternalSubtitleEntry.fromJson(s as Map<String, dynamic>))
              .toList()
          : null,
      releaseDate: map['releaseDate'] as String?,
      runtime: map['runtime'] as int?,
      year: map['year'] as int?,
      tmdbId: map['tmdbId'] as int?,
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
    String? videoUrl,
    List<ExternalSubtitleEntry>? subtitles,
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
      videoUrl: videoUrl ?? this.videoUrl,
      subtitles: subtitles ?? this.subtitles,
      releaseDate: releaseDate ?? this.releaseDate,
      runtime: runtime ?? this.runtime,
      year: year ?? this.year,
      tmdbId: tmdbId ?? this.tmdbId,
      availableMovieCount: availableMovieCount ?? this.availableMovieCount,
      lastSynced: lastSynced ?? this.lastSynced,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}
