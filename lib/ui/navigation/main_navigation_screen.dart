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
    // NÃO usamos `_contentScopeNode.focusedChild` aqui: durante reparenting
    // de rota filha sob ModalRoute por cima, o getter dispara a assertion
    // `_focusedChildren.last.enclosingScope == this` (anti-pattern #19 do
    // skill `flutter-reactivity-gotchas`). Em vez disso, lemos o
    // `primaryFocus` global e validamos manualmente se ele pertence a este
    // scope — caminho público, sem assertion interna.
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return;
    if (!_isInContentScope(primary)) return;
    if (primary.context == null) return;
    _lastContentFocusNode = primary;
  }

  /// True se [node] é um descendente direto do `_contentScopeNode`
  /// (não da sidebar). `nearestScope` é a API pública que sobe a árvore
  /// até o `FocusScope` mais próximo — sem tocar em `focusedChild`.
  bool _isInContentScope(FocusNode node) {
    return node.nearestScope == _contentScopeNode;
  }

  /// Restaura o foco ao conteúdo:
  /// 1. Último nó focado (se ainda válido E for um widget focável real,
  ///    não um `FocusScopeNode`).
  /// 2. Caso contrário, primeiro descendente focável do `_contentScopeNode`.
  /// 3. Caso contrário, `unfocus()` (último recurso).
  ///
  /// Por que não aceitar scope: focar um `FocusScopeNode` não move o
  /// foco visualmente — só marca o scope como "primário". O usuário
  /// ficaria sem anel de foco visível após fechar a sidebar.
  ///
  /// Mesma defesa do `_onContentFocusChange`: nunca chama
  /// `_contentScopeNode.focusedChild` (getter com assertion).
  void _restoreContentFocus() {
    final last = _lastContentFocusNode;
    if (last != null && last.context != null && last.canRequestFocus) {
      last.requestFocus();
      return;
    }
    // Fallback: primeiro descendente focável do scope de conteúdo.
    final fallback = _contentScopeNode.traversalDescendants
        .where((n) => n.canRequestFocus && !n.skipTraversal && n.context != null)
        .firstOrNull;
    if (fallback != null) {
      fallback.requestFocus();
      return;
    }
    // Último recurso.
    FocusManager.instance.primaryFocus?.unfocus();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Controle da sidebar
  // ───────────────────────────────────────────────────────────────────────

  void _openSidebar() {
    if (_sidebarOpen) return;
    // Captura o foco atual ANTES de qualquer mudança — vai ser o
    // alvo do `_restoreContentFocus` quando a sidebar fechar
    // (via → ou Back). Garante que sempre há um último foco válido,
    // mesmo na primeira vez (quando `_lastContentFocusNode` ainda
    // é null ou o usuário nunca focou explicitamente no conteúdo).
    //
    // IMPORTANTE: o `primaryFocus` pode ser um `FocusScopeNode` (root
    // da rota) quando o usuário não chegou a focar explicitamente em
    // um widget. Focar um scope não move o foco visualmente — só
    // garante que o scope é o "primário". Para evitar isso, só
    // capturamos se for um widget focável real (`canRequestFocus`).
    final currentFocus = FocusManager.instance.primaryFocus;
    debugPrint('[SIDEBAR] _openSidebar — primaryFocus antes: '
        'hasPrimary=${currentFocus?.hasPrimaryFocus} '
        'inContent=${currentFocus != null ? _isInContentScope(currentFocus) : "N/A"} '
        'canRequest=${currentFocus?.canRequestFocus}');
    if (currentFocus != null &&
        _isInContentScope(currentFocus) &&
        currentFocus.canRequestFocus) {
      _lastContentFocusNode = currentFocus;
      debugPrint('[SIDEBAR] _openSidebar — _lastContentFocusNode set to: '
          '${currentFocus.toString().substring(0, 60)}...');
    }
    setState(() => _sidebarOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[SIDEBAR] _openSidebar — post-frame focusActiveItem');
      _sidebarKey.currentState?.focusActiveItem();
    });
  }

  void _closeSidebar() {
    debugPrint('[SIDEBAR] _closeSidebar — wasOpen=$_sidebarOpen, '
        'primaryFocus=${FocusManager.instance.primaryFocus?.toString().substring(0, 60)}');
    if (!_sidebarOpen) return;
    setState(() => _sidebarOpen = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint('[SIDEBAR] _closeSidebar — post-frame _restoreContentFocus. '
            'last=${_lastContentFocusNode?.toString().substring(0, 60)}, '
            'contextNull=${_lastContentFocusNode?.context == null}');
        _restoreContentFocus();
      }
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
    debugPrint('[SIDEBAR] _isAtLeftEdge — '
        'contextNull=${node.context == null}, '
        'rect=${node.rect}, '
        'rectIsZero=${node.rect == Rect.zero}, '
        'nearestScope=${node.nearestScope != null}, '
        'primaryFocus=$node');
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
    debugPrint('[SIDEBAR] _isAtLeftEdge — descendants count: ${descendants.length}');
    if (descendants.isEmpty) return true;
    // Mesma linha = sobreposição vertical (band) com o nó atual.
    final band = node.rect;
    final sameRow = descendants.where((n) {
      return !(n.rect.bottom < band.top || n.rect.top > band.bottom);
    }).toList();
    debugPrint('[SIDEBAR] _isAtLeftEdge — sameRow count: ${sameRow.length}');
    if (sameRow.isEmpty) return true;
    double minDx = sameRow.first.rect.center.dx;
    for (final n in sameRow) {
      if (n.rect.center.dx < minDx) minDx = n.rect.center.dx;
    }
    final result = node.rect.center.dx <= minDx + 0.5;
    debugPrint('[SIDEBAR] _isAtLeftEdge — result: $result '
        '(node.dx=${node.rect.center.dx}, minDx=$minDx)');
    return result;
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
    debugPrint('[SIDEBAR] _SidebarEdgeAction.invoke — '
        'direction=${intent.direction}, '
        'primaryFocus=$node, '
        'inSidebar=${node != null ? isInSidebar(node) : "N/A"}');
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
                    context.goNamed(
                      type == ContentType.movie
                          ? 'pauloflix-movies'
                          : 'home',
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
                  context.goNamed('home');
                  onItemSelected();
                },
              ),
              _DrawerItem(
                icon: Icons.search,
                label: 'Buscar',
                selected:
                    location == '/search' ||
                    location == '/pauloflix-search' ||
                    location == '/pauloflix-movies/search',
                onTap: () {
                  // Comportamento contextual — mesmo padrão do sidebar.
                  if (location.contains('pauloflix-movies')) {
                    context.goNamed('pauloflix-movies-search');
                  } else if (location == '/pauloflix-see-all' ||
                      location == '/pauloflix-search') {
                    context.goNamed('pauloflix-search');
                  } else {
                    context.goNamed('search');
                  }
                  onItemSelected();
                },
              ),
              _DrawerItem(
                icon: Icons.bookmark,
                label: 'Favoritos',
                selected: location == '/watchlist',
                onTap: () {
                  context.pushNamed('watchlist');
                  onItemSelected();
                },
              ),
              _DrawerItem(
                icon: Icons.download_outlined,
                label: 'Downloads',
                selected: location == '/downloads',
                onTap: () {
                  context.pushNamed('downloads');
                  onItemSelected();
                },
              ),
              _DrawerItem(
                icon: Icons.settings_outlined,
                label: 'Ajustes',
                selected: location == '/settings',
                onTap: () {
                  context.pushNamed('settings');
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
