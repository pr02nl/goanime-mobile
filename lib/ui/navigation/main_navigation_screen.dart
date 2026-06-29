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

  /// Escopo de foco do conteúdo — permite restaurar o foco quando a
  /// sidebar fecha.
  final FocusScopeNode _contentScopeNode = FocusScopeNode();

  /// Flag que indica que o diálogo de saída está aberto — evita re-entrada
  /// no HardwareKeyboard handler enquanto o diálogo está visível.
  bool _isDialogShowing = false;

  /// Debounce do botão Back: HardwareKeyboard e PopScope podem disparar
  /// para o mesmo evento (conhecido em alguns firmwares Android TV).
  DateTime? _lastBackTime;

  bool _isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= Responsive.phoneMaxWidth;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _contentScopeNode.dispose();
    super.dispose();
  }

  /// True se [node] é um descendente direto do `_contentScopeNode`
  /// (não da sidebar). `nearestScope` é a API pública que sobe a árvore
  /// até o `FocusScope` mais próximo — sem tocar em `focusedChild`.
  bool _isInContentScope(FocusNode node) {
    return node.nearestScope == _contentScopeNode;
  }

  /// Restaura o foco ao conteúdo após fechar a sidebar.
  ///
  /// Encontra o primeiro descendente focável do `_contentScopeNode` e
  /// requisita foco. Não usa `_contentScopeNode.focusedChild` (dispara
  /// assertion durante reparenting de rota filha).
  void _restoreContentFocus() {
    final target = _contentScopeNode.traversalDescendants
        .where(
          (n) => n.canRequestFocus && !n.skipTraversal && n.context != null,
        )
        .firstOrNull;
    target?.requestFocus();
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
    debugPrint(
      '[SIDEBAR] _openSidebar — primaryFocus antes: '
      'hasPrimary=${currentFocus?.hasPrimaryFocus} '
      'inContent=${currentFocus != null ? _isInContentScope(currentFocus) : "N/A"} '
      'canRequest=${currentFocus?.canRequestFocus}',
    );
    if (currentFocus != null &&
        _isInContentScope(currentFocus) &&
        currentFocus.canRequestFocus) {
      debugPrint(
        '[SIDEBAR] _openSidebar — current content focus: '
        '${currentFocus.toString().substring(0, 60)}...',
      );
    }
    setState(() => _sidebarOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[SIDEBAR] _openSidebar — post-frame focusActiveItem');
      _sidebarKey.currentState?.focusActiveItem();
    });
  }

  void _closeSidebar() {
    debugPrint(
      '[SIDEBAR] _closeSidebar — wasOpen=$_sidebarOpen, '
      'primaryFocus=${FocusManager.instance.primaryFocus?.toString().substring(0, 60)}',
    );
    if (!_sidebarOpen) return;
    setState(() => _sidebarOpen = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint('[SIDEBAR] _closeSidebar — post-frame _restoreContentFocus.');
        _restoreContentFocus();
      }
    });
  }

  // ───────────────────────────────────────────────────────────────────────
  // Botão Back (ponto 4)
  // ───────────────────────────────────────────────────────────────────────

  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.goBack) return false;
    if (!mounted) return false;

    // Só trata Back no layout largo (TV/desktop).
    if (!_isWideScreen(context)) return false;

    // Se um diálogo está aberto em cima do shell, não consome o evento —
    // deixa o próprio diálogo ou o sistema lidar com o Back.
    if (_isDialogShowing) return false;

    // Se há rotas empilhadas (ex.: player, configurações pushed),
    // não consome — deixa o sistema popar a rota do topo.
    final router = GoRouter.of(context);
    if (router.canPop()) return false;

    _onBackButton();
    return true; // consome → suprime o system pop
  }

  void _onBackButton() {
    // Debounce: HardwareKeyboard + PopScope podem disparar juntos no mesmo
    // frame em alguns firmwares Android TV, causando double-fire.
    final now = DateTime.now();
    if (_lastBackTime != null &&
        now.difference(_lastBackTime!) < const Duration(milliseconds: 300)) {
      return;
    }
    _lastBackTime = now;
    if (_sidebarOpen) {
      _showExitDialog();
    } else {
      _openSidebar();
    }
  }

  Future<void> _showExitDialog() async {
    // Marca que o diálogo está aberto para o HardwareKeyboard handler não
    // tentar processar Back enquanto o diálogo estiver visível.
    _isDialogShowing = true;

    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Não', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Sim',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    // Nota: o diálogo com barrierDismissible:false só fecha via botões
    // (Sim/Não) ou sistema Back. Quando o usuário pressiona Back no
    // controle remoto, o sistema fecha o diálogo e shouldExit é null.
    // Neste caso mantemos a sidebar aberta.
    if (!mounted) return;

    _isDialogShowing = false;

    if (shouldExit == true) {
      SystemNavigator.pop();
    } else if (shouldExit == false) {
      // Usuário clicou "Não" → fecha a sidebar para continuar navegando.
      _closeSidebar();
    }
    // Se shouldExit é null (diálogo foi fechado via Back do sistema),
    // apenas mantém a sidebar aberta — o usuário ainda está nela.
  }

  // ───────────────────────────────────────────────────────────────────────
  // Detecção de edge esquerdo do conteúdo (ponto 1)
  // ───────────────────────────────────────────────────────────────────────

  /// True se [node] é o item selecionável mais à esquerda na sua linha
  /// (mesma banda vertical) dentro do conteúdo. Rect-based e síncrono —
  /// não depende de `requestFocus` (que é assíncrono).
  ///
  /// Para evitar falsos positivos com múltiplos carrosséis na mesma
  /// faixa vertical, filtra os descendentes pelo mesmo [Scrollable]
  /// horizontal do nó atual (se aplicável).
  bool _isAtLeftEdge(FocusNode node) {
    if (node.context == null || node.rect == Rect.zero) return true;
    final scope = node.nearestScope;
    if (scope == null) return true;
    final sidebar = _sidebarKey.currentState;

    // Descobre o Scrollable horizontal do nó atual (se estiver num carrossel).
    final ScrollableState? currentScrollable =
        node.context != null
            ? Scrollable.maybeOf(node.context!, axis: Axis.horizontal)
            : null;

    final descendants = scope.traversalDescendants.where((n) {
      if (!n.canRequestFocus || n.skipTraversal) return false;
      if (n.context == null || n.rect == Rect.zero) return false;
      if (sidebar?.containsNode(n) ?? false) return false; // exclui sidebar
      // Se o nó atual está num Scrollable horizontal, filtra apenas
      // nós do MESMO carrossel (mesmo Scrollable). Isso evita que
      // itens de carrosséis diferentes na mesma banda Y interfiram.
      if (currentScrollable != null) {
        return Scrollable.maybeOf(n.context!, axis: Axis.horizontal) ==
            currentScrollable;
      }
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
        // Fallback para dispositivos onde o HardwareKeyboard não captura
        // o Back (alguns firmwares Android TV). Só processa se o
        // HardwareKeyboard NÃO consumiu o evento — verificado pelas
        // mesmas guards: sem diálogo aberto, sem rotas empilhadas.
        if (didPop || !isWide) return;
        if (_isDialogShowing) return;
        final router = GoRouter.of(context);
        if (router.canPop()) return;
        _onBackButton();
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
// ─────────────────────────────────────────────────────────────────────────────  /// Intercepta [DirectionalFocusIntent] (gerado por FocusableWidget ao
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
        // move ← no conteúdo via traversal padrão
        DirectionalFocusAction().invoke(intent);
      }
    } else if (intent.direction == TraversalDirection.right) {
      if (node != null && isInSidebar(node)) {
        onRightEdgeFromSidebar(); // fecha sidebar
      } else {
        // move → no conteúdo via traversal padrão
        DirectionalFocusAction().invoke(intent);
      }
    } else {
      // ↑↓ default — deixa o traversal padrão gerenciar
      // (sidebar usa _SidebarTraversalPolicy, conteúdo usa o padrão)
      DirectionalFocusAction().invoke(intent);
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
                      type == ContentType.movie ? 'pauloflix-movies' : 'home',
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
