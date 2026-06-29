library;

/// Carrossel paginado em ordem alfabética com navegação por setas.
///
/// Substitui o `PaginatedLetterGrid` (índice A–Z) nas telas de "Todos
/// os Animes" e "Todos os Filmes". A seleção por letra do grid não
/// funcionava bem com pouca mídia disponível.
///
/// Layout:
/// * Título + contagem total no cabeçalho do [NetflixCarousel].
/// * Corpo: [NetflixCarousel] com os cards da página atual (10 itens
///   por página), mais cards de navegação "Anterior" e "Próximo" nas
///   pontas. Herda o `_ClampedTraversalPolicy` que prende o foco em
///   navegação horizontal ← →.
/// * Cards de navegação: saturados no centro da página, ao chegar na
///   ponta o usuário vê o card "Próximo →" ou "← Anterior" e
///   Enter/Select troca de página.
/// * Indicador "Pág. X de Y" abaixo do carrossel (não-focusável).
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

  bool get _hasPrev => _currentPage > 0;
  bool get _hasNext => _currentPage < _totalPages - 1;

  List<T> _currentPageItems() {
    final start = _currentPage * widget.pageSize;
    final end = (start + widget.pageSize).clamp(0, widget.items.length);
    if (start >= widget.items.length) return [];
    return widget.items.sublist(start, end);
  }

  void _prevPage() {
    if (!_hasPrev) return;
    setState(() => _currentPage--);
  }

  void _nextPage() {
    if (!_hasNext) return;
    setState(() => _currentPage++);
  }

  @override
  void didUpdateWidget(covariant PaginatedAlphabeticalCarousel<T> oldWidget) {
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

    // Constrói os cards dos itens da página atual
    final carouselItems = <Widget>[
      ..._currentPageItems().map((item) {
        return SizedBox(
          width: cardWidth,
          child: widget.cardBuilder(context, item),
        );
      }),
    ];

    // Insere card "Anterior" no início se houver página anterior
    if (_hasPrev) {
      carouselItems.insert(
        0,
        SizedBox(
          width: cardWidth,
          child: _NavCard(
            icon: Icons.chevron_left,
            label: 'Anterior',
            accentColor: widget.accentColor,
            isTV: widget.isTV,
            onTap: _prevPage,
          ),
        ),
      );
    }

    // Insere card "Próximo" no final se houver próxima página
    if (_hasNext) {
      carouselItems.add(
        SizedBox(
          width: cardWidth,
          child: _NavCard(
            icon: Icons.chevron_right,
            label: 'Próximo',
            accentColor: widget.accentColor,
            isTV: widget.isTV,
            onTap: _nextPage,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        NetflixCarousel(
          title: widget.title,
          isTV: widget.isTV,
          items: carouselItems,
          // Sem trailing — navegação via cards dentro do carrossel
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

/// Card tipo NetflixCard que funciona como botão de navegação entre
/// páginas. Exibe um ícone (seta) + rótulo centralizado.
class _NavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final bool isTV;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.isTV,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardHeight = Responsive.getCardHeightSync(context);

    return FocusableWidget(
      onSelect: onTap,
      focusPadding: EdgeInsets.zero,
      focusScale: 1.0,
      borderRadius: 6,
      child: Container(
        height: cardHeight,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: accentColor, size: 32),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
