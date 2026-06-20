// ─────────────────────────────────────────────────────────────────────────────
// SeeAllCard — card fantasma no final do carousel, acessível pelo D-pad
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../themes/netflix_theme.dart';

/// Card "Ver Todos" que aparece como último item do carousel.
///
/// É o destino natural da navegação D-pad: o usuário chega nele simplesmente
/// continuando a pressionar →. Exibe um ícone de seta centralizado com
/// animação de foco igual aos outros cards.
class SeeAllCard extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final double width;
  final double height;
  final Color accentColor;
  final bool isTV;

  const SeeAllCard({
    super.key,
    required this.label,
    required this.onTap,
    required this.width,
    required this.height,
    this.accentColor = const Color(0xFF00BCD4),
    this.isTV = false,
  });

  @override
  State<SeeAllCard> createState() => _SeeAllCardState();
}

class _SeeAllCardState extends State<SeeAllCard>
    with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!mounted) return;
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  bool get _active => _isFocused || _isHovered;

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor;

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
              widget.onTap();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            setState(() => _isHovered = true);
          },
          onExit: (_) {
            setState(() => _isHovered = false);
          },
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: AnimatedContainer(
              duration: NetflixTheme.fastDuration,
              curve: NetflixTheme.fastCurve,
              decoration: BoxDecoration(
                color: _active
                    ? color.withValues(alpha: 0.12)
                    : NetflixTheme.surfaceLight,
                borderRadius: BorderRadius.circular(NetflixTheme.radiusMd),
                border: Border.all(
                  color: _active ? color : color.withValues(alpha: 0.25),
                  width: _active ? 2 : 1,
                ),
                boxShadow: _active
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(NetflixTheme.radiusMd),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  focusNode: _focusNode,
                  canRequestFocus: true,
                  onTap: widget.onTap,
                  onFocusChange: (hasFocus) {
                    if (!mounted) return;
                    setState(() => _isFocused = hasFocus);
                  },
                  borderRadius: BorderRadius.circular(NetflixTheme.radiusMd),
                  splashColor: color.withValues(alpha: 0.25),
                  highlightColor: color.withValues(alpha: 0.12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Ícone com círculo
                      AnimatedContainer(
                        duration: NetflixTheme.fastDuration,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _active
                              ? color.withValues(alpha: 0.2)
                              : color.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withValues(alpha: _active ? 0.9 : 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: color.withValues(alpha: _active ? 1.0 : 0.7),
                          size: widget.isTV ? 32 : 26,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _active ? color : NetflixTheme.textSecondary,
                          fontSize: widget.isTV ? 15 : 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
