import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../theme/netflix_theme.dart';
import '../utils/responsive.dart';

/// Netflix-inspired horizontal carousel with smooth scrolling
/// Supports responsive sizing and TV navigation
class NetflixCarousel extends StatefulWidget {
  final String title;
  final List<Widget> items;
  final double? height;
  final bool showTitle;
  final bool isTV;
  final Widget? trailing;

  const NetflixCarousel({
    super.key,
    required this.title,
    required this.items,
    this.height,
    this.showTitle = true,
    this.isTV = false,
    this.trailing,
  });

  @override
  State<NetflixCarousel> createState() => _NetflixCarouselState();
}

class _NetflixCarouselState extends State<NetflixCarousel> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeftGradient = false;
  bool _showRightGradient = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateGradientVisibility);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateGradientVisibility);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateGradientVisibility() {
    if (!mounted) return;
    setState(() {
      _showLeftGradient = _scrollController.offset > 0;
      _showRightGradient =
          _scrollController.offset <
          _scrollController.position.maxScrollExtent - 10;
    });
  }

  // _scrollLeft/_scrollRight removidos: Netflix nao usa botoes de navegacao.

  @override
  Widget build(BuildContext context) {
    final defaultHeight = widget.height ?? (widget.isTV ? 360.0 : 280.0);

    // Estrutura de foco:
    // • trailing fica num FocusTraversalGroup próprio isolado dos cards.
    // • cards ficam num FocusTraversalGroup com ReadingOrderTraversalPolicy.
    // O grupo pai da tela os visita em ordem de widget: trailing → cards.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Cabeçalho: título + trailing ─────────────────────────────────
        if (widget.showTitle)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: NetflixTheme.horizontalPadding(context),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: NetflixTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.trailing != null)
                  FocusTraversalGroup(child: widget.trailing!),
              ],
            ),
          ),
        SizedBox(height: widget.showTitle ? NetflixTheme.sm : 0),

        // ── Carousel de cards ─────────────────────────────────────────────
        FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: SizedBox(
            height: defaultHeight,
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                    horizontal: NetflixTheme.horizontalPadding(context),
                  ),
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right: NetflixTheme.cardSpacing(context),
                      ),
                      child: _AutoScrollOnFocus(
                        scrollController: _scrollController,
                        child: widget.items[index],
                      ),
                    );
                  },
                ),
                // Edge gradient fades
                if (_showLeftGradient)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 60,
                    child: IgnorePointer(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              NetflixTheme.background,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_showRightGradient)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 60,
                    child: IgnorePointer(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              NetflixTheme.background,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // Netflix não usa botões de navegação explícitos no carousel —
                // o fade lateral comunica que há mais conteúdo para rolar.
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SeeAllButton — chip estilizado para o header do carousel
// ─────────────────────────────────────────────────────────────────────────────

/// Botão "Ver Todos" para o header do [NetflixCarousel].
///
/// Visualmente é um chip com label + ícone de seta. No foco (teclado/D-pad)
/// exibe um contorno colorido e pequeno scale, facilitando a localização.
/// Aciona [onTap] com Enter / Space / Select / clique.
class SeeAllButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color accentColor;
  final bool isTV;

  const SeeAllButton({
    super.key,
    required this.label,
    required this.onTap,
    this.accentColor = const Color(0xFF00BCD4),
    this.isTV = false,
  });

  @override
  State<SeeAllButton> createState() => _SeeAllButtonState();
}

