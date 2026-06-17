import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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

  void _scrollLeft() {
    _scrollController.animateTo(
      _scrollController.offset - MediaQuery.of(context).size.width * 0.7,
      duration: NetflixTheme.mediumDuration,
      curve: NetflixTheme.defaultCurve,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      _scrollController.offset + MediaQuery.of(context).size.width * 0.7,
      duration: NetflixTheme.mediumDuration,
      curve: NetflixTheme.defaultCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultHeight = widget.height ?? (widget.isTV ? 360.0 : 280.0);

    // Estrutura de foco:
    // • O trailing ("Ver Todos") fica num FocusTraversalGroup próprio com
    //   policy padrão (WidgetOrderTraversalPolicy), isolado dos cards.
    //   Isso garante que Tab o alcance independentemente de qualquer
    //   ListView scrollável abaixo.
    // • Os cards do carousel ficam num FocusTraversalGroup separado com
    //   ReadingOrderTraversalPolicy, mantendo navegação esquerda→direita.
    // Ambos os grupos são filhos diretos da Column, então o grupo pai
    // (da tela) os visita em ordem de widget: trailing primeiro, cards depois.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Cabeçalho: título + trailing ──────────────────────────────────
        if (widget.showTitle)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: NetflixTheme.horizontalPadding(context),
            ),
            child: Row(
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
                // Trailing isolado: FocusTraversalGroup próprio evita que
                // o ListView horizontal do carousel interfira no traversal.
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
                        decoration: BoxDecoration(
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
                        decoration: BoxDecoration(
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
                // Navigation buttons (desktop only)
                if (!widget.isTV &&
                    MediaQuery.of(context).size.width > 600) ...[
                  if (_showLeftGradient)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: NetflixTheme.background.withValues(
                              alpha: 0.8,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.chevron_left),
                            color: NetflixTheme.textPrimary,
                            onPressed: _scrollLeft,
                          ),
                        ),
                      ),
                    ),
                  if (_showRightGradient)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: NetflixTheme.background.withValues(
                              alpha: 0.8,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.chevron_right),
                            color: NetflixTheme.textPrimary,
                            onPressed: _scrollRight,
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

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
