import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/netflix_theme.dart';

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
  });

  @override
  State<NetflixCard> createState() => _NetflixCardState();
}

class _NetflixCardState extends State<NetflixCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isFocused = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: NetflixTheme.mediumDuration,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.isTV ? 1.08 : 1.05)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: NetflixTheme.defaultCurve,
          ),
        );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleHover(bool isHovered) {
    if (!widget.isTV) {
      setState(() {
        _isHovered = isHovered;
      });
      if (isHovered) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  void _handleFocus(bool isFocused) {
    setState(() {
      _isFocused = isFocused;
    });
    if (isFocused) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      cursor: SystemMouseCursors.click,
      child: Focus(
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
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
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
                            color: NetflixTheme.surfaceLight,
                            child: const Icon(
                              Icons.error_outline,
                              color: NetflixTheme.textTertiary,
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
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Hero card variant for featured content.
/// On TV / d-pad the Play button auto-focuses so the user can immediately
/// press Select to start watching.
class NetflixHeroCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String? description;
  final VoidCallback? onPlay;
  final VoidCallback? onMyList;
  final double height;
  final bool isTV;

  const NetflixHeroCard({
    super.key,
    required this.imageUrl,
    required this.title,
    this.description,
    this.onPlay,
    this.onMyList,
    this.height = 400,
    this.isTV = false,
  });

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: Container(
      height: height,
      decoration: const BoxDecoration(color: NetflixTheme.background),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: height,
            filterQuality: FilterQuality.high,
            placeholder: (context, url) => Container(
              color: NetflixTheme.surface,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: NetflixTheme.surface,
              child: const Icon(
                Icons.error_outline,
                color: NetflixTheme.textTertiary,
              ),
            ),
          ),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  NetflixTheme.background.withValues(alpha: 0.3),
                  NetflixTheme.background.withValues(alpha: 0.6),
                  NetflixTheme.background,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
          // Content
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: NetflixTheme.horizontalPadding(context),
                vertical: NetflixTheme.lg,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, NetflixTheme.background],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: NetflixTheme.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: NetflixTheme.md),
                    Text(
                      description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NetflixTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: NetflixTheme.lg),
                  Row(
                    children: [
                      if (onPlay != null)
                        _HeroActionButton(
                          onPressed: onPlay!,
                          icon: Icons.play_arrow,
                          label: 'Play',
                          filled: true,
                          autofocus: isTV,
                        ),
                      if (onMyList != null) ...[
                        const SizedBox(width: NetflixTheme.md),
                        _HeroActionButton(
                          onPressed: onMyList!,
                          icon: Icons.add,
                          label: 'My List',
                          filled: false,
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
    );
  }
}

/// A hero-area action button that is keyboard/d-pad focusable and shows a
/// visible focus ring so TV users can see which button is highlighted.
class _HeroActionButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool filled;
  final bool autofocus;

  const _HeroActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.filled,
    this.autofocus = false,
  });

  @override
  State<_HeroActionButton> createState() => _HeroActionButtonState();
}

class _HeroActionButtonState extends State<_HeroActionButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final button = widget.filled
        ? ElevatedButton.icon(
            onPressed: widget.onPressed,
            icon: Icon(widget.icon),
            label: Text(widget.label),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: NetflixTheme.lg,
                vertical: NetflixTheme.md,
              ),
            ),
          )
        : OutlinedButton.icon(
            onPressed: widget.onPressed,
            icon: Icon(widget.icon),
            label: Text(widget.label),
            style: OutlinedButton.styleFrom(
              foregroundColor: NetflixTheme.textPrimary,
              side: const BorderSide(
                color: NetflixTheme.textSecondary,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: NetflixTheme.lg,
                vertical: NetflixTheme.md,
              ),
            ),
          );

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: NetflixTheme.fastDuration,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(NetflixTheme.radiusMd),
          border: _isFocused
              ? Border.all(color: AppColors.primary, width: 3)
              : null,
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: button,
      ),
    );
  }
}
