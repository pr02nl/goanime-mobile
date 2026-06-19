import '../../models/jikan_models.dart';

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
      'status': status,
      'episodeCount': episodeCount,
      'malId': malId,
      'anilistId': anilistId,
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
      genres:
          (map['genres'] as String?)
              ?.split(',')
              .where((g) => g.isNotEmpty)
              .toList() ??
          [],
      status: map['status'] as String?,
      episodeCount: map['episodeCount'] as int?,
      malId: map['malId'] as int?,
      anilistId: map['anilistId'] as int?,
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
