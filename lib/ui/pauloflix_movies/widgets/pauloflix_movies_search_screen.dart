import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/pauloflix_movie.dart';
import '../../core/themes/app_colors.dart';
import '../../core/widgets/base_pauloflix_search_screen.dart';
import '../../core/widgets/netflix_card.dart';
import '../view_models/pauloflix_movies_provider.dart';

/// Tela de busca de filmes PauloFlix.
///
/// Delega toda a lógica para [BasePauloFlixSearchScreen].
class PauloFlixMoviesSearchScreen extends StatelessWidget {
  const PauloFlixMoviesSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BasePauloFlixSearchScreen<PauloFlixMovie>(
      hintText: 'Buscar filme...',
      idleText: 'Digite para buscar filmes',
      accentColor: AppColors.moviesAccent,
      debugLabel: 'pauloflix-movie',
      searchFunction: (query, ctx) =>
          ctx.read<PauloFlixMoviesProvider>().searchByName(query),
      cardBuilder: (ctx, content, isTV) => NetflixCard(
        imageUrl: content.imageUrl ?? '',
        title: content.displayName,
        rating: content.score,
        width: double.infinity,
        height: double.infinity,
        isTV: isTV,
        showTitle: true,
        showRating: content.score != null,
        onTap: () => ctx.pushNamed('pauloflix-movie-detail', extra: content),
      ),
    );
  }
}
