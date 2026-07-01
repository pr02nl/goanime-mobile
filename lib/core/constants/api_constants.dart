class ApiConstants {
  ApiConstants._();

  static const String jikanBaseUrl = 'https://api.jikan.moe/v4';
  static const String anilistBaseUrl = 'https://graphql.anilist.co';
  static const String introdbBaseUrl = 'https://api.theintrodb.org/v3';
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String tmdbImageBase = 'https://image.tmdb.org/t/p';
  static const String animeFireBaseUrl = 'https://animefire.plus';
  // PauloFlix migrou de Tailscale (relay DERP, 2.1 Mbps) para HTTPS
  // direto via domínio próprio. Auth via JWT Ed25519 — toda request
  // injeta `Authorization: Bearer *** (ver AuthenticatedHttpClient).
  static const String animePauloFlix =
      'https://media.oliveira.braga.nom.br/tvshows/';
  static const String moviePauloFlix =
      'https://media.oliveira.braga.nom.br/movies/';
  static const String kitsuBaseUrl = 'https://kitsu.io/api/edge';

  // JSON index files — índice completo com todos os metadados,
  // gerado server-side para sync rápido (substitui scraping HTML).
  static const String tvIndexUrl =
      'https://media.oliveira.braga.nom.br/tvshows/tv_index.json';
  static const String movieIndexUrl =
      'https://media.oliveira.braga.nom.br/movies/movie_index.json';

  /// Host base do servidor de mídia — usado para resolver paths
  /// relativos nos JSON index (`tv_index.json`, `movie_index.json`).
  static const String mediaBaseHost = 'https://media.oliveira.braga.nom.br';
}
