import 'package:flutter/material.dart';

import '../models/pauloflix_content.dart';
import '../utils/responsive.dart';
import 'netflix_card.dart';
import 'netflix_carousel.dart';
import 'pauloflix_badge.dart';

class PauloFlixSection extends StatelessWidget {
  final String title;
  final List<PauloFlixContent> contents;
  final VoidCallback? onSeeAll;
  final Function(PauloFlixContent)? onItemTap;
  final bool isTV;

  const PauloFlixSection({
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
                  color: Color(0xFF6366F1),
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
          overlayWidget: const PauloFlixBadge(),
        );
      }).toList(),
    );
  }
}
