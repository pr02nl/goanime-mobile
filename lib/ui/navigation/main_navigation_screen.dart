import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/themes/app_colors.dart';
import '../core/utils/responsive.dart';
import '../core/widgets/content_type_selector.dart';
import 'key_activable.dart';
import 'side_bar.dart';

/// Ponto central de navegação do app.
///
/// Em telas largas (tablet, TV, desktop) exibe uma [Sidebar] à esquerda
/// estilo YouTube TV:
/// * Inicia **colapsada** (só ícones) com o foco no conteúdo.
/// * **←** no conteúdo no item mais à esquerda → expande a sidebar e foca o
///   item da rota ativa. ← no meio do conteúdo move entre itens.
/// * **↑↓** na sidebar seleciona o conteúdo e atualiza o lado direito
///   imediatamente (foco = ativação). A sidebar permanece expandida.
/// * **→** na sidebar ou **Enter/Select** em um item → colapsa e devolve o
///   foco ao último item selecionado no conteúdo.
/// * **Back** do d-pad → abre a sidebar (se fechada) ou fecha + devolve foco
///   ao conteúdo (se aberta).
///
/// Em telas estreitas (mobile) usa um [Drawer] tradicional.
class MainNavigationScreen extends StatefulWidget {
  final Widget child;

  const MainNavigationScreen({super.key, required this.child});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<SidebarState> _sidebarKey = GlobalKey<SidebarState>();

  /// Estado de expansão da sidebar — controlado pelo shell (não por listener
  /// de foco) para evitar colapso indesejado durante autofocus steal.
  bool _sidebarOpen = false;

  /// Escopo de foco do conteúdo — permite rastrear o último item focado e
  /// restaurá-lo quando a sidebar fecha.
  final FocusScopeNode _contentScopeNode = FocusScopeNode();
  FocusNode? _lastContentFocusNode;

  /// Debounce do botão Back (HardwareKeyboard + PopScope podem disparar).
  DateTime? _lastBackTime;

  bool _isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= Responsive.phoneMaxWidth;

  @override
  void initState() {
    super.initState();
    _contentScopeNode.addListener(_onContentFocusChange);
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _contentScopeNode.removeListener(_onContentFocusChange);
    _contentScopeNode.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Tracking do último foco no conteúdo
  // ───────────────────────────────────────────────────────────────────────

  void _onContentFocusChange() {
    if (_contentScopeNode.hasFocus) {
      final focused = _contentScopeNode.focusedChild;
      if (focused != null) {
        _lastContentFocusNode = focused;
      }
    }
  }

  /// Restaura o foco ao conteúdo: último nó focado (se ainda válido) →
  /// focusedChild do escopo → unfocus (d-pad foca no primeiro arrow).
  void _restoreContentFocus() {
    final last = _lastContentFocusNode;
    if (last != null && last.context != null) {
      last.requestFocus();
      return;
    }
    final focused = _contentScopeNode.focusedChild;
    if (focused != null && focused.context != null) {
      focused.requestFocus();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Controle da sidebar
  // ───────────────────────────────────────────────────────────────────────

  void _openSidebar() {
    if (_sidebarOpen) return;
    setState(() => _sidebarOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sidebarKey.currentState?.focusActiveItem();
    });
  }

  void _closeSidebar() {
    if (!_sidebarOpen) return;
    setState(() => _sidebarOpen = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restoreContentFocus();
    });
  }

  // ───────────────────────────────────────────────────────────────────────
  // Botão Back (ponto 4)
  // ───────────────────────────────────────────────────────────────────────

  bool _shellHasFocus() {
    final sidebar = _sidebarKey.currentState;
    return (sidebar?.hasFocus ?? false) || _contentScopeNode.hasFocus;
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.goBack) return false;
    // Só trata Back no layout largo (TV/desktop) e quando o shell está ativo
    // (não intercepta em telas de detalhe pushed fora do shell).
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return false;
    final view = views.first;
    final screenWidth = view.physicalSize.width / view.devicePixelRatio;
    if (screenWidth < Responsive.phoneMaxWidth) return false;
    if (!_shellHasFocus()) return false;
    _onBackButton();
    return true; // consome → suprime o system pop
  }

