library;

/// Carrossel paginado em ordem alfabética com navegação por setas.
///
/// Substitui o `PaginatedLetterGrid` (índice A–Z) nas telas de "Todos
/// os Animes" e "Todos os Filmes". A seleção por letra do grid não
/// funcionava bem com pouca mídia disponível.
///
/// Layout:
/// * Título + contagem total + setas ◀ ▶ (no `trailing` do
///   [NetflixCarousel]).
/// * Corpo: [NetflixCarousel] com os cards da página atual (10 itens
///   por página). Herda o `_ClampedTraversalPolicy` que prende o foco
///   em navegação horizontal ← →.
/// * Indicador "Pág. X de Y" abaixo do carrossel.
///
/// Uso:
/// ```dart
/// final sorted = [...contents]..sort(...);
/// PaginatedAlphabeticalCarousel<PauloFlixContent>(
///   title: 'Todos os Animes (42)',
///   items: sorted,
///   isTV: false,
///   accentColor: AppColors.animeAccent,
///   cardBuilder: (ctx, item) => NetflixCard(...),
/// );
/// ```

import 'package:flutter/material.dart';

import '../themes/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/focusable_widget.dart';
import '../widgets/netflix_carousel.dart';

class PaginatedAlphabeticalCarousel<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final Widget Function(BuildContext, T) cardBuilder;
  final bool isTV;
  final Color accentColor;
  final int pageSize;

  const PaginatedAlphabeticalCarousel({
    super.key,
    required this.title,
    required this.items,
    required this.cardBuilder,
    this.isTV = false,
    this.accentColor = AppColors.moviesAccent,
    this.pageSize = 10,
  });

  @override
  State<PaginatedAlphabeticalCarousel<T>> createState() =>
      _PaginatedAlphabeticalCarouselState<T>();
}

class _PaginatedAlphabeticalCarouselState<T>
    extends State<PaginatedAlphabeticalCarousel<T>> {
  int _currentPage = 0;

  int get _totalPages =>
      widget.items.isEmpty ? 1 : (widget.items.length / widget.pageSize).ceil();

  List<T> get _currentPageItems {
    final start = _currentPage * widget.pageSize;
    final end = (start + widget.pageSize).clamp(0, widget.items.length);
    if (start >= widget.items.length) return [];
    return widget.items.sublist(start, end);
  }

  bool get _hasPrev => _currentPage > 0;
  bool get _hasNext => _currentPage < _totalPages - 1;

  void _prevPage() {
    if (!_hasPrev) return;
    setState(() => _currentPage--);
  }

  void _nextPage() {
    if (!_hasNext) return;
    setState(() => _currentPage++);
  }

  @override
  void didUpdateWidget(
      covariant PaginatedAlphabeticalCarousel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      final maxPage = _totalPages - 1;
      if (_currentPage > maxPage) {
        _currentPage = maxPage;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final cardWidth = Responsive.getHorizontalListItemWidth(context);

    final items = _currentPageItems.map((item) {
      return SizedBox(
        width: cardWidth,
        child: widget.cardBuilder(context, item),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        NetflixCarousel(
          title: widget.title,
          isTV: widget.isTV,
          items: items,
          trailing: _PageArrows(
            hasPrev: _hasPrev,
            hasNext: _hasNext,
            accentColor: widget.accentColor,
            onPrev: _prevPage,
            onNext: _nextPage,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.accentColor.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              'Pág. ${_currentPage + 1} de $_totalPages',
              style: TextStyle(
                color: widget.accentColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Setas ◀ ▶ para navegação entre páginas.
class _PageArrows extends StatelessWidget {
  final bool hasPrev;
  final bool hasNext;
  final Color accentColor;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _PageArrows({
    required this.hasPrev,
    required this.hasNext,
    required this.accentColor,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FocusableWidget(
          onSelect: hasPrev ? onPrev : null,
          borderRadius: 20,
          focusPadding: EdgeInsets.zero,
          child: AnimatedOpacity(
            opacity: hasPrev ? 1.0 : 0.3,
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              icon: const Icon(Icons.chevron_left),
              color: hasPrev ? accentColor : Colors.white38,
              tooltip: 'Página anterior',
              onPressed: hasPrev ? onPrev : null,
            ),
          ),
        ),
        const SizedBox(width: 4),
        FocusableWidget(
          onSelect: hasNext ? onNext : null,
          borderRadius: 20,
          focusPadding: EdgeInsets.zero,
          child: AnimatedOpacity(
            opacity: hasNext ? 1.0 : 0.3,
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              icon: const Icon(Icons.chevron_right),
              color: hasNext ? accentColor : Colors.white38,
              tooltip: 'Próxima página',
              onPressed: hasNext ? onNext : null,
            ),
          ),
        ),
      ],
    );
  }
}
