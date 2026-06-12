import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/jikan_models.dart';
import '../theme/app_colors.dart';
import '../theme/netflix_theme.dart';
import 'focusable_widget.dart';

class AnimeCard extends StatefulWidget {
  final JikanAnime anime;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final bool showTitle;
  final bool showScore;
  final bool useNetflixStyle; // Flag para ativar estilo Netflix

  const AnimeCard({
    super.key,
    required this.anime,
    this.onTap,
    this.width = 120,
    this.height = 180,
    this.showTitle = true,
    this.showScore = true,
    this.useNetflixStyle = true, // Ativado por padrão (estilo Netflix)
  });

  @override
  State<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends State<AnimeCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController? _animationController;
  late Animation<double>? _scaleAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.useNetflixStyle) {
      _animationController = AnimationController(
        vsync: this,
        duration: NetflixTheme.mediumDuration,
      );
      _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(
          parent: _animationController!,
          curve: NetflixTheme.defaultCurve,
        ),
      );
    }
  }

  @override
  void dispose() {
    if (widget.useNetflixStyle && _animationController != null) {
      _animationController!.dispose();
    }
    super.dispose();
  }

  void _handleHover(bool isHovered) {
    if (widget.useNetflixStyle) {
      setState(() {
        _isHovered = isHovered;
      });
      if (isHovered) {
        _animationController?.forward();
      } else {
        _animationController?.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = FocusableWidget(
      onSelect: widget.onTap,
      borderRadius: 8,
      focusPadding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: widget.width,
          margin: const EdgeInsets.only(right: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagem do anime
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl:
                          widget.anime.largImageUrl ?? widget.anime.imageUrl,
                      width: widget.width,
                      height: widget.height,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      memCacheWidth: (widget.width * 2).toInt(),
                      memCacheHeight: (widget.height * 2).toInt(),
                      maxWidthDiskCache: (widget.width * 2).toInt(),
                      maxHeightDiskCache: (widget.height * 2).toInt(),
                      placeholder: (context, url) => Container(
                        width: widget.width,
                        height: widget.height,
                        color: widget.useNetflixStyle
                            ? NetflixTheme.surfaceLight
                            : NetflixTheme.surface,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.useNetflixStyle
                                  ? AppColors.primary
                                  : AppColors.primary,
                            ),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: widget.width,
                        height: widget.height,
                        color: widget.useNetflixStyle
                            ? NetflixTheme.surfaceLight
                            : NetflixTheme.surface,
                        child: Icon(
                          Icons.error,
                          color: widget.useNetflixStyle
                              ? NetflixTheme.textTertiary
                              : NetflixTheme.textTertiary,
                        ),
                      ),
                    ),
                    // NOVO: Gradient overlay estilo Netflix
                    if (widget.useNetflixStyle &&
                        (widget.showTitle || widget.showScore))
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.netflixGradientOverlay,
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
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                            border: widget.useNetflixStyle
                                ? Border.all(
                                    color: NetflixTheme.textSecondary
                                        .withValues(alpha: 0.3),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                color: AppColors.warning,
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
                  ],
                ),
              ),
              // Título do anime
              if (widget.showTitle) ...[
                const SizedBox(height: 8),
                Text(
                  widget.anime.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // NOVO: Envolver com MouseRegion e AnimatedScale se estilo Netflix ativado
    if (widget.useNetflixStyle) {
      return MouseRegion(
        onEnter: (_) => _handleHover(true),
        onExit: (_) => _handleHover(false),
        cursor: SystemMouseCursors.click,
        child: AnimatedBuilder(
          animation: _scaleAnimation!,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation!.value,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _isHovered
                      ? NetflixTheme.elevatedCardShadow
                      : NetflixTheme.cardShadow,
                ),
                child: child,
              ),
            );
          },
          child: card,
        ),
      );
    }

    return card;
  }
}

class AnimeCardLarge extends StatelessWidget {
  final JikanAnime anime;
  final VoidCallback? onTap;

  const AnimeCardLarge({super.key, required this.anime, this.onTap});

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onSelect: onTap,
      borderRadius: 12,
      focusPadding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: NetflixTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Imagem
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: anime.largImageUrl ?? anime.imageUrl,
                  width: 100,
                  height: 140,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  memCacheWidth: 200,
                  memCacheHeight: 280,
                  maxWidthDiskCache: 200,
                  maxHeightDiskCache: 280,
                  placeholder: (context, url) => Container(
                    width: 100,
                    height: 140,
                    color: NetflixTheme.surfaceLight,
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 100,
                    height: 140,
                    color: NetflixTheme.surfaceLight,
                    child: const Icon(
                      Icons.error,
                      color: NetflixTheme.textTertiary,
                    ),
                  ),
                ),
              ),
              // Informações
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anime.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (anime.synopsis != null)
                        Text(
                          anime.synopsis!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: NetflixTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (anime.score != null) ...[
                            const Icon(
                              Icons.star,
                              color: AppColors.warning,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              anime.score!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (anime.episodes != null) ...[
                            Icon(
                              Icons.tv,
                              color: NetflixTheme.textSecondary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${anime.episodes} eps',
                              style: TextStyle(
                                color: NetflixTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
