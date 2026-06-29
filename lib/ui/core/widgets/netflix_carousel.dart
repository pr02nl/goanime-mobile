import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../themes/netflix_theme.dart';
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
    this.height = 250,
    this.showTitle = true,
    this.isTV = false,
    this.trailing,
  });

  @override
  State<NetflixCarousel> createState() => _NetflixCarouselState();
}

class _NetflixCarouselState extends State<NetflixCarousel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // _scrollLeft/_scrollRight removidos: Netflix nao usa botoes de navegacao.

  @override
  Widget build(BuildContext context) {
    final defaultHeight = widget.height ?? (widget.isTV ? 360.0 : 280.0);

    // Estrutura de foco:
    // • trailing fica num FocusTraversalGroup próprio isolado dos cards.
    // • cards ficam num FocusTraversalGroup com _ClampedTraversalPolicy
    //   (WidgetOrderTraversalPolicy modificado que prende o foco apenas na
    //    borda direita — na esquerda o ← navega para o grupo anterior).
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
          policy: _ClampedTraversalPolicy(),
          child: SizedBox(
            height: defaultHeight,
            child: ListView.builder(
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
          ),
        ),
      ],
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
// _ClampedTraversalPolicy
// ─────────────────────────────────────────────────────────────────────────────

/// Política de travessia que prende (clamp) o foco na borda **direita**
/// do carrossel — ao chegar no último card, a seta → mantém o foco ali.
///
/// Na borda **esquerda** a navegação ← delega ao comportamento padrão
/// ([WidgetOrderTraversalPolicy]), que move o foco para o grupo anterior
/// (carrossel acima, cabeçalho ou menu lateral). Isso permite que o
/// usuário chegue ao menu simplesmente pressionando ← repetidamente.
///
/// Navegação vertical (↑/↓) continua saindo do grupo normalmente para
/// permitir a transição entre carrosséis.
///
/// A implementação isola os nós do mesmo carrossel usando o
/// [Scrollable] horizontal como chave de agrupamento (cada carrossel
/// tem seu próprio ListView horizontal), e navega ordenando por posição
/// horizontal. Nos limites → ou ←, mantém o foco no card atual.
class _ClampedTraversalPolicy extends WidgetOrderTraversalPolicy {
  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    // Deixa navegação vertical (cima/baixo) com o comportamento padrão
    // — permite sair do grupo para o próximo/ anterior carrossel.
    if (direction == TraversalDirection.left ||
        direction == TraversalDirection.right) {
      return _handleHorizontal(currentNode, direction);
    }
    return super.inDirection(currentNode, direction);
  }

  /// Navegação horizontal: caminha entre os cards do mesmo carrossel
  /// e prende no primeiro/último quando atinge o limite.
  bool _handleHorizontal(FocusNode currentNode, TraversalDirection direction) {
    final scope = currentNode.nearestScope!;
    final FocusNode? focusedChild = scope.focusedChild;
    if (focusedChild == null) return false;

    // Descobre a qual carrossel (Scrollable horizontal) o nó atual pertence.
    final ScrollableState? currentScrollable = Scrollable.maybeOf(
      focusedChild.context!,
      axis: Axis.horizontal,
    );

    // Filtra os descendentes do scope para incluir apenas nós que
    // compartilham o mesmo Scrollable horizontal (mesmo carrossel).
    final List<FocusNode> rowNodes = scope.traversalDescendants
        .where(
          (FocusNode n) =>
              n.canRequestFocus &&
              !n.skipTraversal &&
              n.context != null &&
              _sameCarousel(n, currentScrollable, focusedChild),
        )
        .toList();

    if (rowNodes.isEmpty) return false;

    // Ordena da esquerda para a direita pela posição horizontal.
    rowNodes.sort((a, b) => a.rect.center.dx.compareTo(b.rect.center.dx));

    final int idx = rowNodes.indexOf(focusedChild);
    if (idx < 0) return false;

    if (direction == TraversalDirection.right) {
      if (idx < rowNodes.length - 1) {
        _requestFocusInDirection(rowNodes[idx + 1], direction);
      } else {
        // Clamp: mantém foco no último card
        _requestFocusInDirection(focusedChild, direction);
      }
    } else {
      // direction == TraversalDirection.left
      if (idx > 0) {
        _requestFocusInDirection(rowNodes[idx - 1], direction);
      } else {
        // Clamp: mantém foco no primeiro card
        _requestFocusInDirection(focusedChild, direction);
      }
    }
    return true;
  }

  /// Duas formas de determinar se [node] está no mesmo carrossel que o
  /// nó atualmente focado:
  ///
  /// 1. Se ambos compartilham o mesmo [Scrollable] horizontal →
  ///    estão na mesma [ListView].
  /// 2. Fallback por sobreposição vertical — mesma faixa de Y.
  bool _sameCarousel(
    FocusNode node,
    ScrollableState? currentScrollable,
    FocusNode focusedChild,
  ) {
    if (currentScrollable != null) {
      return Scrollable.maybeOf(node.context!, axis: Axis.horizontal) ==
          currentScrollable;
    }
    // Fallback: verifica se os retângulos estão na mesma linha vertical.
    return (node.rect.top - focusedChild.rect.top).abs() < 1 &&
        (node.rect.bottom - focusedChild.rect.bottom).abs() < 1;
  }

  void _requestFocusInDirection(
    FocusNode target,
    TraversalDirection direction,
  ) {
    requestFocusCallback(
      target,
      alignmentPolicy: direction == TraversalDirection.right
          ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
          : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
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
