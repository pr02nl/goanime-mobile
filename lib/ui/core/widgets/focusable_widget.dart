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

  /// Action opcional para processar `DirectionalFocusIntent` antes do
  /// fallback do `DirectionalFocusAction` default. Usado pelo shell
  /// (que precisa interceptar setas para abrir/fechar a sidebar).
  ///
  /// Por que isso é necessário: o `Shortcuts` deste widget mapeia setas
  /// para `DirectionalFocusIntent`. O `Actions` local deste widget é o
  /// primeiro ancestor e captura o intent. Se este widget não tiver
  /// um handler para o intent, o Flutter NÃO sobe até o próximo
  /// `Actions` ancestor — o intent é descartado.
  ///
  /// Como o `Actions` ancestor do shell (`_SidebarEdgeAction` no
  /// `MainNavigationScreen`) está acima de vários outros `Actions`
  /// defaults do framework, o pass-through via `Actions.maybeFind`
  /// não consegue chegar nele de forma confiável.
  ///
  /// A solução é o shell passar explicitamente sua action via este
  /// parâmetro. Widgets core que não têm shell não passam nada, e o
  /// comportamento default (foco no traversal) é preservado.
  final Action<DirectionalFocusIntent>? directionalAction;

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
    this.directionalAction,
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

  /// `BuildContext` do PARENT do `Actions` local. Usado pelo
  /// pass-through de `DirectionalFocusIntent` para buscar a action
  /// no `Actions` ancestor (o do shell), evitando o `Actions` local
  /// (que é o primeiro ancestor e causaria loop infinito).
  ///
  /// Capturado em `build`. Null antes do primeiro build.
  BuildContext? _parentOfActionsContext;

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
    // Captura o context do parent ANTES do `Actions` local. Esse context
    // aponta para um lugar ACIMA do nosso `Actions`, então `Actions.maybeFind`
    // (que sobe a partir dele) vai achar o ANCESTRAL do nosso — não o local.
    _parentOfActionsContext = context;

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
        // Navegação direcional D-pad — move o foco na direção da seta
        SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(
          TraversalDirection.up,
        ),
        SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(
          TraversalDirection.down,
        ),
        SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(
          TraversalDirection.left,
        ),
        SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(
          TraversalDirection.right,
        ),
        // ESC/Back — desfoca este widget (volta para o pai)
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.goBack): DismissIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              _focusNode.unfocus();
              return null;
            },
          ),
          // Repassa `DirectionalFocusIntent` para a action do shell
          // (se fornecida via [widget.directionalAction]) ou usa o
          // default `DirectionalFocusAction` do Flutter (foco no traversal).
          //
          // Por que injetar a action do shell em vez de fazer lookup?
          // O `Actions.maybeFind` percorre a árvore e pode encontrar
          // outros `Actions` ancestors (defaults do framework) ANTES
          // de chegar no `Actions` do shell. A action do shell precisa
          // de prioridade para que a sidebar funcione corretamente.
          DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
            onInvoke: (intent) {
              final custom = widget.directionalAction;
              if (custom != null) {
                debugPrint(
                  '[FocusableWidget] using custom directional action: '
                  '${custom.runtimeType} (hashCode=${custom.hashCode}) '
                  'for direction=${intent.direction}',
                );
                Actions.invoke(context, intent);
                return true;
              }
              // Sem action customizada: usa o default do Flutter
              // (DirectionalFocusAction) via Actions.maybeFind.
              final parentCtx = _parentOfActionsContext;
              if (parentCtx == null) return true;
              final ancestor = Actions.maybeFind<DirectionalFocusIntent>(
                parentCtx,
                intent: intent,
              );
              if (ancestor != null) {
                return Actions.invoke(context, intent);
              }
              // Default: o Flutter já moveu o foco via focus traversal.
              // Retorna true para consumir o evento e impedir que ele
              // vaze para CallbackShortcuts (seek/volume) quando o
              // botão está focado (P4 TV-readiness).
              return true;
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
                    // SEM `onFocusChange:` no InkWell — a cobertura
                    // de foco é feita EXCLUSIVAMENTE pelo listener
                    // `_focusNode.addListener(_handleFocusChange)`
                    // em initState. Manter o `onFocusChange` aqui
                    // causa chamada dupla de `widget.onFocus` (e
                    // `widget.onUnfocus`) a cada mudança de foco.
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
