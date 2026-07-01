import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/pauloflix_content.dart';
import '../../core/themes/app_colors.dart';
import '../../core/widgets/base_pauloflix_search_screen.dart';
import '../../core/widgets/netflix_card.dart';
import '../view_models/pauloflix_provider.dart';

/// Tela de busca de animes PauloFlix.
///
/// Delega toda a lógica para [BasePauloFlixSearchScreen].
class PauloFlixSearchScreen extends StatelessWidget {
  const PauloFlixSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BasePauloFlixSearchScreen<PauloFlixContent>(
      hintText: 'Buscar anime...',
      idleText: 'Digite para buscar animes',
      accentColor: AppColors.animeAccent,
      debugLabel: 'pauloflix',
      searchFunction: (query, ctx) =>
          ctx.read<PauloFlixProvider>().searchByName(query),
      cardBuilder: (ctx, content, isTV) => NetflixCard(
        imageUrl: content.imageUrl ?? '',
        title: content.displayName,
        rating: content.score,
        width: double.infinity,
        height: double.infinity,
        isTV: isTV,
        showTitle: true,
        showRating: content.score != null,
        onTap: () => ctx.pushNamed('pauloflix-episodes', extra: content),
      ),
    );
  }
}
