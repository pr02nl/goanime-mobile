import '../../core/utils/genre_codec.dart';

/// Conteúdo mapeado do PauloFlix TV.
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
    this.originalTitle,
    this.year,
    this.tmdbId,
    DateTime? lastSynced,
    this.isAvailable = true,
  }) : lastSynced = lastSynced ?? DateTime.now();

  /// Cria um [PauloFlixContent] a partir do JSON index do servidor
  /// PauloFlix (`tv_index.json`).
  ///
  /// [baseHost] é o host sem path (ex: `https://media.oliveira.braga.nom.br`).
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
      description: json['plot'] as String?,
      score: json['rating'] is num
          ? (json['rating'] as num).toDouble()
          : double.tryParse(json['rating'] as String? ?? ''),
      genres: json['genre'] != null
          ? List<String>.from(json['genre'] as List)
          : [],
      status: json['status'] as String?,
      episodeCount: json['episode_count'] as int?,
      originalTitle: json['original_title'] as String?,
      year: (json['year'] as String?)?.isNotEmpty == true
          ? int.tryParse(json['year'] as String)
          : null,
      tmdbId: json['tmdb_id'] as int?,
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
      'genres': encodeGenres(genres),
      'status': status,
      'episodeCount': episodeCount,
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
      genres: decodeGenresOrFallback(map['genres']),
      status: map['status'] as String?,
      episodeCount: map['episodeCount'] as int?,
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
