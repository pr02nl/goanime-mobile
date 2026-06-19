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

  const PlayerRouteData({
    required this.episode,
    required this.animeTitle,
    this.anime,
    this.isMovie = false,
    this.episodeList,
    this.episodeIndex,
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
