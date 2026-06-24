class Episode {
  final String number;
  final String url;
  final String? thumbnail;

  /// URL absoluta do thumb de episódio (servidor PauloFlix NFO,
  /// `S01E001-thumb.jpg`), exposto para o `EpisodeGridCard`.
  ///
  /// **Fase 6 (PauloFlix NFO enrichment):** preenchido a partir do
  /// `PauloFlixEpisode.thumbnailUrl` em
  /// `PauloFlixEpisodeListScreen._playEpisode`. Quando `null`, o
  /// `EpisodeGridCard` exibe o gradient de fallback (sem imagem).
  final String? thumbnailUrl;
  final String? title;
  final String? description;

  /// Lista de tracks de legenda opcionais (URLs SRT externas).
  ///
  /// O player mescla essas legendas externas com as tracks embutidas
  /// que o `media_kit` descobre dentro do MKV/MP4. O usuário pode
  /// alternar entre todas via selector no overlay.
  ///
  /// Suporta múltiplas legendas simultâneas no menu (pt-BR, en, es, etc.).
  ///
  /// Quando vazio e o vídeo tem legendas embutidas, elas ainda aparecem
  /// no selector (carregadas dinamicamente via `player.state.tracks`).
  final List<EpisodeSubtitleTrack> subtitleTracks;

  /// Mantido por compatibilidade: a URL da primeira legenda da lista
  /// [subtitleTracks], ou null se vazia.
  String? get subtitleUrl =>
      subtitleTracks.isNotEmpty ? subtitleTracks.first.url : null;

  /// Idioma inferido da legenda principal.
  String? get subtitleLanguage =>
      subtitleTracks.isNotEmpty ? subtitleTracks.first.language : null;

  Episode({
    required this.number,
    required this.url,
    this.thumbnail,
    this.thumbnailUrl,
    this.title,
    this.description,
    this.subtitleTracks = const [],
  });

  @override
  String toString() => number;

  /// Get episode thumbnail URL
  String? getImageUrl() => thumbnail;
}

/// Representa uma legenda individual disponível para o player.
///
/// Pode ser uma URL `.srt` externa (PauloFlix) ou um identificador de
/// track embutida no MKV (preenchido em runtime pelo `media_kit`).
class EpisodeSubtitleTrack {
  /// URL absoluta do arquivo `.srt` no servidor, ou null quando for
  /// uma track embutida no vídeo (descoberta depois do open).
  final String? url;

  /// Idioma inferido (e.g. `"pt-BR"`, `"en"`). Default é `"pt-BR"`.
  final String language;

  /// Rótulo para mostrar ao usuário.
  final String displayName;

  /// Se `true`, é uma legenda "forced" — exibida mesmo com a faixa principal
  /// desabilitada.
  final bool forced;

  const EpisodeSubtitleTrack({
    this.url,
    required this.language,
    required this.displayName,
    this.forced = false,
  });

  @override
  String toString() =>
      'EpisodeSubtitleTrack($language, ${forced ? "forced, " : ""}$url)';
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
