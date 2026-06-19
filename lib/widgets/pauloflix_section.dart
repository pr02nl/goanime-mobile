import 'package:flutter/material.dart';

import '../domain/models/pauloflix_content.dart';
import '../l10n/app_localizations.dart';
import '../utils/responsive.dart';
import 'netflix_card.dart';
import 'netflix_carousel.dart';
import 'pauloflix_badge.dart';

// Cor identidade PauloFlix animes (índigo)
const _kPauloFlixColor = Color(0xFF6366F1);

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

    final l10n = AppLocalizations.of(context);
    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeightSync(context);

    // Cards de conteúdo + SeeAllCard como último item (acessível pelo D-pad)
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
          overlayWidget: const PauloFlixBadge(),
        ),
      ),
      if (onSeeAll != null)
        SeeAllCard(
          label: l10n.seeAll,
          onTap: onSeeAll!,
          width: cardWidth,
          height: cardHeight,
          accentColor: _kPauloFlixColor,
          isTV: isTV,
        ),
    ];

    return NetflixCarousel(
      title: title,
      height: cardHeight + 60,
      isTV: isTV,
      // SeeAllButton no header: acessível por Tab / D-pad ↑ antes dos cards
      trailing: onSeeAll != null
          ? SeeAllButton(
              label: l10n.seeAll,
              onTap: onSeeAll!,
              accentColor: _kPauloFlixColor,
              isTV: isTV,
            )
          : null,
      items: items,
    );
  }
}
