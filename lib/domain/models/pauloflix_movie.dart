import 'dart:convert';

import '../../core/utils/genre_codec.dart';
import 'pauloflix_movie_item.dart';

/// Conteúdo mapeado do PauloFlix Movies.
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
  final int? runtime;
  final int? year;
  final int? tmdbId;
  final DateTime lastSynced;

  /// URL direta do arquivo de vídeo, vinda do campo `file` do
  /// `movie_index.json`.
  final String? videoUrl;

  /// Legendas externas vindas do campo `subtitles` do `movie_index.json`.
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
    this.runtime,
    this.year,
    this.tmdbId,
    this.videoUrl,
    this.subtitles,
    DateTime? lastSynced,
    this.isAvailable = true,
  }) : lastSynced = lastSynced ?? DateTime.now();

  /// Cria a partir do JSON index do servidor PauloFlix
  /// (`movie_index.json`).
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

    final file = json['file'] as String?;
    final videoUrl = file != null ? resolveUrl(file) : null;

    List<ExternalSubtitleEntry>? subtitles;
    if (json['subtitles'] != null && (json['subtitles'] as List).isNotEmpty) {
      subtitles = (json['subtitles'] as List)
          .map((s) => ExternalSubtitleEntry.fromJson(s as Map<String, dynamic>))
          .toList();
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
      description: json['plot'] as String?,
      score: json['rating'] is num
          ? (json['rating'] as num).toDouble()
          : double.tryParse(json['rating'] as String? ?? ''),
      genres: json['genre'] != null
          ? List<String>.from(json['genre'] as List)
          : [],
      runtime: json['runtime'] is int
          ? json['runtime'] as int
          : int.tryParse(json['runtime'] as String? ?? ''),
      year: json['year'] is int
          ? json['year'] as int
          : int.tryParse(json['year'] as String? ?? ''),
      tmdbId: json['tmdb_id'] is int
          ? json['tmdb_id'] as int
          : int.tryParse(json['tmdb_id'] as String? ?? ''),
      videoUrl: videoUrl,
      subtitles: subtitles,
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
      'runtime': runtime,
      'year': year,
      'tmdbId': tmdbId,
      'videoUrl': videoUrl,
      'subtitles': subtitles != null && subtitles!.isNotEmpty
          ? jsonEncode(subtitles!.map((s) => s.toJson()).toList())
          : null,
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
      genres: decodeGenresOrFallback(map['genres']),
      videoUrl: map['videoUrl'] as String?,
      subtitles: map['subtitles'] != null
          ? (jsonDecode(map['subtitles'] as String) as List)
                .map(
                  (s) =>
                      ExternalSubtitleEntry.fromJson(s as Map<String, dynamic>),
                )
                .toList()
          : null,
      runtime: map['runtime'] as int?,
      year: map['year'] as int?,
      tmdbId: map['tmdbId'] as int?,
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

  PauloFlixMovie copyWith({
    String? folderName,
    String? displayName,
    String? serverUrl,
    String? imageUrl,
    String? bannerUrl,
    String? description,
    double? score,
    List<String>? genres,
    int? runtime,
    int? year,
    int? tmdbId,
    String? videoUrl,
    List<ExternalSubtitleEntry>? subtitles,
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
      runtime: runtime ?? this.runtime,
      year: year ?? this.year,
      tmdbId: tmdbId ?? this.tmdbId,
      lastSynced: lastSynced ?? this.lastSynced,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}
