import 'package:flutter/material.dart';

import '../ui/core/themes/app_colors.dart';
import 'focusable_widget.dart';

/// Toggle de segmentação entre Animes e Filmes para o AppBar.
class ContentTypeSelector extends StatelessWidget {
  final ContentType selected;
  final ValueChanged<ContentType> onChanged;

  const ContentTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Chip(
            label: 'Animes',
            icon: Icons.tv,
            active: selected == ContentType.anime,
            accent: AppColors.primary,
            onTap: () => onChanged(ContentType.anime),
          ),
          _Chip(
            label: 'Filmes',
            icon: Icons.movie_outlined,
            active: selected == ContentType.movie,
            accent: const Color(0xFFDC2626),
            onTap: () => onChanged(ContentType.movie),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // FocusableWidget adiciona:
    //  - FocusNode + onKeyEvent (Select/Enter/Space disparam onTap)
    //  - Anel de foco visível em TV
    //  - Em mobile/tablet cai para GestureDetector puro (sem custo visual)
    return FocusableWidget(
      onSelect: onTap,
      borderRadius: 16,
      focusPadding: EdgeInsets.zero,
      focusScale: 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : Colors.white60),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white60,
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ContentType { anime, movie }
