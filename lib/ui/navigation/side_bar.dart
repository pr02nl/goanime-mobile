// ─────────────────────────────────────────────────────────────────────────────
// Sidebar expansível (TV / desktop) — comportamento YouTube TV
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io' show exit;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/themes/app_colors.dart';
import '../core/widgets/focusable_widget.dart';
import '../pauloflix/view_models/pauloflix_provider.dart';
import '../pauloflix_movies/view_models/pauloflix_movies_provider.dart';

/// Sidebar persistente estilo YouTube TV.
///
/// O estado expandido/colapsado é controlado pelo shell via [expanded] (não
/// por listener de foco do escopo) — isso evita colapso indesejado quando uma
/// nova tela rouba o foco via autofocus durante a navegação por ↑↓.
///
/// Comportamento D-pad:
/// * **↑↓** move o foco entre itens e **seleciona** o conteúdo
///   (foco = ativação, como no YouTube TV). A sidebar permanece expandida.
/// * **Enter/Select/click** fecha a sidebar e devolve o foco ao conteúdo
///   (via [onClose]).
/// * **→** é interceptada pelo shell (`_SidebarEdgeAction`) → fecha a sidebar.
///
/// O shell chama [focusActiveItem] ao abrir a sidebar (← no edge do conteúdo
/// ou botão Back) para posicionar o foco no item da rota ativa.
class Sidebar extends StatefulWidget {
  final String location;
  final bool expanded;
  final VoidCallback onClose;

  const Sidebar({
    super.key,
    required this.location,
    required this.expanded,
    required this.onClose,
  });

  @override
  State<Sidebar> createState() => SidebarState();
}

class SidebarState extends State<Sidebar> {
  final FocusScopeNode _scopeNode = FocusScopeNode();

  /// FocusNodes por item — permite focar o item da rota ativa de fora.
  late final List<FocusNode> _itemFocusNodes;

  /// Último índice focado. Usado pelo post-frame callback do `_onItemFocus`
  /// para verificar se o foco mudou desde o agendamento — se sim, o callback
  /// é um re-foco obsoleto e não deve roubar o foco de volta.
  int _lastFocusedIndex = -1;

  static const double _collapsedWidth = 72.0;
  static const double _expandedWidth = 220.0;

  @override
  void initState() {
    super.initState();
    _itemFocusNodes = List.generate(_navItems.length, (_) => FocusNode());
  }

