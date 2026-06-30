import 'package:flutter/material.dart';

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

  /// IDs do AniList para AniSkip. Quando nulos, o player tenta
  /// resolver por busca textual na AniList API.
  final int? malId;
  final int? anilistId;

  const PlayerRouteData({
    this.movieFolderName,
    this.malId,
    this.anilistId,

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

class SourceSelectionRouteData {
  final String animeTitle;
  final String imageUrl;
  final String myAnimeListUrl;

  const SourceSelectionRouteData({
    required this.animeTitle,
    required this.imageUrl,
    required this.myAnimeListUrl,
  });
}

class GenreRouteData {
  final String title;
  final IconData icon;
  final LinearGradient gradient;
  final int genreId;

  const GenreRouteData({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.genreId,
  });
}

class WebViewRouteData {
  final String url;
  final String title;

  const WebViewRouteData({required this.url, required this.title});
}
