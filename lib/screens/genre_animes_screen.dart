import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/jikan_models.dart';
import '../services/jikan_service.dart';
import '../theme/app_colors.dart';
import '../theme/netflix_theme.dart';
import '../utils/responsive.dart';
import '../widgets/netflix_card.dart';
import 'source_selection_screen.dart';

class GenreAnimesScreen extends StatefulWidget {
  final String title;
  final int? genreId;
  final IconData icon;
  final Gradient gradient;

  const GenreAnimesScreen({
    super.key,
    required this.title,
    this.genreId,
    required this.icon,
    required this.gradient,
  });

  @override
  State<GenreAnimesScreen> createState() => _GenreAnimesScreenState();
}

class _GenreAnimesScreenState extends State<GenreAnimesScreen> {
  final JikanService _jikanService = JikanService();
  final ScrollController _scrollController = ScrollController();

  List<JikanAnime> _animes = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMorePages = true;

  @override
  void initState() {
    super.initState();
    _loadAnimes();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMorePages) {
        _loadMoreAnimes();
      }
    }
  }

  Future<void> _loadAnimes() async {
    setState(() => _isLoading = true);
    try {
      List<JikanAnime> animes;

      if (widget.genreId != null) {
        animes = await _jikanService.getAnimesByGenre(
          widget.genreId!,
          limit: 25,
        );
      } else {
        animes = await _jikanService.getTopAnimes(limit: 25);
      }

      if (mounted) {
        setState(() {
          _animes = animes;
          _isLoading = false;
          _hasMorePages = animes.length >= 25;
        });
      }
    } catch (e) {
      debugPrint('Error loading animes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreAnimes() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    _currentPage++;

    try {
      await Future.delayed(const Duration(milliseconds: 600));

      List<JikanAnime> newAnimes;

      if (widget.genreId != null) {
        newAnimes = await _jikanService.getAnimesByGenre(
          widget.genreId!,
          page: _currentPage,
          limit: 25,
        );
      } else {
        newAnimes = await _jikanService.getTopAnimes(
          page: _currentPage,
          limit: 25,
        );
      }

      if (mounted) {
        setState(() {
          _animes.addAll(newAnimes);
          _isLoadingMore = false;
          _hasMorePages = newAnimes.length >= 25;
        });
      }
    } catch (e) {
      debugPrint('Error loading more animes: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _currentPage--;
        });
      }
    }
  }

  void _onAnimeTap(JikanAnime jikanAnime) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SourceSelectionScreen(
          animeTitle: jikanAnime.title,
          imageUrl: jikanAnime.imageUrl,
          myAnimeListUrl: 'https://myanimelist.net/anime/${jikanAnime.malId}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // AppBar com gradiente
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 8,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(gradient: widget.gradient),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        widget.icon,
                        size: 90,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.background.withValues(alpha: 0.85),
                              AppColors.background,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Conteúdo usando NetflixCard
          if (_isLoading)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF00BCD4)),
                    const SizedBox(height: 16),
                    Text(
                      l10n.loading,
                      style: const TextStyle(color: NetflixTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else if (_animes.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noResultsFound,
                      style: const TextStyle(
                        color: NetflixTheme.textSecondary,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.all(
                Responsive.getHorizontalPadding(context),
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      Responsive.getGridColumnCount(context),
                  childAspectRatio: 0.65,
                  crossAxisSpacing:
                      Responsive.getCardSpacing(context),
                  mainAxisSpacing:
                      Responsive.getCardSpacing(context),
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index >= _animes.length) return null;
                  final anime = _animes[index];
                  return NetflixCard(
                    imageUrl: anime.imageUrl,
                    title: anime.title,
                    rating: anime.score,
                    width: double.infinity,
                    height: 220,
                    onTap: () => _onAnimeTap(anime),
                  );
                }, childCount: _animes.length),
              ),
            ),

          // Loading indicator para paginação
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
