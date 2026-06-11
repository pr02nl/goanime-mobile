import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/tv_detector.dart';
import 'focusable_widget.dart';

/// GridView otimizado para navegação com controle remoto em TVs
class TVGridView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final void Function(T item, int index)? onItemSelected;
  final int crossAxisCount;
  final double childAspectRatio;
  final double spacing;
  final EdgeInsets padding;
  final ScrollController? scrollController;
  final bool enableDpadNavigation;

  const TVGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.onItemSelected,
    this.crossAxisCount = 4,
    this.childAspectRatio = 0.7,
    this.spacing = 16.0,
    this.padding = const EdgeInsets.all(16.0),
    this.scrollController,
    this.enableDpadNavigation = true,
  });

  @override
  State<TVGridView<T>> createState() => _TVGridViewState<T>();
}

class _TVGridViewState<T> extends State<TVGridView<T>> {
  late ScrollController _scrollController;
  final Map<int, FocusNode> _focusNodes = {};
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _initializeFocusNodes();
  }

  void _initializeFocusNodes() {
    for (int i = 0; i < widget.items.length; i++) {
      _focusNodes[i] = FocusNode();
    }
  }

  @override
  void didUpdateWidget(covariant TVGridView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      // Limpar nós antigos e criar novos
      for (var node in _focusNodes.values) {
        node.dispose();
      }
      _focusNodes.clear();
      _initializeFocusNodes();
    }
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _handleNavigation(int currentIndex, KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final crossAxisCount = widget.crossAxisCount;
    final row = currentIndex ~/ crossAxisCount;
    final col = currentIndex % crossAxisCount;
    int newIndex = currentIndex;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        if (row > 0) {
          newIndex = currentIndex - crossAxisCount;
        }
        break;
      case LogicalKeyboardKey.arrowDown:
        if (row < (widget.items.length - 1) ~/ crossAxisCount) {
          newIndex = currentIndex + crossAxisCount;
          if (newIndex >= widget.items.length) {
            newIndex = widget.items.length - 1;
          }
        }
        break;
      case LogicalKeyboardKey.arrowLeft:
        if (col > 0) {
          newIndex = currentIndex - 1;
        }
        break;
      case LogicalKeyboardKey.arrowRight:
        if (col < crossAxisCount - 1 &&
            currentIndex < widget.items.length - 1) {
          newIndex = currentIndex + 1;
        }
        break;
    }

    if (newIndex != currentIndex && _focusNodes.containsKey(newIndex)) {
      _focusNodes[newIndex]!.requestFocus();
      _scrollToItem(newIndex);
      setState(() {
        _focusedIndex = newIndex;
      });
    }
  }

  void _scrollToItem(int index) {
    if (!_scrollController.hasClients) return;

    final row = index ~/ widget.crossAxisCount;
    final viewportHeight = _scrollController.position.viewportDimension;
    final itemHeight =
        (viewportHeight - (widget.spacing * (widget.crossAxisCount - 1))) /
        widget.crossAxisCount;
    final targetOffset =
        row * (itemHeight / widget.childAspectRatio + widget.spacing);

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTV = TVDetector.isTV;

    if (!isTV || !widget.enableDpadNavigation) {
      // Grid normal para mobile
      return GridView.builder(
        controller: _scrollController,
        padding: widget.padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isTV ? widget.crossAxisCount : 2,
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

    // Grid com suporte a navegação por controle remoto para TV
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (event) {
        if (_focusNodes.containsKey(_focusedIndex)) {
          _handleNavigation(_focusedIndex, event);
        }
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
          return FocusableWidget(
            focusNode: _focusNodes[index]!,
            autoFocus: index == 0,
            onSelect: () {
              widget.onItemSelected?.call(widget.items[index], index);
            },
            onFocus: () {
              setState(() {
                _focusedIndex = index;
              });
              _scrollToItem(index);
            },
            focusScale: 1.08,
            borderRadius: 12,
            child: widget.itemBuilder(context, widget.items[index], index),
          );
        },
      ),
    );
  }
}

/// ListView horizontal otimizado para TV com navegação por controle remoto
class TVHorizontalList<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final void Function(T item, int index)? onItemSelected;
  final double itemWidth;
  final double spacing;
  final EdgeInsets padding;
  final double? height;

  const TVHorizontalList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.onItemSelected,
    this.itemWidth = 150.0,
    this.spacing = 16.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
    this.height,
  });

  @override
  State<TVHorizontalList<T>> createState() => _TVHorizontalListState<T>();
}

class _TVHorizontalListState<T> extends State<TVHorizontalList<T>> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, FocusNode> _focusNodes = {};
  // ignore: unused_field
  int _focusedIndex =
      0; // Rastreia o item atualmente focado para scroll automático

  @override
  void initState() {
    super.initState();
    _initializeFocusNodes();
  }

  void _initializeFocusNodes() {
    for (int i = 0; i < widget.items.length; i++) {
      _focusNodes[i] = FocusNode();
    }
  }

  @override
  void didUpdateWidget(covariant TVHorizontalList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      for (var node in _focusNodes.values) {
        node.dispose();
      }
      _focusNodes.clear();
      _initializeFocusNodes();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _scrollToItem(int index) {
    if (!_scrollController.hasClients) return;

    final targetOffset = index * (widget.itemWidth + widget.spacing);
    final viewportWidth = _scrollController.position.viewportDimension;
    final currentOffset = _scrollController.offset;

    // Verifica se o item está fora da viewport
    if (targetOffset < currentOffset ||
        targetOffset + widget.itemWidth > currentOffset + viewportWidth) {
      _scrollController.animateTo(
        (targetOffset - viewportWidth / 2 + widget.itemWidth / 2).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTV = TVDetector.isTV;
    final itemHeight = widget.height ?? (isTV ? 280.0 : 200.0);

    return SizedBox(
      height: itemHeight,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final item = widget.items[index];

          if (!isTV) {
            // List normal para mobile
            return GestureDetector(
              onTap: () => widget.onItemSelected?.call(item, index),
              child: SizedBox(
                width: widget.itemWidth,
                child: widget.itemBuilder(context, item, index),
              ),
            );
          }

          // Item com foco para TV
          return FocusableWidget(
            focusNode: _focusNodes[index]!,
            autoFocus: index == 0,
            onSelect: () => widget.onItemSelected?.call(item, index),
            onFocus: () {
              setState(() {
                _focusedIndex = index;
              });
              _scrollToItem(index);
            },
            focusScale: 1.1,
            borderRadius: 12,
            child: SizedBox(
              width: widget.itemWidth,
              child: widget.itemBuilder(context, item, index),
            ),
          );
        },
      ),
    );
  }
}
