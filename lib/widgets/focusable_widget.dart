import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget que adiciona suporte a foco para navegação com teclado (Windows/desktop)
/// e controle remoto D-pad (Android TV).
///
/// Arquitetura: o [FocusNode] é passado diretamente ao [InkWell], que no Flutter
/// hospeda seu próprio nó de foco interno. Um [Focus] separado envolvendo o
/// [InkWell] cria um nó concorrente e impede o traversal de alcançar o widget.
/// A solução correta (documentada no PR flutter#41220) é usar [InkWell.focusNode]
/// e registrar um [Shortcuts]/[Actions] para Enter/Space/Select acima dele.
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
    if (!mounted) return;
    setState(() => _isFocused = hasFocus);
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
    if (widget.focusNode == null) _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _activate() => widget.onSelect?.call();

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        widget.focusColor ?? Theme.of(context).colorScheme.primary;
    final splash = effectiveColor.withValues(alpha: 0.18);
    final highlight = effectiveColor.withValues(alpha: 0.08);

    // Shortcuts mapeia Enter/Space/Select → ActivateIntent.
    // Actions associa ActivateIntent → _activate(), o que aciona onSelect
    // tanto no teclado (Windows/desktop) quanto no D-pad (TV).
    // O focusNode é passado diretamente ao InkWell para que haja um único
    // nó de foco — o Flutter PR#41220 estabelece essa como a forma correta.
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
              _activate();
              return null;
            },
          ),
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
                            color: effectiveColor.withValues(alpha: 0.6),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                  border: _isFocused
                      ? Border.all(color: effectiveColor, width: 3)
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    focusNode: _focusNode,
                    autofocus: widget.autoFocus,
                    canRequestFocus: true,
                    onTap: widget.onSelect,
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    splashColor: splash,
                    highlightColor: highlight,
                    child: Padding(
                      padding: widget.focusPadding,
                      child: widget.child,
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
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: items,
      backgroundColor: backgroundColor ?? Colors.black,
      selectedItemColor: selectedItemColor ?? Colors.white,
      unselectedItemColor:
          unselectedItemColor ?? Colors.white.withValues(alpha: 0.5),
      type: BottomNavigationBarType.fixed,
    );
  }
}

/// Indicador de foco para TV — anel colorido ao redor do widget focado
class TVFocusIndicator extends StatelessWidget {
  final Widget child;
  final bool isFocused;
  final Color? focusColor;
  final double borderRadius;
  final double borderWidth;

  const TVFocusIndicator({
    super.key,
    required this.child,
    required this.isFocused,
    this.focusColor,
    this.borderRadius = 12.0,
    this.borderWidth = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    final color = focusColor ?? Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: isFocused ? Border.all(color: color, width: borderWidth) : null,
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}
