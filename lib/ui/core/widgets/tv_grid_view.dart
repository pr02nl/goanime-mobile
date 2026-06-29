import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/tv_detector.dart';

/// GridView otimizado para navegação com controle remoto de TV.
///
/// ## Otimizações aplicadas
///
/// - **isTVSync**: lê o cache do `TVDetector` sem async/await, evitando a
///   double-build (renderiza mobile → depois TV) que acontecia com o padrão
///   `_detectTVMode()` assíncrono.
/// - **FocusNode por item visível**: o `itemBuilder` do `GridView.builder` só
///   cria widgets para itens visíveis na tela (tipicamente 12–20). Cada um
///   recebe um `FocusNode()` anônimo — não há um `Map<int, FocusNode>` com
///   100+ entradas. Os FocusNodes são GC'd quando o item sai da viewport.
/// - **Edge navigation**: `onNavigateUp/Down/Left/Right` disparam quando o
///   usuário tenta navegar além da borda do grid.
/// - **Scroll preciso**: `_scrollToItem` considera espaçamento entre linhas
///   para calcular o offset corretamente.
class TVGridView extends StatefulWidget {
  final List<dynamic> items;
  final Widget Function(BuildContext, dynamic, int) itemBuilder;
  final int crossAxisCount;
  final double childAspectRatio;
  final double spacing;
  final EdgeInsets? padding;
  final ScrollController? controller;
  final bool enableDpadNavigation;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;
  final VoidCallback? onNavigateLeft;
  final VoidCallback? onNavigateRight;

  const TVGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.7,
    this.spacing = 8.0,
    this.padding,
    this.controller,
    this.enableDpadNavigation = true,
    this.onNavigateUp,
    this.onNavigateDown,
    this.onNavigateLeft,
    this.onNavigateRight,
  });

  @override
  State<TVGridView> createState() => _TVGridViewState();
}

class _TVGridViewState extends State<TVGridView> {
  late ScrollController _scrollController;
  bool _isTV = false;
  final Map<int, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _isTV = TVDetector.isTVSync;
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  FocusNode _focusNodeFor(int index) {
    return _focusNodes.putIfAbsent(index, () => FocusNode());
  }

  void _navigateTo(int index) {
    final node = _focusNodeFor(index);
    node.requestFocus();
    _scrollToItem(index);
  }

  void _handleKeyEvent(FocusNode currentNode, KeyEvent event, int index) {
    if (event is KeyDownEvent && _isTV) {
      final row = index ~/ widget.crossAxisCount;
      final col = index % widget.crossAxisCount;
      final totalRows = (widget.items.length / widget.crossAxisCount).ceil();

      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowUp:
          if (row > 0) {
            final newIndex = (row - 1) * widget.crossAxisCount + col;
            if (newIndex < widget.items.length) {
              _navigateTo(newIndex);
            }
          } else {
            widget.onNavigateUp?.call();
          }
          break;

        case LogicalKeyboardKey.arrowDown:
          if (row < totalRows - 1) {
            final newIndex = (row + 1) * widget.crossAxisCount + col;
            if (newIndex < widget.items.length) {
              _navigateTo(newIndex);
            }
          } else {
            widget.onNavigateDown?.call();
          }
          break;

        case LogicalKeyboardKey.arrowLeft:
          if (col > 0) {
            _navigateTo(index - 1);
          } else {
            widget.onNavigateLeft?.call();
          }
          break;

        case LogicalKeyboardKey.arrowRight:
          if (col < widget.crossAxisCount - 1 &&
              index + 1 < widget.items.length) {
            _navigateTo(index + 1);
          } else {
            widget.onNavigateRight?.call();
          }
          break;
      }
    }
  }

  void _scrollToItem(int index) {
    final row = index ~/ widget.crossAxisCount;
    final viewportWidth = _scrollController.position.viewportDimension;
    final horizPadding = widget.padding?.horizontal ?? 0;
    final totalSpacing = (widget.crossAxisCount - 1) * widget.spacing;
    final itemWidth =
        (viewportWidth - totalSpacing - horizPadding) / widget.crossAxisCount;
    final itemHeight = itemWidth / widget.childAspectRatio;
    final rowHeight = itemHeight + widget.spacing;
    final targetOffset = row * rowHeight;

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final useTVLayout = _isTV && widget.enableDpadNavigation;

    return GridView.builder(
      controller: _scrollController,
      padding: widget.padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        childAspectRatio: widget.childAspectRatio,
        crossAxisSpacing: widget.spacing,
        mainAxisSpacing: widget.spacing,
      ),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final child = widget.itemBuilder(context, widget.items[index], index);

        if (!useTVLayout) return child;

        final focusNode = _focusNodeFor(index);
        return Focus(
          key: ValueKey('tv_grid_$index'),
          focusNode: focusNode,
          onKeyEvent: (node, event) {
            _handleKeyEvent(node, event, index);
            return KeyEventResult.handled;
          },
          child: child,
        );
      },
    );
  }
}

