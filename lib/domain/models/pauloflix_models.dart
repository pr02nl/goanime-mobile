// Data models for PauloFlix file server
//
// PauloFlix is a simple file server with HTML directory listings
// for TV shows, organized as: /tvshows/{ShowName}/Season {XX}/S01E01.mkv

class PauloFlixShow {
  final String name;
  final String url;

  /// Nome do arquivo `poster.jpg` (ou similar) na pasta do show,
  /// se existir. O `PauloFlixService` detecta isso durante
  /// `fetchAllShows` e o usa como fallback no `fromNfo` quando
  /// o `tvshow.nfo` não tem `<thumb aspect="poster">`.
  final String? posterFileName;

  /// Nome do arquivo `fanart.jpg` (ou `banner.jpg`) na pasta do
  /// show, se existir. Mesmo rationale do [posterFileName].
  final String? fanartFileName;

  /// URL absoluta do poster resolvida, ou `null` se não existir.
  String? get posterUrl {
    if (posterFileName == null) return null;
    final base = url.endsWith('/') ? url : '$url/';
    return '$base${Uri.encodeComponent(posterFileName!)}';
  }

  /// URL absoluta do fanart resolvida, ou `null` se não existir.
  String? get fanartUrl {
    if (fanartFileName == null) return null;
    final base = url.endsWith('/') ? url : '$url/';
    return '$base${Uri.encodeComponent(fanartFileName!)}';
  }

  const PauloFlixShow({
    required this.name,
    required this.url,
    this.posterFileName,
    this.fanartFileName,
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

  /// URL absoluta do thumbnail do episode (servidor PauloFlix).
  /// Populada pelo `PauloFlixService.syncContent` durante o sync,
  /// lendo o campo `thumb` do JSON index.
  ///
  /// Nullable porque:
  /// 1. Pasta de season pode não ter thumb (mostra placeholder na UI).
  /// 2. Sync antigo não populou este campo, mas rows antigos ficam
  ///    com `null` (não re-raspamos retroativamente).
  ///
  /// O `PauloFlixEpisodeProgressViewModel.scrapingEpisodesForSelected`
  /// propaga este campo a partir do `PauloFlixEpisodeRecord`.
  final String? thumbnailUrl;

  const PauloFlixEpisode({
    required this.number,
    required this.title,
    required this.url,
    this.fileSize,
    this.thumbnailUrl,
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
