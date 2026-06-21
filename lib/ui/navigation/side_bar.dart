// ─────────────────────────────────────────────────────────────────────────────
// Sidebar expansível (TV / desktop)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/themes/app_colors.dart';
import '../core/widgets/focusable_widget.dart';

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

    return AnimatedContainer(
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
              child: const Icon(Icons.play_circle_filled, color: Colors.white),
            ),
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
            _SidebarItem(
              expanded: widget.expanded,
              icon: Icons.tv,
              label: 'Animes',
              selected: widget.location == '/pauloflix-see-all',
              onTap: () {
                context.go('/pauloflix-see-all');
                widget.onClose();
              },
            ),
            const SizedBox(height: 4),
            _SidebarItem(
              expanded: widget.expanded,
              icon: Icons.movie_outlined,
              label: 'Filmes',
              selected: widget.location == '/pauloflix-movies',
              onTap: () {
                context.go('/pauloflix-movies');
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
    return FocusableWidget(
      child: Tooltip(
        message: expanded ? '' : label,
        child: SizedBox(
          height: 48,
          child: Container(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.only(
              left: expanded ? 16 : (72 - 24) / 2, // centraliza ícone
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
