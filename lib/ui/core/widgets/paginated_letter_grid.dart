import 'package:flutter/material.dart';

import '../themes/app_colors.dart';
import '../utils/pagination.dart';
import '../utils/responsive.dart';
import 'letter_index.dart';
import 'netflix_card.dart';

/// Grid paginado genérico com índice A–Z lateral.
///
/// Aceita qualquer tipo [T] (e.g. `PauloFlixMovie`, `PauloFlixContent`)
/// e delega a renderização de cada item ao callback [cardBuilder].
/// Isso permite reuso entre Movies Home e Animes See All sem acoplar
/// o widget a um modelo específico.
///
/// Layout:
/// * **Mobile**: `PageView` horizontal entre páginas + índice vertical
///   fixo no lado direito (overlay).
/// * **Tablet/TV/desktop**: `PageView` + índice horizontal acima do grid.
///
/// Sem `autofocus: true` nos cards (anti-pattern #19 do skill
/// `flutter-reactivity-gotchas` — assertion no FocusScope persistente
/// do shell).
class PaginatedLetterGrid<T> extends StatefulWidget {
  /// Resultado de paginação produzido por
  /// [PauloFlixMoviesProvider.paginateByLetter] ou
  /// [PauloFlixProvider.paginateByLetter].
  final PaginationResult<T> pagination;

  /// Callback que renderiza cada item como card. Deve cuidar de
  /// dimensões, badge e tap.
  final Widget Function(BuildContext, T) cardBuilder;

  /// True se o dispositivo é TV (ajusta comportamento do `NetflixCard`).
  final bool isTV;

  /// Função que extrai o nome de cada item (usado para o índice A–Z).
  /// Deve ser consistente com o `getSortKey` usado na paginação.
  final String Function(T) nameOf;

  /// Cor de destaque do índice A–Z e do indicador de página.
  /// Default: vermelho PauloFlix Movies.
  final Color accentColor;

  const PaginatedLetterGrid({
    super.key,
    required this.pagination,
    required this.cardBuilder,
    required this.nameOf,
    this.isTV = false,
    this.accentColor = AppColors.moviesAccent,
  });

  @override
  State<PaginatedLetterGrid<T>> createState() => _PaginatedLetterGridState<T>();
}

class _PaginatedLetterGridState<T> extends State<PaginatedLetterGrid<T>> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }
  }

  void _jumpToLetter(String letter) {
    final idx = widget.pagination.letterToPageIndex[letter];
    if (idx == null) return;
    _pageController.animateToPage(
      idx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < Responsive.phoneMaxWidth) return 2;
    if (width < Responsive.tabletMaxWidth) return 4;
    return 6;
  }

  String? _getActiveLetter() {
    if (_currentPage < 0 || _currentPage >= widget.pagination.pages.length) {
      return null;
    }
    final page = widget.pagination.pages[_currentPage];
    if (page.isEmpty) return null;
    final name = widget.nameOf(page.first);
    if (name.isEmpty) return null;
    return _letterOf(name);
  }

  String _letterOf(String name) {
    final first = name[0].toUpperCase();
    return RegExp(r'^[A-Z]$').hasMatch(first) ? first : '#';
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.pagination.pages;
    if (pages.isEmpty) return const SizedBox.shrink();

    final crossAxisCount = _getCrossAxisCount(context);
    final isWide =
        MediaQuery.of(context).size.width >= Responsive.phoneMaxWidth;
    final activeLetter = _getActiveLetter();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LetterIndex(
          availableLetters: widget.pagination.availableLetters,
          activeLetter: activeLetter,
          onLetterSelected: _jumpToLetter,
          accentColor: widget.accentColor,
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            SizedBox(
              height: _calculateGridHeight(pages, crossAxisCount),
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                itemBuilder: (context, pageIdx) {
                  return _buildPageGrid(
                    context,
                    pages[pageIdx],
                    crossAxisCount,
                  );
                },
              ),
            ),
            if (!isWide)
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: LetterIndex(
                    availableLetters: widget.pagination.availableLetters,
                    activeLetter: activeLetter,
                    onLetterSelected: _jumpToLetter,
                    accentColor: widget.accentColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _PageIndicator(
            current: _currentPage + 1,
            total: pages.length,
            accentColor: widget.accentColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPageGrid(
    BuildContext context,
    List<T> page,
    int crossAxisCount,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: page.length,
      itemBuilder: (context, index) {
        return widget.cardBuilder(context, page[index]);
      },
    );
  }

  double _calculateGridHeight(
    List<List<T>> pages,
    int crossAxisCount,
  ) {
    if (pages.isEmpty) return 0;
    // Pega a maior página (última pode ser menor).
    final maxPage = pages
        .map((p) => p.length)
        .reduce((a, b) => a > b ? a : b);
    final rows = (maxPage / crossAxisCount).ceil();
    return (rows * 200.0) + ((rows - 1) * 12.0);
  }
}

/// Card de filme usado como exemplo de `cardBuilder` no Movies Home.
/// Mantido aqui para referência — prefira importar [NetflixCard]
/// diretamente no caller.
class NetflixGridCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final double? rating;
  final bool isTV;
  final Widget? overlay;
  final VoidCallback? onTap;

  const NetflixGridCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.isTV,
    this.rating,
    this.overlay,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NetflixCard(
      imageUrl: imageUrl,
      title: title,
      rating: rating,
      width: double.infinity,
      height: double.infinity,
      isTV: isTV,
      showTitle: true,
      showRating: rating != null,
      overlayWidget: overlay,
      onTap: onTap,
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int current;
  final int total;
  final Color accentColor;

  const _PageIndicator({
    required this.current,
    required this.total,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            'Pág. $current de $total',
            style: TextStyle(
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
