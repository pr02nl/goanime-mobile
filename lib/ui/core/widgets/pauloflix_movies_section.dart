import 'package:flutter/material.dart';

import '../../../domain/models/pauloflix_movie.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/responsive.dart';
import 'netflix_card.dart';
import 'netflix_carousel.dart';
import 'pauloflix_movies_badge.dart';

// Cor identidade PauloFlix filmes (vermelho)
const _kMoviesColor = Color(0xFFDC2626);

class PauloFlixMoviesSection extends StatelessWidget {
  final String title;
  final List<PauloFlixMovie> contents;
  final VoidCallback? onSeeAll;
  final Function(PauloFlixMovie)? onItemTap;
  final bool isTV;

  const PauloFlixMoviesSection({
    super.key,
    required this.title,
    required this.contents,
    this.onSeeAll,
    this.onItemTap,
    this.isTV = false,
  });

  @override
  Widget build(BuildContext context) {
    if (contents.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeightSync(context);

    final items = [
      ...contents.map(
        (content) => NetflixCard(
          imageUrl: content.imageUrl ?? '',
          title: content.displayName,
          rating: content.score,
          width: cardWidth,
          height: cardHeight,
          isTV: isTV,
          onTap: () => onItemTap?.call(content),
          overlayWidget: content.isCollection
              ? const CollectionBadge()
              : const PauloFlixMoviesBadge(),
        ),
      ),
      if (onSeeAll != null)
        SeeAllCard(
          label: l10n.seeAll,
          onTap: onSeeAll!,
          width: cardWidth,
          height: cardHeight,
          accentColor: _kMoviesColor,
          isTV: isTV,
        ),
    ];

    return NetflixCarousel(
      title: title,
      height: cardHeight + 60,
      isTV: isTV,
      trailing: onSeeAll != null
          ? SeeAllButton(
              label: l10n.seeAll,
              onTap: onSeeAll!,
              accentColor: _kMoviesColor,
              isTV: isTV,
            )
          : null,
      items: items,
    );
  }
}
