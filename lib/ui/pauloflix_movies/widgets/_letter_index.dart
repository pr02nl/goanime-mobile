import 'package:flutter/material.dart';

import '../../core/utils/responsive.dart';
import '../../core/widgets/focusable_widget.dart';

/// Barra de índice A–Z (com "#") para "pular para letra" no grid paginado.
///
/// Comportamento:
/// * **Mobile** (`< phoneMaxWidth`): coluna vertical fixa no lado direito
///   da tela, opaca, scrollável. Toque em uma letra → `onLetterSelected`.
/// * **Tablet/TV/desktop** (`>= phoneMaxWidth`): linha horizontal abaixo do
///   cabeçalho "Todos os Filmes". Setas ↑↓/←→ navegam entre letras,
///   Enter/Select ativa.
///
/// Apenas letras em [availableLetters] são clicáveis/ativas — outras
/// letras aparecem com opacidade reduzida.
class LetterIndex extends StatelessWidget {
  /// Letras que devem aparecer na barra (ex: `['A', 'B', 'C', '#']`).
  final List<String> availableLetters;

  /// Letra atualmente selecionada (será destacada em vermelho PauloFlix).
  final String? activeLetter;

  /// Callback quando o usuário toca ou ativa uma letra.
  final ValueChanged<String> onLetterSelected;

  const LetterIndex({
    super.key,
    required this.availableLetters,
    required this.activeLetter,
    required this.onLetterSelected,
  });

  static const List<String> _allLetters = [
    '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= Responsive.phoneMaxWidth;
    return isWide ? _buildHorizontal(context) : _buildVertical(context);
  }

  Widget _buildHorizontal(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final l in _allLetters)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _buildLetterChip(context, l, axis: Axis.horizontal),
            ),
        ],
      ),
    );
  }

  Widget _buildVertical(BuildContext context) {
    return Container(
      width: 28,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final l in _allLetters)
              _buildLetterChip(context, l, axis: Axis.vertical),
          ],
        ),
      ),
    );
  }

  Widget _buildLetterChip(
    BuildContext context,
    String letter, {
    required Axis axis,
  }) {
    final enabled = availableLetters.contains(letter);
    final isActive = activeLetter == letter;

    final color = !enabled
        ? Colors.white24
        : isActive
            ? const Color(0xFFDC2626)
            : Colors.white;

    final child = Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );

    if (!enabled) {
      return child;
    }

    return FocusableWidget(
      onSelect: () => onLetterSelected(letter),
      borderRadius: 12,
      focusPadding: EdgeInsets.zero,
      focusScale: 1.1,
      child: GestureDetector(
        onTap: () => onLetterSelected(letter),
        child: child,
      ),
    );
  }
}
