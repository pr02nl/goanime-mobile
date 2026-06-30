/// Tela de lista de episódios do PauloFlix no estilo Netflix.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/anime.dart';
import '../../../domain/models/episode.dart';
import '../../../domain/models/paulo_flix_episode_record.dart';
import '../../../domain/models/paulo_flix_season_record.dart';
import '../../../domain/models/pauloflix_content.dart';
import '../../../domain/models/pauloflix_models.dart' as scraping;
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
    final content = context
        .select<PauloFlixEpisodeProgressViewModel, PauloFlixContent>(
          (vm) => vm.content,
        );
    final isLoading = context.select<PauloFlixEpisodeProgressViewModel, bool>(
      (vm) => vm.isLoading,
    );
    final hasSeasons = context.select<PauloFlixEpisodeProgressViewModel, bool>(
      (vm) => vm.hasSeasons,
    );
    final errorMessage = context
        .select<PauloFlixEpisodeProgressViewModel, String?>(
          (vm) => vm.errorMessage,
        );
    final scrapingSeasons = context
        .select<
          PauloFlixEpisodeProgressViewModel,
          List<scraping.PauloFlixSeason>
        >((vm) => vm.scrapingSeasons);
    final selectedSeasonIndex = context
        .select<PauloFlixEpisodeProgressViewModel, int>(
          (vm) => vm.selectedSeasonIndex,
        );
    final isCompletedByIndex = context
        .select<PauloFlixEpisodeProgressViewModel, Map<int, bool>?>(
          (vm) => vm.isCompletedByIndex,
        );
    final isTV = MediaQuery.of(context).size.width > 1200;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          content.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _HeroBanner(content: content)),

          SliverToBoxAdapter(child: _InfoPanel(content: content)),

          if (!isLoading && hasSeasons)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: PauloflixSeasonSelector(
                  seasons: scrapingSeasons,
                  selectedIndex: selectedSeasonIndex,
                  onSeasonSelected: (index) => context
                      .read<PauloFlixEpisodeProgressViewModel>()
                      .selectSeason(index),
                  isCompletedByIndex: isCompletedByIndex,
                ),
              ),
            ),

          if (isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (errorMessage != null)
            SliverFillRemaining(child: _ErrorState(errorMessage: errorMessage))
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
    final heroUrl = context.select<PauloFlixEpisodeProgressViewModel, String?>(
      (vm) => vm.selectedSeasonHeroUrl,
    );
    final isTV = MediaQuery.of(context).size.width > 1200;
    final heroHeight = isTV ? 350.0 : 280.0;

    return SizedBox(
      height: heroHeight,
      child: NetflixHeroCard(
        imageUrl: heroUrl ?? '',
        title: content.displayName,
        showTitle: false,
        height: heroHeight,
        isTV: isTV,
        onPlay: () {
          final vm = context.read<PauloFlixEpisodeProgressViewModel>();
          final playEpisodes = vm.episodes;
          if (playEpisodes.isNotEmpty) {
            _playEpisode(context, playEpisodes.first, 0);
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
    final hasSeasons = context.select<PauloFlixEpisodeProgressViewModel, bool>(
      (vm) => vm.hasSeasons,
    );
    final seasonCount = context.select<PauloFlixEpisodeProgressViewModel, int>(
      (vm) => vm.seasons.length,
    );

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
              if (hasSeasons) ...[
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
                    '$seasonCount ${seasonCount == 1 ? 'temporada' : 'temporadas'}',
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
    final records = context
        .select<
          PauloFlixEpisodeProgressViewModel,
          List<PauloFlixEpisodeRecord>
        >((vm) => vm.episodes);
    final season = context
        .select<PauloFlixEpisodeProgressViewModel, PauloFlixSeasonRecord?>(
          (vm) => vm.selectedSeason,
        );
    final scrapings = context
        .select<
          PauloFlixEpisodeProgressViewModel,
          List<scraping.PauloFlixEpisode>
        >((vm) => vm.scrapingEpisodesForSelected);

    if (records.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == records.length - 1 ? 0 : 8),
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
        );
      }, childCount: records.length),
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
