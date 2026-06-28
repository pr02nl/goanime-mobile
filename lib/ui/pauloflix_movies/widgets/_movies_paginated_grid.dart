import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/pauloflix_movie.dart';
import '../../core/themes/app_colors.dart';
import '../../core/utils/pagination.dart';
import '../../core/widgets/netflix_card.dart';
import '../../core/widgets/paginated_letter_grid.dart';
import '../models/movie_progress_state.dart';

/// Wrapper sobre [PaginatedLetterGrid] específico para [PauloFlixMovie].
/// Fixa a cor de destaque (vermelho PauloFlix Movies) e o builder
/// do card (com badge Coleção/Filme).
///
/// Usado pela `PauloFlixMoviesHomeScreen` no grid "Todos os Filmes".
class MoviesPaginatedGrid extends StatelessWidget {
  final PaginationResult<PauloFlixMovie> pagination;
  final bool isTV;

  /// Mapa folderName → estado de progresso. Usado para exibir overlay
  /// de completado ou barra de progresso nos cards.
  final Map<String, MovieProgressState>? progressMap;

  const MoviesPaginatedGrid({
    super.key,
    required this.pagination,
    required this.isTV,
    this.progressMap,
  });

  @override
  Widget build(BuildContext context) {
    return PaginatedLetterGrid<PauloFlixMovie>(
      pagination: pagination,
      isTV: isTV,
      accentColor: AppColors.moviesAccent,
      nameOf: (m) => m.displayName,
      cardBuilder: (context, movie) {
        final progress = progressMap?[movie.folderName];
        final overlay = MovieProgressState.buildOverlayWidget(progress);
        return NetflixCard(
          imageUrl: movie.imageUrl ?? '',
          title: movie.displayName,
          rating: movie.score,
          width: double.infinity,
          height: double.infinity,
          isTV: isTV,
          showTitle: true,
          showRating: movie.score != null,
          overlayWidget: overlay,
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
