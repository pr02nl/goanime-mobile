import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../themes/app_colors.dart';
import '../themes/netflix_theme.dart';

/// Netflix-inspired card with hover effects and smooth animations
/// Supports responsive sizing and TV navigation
class NetflixCard extends StatefulWidget {
  final String imageUrl;
  final String? title;
  final double? rating;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final bool showTitle;
  final bool showRating;
  final bool isTV;
  final Widget? overlayWidget;
  final bool autofocus;

  const NetflixCard({
    super.key,
    required this.imageUrl,
    this.title,
    this.rating,
    this.onTap,
    this.width = 120,
    this.height = 180,
    this.showTitle = true,
    this.showRating = true,
    this.isTV = false,
    this.overlayWidget,
    this.autofocus = false,
  });

  @override
  State<NetflixCard> createState() => _NetflixCardState();
}

class _NetflixCardState extends State<NetflixCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  void _handleHover(bool isHovered) {
    if (!widget.isTV) {
      setState(() {
        _isHovered = isHovered;
      });
    }
  }

  void _handleFocus(bool isFocused) {
    setState(() {
      _isFocused = isFocused;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      cursor: SystemMouseCursors.click,
      child: Focus(
        autofocus: widget.autofocus,
        onFocusChange: _handleFocus,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space) {
              widget.onTap?.call();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: widget.width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NetflixTheme.radiusMd),
              boxShadow: (_isHovered || _isFocused)
                  ? NetflixTheme.elevatedCardShadow
                  : NetflixTheme.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(NetflixTheme.radiusMd),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image
                  CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    width: widget.width,
                    height: widget.height,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    memCacheWidth: widget.width.isFinite
                        ? (widget.width * 2).toInt()
                        : null,
                    memCacheHeight: widget.height.isFinite
                        ? (widget.height * 2).toInt()
                        : null,
                    maxWidthDiskCache: widget.width.isFinite
                        ? (widget.width * 2).toInt()
                        : null,
                    maxHeightDiskCache: widget.height.isFinite
                        ? (widget.height * 2).toInt()
                        : null,
                    fadeInDuration: NetflixTheme.mediumDuration,
                    placeholder: (context, url) => Container(
                      width: widget.width,
                      height: widget.height,
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
                      width: widget.width,
                      height: widget.height,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.movie_outlined,
                          color: Colors.white24,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  // Gradient overlay permanente e suave — Netflix usa
                  // degradê curto só na base para legibilidade do título.
                  if (widget.showTitle || widget.showRating)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            stops: const [0.0, 0.6, 0.85, 1.0],
                          ),
                        ),
                      ),
                    ),
                  // Rating badge — sem borda, só backdrop escuro
                  if (widget.showRating && widget.rating != null)
                    Positioned(
                      top: NetflixTheme.sm,
                      right: NetflixTheme.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(
                            NetflixTheme.radiusSm,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 11,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              widget.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: NetflixTheme.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Título sempre visível — Netflix não esconde o título
                  // ao hover. Degradê permanente garante a legibilidade.
                  if (widget.showTitle && widget.title != null)
                    Positioned(
                      left: NetflixTheme.sm,
                      right: NetflixTheme.sm,
                      bottom: NetflixTheme.sm,
                      child: Text(
                        widget.title!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: NetflixTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(0, 1),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Custom overlay widget — posicionado no canto
                  // inferior-esquerdo, acima do título (badge pequeno).
                  if (widget.overlayWidget != null)
                    Positioned(
                      left: NetflixTheme.sm,
                      bottom: widget.showTitle ? 36 : NetflixTheme.sm,
                      child: widget.overlayWidget!,
                    ),
                  // Hover / Focus glow — glow colorido ao redor do card
                  if (_isHovered || _isFocused)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            NetflixTheme.radiusMd,
                          ),
                        ),
                      ),
                    ),
                  // Focus border for TV
                  if (widget.isTV && _isFocused)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.primary,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(
                            NetflixTheme.radiusMd,
                          ),
                        ),
                      ),
                    ),
                  // Hover overlay — leve escurecimento para destacar
                  if (_isHovered && !_isFocused)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            NetflixTheme.radiusMd,
                          ),
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
