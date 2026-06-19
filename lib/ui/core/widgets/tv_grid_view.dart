import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/tv_detector.dart';

/// GridView otimizado para navegação com controle remoto de TV
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
    _detectTVMode();
  }

  Future<void> _detectTVMode() async {
    final isTV = await TVDetector.isTV;
    if (mounted) {
      setState(() {
        _isTV = isTV;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  FocusNode _getFocusNode(int index) {
    if (!_focusNodes.containsKey(index)) {
      _focusNodes[index] = FocusNode();
    }
    return _focusNodes[index]!;
  }

  void _handleKeyEvent(FocusNode currentNode, KeyEvent event, int index) {
    if (event is KeyDownEvent && _isTV) {
      final row = index ~/ widget.crossAxisCount;
      final col = index % widget.crossAxisCount;
      final totalRows = (widget.items.length / widget.crossAxisCount).ceil();

      FocusNode? nextFocus;

      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowUp:
          if (row > 0) {
            final newIndex = (row - 1) * widget.crossAxisCount + col;
            if (newIndex < widget.items.length) {
              nextFocus = _getFocusNode(newIndex);
            }
          } else {
            widget.onNavigateUp?.call();
          }
          break;

        case LogicalKeyboardKey.arrowDown:
          if (row < totalRows - 1) {
            final newIndex = (row + 1) * widget.crossAxisCount + col;
            if (newIndex < widget.items.length) {
              nextFocus = _getFocusNode(newIndex);
            }
          } else {
            widget.onNavigateDown?.call();
          }
          break;

        case LogicalKeyboardKey.arrowLeft:
          if (col > 0) {
            nextFocus = _getFocusNode(index - 1);
          } else {
            widget.onNavigateLeft?.call();
          }
          break;

        case LogicalKeyboardKey.arrowRight:
          if (col < widget.crossAxisCount - 1 &&
              index + 1 < widget.items.length) {
            nextFocus = _getFocusNode(index + 1);
          } else {
            widget.onNavigateRight?.call();
          }
          break;
      }

      if (nextFocus != null) {
        nextFocus.requestFocus();
        // Scroll para o item focado
        _scrollToItem(index);
      }
    }
  }

  void _scrollToItem(int index) {
    final row = index ~/ widget.crossAxisCount;
    final itemHeight =
        (_scrollController.position.viewportDimension / widget.crossAxisCount) *
        widget.childAspectRatio;
    final targetOffset = row * itemHeight;

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isTV || !widget.enableDpadNavigation) {
      // Grid normal para mobile
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
          return widget.itemBuilder(context, widget.items[index], index);
        },
      );
    }

    // Grid otimizado para TV
    return Focus(
      onKeyEvent: (node, event) {
        // Deixa o sistema tratar navegação básica
        return KeyEventResult.ignored;
      },
      child: GridView.builder(
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
          final focusNode = _getFocusNode(index);

          return Focus(
            focusNode: focusNode,
            onKeyEvent: (node, event) {
              _handleKeyEvent(focusNode, event, index);
              return KeyEventResult.handled;
            },
            child: widget.itemBuilder(context, widget.items[index], index),
          );
        },
      ),
    );
  }
}

/// ListView horizontal otimizada para TV
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
    _detectTVMode();
  }

  Future<void> _detectTVMode() async {
    final isTV = await TVDetector.isTV;
    if (mounted) {
      setState(() {
        _isTV = isTV;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  FocusNode _getFocusNode(int index) {
    if (!_focusNodes.containsKey(index)) {
      _focusNodes[index] = FocusNode();
    }
    return _focusNodes[index]!;
  }

  void _handleKeyEvent(FocusNode currentNode, KeyEvent event, int index) {
    if (event is KeyDownEvent && _isTV) {
      FocusNode? nextFocus;

      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowLeft:
          if (index > 0) {
            nextFocus = _getFocusNode(index - 1);
          }
          break;

        case LogicalKeyboardKey.arrowRight:
          if (index < widget.items.length - 1) {
            nextFocus = _getFocusNode(index + 1);
          }
          break;
      }

      if (nextFocus != null) {
        nextFocus.requestFocus();
        _scrollToItem(index);
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
    if (!_isTV || !widget.enableDpadNavigation) {
      // Lista normal para mobile
      return ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        separatorBuilder: (context, index) => SizedBox(width: widget.spacing),
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          return SizedBox(
            width: widget.itemWidth,
            height: widget.itemHeight,
            child: widget.itemBuilder(context, widget.items[index], index),
          );
        },
      );
    }

    // Lista otimizada para TV
    return Focus(
      onKeyEvent: (node, event) => KeyEventResult.ignored,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        separatorBuilder: (context, index) => SizedBox(width: widget.spacing),
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final focusNode = _getFocusNode(index);

          return SizedBox(
            width: widget.itemWidth,
            height: widget.itemHeight,
            child: Focus(
              focusNode: focusNode,
              onKeyEvent: (node, event) {
                _handleKeyEvent(focusNode, event, index);
                return KeyEventResult.handled;
              },
              child: widget.itemBuilder(context, widget.items[index], index),
            ),
          );
        },
      ),
    );
  }
}
