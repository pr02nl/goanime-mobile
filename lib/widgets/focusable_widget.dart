import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/tv_detector.dart';

/// Widget que adiciona suporte a foco para navegação com controle remoto (TV)
class FocusableWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSelect;
  final VoidCallback? onFocus;
  final VoidCallback? onUnfocus;
  final bool autoFocus;
  final FocusNode? focusNode;
  final EdgeInsets focusPadding;
  final double focusScale;
  final Color? focusColor;
  final double borderRadius;
  final bool enableDpadNavigation;

  const FocusableWidget({
    super.key,
    required this.child,
    this.onSelect,
    this.onFocus,
    this.onUnfocus,
    this.autoFocus = false,
    this.focusNode,
    this.focusPadding = const EdgeInsets.all(4.0),
    this.focusScale = 1.05,
    this.focusColor,
    this.borderRadius = 12.0,
    this.enableDpadNavigation = true,
  });

  @override
  State<FocusableWidget> createState() => _FocusableWidgetState();
}

class _FocusableWidgetState extends State<FocusableWidget>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.focusScale).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    final hasFocus = _focusNode.hasFocus;
    setState(() {
      _isFocused = hasFocus;
    });

    if (hasFocus) {
      _animationController.forward();
      widget.onFocus?.call();
    } else {
      _animationController.reverse();
      widget.onUnfocus?.call();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        widget.onSelect?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTV = TVDetector.isTV;

    // Se não for TV e não tiver navegação D-pad habilitada, retorna widget normal
    if (!isTV && !widget.enableDpadNavigation) {
      return GestureDetector(onTap: widget.onSelect, child: widget.child);
    }

    return GestureDetector(
      onTap: widget.onSelect,
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autoFocus,
        onKeyEvent: (node, event) {
          _handleKeyEvent(event);
          return KeyEventResult.ignored; // Deixa o sistema tratar também
        },
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: _isFocused
                      ? [
                          BoxShadow(
                            color:
                                (widget.focusColor ??
                                        Theme.of(context).colorScheme.primary)
                                    .withValues(alpha: 0.6),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                  border: _isFocused
                      ? Border.all(
                          color:
                              widget.focusColor ??
                              Theme.of(context).colorScheme.primary,
                          width: 3,
                        )
                      : null,
                ),
                child: Padding(
                  padding: widget.focusPadding,
                  child: widget.child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Botão otimizado para TV com suporte a foco
class TVButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final bool autoFocus;
  final Color? focusColor;
  final double? width;
  final double? height;

  const TVButton({
    super.key,
    required this.child,
    this.onPressed,
    this.focusNode,
    this.autoFocus = false,
    this.focusColor,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onSelect: onPressed,
      focusNode: focusNode,
      autoFocus: autoFocus,
      focusColor: focusColor,
      child: SizedBox(
        width: width,
        height: height,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Card de anime otimizado para navegação com controle remoto
class TVAnimeCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autoFocus;
  final String? heroTag;

  const TVAnimeCard({
    super.key,
    required this.child,
    this.onTap,
    this.focusNode,
    this.autoFocus = false,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final card = FocusableWidget(
      onSelect: onTap,
      focusNode: focusNode,
      autoFocus: autoFocus,
      focusScale: 1.1,
      borderRadius: 16,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: child,
      ),
    );

    if (heroTag != null) {
      return Hero(tag: heroTag!, child: card);
    }

    return card;
  }
}

/// Navigation bar otimizada para TV
class TVNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavigationBarItem> items;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;

  const TVNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      color: backgroundColor ?? Theme.of(context).colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          items.length,
          (index) => FocusableWidget(
            onSelect: () => onTap(index),
            autoFocus: index == currentIndex,
            child: SizedBox(
              width: 100,
              height: 60,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme(
                    data: IconThemeData(
                      color: index == currentIndex
                          ? (selectedItemColor ??
                                Theme.of(context).colorScheme.primary)
                          : (unselectedItemColor ??
                                Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6)),
                      size: 28,
                    ),
                    child: items[index].icon,
                  ),
                  if (items[index].label != null)
                    Text(
                      items[index].label!,
                      style: TextStyle(
                        color: index == currentIndex
                            ? (selectedItemColor ??
                                  Theme.of(context).colorScheme.primary)
                            : (unselectedItemColor ??
                                  Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6)),
                        fontSize: 12,
                        fontWeight: index == currentIndex
                            ? FontWeight.bold
                            : FontWeight.normal,
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
