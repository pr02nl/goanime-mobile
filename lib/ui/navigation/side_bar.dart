// ─────────────────────────────────────────────────────────────────────────────
// Sidebar expansível (TV / desktop) — comportamento YouTube TV
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/themes/app_colors.dart';
import '../core/widgets/focusable_widget.dart';

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
  /// distinguish conteúdo vs sidebar em `_SidebarEdgeAction`).
  bool containsNode(FocusNode node) {
    FocusNode? current = node;
    while (current != null) {
      if (current == _scopeNode) return true;
      current = current.parent;
    }
    return false;
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

  /// ↑↓ focou um item → navega (se a rota for diferente) + re-foca o item
  /// pós-frame para contrapor autofocus steal da nova tela.
  void _onItemFocus(int index) {
    final target = _navItems[index];
    if (!target.isSelected(widget.location)) {
      target.onTap(context); // context.go
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_itemFocusNodes[index].hasFocus) {
        _itemFocusNodes[index].requestFocus();
      }
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
    _NavItem(
      icon: Icons.home,
      label: 'Início',
      isSelected: (loc) => loc == '/',
      onTap: (ctx) => ctx.go('/'),
    ),
    _NavItem(
      icon: Icons.tv,
      label: 'Animes',
      isSelected: (loc) => loc == '/pauloflix-see-all',
      onTap: (ctx) => ctx.go('/pauloflix-see-all'),
    ),
    _NavItem(
      icon: Icons.movie_outlined,
      label: 'Filmes',
      isSelected: (loc) => loc == '/pauloflix-movies',
      onTap: (ctx) => ctx.go('/pauloflix-movies'),
    ),
    _NavItem(
      icon: Icons.search,
      label: 'Buscar',
      isSelected: (loc) =>
          loc == '/search' || loc == '/pauloflix-movies/search',
      onTap: (ctx) {
        final isAnimeSection = !widget.location.contains('pauloflix-movies');
        ctx.go(isAnimeSection ? '/search' : '/pauloflix-movies/search');
      },
    ),
    _NavItem(
      icon: Icons.bookmark,
      label: 'Favoritos',
      isSelected: (loc) => loc == '/watchlist',
      onTap: (ctx) => ctx.go('/watchlist'),
    ),
    _NavItem(
      icon: Icons.download_outlined,
      label: 'Downloads',
      isSelected: (loc) => loc == '/downloads',
      onTap: (ctx) => ctx.go('/downloads'),
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      label: 'Ajustes',
      isSelected: (loc) => loc == '/settings',
      onTap: (ctx) => ctx.go('/settings'),
    ),
  ];

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
                  _SidebarItem(
                    expanded: widget.expanded,
                    icon: items[i].icon,
                    label: items[i].label,
                    selected: items[i].isSelected(widget.location),
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
  final FocusNode focusNode;
  final VoidCallback onFocus;
  final VoidCallback onSelect;

  const _SidebarItem({
    required this.expanded,
    required this.icon,
    required this.label,
    required this.selected,
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
                Icon(
                  icon,
                  size: 24,
                  color: selected ? AppColors.primary : Colors.white70,
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
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