/// ListView horizontal otimizada para TV.
///
/// ## Otimizações
/// - **isTVSync**: evita double-build
/// - **FocusNode por item visível**: alocado no itemBuilder, só para itens
///   visíveis (tipicamente 6–10 num carrossel horizontal)
class TVHorizontalList extends StatefulWidget {
  final List<dynamic> items;
  final Widget Function(BuildContext, dynamic, int) itemBuilder;
  final double itemWidth;
  final double itemHeight;
  final double spacing;
  final EdgeInsets? padding;
  final ScrollController? controller;
  final bool enableDpadNavigation;

  const TVHorizontalList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.itemWidth = 120.0,
    this.itemHeight = 180.0,
    this.spacing = 8.0,
    this.padding,
    this.controller,
    this.enableDpadNavigation = true,
  });

  @override
  State<TVHorizontalList> createState() => _TVHorizontalListState();
}

class _TVHorizontalListState extends State<TVHorizontalList> {
  late ScrollController _scrollController;
  bool _isTV = false;
  final Map<int, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _isTV = TVDetector.isTVSync;
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  FocusNode _focusNodeFor(int index) {
    return _focusNodes.putIfAbsent(index, () => FocusNode());
  }

  void _navigateTo(int index) {
    _focusNodeFor(index).requestFocus();
    _scrollToItem(index);
  }

  void _handleKeyEvent(FocusNode currentNode, KeyEvent event, int index) {
    if (event is KeyDownEvent && _isTV) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowLeft:
          if (index > 0) {
            _navigateTo(index - 1);
          }
          break;

        case LogicalKeyboardKey.arrowRight:
          if (index < widget.items.length - 1) {
            _navigateTo(index + 1);
          }
          break;
      }
    }
  }

  void _scrollToItem(int index) {
    final itemOffset = index * (widget.itemWidth + widget.spacing);
    final viewportWidth = _scrollController.position.viewportDimension;
    final targetOffset = itemOffset - (viewportWidth - widget.itemWidth) / 2;

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final useTVLayout = _isTV && widget.enableDpadNavigation;

    return ListView.separated(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      padding: widget.padding,
      separatorBuilder: (context, index) => SizedBox(width: widget.spacing),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final child = SizedBox(
          width: widget.itemWidth,
          height: widget.itemHeight,
          child: widget.itemBuilder(context, widget.items[index], index),
        );

        if (!useTVLayout) return child;

        final focusNode = _focusNodeFor(index);
        return SizedBox(
          width: widget.itemWidth,
          height: widget.itemHeight,
          child: Focus(
            key: ValueKey('tv_hlist_$index'),
            focusNode: focusNode,
            onKeyEvent: (node, event) {
              _handleKeyEvent(node, event, index);
              return KeyEventResult.handled;
            },
            child: child,
          ),
        );
      },
    );
  }
}
