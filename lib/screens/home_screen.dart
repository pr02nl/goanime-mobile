import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/jikan_models.dart';
import '../services/jikan_service.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/netflix_card.dart';
import '../widgets/netflix_carousel.dart';
import 'genre_animes_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'source_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final JikanService _jikanService = JikanService();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _fabAnimationController;

  bool _showFab = false;
  double _headerOpacity = 1.0;
  bool _dataLoaded = false;
  bool _isLoading = true;

  // Listas de animes
  List<JikanAnime> _seasonAnimes = [];
  List<JikanAnime> _topAnimes = [];
  List<JikanAnime> _actionAnimes = [];
  List<JikanAnime> _romanceAnimes = [];
  List<JikanAnime> _comedyAnimes = [];
  List<JikanAnime> _fantasyAnimes = [];

  // Índice do banner atual

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scrollController.addListener(_onScroll);
    if (!_dataLoaded) {
      _loadAllData();
    }
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;

    if (offset > 300 && !_showFab) {
      setState(() => _showFab = true);
      _fabAnimationController.forward();
    } else if (offset <= 300 && _showFab) {
      setState(() => _showFab = false);
      _fabAnimationController.reverse();
    }

    final newOpacity = offset > 0 ? 1.0 : 0.0;
    if ((newOpacity - _headerOpacity).abs() > 0.01) {
      setState(() {
        _headerOpacity = newOpacity;
      });
    }
  }

  /// Carrega TODOS os dados de uma vez usando o método otimizado
  Future<void> _loadAllData({bool forceRefresh = false}) async {
    _dataLoaded = true;

    if (!forceRefresh && _seasonAnimes.isNotEmpty) {
      // Já tem dados, não precisa recarregar
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Carrega tudo de uma vez com o novo método paralelo
      final homeData = await _jikanService.loadHomeData(
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _seasonAnimes = homeData.seasonAnimes;
          _topAnimes = homeData.topAnimes;
          _actionAnimes = homeData.actionAnimes;
          _romanceAnimes = homeData.romanceAnimes;
          _comedyAnimes = homeData.comedyAnimes;
          _fantasyAnimes = homeData.fantasyAnimes;
          _isLoading = false;
        });

        // Pre-cache das imagens do banner para transições suaves
        _precacheBannerImages();
      }
    } catch (e) {
      debugPrint('Error loading home data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Pre-carrega imagens do banner para transições mais suaves
  void _precacheBannerImages() {
    final bannerAnimes = _seasonAnimes.take(5);
    for (final anime in bannerAnimes) {
      final imageUrl = anime.largImageUrl ?? anime.imageUrl;
      precacheImage(CachedNetworkImageProvider(imageUrl), context);
    }
  }

  void _onAnimeTap(JikanAnime anime) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SourceSelectionScreen(
          animeTitle: anime.title,
          imageUrl: anime.imageUrl,
          myAnimeListUrl: 'https://myanimelist.net/anime/${anime.malId}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: () => _loadAllData(forceRefresh: true),
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Hero Netflix - Anime em destaque
            if (_seasonAnimes.isNotEmpty)
              SliverToBoxAdapter(
                child: NetflixHeroCard(
                  imageUrl: _seasonAnimes.first.largImageUrl ?? _seasonAnimes.first.imageUrl,
                  title: _seasonAnimes.first.title,
                  description: _seasonAnimes.first.synopsis,
                  onPlay: () => _onAnimeTap(_seasonAnimes.first),
                  height: Responsive.getBannerHeight(context) * 1.2,
                ),
              ),

            // Conteúdo principal - cada seção como SliverToBoxAdapter separado
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Seção: Destaques da Temporada
            SliverToBoxAdapter(
              child: _buildNetflixSection(
                title: l10n.seasonHighlights,
                animes: _seasonAnimes,
                isLoading: _isLoading && _seasonAnimes.isEmpty,
                genreId: null,
              ),
            ),

            // Seção: Top Animes
            SliverToBoxAdapter(
              child: _buildNetflixSection(
                title: l10n.topAnime,
                animes: _topAnimes,
                isLoading: _isLoading && _topAnimes.isEmpty,
                genreId: null,
              ),
            ),

            // Seção: Ação
            SliverToBoxAdapter(
              child: _buildNetflixSection(
                title: l10n.action,
                animes: _actionAnimes,
                isLoading: _isLoading && _actionAnimes.isEmpty,
                genreId: JikanGenreIds.action,
              ),
            ),

            // Seção: Romance
            SliverToBoxAdapter(
              child: _buildNetflixSection(
                title: l10n.romance,
                animes: _romanceAnimes,
                isLoading: _isLoading && _romanceAnimes.isEmpty,
                genreId: JikanGenreIds.romance,
              ),
            ),

            // Seção: Comédia
            SliverToBoxAdapter(
              child: _buildNetflixSection(
                title: l10n.comedy,
                animes: _comedyAnimes,
                isLoading: _isLoading && _comedyAnimes.isEmpty,
                genreId: JikanGenreIds.comedy,
              ),
            ),

            // Seção: Fantasia
            SliverToBoxAdapter(
              child: _buildNetflixSection(
                title: l10n.fantasy,
                animes: _fantasyAnimes,
                isLoading: _isLoading && _fantasyAnimes.isEmpty,
                genreId: JikanGenreIds.fantasy,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
      floatingActionButton: _showFab
          ? ScaleTransition(
              scale: _fabAnimationController,
              child: FloatingActionButton(
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                },
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.arrow_upward, color: Colors.white),
              ),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _headerOpacity > 0
          ? AppColors.background.withValues(alpha: 0.95)
          : Colors.transparent,
      elevation: 0,
      toolbarHeight: 64,
      flexibleSpace: _headerOpacity > 0
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background,
                    AppColors.background.withValues(alpha: 0.0),
                  ],
                ),
              ),
            )
          : null,
      title: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.play_circle_filled,
          color: Colors.white,
          size: 22,
        ),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white, size: 24),
          tooltip: 'Search',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            );
          },
        ),
        IconButton(
          icon: const Icon(
            Icons.settings_outlined,
            color: Colors.white,
            size: 24,
          ),
          tooltip: 'Settings',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // Seção com NetflixCarousel e NetflixCard
  Widget _buildNetflixSection({
    required String title,
    required List<JikanAnime> animes,
    required bool isLoading,
    int? genreId,
  }) {
    final l10n = AppLocalizations.of(context);
    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeightSync(context);
    final sectionHeight = cardHeight + 60;

    if (isLoading) {
      return NetflixCarouselShimmer(
        title: title,
        height: sectionHeight,
      );
    }

    if (animes.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: sectionHeight,
            child: Center(
              child: Text(
                'Nenhum anime encontrado',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ),
        ],
      );
    }

    return NetflixCarousel(
      title: title,
      height: sectionHeight,
      trailing: genreId != null
          ? TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GenreAnimesScreen(
                      title: title,
                      icon: Icons.movie,
                      gradient: AppColors.getPrimaryGradient(),
                      genreId: genreId,
                    ),
                  ),
                );
              },
              child: Text(
                l10n.seeAll,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      items: animes.map((anime) {
        return NetflixCard(
          imageUrl: anime.imageUrl,
          title: anime.title,
          rating: anime.score,
          width: cardWidth,
          height: cardHeight,
          onTap: () => _onAnimeTap(anime),
        );
      }).toList(),
    );
  }
}

