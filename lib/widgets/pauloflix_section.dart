import 'package:flutter/material.dart';

import '../models/pauloflix_content.dart';
import '../utils/responsive.dart';
import 'focusable_widget.dart';
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
          ? FocusableWidget(
              // Wrap crucial para teclado/d-pad: o TextButton original era
              // invisível a Tab/Setas no desktop (foco obstruído pelo
              // FocusTraversalGroup do NetflixCarousel) e ao d-pad na TV.
              // FocusableWidget provê Focus + Select/Enter/Space → onSelect.
              // Parâmetros: botão tipo text-link, padding Material próprio
              // já existe, então focusPadding=zero. Cor foco do widget é
              // neutro (wrapper cuida); cor "Ver Todos" é violet (0xFF6366F1)
              // para combinar com a identidade do PauloFlix.
              focusColor: const Color(0xFF6366F1),
              onSelect: onSeeAll,
              borderRadius: 12,
              focusPadding: EdgeInsets.zero,
              focusScale: 1.05,
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
