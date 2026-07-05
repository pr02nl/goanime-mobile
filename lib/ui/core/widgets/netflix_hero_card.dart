import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../themes/app_colors.dart';
import '../themes/netflix_theme.dart';

/// Hero card variant for featured content.
///
/// **Sem `autofocus: true`** em descendentes — anti-pattern #19 do skill
/// `flutter-reactivity-gotchas` (assertion no FocusScope persistente do
/// shell `MainNavigationScreen`). O shell gerencia o foco inicial via
/// `_lastContentFocusNode` + `_restoreContentFocus`; autofocus declarativo
/// aqui causa race condition com ModalRoute por cima.
///
/// **Props opcionais:**
/// * [badge] — overlay no canto superior esquerdo (ex: `PauloFlixBadge`).
///   Renderizado apenas se fornecido.
/// * [score] — quando não-nulo, exibe estrela + valor formatado
///   `9.0` ao lado do título. Usado para exibir score do anime.
///   Quando `null`, não renderiza nada (movies não têm score).
/// * [showTitle] — quando `false`, esconde o `Text` do título. Usado
///   em screens onde o título já está na `AppBar` (ex: lista de
///   episódios — ver `PauloFlixEpisodeListScreen._HeroBanner`).
///   Default `true` (consistência com hero do see-all).
class NetflixHeroCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String? description;
  final VoidCallback? onPlay;
  final VoidCallback? onMyList;
  final Widget? badge;
  final double? score;
  final bool showTitle;
  final bool hasSeasons;
  final int seasonCount;
  final List<String> genres;
  final double height;
  final bool isTV;

  const NetflixHeroCard({
    super.key,
    required this.imageUrl,
    required this.title,
    this.description,
    this.onPlay,
    this.onMyList,
    this.badge,
    this.score,
    this.showTitle = true,
    this.hasSeasons = false,
    this.seasonCount = 0,
    this.height = 400,
    this.isTV = false,
    this.genres = const [],
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
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
          // Badge (canto superior esquerdo) — opcional
          if (badge != null)
            Positioned(
              left: NetflixTheme.horizontalPadding(context),
              top: NetflixTheme.lg,
              child: badge!,
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
                  if (showTitle)
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
                  Row(
                    spacing: NetflixTheme.sm,
                    children: [
                      if (score != null) ...[
                        // const SizedBox(height: NetflixTheme.sm),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFFFBBF24),
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              score!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (hasSeasons) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$seasonCount ${seasonCount == 1 ? 'temporada' : 'temporadas'}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      if (genres.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: genres
                              .take(5)
                              .map(
                                (genre) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    genre,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
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
                          label: l10n.playNow,
                          filled: true,
                        ),
                      if (onMyList != null) ...[
                        const SizedBox(width: NetflixTheme.md),
                        _HeroActionButton(
                          onPressed: onMyList!,
                          icon: Icons.add,
                          label: l10n.myList,
                          filled: false,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (Navigator.of(context).canPop())
            Positioned(
              top: 32,
              left: 32,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                color: Colors.white,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
        ],
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
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    final focused = _focusNode.hasFocus;
    setState(() => _isFocused = focused);
    if (focused) {
      // Revela o herocard completo ao receber foco via D-pad "cima".
      // Usa addPostFrameCallback para evitar conflito com o
      // ensureVisible automático do sistema de foco do Flutter.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.maybeOf(context)?.position.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final button = widget.filled
        ? ElevatedButton.icon(
            onPressed: widget.onPressed,
            icon: Icon(widget.icon),
            label: Text(widget.label),
            focusNode: _focusNode,
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
            focusNode: _focusNode,
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
      // Apenas para capturar o botão SELECT do TV remote;
      // o foco real é detectado via _focusNode passado ao botão.
      canRequestFocus: false,
      includeSemantics: false,
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
