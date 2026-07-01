import '../domain/models/anime.dart';
import '../domain/models/episode.dart';

class PlayerRouteData {
  final Episode episode;
  final String animeTitle;
  final Anime? anime;
  final bool isMovie;
  final List<Episode>? episodeList;
  final int? episodeIndex;

  /// FK para `paulo_flix_content.id` (Fase 5 do plano de progresso —
  /// usado pelo carrossel "Continue assistindo" para refresh após o
  /// player fechar).
  final int? contentId;

  /// FK para `paulo_flix_seasons.id` (Fase 2 do plano de progresso).
  /// `null` para fluxos não-PauloFlix (filmes, AnimeFire).
  final int? seasonId;

  /// Número do episódio (string para casar com `Episode.number`).
  /// `null` para fluxos não-PauloFlix.
  final String? episodeNumber;

  /// `folderName` do filme para salvar progresso.
  /// `null` para fluxos que não são filmes PauloFlix Movies.
  final String? movieFolderName;

  /// TMDB ID para consulta de segmentos (intro/outro) via TheIntroDB.
  /// `null` para fluxos sem metadados TMDB (AnimeFire, etc.).
  final int? tmdbId;

  /// Número da temporada (1, 2, 3...) para consulta TheIntroDB em TV.
  /// `null` para filmes ou quando não disponível.
  final int? seasonNumber;

  const PlayerRouteData({
    this.movieFolderName,
    this.tmdbId,
    this.seasonNumber,

    required this.episode,
    required this.animeTitle,
    this.anime,
    this.isMovie = false,
    this.episodeList,
    this.episodeIndex,
    this.contentId,
    this.seasonId,
    this.episodeNumber,
  });
}
