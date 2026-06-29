import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/models/jikan_models.dart';
import '../../../data/services/jikan_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/route_data.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/netflix_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/tv_detector.dart';
import '../../core/widgets/netflix_card.dart';
import '../../core/widgets/netflix_carousel.dart';
import '../../core/widgets/netflix_hero_card.dart';
import '../../core/widgets/see_all_card.dart';
import '../../pauloflix/view_models/pauloflix_provider.dart';
import '../../pauloflix/widgets/pauloflix_section.dart';
import '../view_models/home_viewmodel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _detectTVMode();
  }

  Future<void> _detectTVMode() async {
    final isTV = await TVDetector.isTV;
    if (mounted) {
      context.read<HomeViewModel>().setTVMode(isTV);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () =>
            context.read<HomeViewModel>().loadHomeData(forceRefresh: true),
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: const CustomScrollView(
          slivers: [
            _HeroBannerSection(),
            SliverToBoxAdapter(child: SizedBox(height: 24)),
            _SeasonHighlightsSection(),
            _TopAnimeSection(),
            _ActionAnimeSection(),
            _RomanceAnimeSection(),
            _ComedyAnimeSection(),
            _FantasyAnimeSection(),
            _PauloFlixHomeSection(),
            SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section widgets (isolados em Consumer/Selector para evitar rebuilds em
// cascata quando qualquer propriedade do HomeViewModel muda)
// ─────────────────────────────────────────────────────────────────────────────

/// Hero banner da season atual.
class _HeroBannerSection extends StatelessWidget {
  const _HeroBannerSection();

  @override
  Widget build(BuildContext context) {
    final animes = context.select<HomeViewModel, List<JikanAnime>>(
      (vm) => vm.seasonAnimes,
    );
    if (animes.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final isTV = context.select<HomeViewModel, bool>((vm) => vm.isTV);
    final first = animes.first;

    return SliverToBoxAdapter(
      child: NetflixHeroCard(
        imageUrl: first.largImageUrl ?? first.imageUrl,
        title: first.title,
        description: first.synopsis,
        onPlay: () => _navigateToAnime(context, first),
        height: Responsive.getBannerHeight(context),
        isTV: isTV,
      ),
    );
  }
}

/// Carrossel de "Destaques da Temporada".
class _SeasonHighlightsSection extends StatelessWidget {
  const _SeasonHighlightsSection();

  @override
  Widget build(BuildContext context) {
    final animes = context.select<HomeViewModel, List<JikanAnime>>(
      (vm) => vm.seasonAnimes,
    );
    final isLoading = context.select<HomeViewModel, bool>((vm) => vm.isLoading);
    return _buildAnimeCarousel(
      context: context,
      animes: animes,
      isLoading: isLoading,
      title: (l10n) => l10n.seasonHighlights,
      genreId: null,
    );
  }
}

/// Carrossel de "Top Animes".
class _TopAnimeSection extends StatelessWidget {
  const _TopAnimeSection();

  @override
  Widget build(BuildContext context) {
    final animes = context.select<HomeViewModel, List<JikanAnime>>(
      (vm) => vm.topAnimes,
    );
    final isLoading = context.select<HomeViewModel, bool>((vm) => vm.isLoading);
    return _buildAnimeCarousel(
      context: context,
      animes: animes,
      isLoading: isLoading,
      title: (l10n) => l10n.topAnime,
      genreId: null,
    );
  }
}

/// Carrossel de "Ação".
class _ActionAnimeSection extends StatelessWidget {
  const _ActionAnimeSection();

  @override
  Widget build(BuildContext context) {
    final animes = context.select<HomeViewModel, List<JikanAnime>>(
      (vm) => vm.actionAnimes,
    );
    final isLoading = context.select<HomeViewModel, bool>((vm) => vm.isLoading);
    return _buildAnimeCarousel(
      context: context,
      animes: animes,
      isLoading: isLoading,
      title: (l10n) => l10n.action,
      genreId: JikanGenreIds.action,
    );
  }
}

/// Carrossel de "Romance".
class _RomanceAnimeSection extends StatelessWidget {
  const _RomanceAnimeSection();

  @override
  Widget build(BuildContext context) {
    final animes = context.select<HomeViewModel, List<JikanAnime>>(
      (vm) => vm.romanceAnimes,
    );
    final isLoading = context.select<HomeViewModel, bool>((vm) => vm.isLoading);
    return _buildAnimeCarousel(
      context: context,
      animes: animes,
      isLoading: isLoading,
      title: (l10n) => l10n.romance,
      genreId: JikanGenreIds.romance,
    );
  }
}

/// Carrossel de "Comédia".
class _ComedyAnimeSection extends StatelessWidget {
  const _ComedyAnimeSection();

  @override
  Widget build(BuildContext context) {
    final animes = context.select<HomeViewModel, List<JikanAnime>>(
      (vm) => vm.comedyAnimes,
    );
    final isLoading = context.select<HomeViewModel, bool>((vm) => vm.isLoading);
    return _buildAnimeCarousel(
      context: context,
      animes: animes,
      isLoading: isLoading,
      title: (l10n) => l10n.comedy,
      genreId: JikanGenreIds.comedy,
    );
  }
}

/// Carrossel de "Fantasia".
class _FantasyAnimeSection extends StatelessWidget {
  const _FantasyAnimeSection();

  @override
  Widget build(BuildContext context) {
    final animes = context.select<HomeViewModel, List<JikanAnime>>(
      (vm) => vm.fantasyAnimes,
    );
    final isLoading = context.select<HomeViewModel, bool>((vm) => vm.isLoading);
    return _buildAnimeCarousel(
      context: context,
      animes: animes,
      isLoading: isLoading,
      title: (l10n) => l10n.fantasy,
      genreId: JikanGenreIds.fantasy,
    );
  }
}

/// Seção PauloFlix na home — usa `context.select` para `isTV` em vez
/// de receber do pai (evita rebuild em cascata).
class _PauloFlixHomeSection extends StatelessWidget {
  const _PauloFlixHomeSection();

  @override
  Widget build(BuildContext context) {
    final isTV = context.select<HomeViewModel, bool>((vm) => vm.isTV);
    final l10n = AppLocalizations.of(context);

    return Consumer<PauloFlixProvider>(
      builder: (context, pauloflix, _) {
        if (pauloflix.contents.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverToBoxAdapter(
          child: PauloFlixSection(
            title: l10n.pauloFlix,
            contents: pauloflix.contents.take(15).toList(),
            isTV: isTV,
            onSeeAll: () => context.pushNamed('pauloflix-see-all'),
            onItemTap: (content) =>
                context.pushNamed('pauloflix-episodes', extra: content),
          ),
        );
      },
    );
  }
}

// ─── Helper compartilhado: constrói um carrossel de animes ──────────

/// Constrói o carrossel horizontal de animes (shimmer, vazio ou populado).
/// Chamado pelos widgets de seção que já fizeram `context.select` para
/// seus dados específicos.
Widget _buildAnimeCarousel({
  required BuildContext context,
  required List<JikanAnime> animes,
  required bool isLoading,
  required String Function(AppLocalizations) title,
  int? genreId,
}) {
  final isTV = context.select<HomeViewModel, bool>((vm) => vm.isTV);
  final l10n = AppLocalizations.of(context);
  final resolvedTitle = title(l10n);
  final cardWidth = Responsive.getHorizontalListItemWidth(context);
  final cardHeight = Responsive.getCardHeightSync(context);
  final sectionHeight = cardHeight + 60;

  if (isLoading && animes.isEmpty) {
    return SliverToBoxAdapter(
      child: NetflixCarouselShimmer(
        title: resolvedTitle,
        height: sectionHeight,
      ),
    );
  }

  if (animes.isEmpty) {
    return SliverToBoxAdapter(
      child: _buildEmptyCarousel(context, resolvedTitle, sectionHeight),
    );
  }

  final items = [
    ...animes.map(
      (anime) => NetflixCard(
        imageUrl: anime.imageUrl,
        title: anime.title,
        rating: anime.score,
        width: cardWidth,
        height: cardHeight,
        isTV: isTV,
        onTap: () => _navigateToAnime(context, anime),
      ),
    ),
    if (genreId != null)
      SeeAllCard(
        label: l10n.seeAll,
        onTap: () => _navigateToGenre(context, resolvedTitle, genreId),
        width: cardWidth,
        height: cardHeight,
        accentColor: AppColors.primary,
        isTV: isTV,
      ),
  ];

  return SliverToBoxAdapter(
    child: NetflixCarousel(
      title: resolvedTitle,
      height: sectionHeight,
      isTV: isTV,
      items: items,
    ),
  );
}

// ─── Helpers de navegação ───────────────────────────────────────────

void _navigateToAnime(BuildContext context, JikanAnime anime) {
  context.pushNamed(
    'source-selection',
    extra: SourceSelectionRouteData(
      animeTitle: anime.title,
      imageUrl: anime.imageUrl,
      myAnimeListUrl: 'https://myanimelist.net/anime/${anime.malId}',
    ),
  );
}

void _navigateToGenre(BuildContext context, String title, int genreId) {
  context.pushNamed(
    'genre',
    extra: GenreRouteData(
      title: title,
      icon: Icons.movie,
      gradient: AppColors.getPrimaryGradient(),
      genreId: genreId,
    ),
  );
}

Widget _buildEmptyCarousel(BuildContext context, String title, double height) {
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
        height: height,
        child: Center(
          child: Text(
            AppLocalizations.of(context).noAnimeFound,
            style: const TextStyle(color: NetflixTheme.textTertiary),
          ),
        ),
      ),
    ],
  );
}
