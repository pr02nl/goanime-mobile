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

  const AnimeCard({
    super.key,
    required this.anime,
    this.onTap,
    this.width = 120,
    this.height = 180,
    this.showTitle = true,
    this.showScore = true,
  });

  @override
  State<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends State<AnimeCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  AnimationController? _animationController;
  Animation<double>? _scaleAnimation;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  void _handleHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    if (isHovered) {
      _animationController?.forward();
    } else {
      _animationController?.reverse();
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
                        color: NetflixTheme.surfaceLight,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: widget.width,
                        height: widget.height,
                        color: NetflixTheme.surfaceLight,
                        child: const Icon(
                          Icons.error,
                          color: NetflixTheme.textTertiary,
                        ),
                      ),
                    ),
                    if (widget.showTitle || widget.showScore)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.netflixGradientOverlay,
                          ),
                        ),
                      ),
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
                            border: Border.all(
                              color: NetflixTheme.textSecondary
                                  .withValues(alpha: 0.3),
                              width: 1,
                            ),
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
}
