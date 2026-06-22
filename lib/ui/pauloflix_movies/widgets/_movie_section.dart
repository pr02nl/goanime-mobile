import 'package:flutter/material.dart';

import '../../../domain/models/pauloflix_movie.dart';
import '../../core/widgets/netflix_card.dart';
import '../../core/widgets/netflix_carousel.dart';
import '../../core/widgets/pauloflix_movies_badge.dart';
import 'pauloflix_movie_detail_screen.dart';

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

  const MovieSection({
    super.key,
    required this.title,
    required this.movies,
    required this.isTV,
    this.icon,
    this.cardHeight = 220,
  });

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();

    return NetflixCarousel(
      title: '$title (${movies.length})',
      isTV: isTV,
      items: [
        for (final m in movies)
          _buildCard(context, m),
      ],
    );
  }

  Widget _buildCard(BuildContext context, PauloFlixMovie movie) {
    return NetflixCard(
      imageUrl: movie.imageUrl ?? '',
      title: movie.displayName,
      rating: movie.score,
      width: 140,
      height: cardHeight,
      isTV: isTV,
      showTitle: true,
      showRating: movie.score != null,
      overlayWidget: movie.isCollection
          ? CollectionBadge(fontSize: movie.availableMovieCount > 9 ? 10 : 9)
          : const PauloFlixMoviesBadge(fontSize: 10),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PauloFlixMovieDetailScreen(content: movie),
          ),
        );
      },
    );
  }
}
