import '../../data/models/jikan_models.dart';
import '../../data/services/kodi/kodi_nfo_models.dart';
import '../../data/services/kodi/pauloflix_nfo_enricher.dart';
import '../../core/utils/genre_codec.dart';

/// Conteúdo mapeado do PauloFlix com metadados do Jikan
class PauloFlixContent {
  final int? id;
  final String folderName;
  final String displayName;
  final String serverUrl;
  final String? imageUrl;
  final String? bannerUrl;
  final String? description;
  final double? score;
  final List<String> genres;
  final String? status;
  final int? episodeCount;
  final int? malId;
  final int? anilistId;

  /// Título original (idioma original da produção).
  final String? originalTitle;

  /// Ano de estreia.
  final int? year;

  /// ID do TMDB para fallback de metadados.
  final int? tmdbId;

  final DateTime lastSynced;
  final bool isAvailable;

  PauloFlixContent({
    this.id,
    required this.folderName,
    required this.displayName,
    required this.serverUrl,
    this.imageUrl,
    this.bannerUrl,
    this.description,
    this.score,
    this.genres = const [],
    this.status,
    this.episodeCount,
    this.malId,
    this.anilistId,
    this.originalTitle,
    this.year,
    this.tmdbId,
    DateTime? lastSynced,
    this.isAvailable = true,
  }) : lastSynced = lastSynced ?? DateTime.now();

  factory PauloFlixContent.fromJikan({
    required String folderName,
    required String serverUrl,
    required JikanAnime jikanAnime,
  }) {
    return PauloFlixContent(
      folderName: folderName,
      displayName: jikanAnime.title,
      serverUrl: serverUrl,
      imageUrl: jikanAnime.imageUrl,
      bannerUrl: jikanAnime.largImageUrl,
      description: jikanAnime.synopsis,
      score: jikanAnime.score,
      genres: jikanAnime.genres.map((g) => g.name).toList(),
      status: jikanAnime.status,
      episodeCount: jikanAnime.episodes,
      malId: jikanAnime.malId,
    );
  }

  /// Cria um [PauloFlixContent] a partir de um NFO parseado do servidor
  /// PauloFlix (`tvshow.nfo` / `movie.nfo`).
  ///
  /// **Origem (Fase 3 do plano NFO enrichment):** quando o servidor
  /// PauloFlix tem o arquivo NFO do show, o `PauloFlixNfoEnricher` faz
  /// o parse e chama este factory. NFO é a fonte primária de
  /// `displayName`/`description`/`genres`/`score`/`imageUrl`/`bannerUrl`;
  /// Jikan só é chamado como fallback (em `PauloFlixService.syncContent`).
  ///
  /// **Campos não disponíveis no NFO:** `status` (NFO tem `<status>`
  /// "Continuing"/"Ended" mas não mapeamos nesta versão), `episodeCount`
  /// (NFO de tvshow não traz), `malId`, `anilistId` (vínculo com
  /// MyAnimeList/AniList não está no NFO). Esses campos ficam `null` —
  /// se o caller quiser, pode enriquecer com Jikan depois.
  ///
  /// **Resolução de URLs de imagem:** [nfo] pode conter URLs absolutas
  /// (`http://...`) ou paths relativos (`poster.jpg`). O
  /// `PauloFlixNfoEnricher.resolveThumbUrl` cuida de juntar com
  /// [serverUrl] (e aplicar URL-encoding nos paths relativos).
  factory PauloFlixContent.fromNfo({
    required String folderName,
    required String serverUrl,
    required KodiShowNfo nfo,
    String? fallbackPosterUrl,
    String? fallbackFanartUrl,
  }) {
    return PauloFlixContent(
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
      // Campos que NFO não cobre nesta versão — ficam null. O caller
      // pode preencher via Jikan se quiser (não é o caso do sync padrão).
      status: null,
      episodeCount: null,
      malId: null,
      anilistId: null,
    );
  }

  /// Cria um [PauloFlixContent] a partir do JSON index do servidor
  /// PauloFlix (`tv_index.json`).
  ///
  /// O JSON já contém todos os metadados disponíveis (título,
  /// descrição, poster, fanart, gêneros, etc.), eliminando a
  /// necessidade de scraping HTML + chamadas à Jikan.
  ///
  /// [baseHost] é o host sem path (ex: `https://media.oliveira.braga.nom.br`).
  /// Os paths relativos do JSON (`/tvshows/.../poster.jpg`) são
  /// resolvidos para URLs absolutas automaticamente.
  factory PauloFlixContent.fromTvIndex({
    required Map<String, dynamic> json,
    required String baseHost,
  }) {
    final path = json['path'] as String;
    final encodedPath = Uri.encodeComponent(path);
    final serverUrl = '$baseHost/tvshows/$encodedPath/';

    String? resolveUrl(String? relative) {
      if (relative == null || relative.isEmpty) return null;
      return relative.startsWith('http') ? relative : '$baseHost$relative';
    }

    return PauloFlixContent(
      folderName: path,
      displayName: (json['title'] as String?) ?? path,
      serverUrl: serverUrl,
      imageUrl: resolveUrl(json['poster'] as String?),
      bannerUrl: resolveUrl(
            json['banner'] as String? ?? json['fanart'] as String?,
      ),
      description: json['description'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      genres: json['genres'] != null
          ? List<String>.from(json['genres'] as List)
          : [],
      status: json['status'] as String?,
      episodeCount: json['episode_count'] as int?,
      originalTitle: json['original_title'] as String?,
      year: json['year'] as int?,
      tmdbId: json['tmdb_id'] as int?,
      malId: json['mal_id'] as int?,
      anilistId: json['anilist_id'] as int?,
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
      // JSON (não CSV): preserva vírgulas dentro de nomes de gênero
      // como "Slice of Life" e "Action, Adventure" sem ambiguidade.
      'genres': encodeGenres(genres),
      'status': status,
      'episodeCount': episodeCount,
      'malId': malId,
      'anilistId': anilistId,
      'originalTitle': originalTitle,
      'year': year,
      'tmdbId': tmdbId,
      'lastSynced': lastSynced.toIso8601String(),
      'isAvailable': isAvailable ? 1 : 0,
    };
  }

  factory PauloFlixContent.fromMap(Map<String, dynamic> map) {
    return PauloFlixContent(
      id: map['id'] as int?,
      folderName: map['folderName'] as String,
      displayName: map['displayName'] as String,
      serverUrl: map['serverUrl'] as String,
      imageUrl: map['imageUrl'] as String?,
      bannerUrl: map['bannerUrl'] as String?,
      description: map['description'] as String?,
      score: map['score'] as double?,
      // Decodifica JSON. Em bancos legados (pré-Fase 1) com CSV, faz
      // fallback para split por vírgula para não quebrar a leitura de
      // instalações antigas antes da migração v1→v3.
      genres: decodeGenresOrFallback(map['genres']),
      status: map['status'] as String?,
      episodeCount: map['episodeCount'] as int?,
      malId: map['malId'] as int?,
      anilistId: map['anilistId'] as int?,
      originalTitle: map['originalTitle'] as String?,
      year: map['year'] as int?,
      tmdbId: map['tmdbId'] as int?,
      lastSynced: DateTime.parse(map['lastSynced'] as String),
      isAvailable: (map['isAvailable'] as int) == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PauloFlixContent &&
          runtimeType == other.runtimeType &&
          folderName == other.folderName;

  @override
  int get hashCode => folderName.hashCode;

  @override
  String toString() => 'PauloFlixContent($displayName)';
}
