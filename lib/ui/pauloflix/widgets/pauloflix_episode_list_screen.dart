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
import '../view_models/paulo_flix_episode_progress_viewmodel.dart';
import 'anime_hero_banner.dart';
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
    final seasonCount = context.select<PauloFlixEpisodeProgressViewModel, int>(
      (vm) => vm.seasons.length,
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
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: AnimeHeroBanner(
              content: content,
              isTV: isTV,
              hasSeasons: hasSeasons,
              seasonCount: seasonCount,
              onPlay: () {
                final vm = context.read<PauloFlixEpisodeProgressViewModel>();
                final playEpisodes = vm.episodes;
                if (playEpisodes.isNotEmpty) {
                  _playEpisode(context, playEpisodes.first, 0);
                }
              },
            ),
          ),

          // SliverToBoxAdapter(child: _HeroBanner(content: content)),
          // SliverToBoxAdapter(child: InfoPanel(content: content)),
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

  Future<void> _playEpisode(
    BuildContext context,
    dynamic episode,
    int index,
  ) async {
    final vm = context.read<PauloFlixEpisodeProgressViewModel>();
    final selectedSeason = vm.selectedSeason;
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

    await context.pushNamed(
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
        seasonId: records[index].seasonId,
        episodeNumber: records[index].episodeNumber.toString(),
        tmdbId: vm.content.tmdbId,
        seasonNumber: selectedSeason?.seasonNumber,
      ),
    );
    if (context.mounted) {
      await vm.refreshProgress();
    }
  }
}

// --- Info Panel ---

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

class _EpisodesList extends StatefulWidget {
  final bool isTV;

  const _EpisodesList({required this.isTV});

  @override
  State<_EpisodesList> createState() => _EpisodesListState();
}

class _EpisodesListState extends State<_EpisodesList> {
  List<PauloFlixEpisodeRecord> _records = const [];
  PauloFlixSeasonRecord? _season;
  List<scraping.PauloFlixEpisode> _scrapings = const [];
  PauloFlixEpisodeProgressViewModel? _vm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _readVm();
    _vm = context.read<PauloFlixEpisodeProgressViewModel>();
    _vm?.removeListener(_onVmChanged);
    _vm?.addListener(_onVmChanged);
  }

  void _onVmChanged() {
    _readVm();
  }

  void _readVm() {
    setState(() {
      _records = _vm?.episodes ?? const [];
      _season = _vm?.selectedSeason;
      _scrapings = _vm?.scrapingEpisodesForSelected ?? const [];
    });
  }

  @override
  void dispose() {
    _vm?.removeListener(_onVmChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_records.isEmpty) {
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
          padding: EdgeInsets.only(
            bottom: index == _records.length - 1 ? 0 : 8,
          ),
          child: PauloflixEpisodeCard(
            episode: _scrapings[index],
            seasonNumber: _season?.seasonNumber ?? 1,
            positionSeconds: _records[index].positionSeconds,
            durationSeconds: _records[index].durationSeconds,
            isCompleted: _records[index].isCompleted,
            thumbnailUrl: _records[index].thumbnailUrl,
            originalTitle: _records[index].originalTitle,
            outline: _records[index].outline,
            aired: _records[index].aired,
            rating: _records[index].rating,
            runtime: _records[index].runtime,
            isTV: widget.isTV,
            onTap: () => _playEpisode(context, _records[index], index),
          ),
        );
      }, childCount: _records.length),
    );
  }

  Future<void> _playEpisode(
    BuildContext context,
    dynamic episode,
    int index,
  ) async {
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

    await context.pushNamed(
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
        tmdbId: vm.content.tmdbId,
        seasonNumber: selectedSeason?.seasonNumber,
      ),
    );
    if (context.mounted) {
      await vm.refresh();
    }
  }
}
