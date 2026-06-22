import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../themes/app_colors.dart';
import '../themes/netflix_theme.dart';

/// Hero card variant for featured content.
///
/// **Sem `autofocus: true`** em descendentes — anti-pattern #19 do skill
/// `flutter-reactivity-gotchas` (assertion no FocusScope persistente do
/// shell `MainNavigationScreen`). O shell gerencia o foco inicial via
/// `_lastContentFocusNode` + `_restoreContentFocus`; autofocus declarativo
/// aqui causa race condition com ModalRoute por cima.
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
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
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
                decoration: const BoxDecoration(
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
                          // Sem `autofocus: isTV` aqui — o shell gerencia
                          // o foco inicial. Foco no Play via d-pad é
                          // responsabilidade do `_restoreContentFocus`.
                          _HeroActionButton(
                            onPressed: onPlay!,
                            icon: Icons.play_arrow,
                            label: 'Play',
                            filled: true,
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

  const _HeroActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.filled,
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
              side: const BorderSide(color: NetflixTheme.textSecondary),
              padding: const EdgeInsets.symmetric(
                horizontal: NetflixTheme.lg,
                vertical: NetflixTheme.md,
              ),
            ),
          );

    return Focus(
      // Sem `autofocus: true` — ver doc do `NetflixHeroCard`.
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
