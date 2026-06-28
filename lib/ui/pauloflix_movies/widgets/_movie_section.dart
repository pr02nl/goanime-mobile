import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/pauloflix_movie.dart';
import '../../core/widgets/netflix_card.dart';
import '../../core/widgets/netflix_carousel.dart';
import '../models/movie_progress_state.dart';

/// Carrossel horizontal padronizado para uma seção de filmes.
///
/// Encapsula:
/// * [NetflixCarousel] com título + opcional ícone + contagem
/// * Geração de cards com badge apropriado (Coleção vs Filme)
/// * Tap em card → [PauloFlixMovieDetailScreen]
class MovieSection extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<PauloFlixMovie> movies;
  final bool isTV;
  final double cardHeight;

  /// Mapa folderName → estado de progresso. Usado para exibir overlay
  /// de completado ou barra de progresso nos cards.
  final Map<String, MovieProgressState>? progressMap;

  const MovieSection({
    super.key,
    required this.title,
    required this.movies,
    required this.isTV,
    this.icon,
    this.cardHeight = 220,
    this.progressMap,
  });

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();

    return NetflixCarousel(
      title: '$title (${movies.length})',
      isTV: isTV,
      items: [for (final m in movies) _buildCard(context, m)],
    );
  }

  Widget _buildCard(BuildContext context, PauloFlixMovie movie) {
    final progress = progressMap?[movie.folderName];
    final overlay = MovieProgressState.buildOverlayWidget(progress);
    return NetflixCard(
      imageUrl: movie.imageUrl ?? '',
      title: movie.displayName,
      rating: movie.score,
      width: 140,
      height: cardHeight,
      isTV: isTV,
      showTitle: true,
      showRating: movie.score != null,
      overlayWidget: overlay,
      onTap: () {
        context.pushNamed('pauloflix-movie-detail', extra: movie);
      },
    );
  }

}