  void _onBackButton() {
    final now = DateTime.now();
    if (_lastBackTime != null &&
        now.difference(_lastBackTime!) < const Duration(milliseconds: 300)) {
      return; // debounce: HardwareKeyboard + PopScope podem disparar juntos
    }
    _lastBackTime = now;
    if (_sidebarOpen) {
      _closeSidebar();
    } else {
      _openSidebar();
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Detecção de edge esquerdo do conteúdo (ponto 1)
  // ───────────────────────────────────────────────────────────────────────

  /// True se [node] é o item selecionável mais à esquerda na sua linha
  /// (mesma banda vertical) dentro do conteúdo. Rect-based e síncrono —
  /// não depende de `requestFocus` (que é assíncrono).
  bool _isAtLeftEdge(FocusNode node) {
    if (node.context == null || node.rect == Rect.zero) return true;
    final scope = node.nearestScope;
    if (scope == null) return true;
    final sidebar = _sidebarKey.currentState;
    final descendants = scope.traversalDescendants.where((n) {
      if (!n.canRequestFocus || n.skipTraversal) return false;
      if (n.context == null || n.rect == Rect.zero) return false;
      if (sidebar?.containsNode(n) ?? false) return false; // exclui sidebar
      return true;
    }).toList();
    if (descendants.isEmpty) return true;
    // Mesma linha = sobreposição vertical (band) com o nó atual.
    final band = node.rect;
    final sameRow = descendants.where((n) {
      return !(n.rect.bottom < band.top || n.rect.top > band.bottom);
    }).toList();
    if (sameRow.isEmpty) return true;
    double minDx = sameRow.first.rect.center.dx;
    for (final n in sameRow) {
      if (n.rect.center.dx < minDx) minDx = n.rect.center.dx;
    }
    return node.rect.center.dx <= minDx + 0.5;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Build
  // ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final isWide = _isWideScreen(context);

    return PopScope(
      // Wide: nunca pop via sistema (HardwareKeyboard trata Back).
      // Mobile: comportamento legado (canPop na root).
      canPop: isWide ? false : location == '/',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isWide) _onBackButton();
      },
      child: isWide
          ? _buildWideLayout(context, location)
          : _buildMobileLayout(context, location),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Layout telas largas (TV / desktop / tablet)
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildWideLayout(BuildContext context, String location) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Actions(
        actions: <Type, Action<Intent>>{
          DirectionalFocusIntent: _SidebarEdgeAction(
            isInSidebar: (n) =>
                _sidebarKey.currentState?.containsNode(n) ?? false,
            isAtLeftEdge: _isAtLeftEdge,
            onLeftEdge: _openSidebar,
            onRightEdgeFromSidebar: _closeSidebar,
          ),
        },
        child: Row(
          children: [
            Sidebar(
              key: _sidebarKey,
              location: location,
              expanded: _sidebarOpen,
              onClose: _closeSidebar,
            ),
            Expanded(
              child: FocusScope(node: _contentScopeNode, child: widget.child),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Layout mobile
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildMobileLayout(BuildContext context, String location) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: _DrawerMenu(
        location: location,
        onItemSelected: () => Navigator.of(context).pop(),
      ),
      body: Stack(
        children: [
          widget.child,
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: SafeArea(
              bottom: false,
              child: _HamburgerButton(onTap: _openDrawer),
            ),
          ),
        ],
      ),
    );
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ação de borda: ← no edge do conteúdo abre sidebar; → na sidebar fecha
// ─────────────────────────────────────────────────────────────────────────────

/// Intercepta [DirectionalFocusIntent] (gerado por FocusableWidget ao
/// mapear setas):
///
/// * **←** na sidebar → no-op (sidebar já está no edge esquerdo).
/// * **←** no conteúdo no edge → [onLeftEdge] (abre sidebar).
/// * **←** no conteúdo no meio → move dentro do conteúdo (default).
/// * **→** na sidebar → [onRightEdgeFromSidebar] (fecha sidebar + restaura foco).
/// * **→** no conteúdo → move dentro do conteúdo (default).
/// * **↑↓** → default (move dentro da sidebar via `_SidebarTraversalPolicy`
///   ou dentro do conteúdo).
class _SidebarEdgeAction extends Action<DirectionalFocusIntent> {
  final bool Function(FocusNode) isInSidebar;
  final bool Function(FocusNode) isAtLeftEdge;
  final VoidCallback onLeftEdge;
  final VoidCallback onRightEdgeFromSidebar;

  _SidebarEdgeAction({
    required this.isInSidebar,
    required this.isAtLeftEdge,
    required this.onLeftEdge,
    required this.onRightEdgeFromSidebar,
  });

  @override
  void invoke(DirectionalFocusIntent intent) {
    final node = primaryFocus;
    if (intent.direction == TraversalDirection.left) {
      if (node != null && isInSidebar(node)) return; // sidebar: ← no-op
      if (node != null && isAtLeftEdge(node)) {
        onLeftEdge();
      } else {
        DirectionalFocusAction().invoke(intent); // move ← no conteúdo
      }
    } else if (intent.direction == TraversalDirection.right) {
      if (node != null && isInSidebar(node)) {
        onRightEdgeFromSidebar(); // fecha sidebar
      } else {
        DirectionalFocusAction().invoke(intent); // move → no conteúdo
      }
    } else {
      DirectionalFocusAction().invoke(intent); // ↑↓ default
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botão hamburger (mobile)
// ─────────────────────────────────────────────────────────────────────────────

class _HamburgerButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HamburgerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return KeyActivable(
      onActivate: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          canRequestFocus: true,
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(
              Icons.menu_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drawer menu (mobile)
// ─────────────────────────────────────────────────────────────────────────────

class _DrawerMenu extends StatelessWidget {
  final String location;
  final VoidCallback onItemSelected;

  const _DrawerMenu({required this.location, required this.onItemSelected});

  @override
  Widget build(BuildContext context) {
    final isAnimeSection = !location.contains('pauloflix-movies');

    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.play_circle_filled,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'GoAnime',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: ContentTypeSelector(
                  selected: isAnimeSection
                      ? ContentType.anime
                      : ContentType.movie,
                  onChanged: (type) {
                    context.go(
                      type == ContentType.movie ? '/pauloflix-movies' : '/',
                    );
                    onItemSelected();
                  },
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 8),
              _DrawerItem(
                icon: Icons.home,
                label: 'Início',
                selected: location == '/',
                onTap: () {
                  context.go('/');
                  onItemSelected();
                },
              ),
              _DrawerItem(
                icon: Icons.search,
                label: 'Buscar',
                selected:
                    location == '/search' ||
                    location == '/pauloflix-movies/search',
                onTap: () {
                  context.push(
                    isAnimeSection ? '/search' : '/pauloflix-movies/search',
                  );
                  onItemSelected();
                },
              ),
              _DrawerItem(
                icon: Icons.bookmark,
                label: 'Favoritos',
                selected: location == '/watchlist',
                onTap: () {
                  context.push('/watchlist');
                  onItemSelected();
                },
              ),
              _DrawerItem(
                icon: Icons.download_outlined,
                label: 'Downloads',
                selected: location == '/downloads',
                onTap: () {
                  context.push('/downloads');
                  onItemSelected();
                },
              ),
              _DrawerItem(
                icon: Icons.settings_outlined,
                label: 'Ajustes',
                selected: location == '/settings',
                onTap: () {
                  context.push('/settings');
                  onItemSelected();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KeyActivable(
      onActivate: onTap,
      child: ListTile(
        leading: Icon(
          icon,
          color: selected ? AppColors.primary : Colors.white70,
          size: 24,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
        selected: selected,
        selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: onTap,
      ),
    );
  }
}
