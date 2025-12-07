import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/jikan_models.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';

/// Card de anime otimizado com animações leves e responsivo
class ResponsiveAnimeCard extends StatefulWidget {
  final JikanAnime anime;
  final VoidCallback? onTap;
  final String heroTag;
  final bool showScore;
  final bool showTitle;

  const ResponsiveAnimeCard({
    super.key,
    required this.anime,
    required this.heroTag,
    this.onTap,
    this.showScore = true,
    this.showTitle = true,
  });

  @override
  State<ResponsiveAnimeCard> createState() => _ResponsiveAnimeCardState();
}

class _ResponsiveAnimeCardState extends State<ResponsiveAnimeCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeight(context);
    final spacing = Responsive.getCardSpacing(context);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: cardWidth,
          margin: EdgeInsets.only(right: spacing),
          transform: Matrix4.identity()
            ..setEntry(0, 0, _isPressed ? 0.95 : (_isHovered ? 1.05 : 1.0))
            ..setEntry(1, 1, _isPressed ? 0.95 : (_isHovered ? 1.05 : 1.0)),
          transformAlignment: Alignment.center,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card com imagem
              Hero(
                tag: widget.heroTag,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: cardHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _isHovered
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.3),
                        blurRadius: _isHovered ? 16 : 8,
                        offset: Offset(0, _isHovered ? 8 : 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Imagem
                        CachedNetworkImage(
                          imageUrl: widget.anime.largImageUrl ?? widget.anime.imageUrl,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          memCacheWidth: (cardWidth * 2).toInt(),
                          memCacheHeight: (cardHeight * 2).toInt(),
                          placeholder: (context, url) => Container(
                            color: AppColors.surface,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.surface,
                            child: const Icon(Icons.error, color: Colors.white54),
                          ),
                        ),

                        // Gradient overlay
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                                stops: const [0.6, 1.0],
                              ),
                            ),
                          ),
                        ),

                        // Score badge
                        if (widget.showScore && widget.anime.score != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    widget.anime.score!.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Hover overlay
                        if (_isHovered)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Título
              if (widget.showTitle) ...[
                const SizedBox(height: 8),
                Text(
                  widget.anime.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Responsive.value(context, phone: 12.0, tablet: 14.0),
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista horizontal de animes responsiva
class ResponsiveAnimeList extends StatelessWidget {
  final List<JikanAnime> animes;
  final String sectionId;
  final bool isLoading;
  final bool showScore;
  final void Function(JikanAnime anime)? onAnimeTap;

  const ResponsiveAnimeList({
    super.key,
    required this.animes,
    required this.sectionId,
    this.isLoading = false,
    this.showScore = true,
    this.onAnimeTap,
  });

  @override
  Widget build(BuildContext context) {
    final height = Responsive.getSectionHeight(context);
    final padding = Responsive.getHorizontalPadding(context);

    if (isLoading) {
      return SizedBox(
        height: height,
        child: _buildLoadingList(context),
      );
    }

    if (animes.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'Nenhum anime encontrado',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: padding),
        itemCount: animes.length,
        cacheExtent: 500,
        itemBuilder: (context, index) {
          final anime = animes[index];
          return ResponsiveAnimeCard(
            anime: anime,
            heroTag: '${sectionId}_${anime.malId}_$index',
            showScore: showScore,
            onTap: () => onAnimeTap?.call(anime),
          );
        },
      ),
    );
  }

  Widget _buildLoadingList(BuildContext context) {
    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeight(context);
    final spacing = Responsive.getCardSpacing(context);
    final padding = Responsive.getHorizontalPadding(context);

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: padding),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          width: cardWidth,
          margin: EdgeInsets.only(right: spacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: cardHeight,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: cardWidth * 0.7,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
