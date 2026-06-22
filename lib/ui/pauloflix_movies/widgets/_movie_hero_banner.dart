import 'package:flutter/material.dart';

import '../../../domain/models/pauloflix_movie.dart';
import '../../core/widgets/netflix_hero_card.dart';
import 'pauloflix_movie_detail_screen.dart';

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

  const MovieHeroBanner({
    super.key,
    required this.movie,
    required this.isTV,
    this.height = 420,
  });

  @override
  Widget build(BuildContext context) {
    final hasBanner = movie.bannerUrl != null && movie.bannerUrl!.isNotEmpty;
    final imageUrl = hasBanner ? movie.bannerUrl! : (movie.imageUrl ?? '');

    return SizedBox(
      height: height,
      child: NetflixHeroCard(
        imageUrl: imageUrl,
        title: movie.displayName,
        description: movie.description,
        height: height,
        isTV: isTV,
        onPlay: () => _openDetail(context),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PauloFlixMovieDetailScreen(content: movie),
      ),
    );
  }
}
