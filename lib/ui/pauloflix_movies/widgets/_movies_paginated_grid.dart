import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/pauloflix_movie.dart';
import '../../core/utils/pagination.dart';
import '../../core/widgets/netflix_card.dart';
import '../../core/widgets/paginated_letter_grid.dart';
import '../../core/widgets/pauloflix_movies_badge.dart';

/// Wrapper sobre [PaginatedLetterGrid] específico para [PauloFlixMovie].
/// Fixa a cor de destaque (vermelho PauloFlix Movies) e o builder
/// do card (com badge Coleção/Filme).
///
/// Usado pela `PauloFlixMoviesHomeScreen` no grid "Todos os Filmes".
class MoviesPaginatedGrid extends StatelessWidget {
  final PaginationResult<PauloFlixMovie> pagination;
  final bool isTV;

  const MoviesPaginatedGrid({
    super.key,
    required this.pagination,
    required this.isTV,
  });

  @override
  Widget build(BuildContext context) {
    return PaginatedLetterGrid<PauloFlixMovie>(
      pagination: pagination,
      isTV: isTV,
      accentColor: const Color(0xFFDC2626),
      nameOf: (m) => m.displayName,
      cardBuilder: (context, movie) {
        return NetflixCard(
          imageUrl: movie.imageUrl ?? '',
          title: movie.displayName,
          rating: movie.score,
          width: double.infinity,
          height: double.infinity,
          isTV: isTV,
          showTitle: true,
          showRating: movie.score != null,
          overlayWidget: const PauloFlixMoviesBadge(),
          onTap: () {
            context.pushNamed(
              'pauloflix-movie-detail',
              extra: movie,
            );
          },
        );
      },
    );
  }
}
