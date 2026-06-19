import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/jikan_models.dart';
import '../providers/pauloflix_provider.dart';
import '../routing/route_data.dart';
import '../services/jikan_service.dart';
import '../theme/app_colors.dart';
import '../theme/netflix_theme.dart';
import '../ui/home/view_models/home_viewmodel.dart';
import '../utils/responsive.dart';
import '../utils/tv_detector.dart';
import '../widgets/netflix_card.dart';
import '../widgets/netflix_carousel.dart';
import '../widgets/pauloflix_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _detectTVMode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPauloFlixSync());
  }

  Future<void> _detectTVMode() async {
    final isTV = await TVDetector.isTV;
    if (mounted) {
      context.read<HomeViewModel>().setTVMode(isTV);
    }
  }

  Future<void> _checkPauloFlixSync() async {
    final provider = context.read<PauloFlixProvider>();
    await provider.loadContents();
    if (provider.contents.isEmpty) {
      provider.syncContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final viewModel = context.watch<HomeViewModel>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () => viewModel.loadHomeData(forceRefresh: true),
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          controller: viewModel.scrollController,
          slivers: [
            if (viewModel.seasonAnimes.isNotEmpty)
              SliverToBoxAdapter(
                child: NetflixHeroCard(
                  imageUrl: viewModel.seasonAnimes.first.largImageUrl ??
                      viewModel.seasonAnimes.first.imageUrl,
                  title: viewModel.seasonAnimes.first.title,
                  description: viewModel.seasonAnimes.first.synopsis,
                  onPlay: () => _onAnimeTap(viewModel.seasonAnimes.first),
                  height: Responsive.getBannerHeight(context),
                  isTV: viewModel.isTV,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            SliverToBoxAdapter(
              child: _buildSection(
                context, l10n.seasonHighlights, viewModel.seasonAnimes,
                isLoading: viewModel.isLoading, viewModel: viewModel,
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSection(
                context, l10n.topAnime, viewModel.topAnimes,
                isLoading: viewModel.isLoading, viewModel: viewModel,
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSection(
                context, l10n.action, viewModel.actionAnimes,
                isLoading: viewModel.isLoading, viewModel: viewModel,
                genreId: JikanGenreIds.action,
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSection(
                context, l10n.romance, viewModel.romanceAnimes,
                isLoading: viewModel.isLoading, viewModel: viewModel,
                genreId: JikanGenreIds.romance,
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSection(
                context, l10n.comedy, viewModel.comedyAnimes,
                isLoading: viewModel.isLoading, viewModel: viewModel,
                genreId: JikanGenreIds.comedy,
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSection(
                context, l10n.fantasy, viewModel.fantasyAnimes,
                isLoading: viewModel.isLoading, viewModel: viewModel,
                genreId: JikanGenreIds.fantasy,
              ),
            ),

            Consumer<PauloFlixProvider>(
              builder: (context, pauloflix, _) {
                if (pauloflix.contents.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: PauloFlixSection(
                    title: l10n.pauloFlix,
                    contents: pauloflix.contents.take(15).toList(),
                    isTV: viewModel.isTV,
                    onSeeAll: () => context.push('/pauloflix-see-all'),
                    onItemTap: (content) => context.push(
                      '/pauloflix-episodes',
                      extra: content,
                    ),
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<JikanAnime> animes, {
    required bool isLoading,
    required HomeViewModel viewModel,
    int? genreId,
  }) {
    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeightSync(context);
    final sectionHeight = cardHeight + 60;

    if (isLoading && animes.isEmpty) {
      return NetflixCarouselShimmer(title: title, height: sectionHeight);
    }

    if (animes.isEmpty) {
      return _buildEmptySection(context, title, sectionHeight);
    }

    final items = [
      ...animes.map(
        (anime) => NetflixCard(
          imageUrl: anime.imageUrl,
          title: anime.title,
          rating: anime.score,
          width: cardWidth,
          height: cardHeight,
          isTV: viewModel.isTV,
          onTap: () => _onAnimeTap(anime),
        ),
      ),
      if (genreId != null)
        SeeAllCard(
          label: AppLocalizations.of(context).seeAll,
          onTap: () => _onSeeAll(title, genreId),
          width: cardWidth,
          height: cardHeight,
          accentColor: AppColors.primary,
          isTV: viewModel.isTV,
        ),
    ];

    return NetflixCarousel(
      title: title,
      height: sectionHeight,
      isTV: viewModel.isTV,
      trailing: genreId != null
          ? SeeAllButton(
              label: AppLocalizations.of(context).seeAll,
              onTap: () => _onSeeAll(title, genreId),
              accentColor: AppColors.primary,
              isTV: viewModel.isTV,
            )
          : null,
      items: items,
    );
  }

  Widget _buildEmptySection(BuildContext context, String title, double height) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: Center(
            child: Text(
              AppLocalizations.of(context).noAnimeFound,
              style: TextStyle(color: NetflixTheme.textTertiary),
            ),
          ),
        ),
      ],
    );
  }

  void _onAnimeTap(JikanAnime anime) {
    context.push(
      '/source-selection',
      extra: SourceSelectionRouteData(
        animeTitle: anime.title,
        imageUrl: anime.imageUrl,
        myAnimeListUrl: 'https://myanimelist.net/anime/${anime.malId}',
      ),
    );
  }

  void _onSeeAll(String title, int genreId) {
    context.push(
      '/genre',
      extra: GenreRouteData(
        title: title,
        icon: Icons.movie,
        gradient: AppColors.getPrimaryGradient(),
        genreId: genreId,
      ),
    );
  }
}
