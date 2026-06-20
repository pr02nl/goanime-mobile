/// Seletor horizontal de temporadas no estilo Netflix.
///
/// Exibe pills scrolláveis com o número e nome de cada temporada.
/// A temporada selecionada é destacada com a cor primária.
library;

import 'package:flutter/material.dart';

import '../../../domain/models/pauloflix_models.dart';
import '../../core/themes/app_colors.dart';
import '../../core/widgets/focusable_widget.dart';

/// Seletor horizontal de temporadas estilo Netflix.
///
/// [Uso]:
/// ```dart
/// PauloflixSeasonSelector(
///   seasons: seasons,
///   selectedIndex: _selectedSeasonIndex,
///   onSeasonSelected: (index) => setState(() => _selectedSeasonIndex = index),
/// )
/// ```
class PauloflixSeasonSelector extends StatelessWidget {
  final List<PauloFlixSeason> seasons;
  final int selectedIndex;
  final ValueChanged<int> onSeasonSelected;
  final int? episodeCounts;

  const PauloflixSeasonSelector({
    super.key,
    required this.seasons,
    required this.selectedIndex,
    required this.onSeasonSelected,
    this.episodeCounts,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: seasons.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final season = seasons[index];
          final isSelected = index == selectedIndex;

          return FocusableWidget(
            onSelect: () => onSeasonSelected(index),
            borderRadius: 20,
            focusPadding: EdgeInsets.zero,
            focusScale: 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'S${season.number.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (season.name.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      _extractSeasonName(season.name),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Extrai o nome descritivo da temporada, removendo o prefixo "S01 - "
  String _extractSeasonName(String fullName) {
    // Remove "S01 - ", "Season 01 - ", etc.
    final cleaned = fullName
        .replaceAll(RegExp(r'^S\d+\s*-\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^Season\s+\d+\s*-\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^Temporada\s+\d+\s*-\s*', caseSensitive: false), '')
        .trim();

    // Se sobrou algo, retorna (truncado se muito longo)
    if (cleaned.isEmpty) return '';
    if (cleaned.length > 20) return '${cleaned.substring(0, 20)}...';
    return cleaned;
  }
}
