// Data models for PauloFlix file server
//
// PauloFlix is a simple file server with HTML directory listings
// for TV shows, organized as: /tvshows/{ShowName}/Season {XX}/S01E01.mkv

class PauloFlixShow {
  final String name;
  final String url;

  const PauloFlixShow({
    required this.name,
    required this.url,
  });

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PauloFlixShow &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          url == other.url;

  @override
  int get hashCode => name.hashCode ^ url.hashCode;
}

class PauloFlixSeason {
  final String name;
  final String url;
  final int number;

  const PauloFlixSeason({
    required this.name,
    required this.url,
    required this.number,
  });

  @override
  String toString() => 'Season $number';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PauloFlixSeason &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          url == other.url &&
          number == other.number;

  @override
  int get hashCode => name.hashCode ^ url.hashCode ^ number.hashCode;
}

class PauloFlixEpisode {
  final int number;
  final String title;
  final String url;
  final int? fileSize;

  const PauloFlixEpisode({
    required this.number,
    required this.title,
    required this.url,
    this.fileSize,
  });

  @override
  String toString() => 'Episode $number: $title';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PauloFlixEpisode &&
          runtimeType == other.runtimeType &&
          number == other.number &&
          title == other.title &&
          url == other.url;

  @override
  int get hashCode => number.hashCode ^ title.hashCode ^ url.hashCode;
}
