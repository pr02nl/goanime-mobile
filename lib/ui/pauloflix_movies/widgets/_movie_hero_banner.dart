import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/pauloflix_movie.dart';
import '../../core/widgets/netflix_hero_card.dart';
import '../models/movie_progress_state.dart';

/// Hero banner que destaca um filme/coleção no topo da home.
///
/// Wrapper sobre [NetflixHeroCard] que adiciona:
/// * Botão "Assistir" (Play) com focus d-pad
/// * Badge "Coleção (N filmes)" se for coleção
/// * Tap em qualquer área → vai para detail
class MovieHeroBanner extends StatelessWidget {
  final PauloFlixMovie movie;
  final bool isTV;
  final double height;

  /// Estado de progresso do filme (completo, em andamento ou nulo).
  /// Quando completo, exibe badge ✓ no banner.
  final MovieProgressState? progress;

  const MovieHeroBanner({
    super.key,
    required this.movie,
    required this.isTV,
    this.height = 420,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final hasBanner = movie.bannerUrl != null && movie.bannerUrl!.isNotEmpty;
    final imageUrl = hasBanner ? movie.bannerUrl! : (movie.imageUrl ?? '');

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          NetflixHeroCard(
            imageUrl: imageUrl,
            title: movie.displayName,
            description: movie.description,
            height: height,
            isTV: isTV,
            onPlay: () => _openDetail(context),
          ),
          if (progress != null && progress!.isCompleted)
            Positioned(
              top: 16,
              right: 16,
              child: _buildCompletedBadge(),
            ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context) {
    context.pushNamed(
      'pauloflix-movie-detail',
      extra: movie,
    );
  }

  /// Badge verde "✓ Completo" no canto superior direito do banner.
  Widget _buildCompletedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 16),
          SizedBox(width: 6),
          Text(
            'Completo',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