class _SeeAllButtonState extends State<SeeAllButton>
    with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: NetflixTheme.fastDuration,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _ctrl, curve: NetflixTheme.fastCurve));
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!mounted) return;
    setState(() => _isFocused = _focusNode.hasFocus);
    _isFocused ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor;
    final tvSize = widget.isTV;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Transform.scale(
              scale: _scale.value,
              child: AnimatedContainer(
                duration: NetflixTheme.fastDuration,
                curve: NetflixTheme.fastCurve,
                decoration: BoxDecoration(
                  // Fundo sutil: transparente quando não focado,
                  // levemente preenchido quando focado
                  color: _isFocused
                      ? color.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isFocused ? color : color.withValues(alpha: 0.5),
                    width: _isFocused ? 2 : 1,
                  ),
                  boxShadow: _isFocused
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    focusNode: _focusNode,
                    canRequestFocus: true,
                    onTap: widget.onTap,
                    onFocusChange: (hasFocus) {
                      if (!mounted) return;
                      setState(() => _isFocused = hasFocus);
                      hasFocus ? _ctrl.forward() : _ctrl.reverse();
                    },
                    borderRadius: BorderRadius.circular(20),
                    splashColor: color.withValues(alpha: 0.25),
                    highlightColor: color.withValues(alpha: 0.12),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: tvSize ? 16 : 12,
                        vertical: tvSize ? 8 : 5,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.label,
                            style: TextStyle(
                              color: _isFocused
                                  ? color
                                  : color.withValues(alpha: 0.85),
                              fontSize: tvSize ? 16 : 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(width: tvSize ? 5 : 3),
                          AnimatedRotation(
                            turns: _isFocused ? 0.0 : 0.0,
                            duration: NetflixTheme.fastDuration,
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: tvSize ? 14 : 11,
                              color: _isFocused
                                  ? color
                                  : color.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// SeeAllCard — card fantasma no final do carousel, acessível pelo D-pad
// ─────────────────────────────────────────────────────────────────────────────

/// Card "Ver Todos" que aparece como último item do carousel.
///
/// É o destino natural da navegação D-pad: o usuário chega nele simplesmente
/// continuando a pressionar →. Exibe um ícone de seta centralizado com
/// animação de foco igual aos outros cards.
class SeeAllCard extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final double width;
  final double height;
  final Color accentColor;
  final bool isTV;

  const SeeAllCard({
    super.key,
    required this.label,
    required this.onTap,
    required this.width,
    required this.height,
    this.accentColor = const Color(0xFF00BCD4),
    this.isTV = false,
  });

  @override
  State<SeeAllCard> createState() => _SeeAllCardState();
}

class _SeeAllCardState extends State<SeeAllCard>
    with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: NetflixTheme.mediumDuration,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: widget.isTV ? 1.08 : 1.04,
    ).animate(CurvedAnimation(parent: _ctrl, curve: NetflixTheme.defaultCurve));
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!mounted) return;
    setState(() => _isFocused = _focusNode.hasFocus);
    _isFocused ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  bool get _active => _isFocused || _isHovered;

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            setState(() => _isHovered = true);
            _ctrl.forward();
          },
          onExit: (_) {
            setState(() => _isHovered = false);
            if (!_isFocused) _ctrl.reverse();
          },
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              return Transform.scale(
                scale: _scale.value,
                child: SizedBox(
                  width: widget.width,
                  height: widget.height,
                  child: AnimatedContainer(
                    duration: NetflixTheme.fastDuration,
                    curve: NetflixTheme.fastCurve,
                    decoration: BoxDecoration(
                      color: _active
                          ? color.withValues(alpha: 0.12)
                          : NetflixTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(
                        NetflixTheme.radiusMd,
                      ),
                      border: Border.all(
                        color: _active ? color : color.withValues(alpha: 0.25),
                        width: _active ? 2 : 1,
                      ),
                      boxShadow: _active
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        NetflixTheme.radiusMd,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        focusNode: _focusNode,
                        canRequestFocus: true,
                        onTap: widget.onTap,
                        onFocusChange: (hasFocus) {
                          if (!mounted) return;
                          setState(() => _isFocused = hasFocus);
                          hasFocus ? _ctrl.forward() : _ctrl.reverse();
                        },
                        borderRadius: BorderRadius.circular(
                          NetflixTheme.radiusMd,
                        ),
                        splashColor: color.withValues(alpha: 0.25),
                        highlightColor: color.withValues(alpha: 0.12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Ícone com círculo
                            AnimatedContainer(
                              duration: NetflixTheme.fastDuration,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _active
                                    ? color.withValues(alpha: 0.2)
                                    : color.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: color.withValues(
                                    alpha: _active ? 0.9 : 0.4,
                                  ),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: color.withValues(
                                  alpha: _active ? 1.0 : 0.7,
                                ),
                                size: widget.isTV ? 32 : 26,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _active
                                    ? color
                                    : NetflixTheme.textSecondary,
                                fontSize: widget.isTV ? 15 : 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer placeholder
// ─────────────────────────────────────────────────────────────────────────────

/// Shimmer loading placeholder for carousel
class NetflixCarouselShimmer extends StatelessWidget {
  final String title;
  final int itemCount;
  final double? height;
  final bool showTitle;

  const NetflixCarouselShimmer({
    super.key,
    required this.title,
    this.itemCount = 6,
    this.height,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final defaultHeight = height ?? 280.0;
    final cardWidth = Responsive.getHorizontalListItemWidth(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTitle)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: NetflixTheme.horizontalPadding(context),
            ),
            child: Container(
              width: 150,
              height: 20,
              decoration: BoxDecoration(
                color: NetflixTheme.surfaceLight,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        SizedBox(height: showTitle ? NetflixTheme.sm : 0),
        SizedBox(
          height: defaultHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: NetflixTheme.horizontalPadding(context),
            ),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: NetflixTheme.cardSpacing(context),
                ),
                child: Container(
                  width: cardWidth,
                  height: defaultHeight,
                  decoration: BoxDecoration(
                    color: NetflixTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AutoScrollOnFocus
// ─────────────────────────────────────────────────────────────────────────────

/// Faz scroll automático quando um card filho recebe foco
class _AutoScrollOnFocus extends StatefulWidget {
  final Widget child;
  final ScrollController scrollController;

  const _AutoScrollOnFocus({
    required this.child,
    required this.scrollController,
  });

  @override
  State<_AutoScrollOnFocus> createState() => _AutoScrollOnFocusState();
}

class _AutoScrollOnFocusState extends State<_AutoScrollOnFocus> {
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      child: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus) _scrollToVisible();
        },
        skipTraversal: true,
        child: widget.child,
      ),
    );
  }

  void _scrollToVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderObject = context.findRenderObject();
      if (renderObject == null) return;
      final viewport = RenderAbstractViewport.of(renderObject);
      final scrollPosition = widget.scrollController.position;
      final revealOffset = viewport.getOffsetToReveal(renderObject, 0.0);
      final targetOffset = revealOffset.offset.clamp(
        scrollPosition.minScrollExtent,
        scrollPosition.maxScrollExtent,
      );
      if ((scrollPosition.pixels - targetOffset).abs() > 10) {
        widget.scrollController.animateTo(
          targetOffset,
          duration: NetflixTheme.mediumDuration,
          curve: NetflixTheme.defaultCurve,
        );
      }
    });
  }
}
