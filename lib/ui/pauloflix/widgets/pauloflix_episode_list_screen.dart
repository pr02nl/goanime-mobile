/// Tela de lista de episódios do PauloFlix no estilo Netflix.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/anime.dart';
import '../../../domain/models/episode.dart';
import '../../../domain/models/pauloflix_content.dart';
import '../../../domain/repositories/paulo_flix_episode_progress_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/route_data.dart';
import '../../core/themes/app_colors.dart';
import '../../core/widgets/focusable_widget.dart';
import '../../core/widgets/netflix_hero_card.dart';
import '../../core/widgets/pauloflix_badge.dart';
import '../view_models/paulo_flix_episode_progress_viewmodel.dart';
import 'pauloflix_episode_card.dart';
import 'pauloflix_season_selector.dart';

class PauloFlixEpisodeListScreen extends StatelessWidget {
  final PauloFlixContent content;

  const PauloFlixEpisodeListScreen({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => PauloFlixEpisodeProgressViewModel(
        content: content,
        repository: ctx.read<PauloFlixEpisodeProgressRepository>(),
      )..loadSeasons(),
      child: const _PauloFlixEpisodeListView(),
    );
  }
}

class _PauloFlixEpisodeListView extends StatelessWidget {
  const _PauloFlixEpisodeListView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PauloFlixEpisodeProgressViewModel>();
    final isTV = MediaQuery.of(context).size.width > 1200;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          vm.content.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _HeroBanner(content: vm.content)),

          SliverToBoxAdapter(child: _InfoPanel(content: vm.content)),

          if (!vm.isLoading && vm.hasSeasons)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: PauloflixSeasonSelector(
                  seasons: vm.scrapingSeasons,
                  selectedIndex: vm.selectedSeasonIndex,
                  onSeasonSelected: (index) => vm.selectSeason(index),
                  isCompletedByIndex: vm.isCompletedByIndex,
                ),
              ),
            ),

          if (vm.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (vm.errorMessage != null)
            SliverFillRemaining(
              child: _ErrorState(errorMessage: vm.errorMessage!),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _EpisodesList(isTV: isTV),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// --- Hero Banner ---

class _HeroBanner extends StatelessWidget {
  final PauloFlixContent content;

  const _HeroBanner({required this.content});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PauloFlixEpisodeProgressViewModel>();
    final isTV = MediaQuery.of(context).size.width > 1200;
    final heroHeight = isTV ? 350.0 : 280.0;

    return SizedBox(
      height: heroHeight,
      child: NetflixHeroCard(
        imageUrl: vm.selectedSeasonHeroUrl ?? '',
        title: content.displayName,
        showTitle: false,
        height: heroHeight,
        isTV: isTV,
        onPlay: () {
          final episodes = vm.episodes;
          if (episodes.isNotEmpty) {
            _playEpisode(context, episodes.first, 0);
          }
        },
      ),
    );
  }

  void _playEpisode(BuildContext context, dynamic episode, int index) {
    final vm = context.read<PauloFlixEpisodeProgressViewModel>();
    final selectedSeason = vm.selectedSeason;
    final seasonId = selectedSeason?.id;
    final records = vm.episodes;
    final scrapings = vm.scrapingEpisodesForSelected;
    final episodes = <Episode>[
      for (var i = 0; i < records.length; i++)
        Episode(
          number: scrapings[i].number.toString(),
          url: scrapings[i].url,
          title: records[i].originalTitle ?? records[i].title,
          thumbnailUrl: scrapings[i].thumbnailUrl,
        ),
    ];

    context.pushNamed(
      'player',
      extra: PlayerRouteData(
        episode: episodes[index],
        animeTitle: vm.content.displayName,
        anime: Anime(
          name: vm.content.displayName,
          url: vm.content.serverUrl,
          source: AnimeSource.pauloFlix,
          fallbackImageUrl: vm.content.imageUrl,
        ),
        isMovie: false,
        episodeList: episodes,
        episodeIndex: index,
        contentId: vm.content.id,
        seasonId: seasonId,
        episodeNumber: records[index].episodeNumber.toString(),
      ),
    );
  }
}

// --- Info Panel ---

class _InfoPanel extends StatelessWidget {
  final PauloFlixContent content;

  const _InfoPanel({required this.content});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PauloFlixEpisodeProgressViewModel>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PauloFlixBadge(),
              if (content.score != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        content.score!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (vm.hasSeasons) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${vm.seasons.length} ${vm.seasons.length == 1 ? 'temporada' : 'temporadas'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),

          if (content.description != null) ...[
            const SizedBox(height: 12),
            Text(
              content.description!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          if (content.genres.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: content.genres
                  .take(5)
                  .map(
                    (genre) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        genre,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// --- Error State ---

class _ErrorState extends StatelessWidget {
  final String errorMessage;

  const _ErrorState({required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vm = context.read<PauloFlixEpisodeProgressViewModel>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FocusableWidget(
              onSelect: vm.refresh,
              borderRadius: 8,
              child: ElevatedButton.icon(
                onPressed: vm.refresh,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Episodes List ---

class _EpisodesList extends StatelessWidget {
  final bool isTV;

  const _EpisodesList({required this.isTV});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PauloFlixEpisodeProgressViewModel>();

    if (vm.episodes.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 48,
                color: Colors.white24,
              ),
              SizedBox(height: 12),
              Text(
                'Nenhum episódio encontrado',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    final season = vm.selectedSeason;
    final records = vm.episodes;
    final scrapings = vm.scrapingEpisodesForSelected;
    return SliverToBoxAdapter(
      child: FocusTraversalGroup(
        policy: _VerticalClampedTraversalPolicy(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < records.length; index++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == records.length - 1 ? 0 : 8,
                ),
                child: PauloflixEpisodeCard(
                  episode: scrapings[index],
                  seasonNumber: season?.seasonNumber ?? 1,
                  positionSeconds: records[index].positionSeconds,
                  durationSeconds: records[index].durationSeconds,
                  isCompleted: records[index].isCompleted,
                  thumbnailUrl: records[index].thumbnailUrl,
                  originalTitle: records[index].originalTitle,
                  outline: records[index].outline,
                  aired: records[index].aired,
                  rating: records[index].rating,
                  runtime: records[index].runtime,
                  isTV: isTV,
                  onTap: () => _playEpisode(context, records[index], index),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _playEpisode(BuildContext context, dynamic episode, int index) {
    final vm = context.read<PauloFlixEpisodeProgressViewModel>();
    final selectedSeason = vm.selectedSeason;
    final seasonId = selectedSeason?.id;
    final records = vm.episodes;
    final scrapings = vm.scrapingEpisodesForSelected;
    final episodes = <Episode>[
      for (var i = 0; i < records.length; i++)
        Episode(
          number: scrapings[i].number.toString(),
          url: scrapings[i].url,
          title: records[i].title,
          thumbnailUrl: scrapings[i].thumbnailUrl,
        ),
    ];

    context.pushNamed(
      'player',
      extra: PlayerRouteData(
        episode: episodes[index],
        animeTitle: vm.content.displayName,
        anime: Anime(
          name: vm.content.displayName,
          url: vm.content.serverUrl,
          source: AnimeSource.pauloFlix,
          fallbackImageUrl: vm.content.imageUrl,
        ),
        isMovie: false,
        episodeList: episodes,
        episodeIndex: index,
        contentId: vm.content.id,
        seasonId: seasonId,
        episodeNumber: records[index].episodeNumber.toString(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Focus traversal policies
// ─────────────────────────────────────────────────────────────────────────────

class _VerticalClampedTraversalPolicy extends WidgetOrderTraversalPolicy {
  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    if (direction == TraversalDirection.down) {
      return _handleDown(currentNode);
    }
    return super.inDirection(currentNode, direction);
  }

  bool _handleDown(FocusNode currentNode) {
    final scope = currentNode.nearestScope!;
    final FocusNode? focusedChild = scope.focusedChild;
    if (focusedChild == null) return false;

    final List<FocusNode> columnNodes = scope.traversalDescendants
        .where(
          (FocusNode n) =>
              n.canRequestFocus &&
              !n.skipTraversal &&
              n.context != null &&
              _sameColumn(n, focusedChild),
        )
        .toList();

    if (columnNodes.isEmpty) return false;

    columnNodes.sort((a, b) => a.rect.center.dy.compareTo(b.rect.center.dy));

    final int idx = columnNodes.indexOf(focusedChild);
    if (idx < 0) return false;

    if (idx < columnNodes.length - 1) {
      _requestFocusInDirection(columnNodes[idx + 1]);
    } else {
      _requestFocusInDirection(focusedChild);
    }
    return true;
  }

  bool _sameColumn(FocusNode node, FocusNode focusedChild) {
    final a = node.rect;
    final b = focusedChild.rect;
    return a.left < b.right && a.right > b.left;
  }

  void _requestFocusInDirection(FocusNode target) {
    requestFocusCallback(
      target,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }
}
