// ─────────────────────────────────────────────────────────────────────────────
// Sidebar expansível (TV / desktop) — comportamento YouTube TV
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/themes/app_colors.dart';
import '../core/widgets/focusable_widget.dart';

/// Sidebar persistente estilo YouTube TV.
///
/// * **Colapsada** (só ícones, 72px) quando o grupo não tem foco.
/// * **Expandida** (ícones + labels, 220px) quando o grupo recebe foco.
/// * Expande automaticamente ao receber foco (← vindo do conteúdo) e
///   **colapsa ao perder foco** (→ ou Select em um item).
/// * **Focar ≠ ativar**: ↑↓ move o anel de foco entre itens sem navegar;
///   só Enter/Select/click dispara [onSelect] do item.
/// * Ao receber foco vindo de fora, redireciona ao item da rota ativa
///   (chamado de fora via [focusActiveItem]).
class Sidebar extends StatefulWidget {
  final String location;

  const Sidebar({super.key, required this.location});

  @override
  State<Sidebar> createState() => SidebarState();
}

class SidebarState extends State<Sidebar> {
  final FocusScopeNode _scopeNode = FocusScopeNode();

  /// FocusNodes por item — permite focar o item da rota ativa de fora.
  late final List<FocusNode> _itemFocusNodes;

  /// Guarda "sidebar estava com foco?" no último evento — detecta transição
  /// "ganhou foco vindo de fora" para redirecionar ao item ativo.
  bool _hadFocus = false;

  bool _expanded = false;

  static const double _collapsedWidth = 72.0;
  static const double _expandedWidth = 220.0;

  @override
  void initState() {
    super.initState();
    _itemFocusNodes = List.generate(_navItems.length, (_) => FocusNode());
    _scopeNode.addListener(_onScopeFocusChange);
  }

  @override
  void didUpdateWidget(covariant Sidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se o número de itens mudou, recria os FocusNodes (não esperado, mas
    // defensivo contra regressões futuras).
    if (_itemFocusNodes.length != _navItems.length) {
      for (final n in _itemFocusNodes) {
        n.dispose();
      }
      _itemFocusNodes = List.generate(_navItems.length, (_) => FocusNode());
    }
  }

  @override
  void dispose() {
    _scopeNode.removeListener(_onScopeFocusChange);
    _scopeNode.dispose();
    for (final n in _itemFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _onScopeFocusChange() {
    if (!mounted) return;
    final hasFocus = _scopeNode.hasFocus;
    if (hasFocus == _hadFocus) return;

    if (hasFocus) {
      // Sidebar ganhou foco vindo de fora: expande e redireciona ao item ativo.
      setState(() {
        _expanded = true;
        _hadFocus = true;
      });
      _focusActiveItem();
    } else {
      // Sidebar perdeu foco: colapsa.
      setState(() {
        _expanded = false;
        _hadFocus = false;
      });
    }
  }

  /// Foca o item da rota ativa. Chamado pelo shell ao capturar ← no conteúdo
  /// (edge) — expande a sidebar e posiciona o d-pad no item da rota atual.
  void focusActiveItem() {
    if (!mounted) return;
    _focusActiveItem();
  }

  void _focusActiveItem() {
    final items = _navItems;
    final idx = items.indexWhere((i) => i.isSelected(widget.location));
    final target = idx >= 0 ? _itemFocusNodes[idx] : _itemFocusNodes.first;
    if (!target.hasFocus) {
      target.requestFocus();
    }
  }

  /// Navega para a rota do item e devolve o foco ao conteúdo (a sidebar
  /// colapsa automaticamente ao perder foco via [_onScopeFocusChange]).
  void _onItemTap(int index) {
    final ctx = context;
    _navItems[index].onTap(ctx);
    // Remove o foco do item da sidebar — o Flutter move o foco primário
    // para o escopo da rota filha, onde a nova tela pode ter autofocus.
    FocusScope.of(ctx).unfocus();
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
        ctx.push(isAnimeSection ? '/search' : '/pauloflix-movies/search');
      },
    ),
    _NavItem(
      icon: Icons.bookmark,
      label: 'Favoritos',
      isSelected: (loc) => loc == '/watchlist',
      onTap: (ctx) => ctx.push('/watchlist'),
    ),
    _NavItem(
      icon: Icons.download_outlined,
      label: 'Downloads',
      isSelected: (loc) => loc == '/downloads',
      onTap: (ctx) => ctx.push('/downloads'),
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      label: 'Ajustes',
      isSelected: (loc) => loc == '/settings',
      onTap: (ctx) => ctx.push('/settings'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final items = _navItems;
    return FocusScope(
      node: _scopeNode,
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: _expanded ? _expandedWidth : _collapsedWidth,
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
                    expanded: _expanded,
                    icon: items[i].icon,
                    label: items[i].label,
                    selected: items[i].isSelected(widget.location),
                    focusNode: _itemFocusNodes[i],
                    onSelect: () => _onItemTap(i),
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
// Focar (d-pad ↑↓) move o anel de foco; só Enter/Select/click ativa onSelect.
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarItem extends StatelessWidget {
  final bool expanded;
  final IconData icon;
  final String label;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onSelect;

  const _SidebarItem({
    required this.expanded,
    required this.icon,
    required this.label,
    required this.selected,
    required this.focusNode,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onSelect: onSelect,
      focusNode: focusNode,
      // Sem onFocus: focar (d-pad ↑↓) não navega — só Enter/Select ativa.
      // Sem autoFocus: o foco inicial é do conteúdo, não da sidebar.
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