  @override
  void didUpdateWidget(covariant Sidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_itemFocusNodes.length != _navItems.length) {
      for (final n in _itemFocusNodes) {
        n.dispose();
      }
      _itemFocusNodes = List.generate(_navItems.length, (_) => FocusNode());
    }
  }

  @override
  void dispose() {
    _scopeNode.dispose();
    for (final n in _itemFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// Se algum descendente da sidebar tem o foco primário.
  bool get hasFocus => _scopeNode.hasFocus;

  /// Se [node] está dentro do escopo da sidebar (usado pelo shell para
  /// discernir conteúdo vs sidebar em `_SidebarEdgeAction`).
  bool containsNode(FocusNode node) => node.nearestScope == _scopeNode;

  /// Retorna a cor do dot de sync para o item no índice [i], ou `null`
  /// se o item não tem indicador de sync.
  ///
  /// * **Animes (índice 1):** lê `PauloFlixProvider.hasSyncError`
  /// * **Filmes (índice 2):** lê `PauloFlixMoviesProvider.hasSyncError`
  ///
  /// Uso: verde (`Colors.greenAccent`) = sync ok; vermelho
  /// (`AppColors.primary` red) = erro na última sync.
  Color? _syncDotForIndex(int i) {
    if (i == 0) {
      // Animes
      final anime = context.read<PauloFlixProvider>();
      if (anime.hasSyncError) return AppColors.primary;
      if (anime.contents.isNotEmpty) return Colors.greenAccent;
      return null;
    }
    if (i == 1) {
      // Filmes
      final movies = context.read<PauloFlixMoviesProvider>();
      if (movies.hasSyncError) return AppColors.primary;
      if (movies.contents.isNotEmpty) return Colors.greenAccent;
      return null;
    }
    return null;
  }

  /// Foca o item da rota ativa. Chamado pelo shell ao abrir a sidebar
  /// (← no edge do conteúdo ou botão Back).
  void focusActiveItem() {
    if (!mounted) return;
    final items = _navItems;
    final idx = items.indexWhere((i) => i.isSelected(widget.location));
    final target = idx >= 0 ? _itemFocusNodes[idx] : _itemFocusNodes.first;
    if (!target.hasFocus) {
      target.requestFocus();
    }
  }

  /// ↑↓ focou um item → re-foca o item pós-frame para contrapor
  /// autofocus steal da nova tela.
  ///
  /// **Padrão "focar ≠ ativar"**: ↑↓ apenas move o anel de foco
  /// entre os itens. Navegação só acontece via click/Enter/Select
  /// (handler `_onItemSelect`). O re-foco pós-frame é mantido
  /// porque o `FocusableWidget` da nova rota pode roubar foco
  /// durante a transição.
  void _onItemFocus(int index) {
    // Atualiza o último índice focado — usado pelo post-frame callback
    // para detectar callbacks obsoletos.
    _lastFocusedIndex = index;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Se o foco já mudou para outro item desde o agendamento,
      // este callback é obsoleto — não rouba o foco de volta.
      if (_lastFocusedIndex != index) return;
      // Se a sidebar foi fechada, não re-foca.
      if (!widget.expanded) return;
      if (_itemFocusNodes[index].hasFocus) return;
      _itemFocusNodes[index].requestFocus();
    });
  }

  /// Enter/Select/click → navega (se necessário) + fecha a sidebar.
  void _onItemSelect(int index) {
    final target = _navItems[index];
    if (!target.isSelected(widget.location)) {
      target.onTap(context); // context.go (caso clique sem foco prévio)
    }
    widget.onClose();
  }

  List<_NavItem> get _navItems => [
    // _NavItem(
    //   icon: Icons.home,
    //   label: 'Início',
    //   isSelected: (loc) => loc == '/',
    //   onTap: (ctx) => ctx.goNamed('home'),
    // ),
    _NavItem(
      icon: Icons.tv,
      label: 'Animes',
      isSelected: (loc) => loc == '/pauloflix-see-all',
      onTap: (ctx) => ctx.goNamed('pauloflix-see-all'),
    ),
    _NavItem(
      icon: Icons.movie_outlined,
      label: 'Filmes',
      isSelected: (loc) => loc == '/pauloflix-movies',
      onTap: (ctx) => ctx.goNamed('pauloflix-movies'),
    ),
    _NavItem(
      icon: Icons.search,
      label: 'Buscar',
      isSelected: (loc) =>
          loc == '/search' ||
          loc == '/pauloflix-search' ||
          loc == '/pauloflix-movies/search',
      onTap: (ctx) {
        // Comportamento contextual: o item "Buscar" da sidebar leva o
        // usuário para a busca da seção atual. Mesmo padrão já usado
        // para /pauloflix-movies/search.
        final current = widget.location;
        if (current.contains('pauloflix-movies')) {
          ctx.pushNamed('pauloflix-movies-search');
        } else if (current == '/pauloflix-see-all' ||
            current == '/pauloflix-search') {
          ctx.pushNamed('pauloflix-search');
        } else {
          ctx.pushNamed('search');
        }
      },
    ),
    _NavItem(
      icon: Icons.bookmark,
      label: 'Favoritos',
      isSelected: (loc) => loc == '/watchlist',
      onTap: (ctx) => ctx.goNamed('watchlist'),
    ),
    _NavItem(
      icon: Icons.download_outlined,
      label: 'Downloads',
      isSelected: (loc) => loc == '/downloads',
      onTap: (ctx) => ctx.goNamed('downloads'),
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      label: 'Ajustes',
      isSelected: (loc) => loc == '/settings',
      onTap: (ctx) => ctx.goNamed('settings'),
    ),
    _NavItem(
      icon: Icons.exit_to_app,
      label: 'Sair',
      isSelected: (loc) => false,
      onTap: (ctx) => _showExitDialog(ctx),
    ),
  ];

  Future<void> _showExitDialog(BuildContext ctx) async {
    final shouldExit = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Sair do aplicativo?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tem certeza que deseja sair?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Não', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            autofocus: true,
            child: const Text(
              'Sim',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (shouldExit == true) {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        SystemNavigator.pop();
      } else {
        exit(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _navItems;
    return FocusScope(
      node: _scopeNode,
      child: FocusTraversalGroup(
        // ↑↓ usa ordered traversal (next/previous) — evita falha rect-based
        // com gaps de 4px entre itens. ← → é interceptado pelo shell.
        policy: _SidebarTraversalPolicy(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: widget.expanded ? _expandedWidth : _collapsedWidth,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                _buildLogo(),
                const SizedBox(height: 12),
                for (var i = 0; i < items.length; i++) ...[
                  // Divider antes do item Sair (último)
                  if (i == items.length - 1 && widget.expanded) ...[
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(color: Colors.white12, height: 1),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _SidebarItem(
                    expanded: widget.expanded,
                    icon: items[i].icon,
                    label: items[i].label,
                    selected: items[i].isSelected(widget.location),
                    syncDotColor: _syncDotForIndex(i),
                    focusNode: _itemFocusNodes[i],
                    onFocus: () => _onItemFocus(i),
                    onSelect: () => _onItemSelect(i),
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Logo no topo (não-focusable, visual only)
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.play_circle_filled,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Política de travessia da sidebar — ↑↓ ordenado, ← → delega ao shell
// ─────────────────────────────────────────────────────────────────────────────

/// ↑↓ usa `next()`/`previous()` (ordered traversal) para ignorar gaps de 4px
/// entre itens (o algoritmo rect-based falha com gaps). ← → delega ao
/// `super.inDirection()` — mas na prática é interceptado pelo `_SidebarEdgeAction`
/// do shell antes de chegar aqui.
class _SidebarTraversalPolicy extends WidgetOrderTraversalPolicy {
  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    if (direction == TraversalDirection.down) return next(currentNode);
    if (direction == TraversalDirection.up) return previous(currentNode);
    return super.inDirection(currentNode, direction);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de item de navegação
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  final bool Function(String location) isSelected;
  final void Function(BuildContext context) onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Item da sidebar — só ícone no estado colapsado, ícone + rótulo no expandido.
// ↑↓ (onFocus) navega; Enter/Select/click (onSelect) fecha a sidebar.
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarItem extends StatelessWidget {
  final bool expanded;
  final IconData icon;
  final String label;
  final bool selected;
  final Color? syncDotColor;
  final FocusNode focusNode;
  final VoidCallback onFocus;
  final VoidCallback onSelect;

  const _SidebarItem({
    required this.expanded,
    required this.icon,
    required this.label,
    required this.selected,
    this.syncDotColor,
    required this.focusNode,
    required this.onFocus,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onSelect: onSelect,
      onFocus: onFocus,
      focusNode: focusNode,
      focusPadding: EdgeInsets.zero,
      focusScale: 1.0,
      borderRadius: 12,
      child: Tooltip(
        message: expanded ? '' : label,
        child: SizedBox(
          height: 48,
          child: Container(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.only(
              left: expanded ? 16 : (72 - 24) / 2, // centraliza ícone colapsado
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: selected ? AppColors.primary : Colors.white70,
                    ),
                    if (syncDotColor != null)
                      Positioned(
                        top: 0,
                        right: -3,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: syncDotColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.background,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (expanded) ...[
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (syncDotColor != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: syncDotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
