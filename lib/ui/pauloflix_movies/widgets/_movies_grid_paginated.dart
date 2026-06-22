import 'package:flutter/material.dart';

import '../../../domain/models/pauloflix_movie.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/netflix_card.dart';
import '../../core/widgets/pauloflix_movies_badge.dart';
import '../view_models/pauloflix_movies_provider.dart';
import '_letter_index.dart';
import 'pauloflix_movie_detail_screen.dart';

/// Grid paginado de filmes com índice A–Z lateral.
///
/// Layout:
/// * **Mobile**: `PageView` horizontal entre páginas + índice vertical
///   fixo no lado direito (overlay).
/// * **Tablet/TV/desktop**: `PageView` + índice horizontal acima do grid.
///
/// Sem `autofocus: true` nos cards (anti-pattern #19 do skill
/// `flutter-reactivity-gotchas` — assertion no FocusScope persistente
/// do shell).
class MoviesGridPaginated extends StatefulWidget {
  final PaginationResult pagination;
  final bool isTV;

  const MoviesGridPaginated({
    super.key,
    required this.pagination,
    required this.isTV,
  });

  @override
  State<MoviesGridPaginated> createState() => _MoviesGridPaginatedState();
}

class _MoviesGridPaginatedState extends State<MoviesGridPaginated> {
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
    final firstName = page.first.displayName;
    if (firstName.isEmpty) return null;
    return _letterOf(firstName);
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
    final isWide = MediaQuery.of(context).size.width >= Responsive.phoneMaxWidth;
    final activeLetter = _getActiveLetter();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LetterIndex(
          availableLetters: widget.pagination.availableLetters,
          activeLetter: activeLetter,
          onLetterSelected: _jumpToLetter,
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
          ),
        ),
      ],
    );
  }

  Widget _buildPageGrid(
    BuildContext context,
    List<PauloFlixMovie> page,
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
        return _MovieGridCard(movie: page[index], isTV: widget.isTV);
      },
    );
  }

  double _calculateGridHeight(
    List<List<PauloFlixMovie>> pages,
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

class _MovieGridCard extends StatelessWidget {
  final PauloFlixMovie movie;
  final bool isTV;

  const _MovieGridCard({required this.movie, required this.isTV});

  @override
  Widget build(BuildContext context) {
    return NetflixCard(
      imageUrl: movie.imageUrl ?? '',
      title: movie.displayName,
      rating: movie.score,
      width: double.infinity,
      height: double.infinity,
      isTV: isTV,
      showTitle: true,
      showRating: movie.score != null,
      overlayWidget: movie.isCollection
          ? const CollectionBadge()
          : const PauloFlixMoviesBadge(),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PauloFlixMovieDetailScreen(content: movie),
          ),
        );
      },
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _PageIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFDC2626).withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            'Pág. $current de $total',
            style: const TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
