import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/themes/app_colors.dart';
import '../core/utils/responsive.dart';
import '../core/widgets/content_type_selector.dart';

/// Ponto central de navegação do app.
///
/// Em telas largas (tablet, TV, desktop) exibe uma [Sidebar] à esquerda que
/// inicia colapsada (apenas ícones) e **expande** ao pressionar ← a partir
/// do conteúdo (comportamento similar ao YouTube na TV).
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
  bool _sidebarExpanded = false;

  bool _isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= Responsive.phoneMaxWidth;

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _expandSidebar() {
    if (!_sidebarExpanded) {
      setState(() => _sidebarExpanded = true);
    }
  }

  void _collapseSidebar() {
    if (_sidebarExpanded) {
      setState(() => _sidebarExpanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final isWide = _isWideScreen(context);

    return PopScope(
      canPop: location == '/',
      child: Actions(
        actions: <Type, Action<Intent>>{
          DirectionalFocusIntent: _SidebarEdgeAction(
            onLeftEdge: isWide ? _expandSidebar : null,
          ),
        },
        child: isWide
            ? _buildWideLayout(context, location)
            : _buildMobileLayout(context, location),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Layout telas largas (TV / desktop / tablet)
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildWideLayout(BuildContext context, String location) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _DrawerMenu(
        location: location,
        onItemSelected: () => Navigator.of(context).pop(),
      ),
      body: Row(
        children: [
          Sidebar(
            location: location,
            expanded: _sidebarExpanded,
            // expanded: false,
            onClose: _collapseSidebar,
          ),
          Expanded(child: widget.child),
        ],
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Ação de borda: expande sidebar ao ← ou foca conteúdo ao →
// ─────────────────────────────────────────────────────────────────────────────

/// Intercepta [DirectionalFocusIntent]:
///
/// * **←** sem movimento de foco → chama [onLeftEdge] (expande sidebar).
/// * Demais direções → delega ao [DirectionalFocusAction].
class _SidebarEdgeAction extends Action<DirectionalFocusIntent> {
  final VoidCallback? onLeftEdge;

  _SidebarEdgeAction({this.onLeftEdge});

  @override
  void invoke(DirectionalFocusIntent intent) {
    if (intent.direction == TraversalDirection.left) {
      final FocusNode? before = primaryFocus;
      DirectionalFocusAction().invoke(intent);
      if (primaryFocus == before && onLeftEdge != null) {
        onLeftEdge!();
      }
    } else {
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
    return _KeyActivable(
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
// _KeyActivable — ativação por teclado/TV sem nó de foco extra
// ─────────────────────────────────────────────────────────────────────────────

class _KeyActivable extends StatelessWidget {
  final Widget child;
  final VoidCallback onActivate;

  const _KeyActivable({required this.child, required this.onActivate});

  @override
  Widget build(BuildContext context) {
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
              onActivate();
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar expansível (TV / desktop)
// ─────────────────────────────────────────────────────────────────────────────

/// Sidebar persistente que alterna entre colapsada (só ícones, 72px) e
/// expandida (ícones + texto, ~220px), similar ao YouTube na TV.
///
/// Quando o foco sai da sidebar (navegação →), [onClose] colapsa.
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
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  @override
  Widget build(BuildContext context) {
    final isAnimeSection = !widget.location.contains('pauloflix-movies');
    const collapsedW = 72.0;
    const expandedW = 220.0;

    return Focus(
      onFocusChange: (hasFocus) {
        // Colapsa a sidebar quando o foco sai dela
        if (!hasFocus && widget.expanded) {
          widget.onClose();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: widget.expanded ? expandedW : collapsedW,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.6),
          border: const Border(right: BorderSide(color: Colors.white12)),
        ),
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              const SizedBox(height: 20),
              // ── Logo ─────────────────────────────────────────────
              Container(
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
                ),
              ),
              const SizedBox(height: 16),
              // ── Seletor Animes | Filmes ──────────────────────────────
              _SidebarToggle(
                expanded: widget.expanded,
                isAnime: isAnimeSection,
                onChanged: (animeMode) {
                  context.go(animeMode ? '/' : '/pauloflix-movies');
                },
              ),
              const SizedBox(height: 8),
              const _SidebarDivider(expanded: false),
              const SizedBox(height: 8),
              // ── Home ─────────────────────────────────────────────────
              _SidebarItem(
                expanded: widget.expanded,
                icon: Icons.home,
                label: 'Início',
                selected: widget.location == '/',
                onTap: () {
                  context.go('/');
                  widget.onClose();
                },
              ),
              const SizedBox(height: 4),
              // ── Buscar ───────────────────────────────────────────────
              _SidebarItem(
                expanded: widget.expanded,
                icon: Icons.search,
                label: 'Buscar',
                selected:
                    widget.location == '/search' ||
                    widget.location == '/pauloflix-movies/search',
                onTap: () {
                  context.push(
                    isAnimeSection ? '/search' : '/pauloflix-movies/search',
                  );
                  widget.onClose();
                },
              ),
              const SizedBox(height: 4),
              // ── Favoritos ────────────────────────────────────────────
              _SidebarItem(
                expanded: widget.expanded,
                icon: Icons.bookmark,
                label: 'Favoritos',
                selected: widget.location == '/watchlist',
                onTap: () {
                  context.push('/watchlist');
                  widget.onClose();
                },
              ),
              const SizedBox(height: 4),
              // ── Downloads ────────────────────────────────────────────
              _SidebarItem(
                expanded: widget.expanded,
                icon: Icons.download_outlined,
                label: 'Downloads',
                selected: widget.location == '/downloads',
                onTap: () {
                  context.push('/downloads');
                  widget.onClose();
                },
              ),
              const SizedBox(height: 4),
              // ── Ajustes ──────────────────────────────────────────────
              _SidebarItem(
                expanded: widget.expanded,
                icon: Icons.settings_outlined,
                label: 'Ajustes',
                selected: widget.location == '/settings',
                onTap: () {
                  context.push('/settings');
                  widget.onClose();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Item da sidebar — mostra só ícone no estado colapsado,
/// ícone + rótulo no estado expandido.
class _SidebarItem extends StatelessWidget {
  final bool expanded;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.expanded,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _KeyActivable(
      onActivate: onTap,
      child: Tooltip(
        message: expanded ? '' : label,
        child: SizedBox(
          height: 48,
          child: InkWell(
            canRequestFocus: true,
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.only(
                left: expanded ? 16 : (72 - 24) / 2, // centraliza ícone
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }
}

/// Toggle Animes / Filmes na sidebar.
class _SidebarToggle extends StatelessWidget {
  final bool expanded;
  final bool isAnime;
  final ValueChanged<bool> onChanged;

  const _SidebarToggle({
    required this.expanded,
    required this.isAnime,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToggleIcon(
          expanded: expanded,
          icon: Icons.tv,
          label: 'Animes',
          active: isAnime,
          accent: AppColors.primary,
          onTap: () => onChanged(true),
        ),
        const SizedBox(height: 4),
        _ToggleIcon(
          expanded: expanded,
          icon: Icons.movie_outlined,
          label: 'Filmes',
          active: !isAnime,
          accent: const Color(0xFFDC2626),
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  final bool expanded;
  final IconData icon;
  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  const _ToggleIcon({
    required this.expanded,
    required this.icon,
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _KeyActivable(
      onActivate: onTap,
      child: SizedBox(
        height: 40,
        child: InkWell(
          canRequestFocus: true,
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.only(left: expanded ? 16 : (72 - 24) / 2),
            decoration: BoxDecoration(
              color: active
                  ? accent.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: active ? accent : Colors.white54),
                if (expanded) ...[
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? accent : Colors.white54,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
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

class _SidebarDivider extends StatelessWidget {
  final bool expanded;
  const _SidebarDivider({required this.expanded});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: expanded ? 16 : 20),
      height: 1,
      color: Colors.white12,
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
    return _KeyActivable(
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
