enum AnimeSource { pauloFlix }

class Anime {
  final String name;
  final String url;
  final AnimeSource source;
  final String? fallbackImageUrl;

  Anime({
    required this.name,
    required this.url,
    this.source = AnimeSource.pauloFlix,
    this.fallbackImageUrl,
  });

  @override
  String toString() => name;

  String get imageUrl => fallbackImageUrl ?? '';
  String get sourceName => 'PauloFlix';
}
