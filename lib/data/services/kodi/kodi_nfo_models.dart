/// DTOs imutáveis para o pipeline de parse de arquivos NFO do Kodi.
///
/// Fonte: plano `.hermes/plans/2026-06-23_224213-pauloflix-nfo-enrichment.md` (Fase 1).
///
/// Os DTOs refletem apenas o subconjunto do schema NFO do Kodi que
/// o PauloFlix consome (escopo mínimo viável aprovado). Outros campos
/// (studio, actor, mpaa, premiered, status) ficam fora desta versão.
///
/// **Formato de campos de imagem** (posterThumb, bannerThumb, fanartThumb,
/// thumb): podem ser:
/// - URL absoluta (`http://...` ou `https://...`) — usar diretamente.
/// - Path relativo (`poster.jpg`) — combinar com `serverUrl` no momento
///   da requisição HTTP (responsabilidade do `PauloFlixNfoEnricher`).
library;

/// NFO de `tvshow.nfo` e `movie.nfo` (mesma estrutura).
///
/// Root: `<tvshow>` ou `<movie>` (Kodi standard). Esta classe é
/// compartilhada entre shows e movies — o parser decide qual root
/// procurar (`KodiNfoParser.parseShow` vs `parseMovie`).
class KodiShowNfo {
  /// Título do show/movie. Vem de `<title>`.
  final String? title;

  /// Sinopse / descrição. Vem de `<plot>` (preserva quebras de linha
  /// e CDATA se houver).
  final String? plot;

  /// Lista de gêneros. Vem de múltiplas tags `<genre>`.
  /// Strings vazias são descartadas pelo parser.
  final List<String> genres;

  /// Ano de lançamento. Vem de `<year>`.
  /// Valores não numéricos (ex: `<year>unknown</year>`) viram `null`.
  final int? year;

  /// Rating / score. Vem de `<rating>` (ex: `8.4`).
  /// Valores não numéricos viram `null`.
  final double? rating;

  /// URL absoluta ou path relativo do poster.
  /// Vem de `<thumb aspect="poster">poster.jpg</thumb>` (primeiro match).
  final String? posterThumb;

  /// URL absoluta ou path relativo do banner.
  /// Vem de `<thumb aspect="banner">banner.jpg</thumb>` (primeiro match).
  final String? bannerThumb;

  /// URL absoluta ou path relativo do fanart.
  /// Vem de `<thumb aspect="fanart">fanart.jpg</thumb>` (primeiro match).
  final String? fanartThumb;

  /// Construtor imutável. Use `const` quando possível.
  const KodiShowNfo({
    this.title,
    this.plot,
    this.genres = const <String>[],
    this.year,
    this.rating,
    this.posterThumb,
    this.bannerThumb,
    this.fanartThumb,
  });
}

/// NFO de `season.nfo`. Usado para enricher de season-level metadata
/// (não lido nesta primeira versão — incluído para completude do schema
/// e para suportar Fase 2.5 no futuro).
class KodiSeasonNfo {
  /// Número da season. Vem de `<season>`.
  final int? seasonNumber;

  /// Sinopse / overview da season. Vem de `<plot>`.
  final String? plot;

  /// URL absoluta ou path relativo do poster da season.
  /// Vem de `<thumb>` (primeiro thumb sem aspect ou com aspect="poster").
  final String? posterThumb;

  /// Construtor imutável.
  const KodiSeasonNfo({
    this.seasonNumber,
    this.plot,
    this.posterThumb,
  });
}

/// NFO de `episodedetails.nfo`.
///
/// Root: `<episodedetails>` (Kodi standard).
/// Usado para enricher de episode-level metadata.
class KodiEpisodeNfo {
  /// Número da season. Vem de `<season>`.
  final int? seasonNumber;

  /// Número do episode. Vem de `<episode>`.
  final int? episodeNumber;

  /// Título do episode. Vem de `<title>`.
  final String? title;

  /// Sinopse / overview do episode. Vem de `<plot>`.
  final String? plot;

  /// URL absoluta ou path relativo do thumb do episode.
  /// Vem de `<thumb>` (primeiro thumb disponível).
  final String? thumb;

  /// Construtor imutável.
  const KodiEpisodeNfo({
    this.seasonNumber,
    this.episodeNumber,
    this.title,
    this.plot,
    this.thumb,
  });
}
