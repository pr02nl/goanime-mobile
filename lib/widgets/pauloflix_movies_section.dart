import 'package:flutter/material.dart';

import '../models/pauloflix_movie.dart';
import '../utils/responsive.dart';
import 'netflix_card.dart';
import 'netflix_carousel.dart';
import 'pauloflix_movies_badge.dart';

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

    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeightSync(context);

    return NetflixCarousel(
      title: title,
      height: cardHeight + 60,
      isTV: isTV,
      trailing: onSeeAll != null
          ? TextButton(
              onPressed: onSeeAll,
              child: const Text(
                'Ver Todos',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      items: contents.map((content) {
        return NetflixCard(
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
        );
      }).toList(),
    );
  }
}
