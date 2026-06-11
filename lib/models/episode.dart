class Episode {
  final String number;
  final String url;
  final String? thumbnail;
  final String? title;
  final String? description;

  Episode({
    required this.number,
    required this.url,
    this.thumbnail,
    this.title,
    this.description,
  });

  @override
  String toString() => number;

  /// Get episode thumbnail URL
  String? getImageUrl() => thumbnail;
}

/// Stream Episode List Item with enhanced metadata
class StreamEpisodeListItem {
  final String episodeNumber;
  final String? thumbnailUrl;
  final String? title;
  final String? description;
  final String? url;
  final Duration? duration;
  final DateTime? airDate;

  StreamEpisodeListItem({
    required this.episodeNumber,
    this.thumbnailUrl,
    this.title,
    this.description,
    this.url,
    this.duration,
    this.airDate,
  });

  /// Get episode thumbnail image URL
  String? getImageUrl() => thumbnailUrl;

  /// Convert to Episode for compatibility
  Episode toEpisode() {
    return Episode(
      number: episodeNumber,
      url: url ?? '',
      thumbnail: thumbnailUrl,
      title: title,
      description: description,
    );
  }

  factory StreamEpisodeListItem.fromJson(Map<String, dynamic> json) {
    return StreamEpisodeListItem(
      episodeNumber:
          json['episodeNumber']?.toString() ?? json['number']?.toString() ?? '',
      thumbnailUrl: json['thumbnail'] ?? json['thumbnailUrl'] ?? json['image'],
      title: json['title'] ?? json['name'],
      description: json['description'] ?? json['synopsis'],
      url: json['url'],
      duration: json['duration'] != null
          ? Duration(
              seconds: json['duration'] is int
                  ? json['duration']
                  : int.tryParse(json['duration'].toString()) ?? 0,
            )
          : null,
      airDate: json['airDate'] != null
          ? DateTime.tryParse(json['airDate'].toString())
          : null,
    );
  }
}
