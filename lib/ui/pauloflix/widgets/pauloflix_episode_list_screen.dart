/// Tela de lista de episódios do PauloFlix no estilo Netflix.
///
/// Exibe hero banner, seletor de temporadas horizontal e cards de episódio
/// com thumbnail. Usa ViewModel para gerenciamento de estado.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/anime.dart';
import '../../../domain/models/episode.dart';
import '../../../domain/models/pauloflix_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/widgets/focusable_widget.dart';
import '../../core/widgets/pauloflix_badge.dart';
import '../../player/widgets/video_player_screen.dart';
import '../view_models/pauloflix_episode_list_viewmodel.dart';
import 'pauloflix_episode_card.dart';
import 'pauloflix_season_selector.dart';

class PauloFlixEpisodeListScreen extends StatelessWidget {
  final PauloFlixContent content;

  const PauloFlixEpisodeListScreen({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PauloFlixEpisodeListViewModel(content: content)
        ..loadSeasons(),
      child: const _PauloFlixEpisodeListView(),
    );
  }
}

class _PauloFlixEpisodeListView extends StatelessWidget {
  const _PauloFlixEpisodeListView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PauloFlixEpisodeListViewModel>();
    final isTV = MediaQuery.of(context).size.width > 1200;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Hero Banner
          _HeroBanner(content: vm.content),

          // Info Panel
          SliverToBoxAdapter(child: _InfoPanel(content: vm.content)),

          // Season Selector
          if (!vm.isLoading && vm.hasSeasons)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: PauloflixSeasonSelector(
                  seasons: vm.seasons,
                  selectedIndex: vm.selectedSeasonIndex,
                  onSeasonSelected: (index) => vm.selectSeason(index),
                ),
              ),
            ),

          // Content States
          if (vm.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (vm.errorMessage != null)
            SliverFillRemaining(child: _ErrorState(errorMessage: vm.errorMessage!))
          else
            _EpisodesList(isTV: isTV),
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
    final vm = context.watch<PauloFlixEpisodeListViewModel>();
    final isTV = MediaQuery.of(context).size.width > 1200;

    return SliverAppBar(
      expandedHeight: isTV ? 350 : 280,
      pinned: true,
      backgroundColor: AppColors.background,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          content.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Banner Image
            if (content.bannerUrl != null)
              Image.network(
                content.bannerUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallback(),
              )
            else
              _buildFallback(),

            // Gradient Top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Gradient Bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 150,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppColors.background],
                  ),
                ),
              ),
            ),

            // Play Button
            if (vm.hasSeasons)
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: FocusableWidget(
                    onSelect: () {
                      final episodes = vm.episodes;
                      if (episodes.isNotEmpty) {
                        _playEpisode(context, episodes.first, 0);
                      }
                    },
                    borderRadius: 30,
                    focusPadding: EdgeInsets.zero,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                          SizedBox(width: 8),
                          Text(
                            'Assistir',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.movie_outlined, color: Colors.white12, size: 80),
      ),
    );
  }

  void _playEpisode(BuildContext context, dynamic episode, int index) {
    final vm = context.read<PauloFlixEpisodeListViewModel>();
    final episodes = vm.episodes
        .map(
          (e) => Episode(
            number: e.number.toString(),
            url: e.url,
            title: e.title,
          ),
        )
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModernVideoPlayerScreen(
          episode: episodes[index],
          episodeList: episodes,
          episodeIndex: index,
          animeTitle: vm.content.displayName,
          anime: Anime(
            name: vm.content.displayName,
            url: vm.content.serverUrl,
            source: AnimeSource.pauloFlix,
            fallbackImageUrl: vm.content.imageUrl,
          ),
        ),
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
    final vm = context.watch<PauloFlixEpisodeListViewModel>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges Row
          Row(
            children: [
              const PauloFlixBadge(),
              if (content.score != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

          // Descrição
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

          // Gêneros
          if (content.genres.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: content.genres
                  .take(5)
                  .map(
                    (genre) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        genre,
                        style: const TextStyle(color: AppColors.primary, fontSize: 11),
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
    final vm = context.read<PauloFlixEpisodeListViewModel>();

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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    final vm = context.watch<PauloFlixEpisodeListViewModel>();

    // Loading
    if (vm.isLoadingEpisodes) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Error
    if (vm.episodeError != null) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                const SizedBox(height: 12),
                Text(
                  vm.episodeError!,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FocusableWidget(
                  onSelect: () => vm.loadEpisodes(vm.selectedSeasonIndex),
                  borderRadius: 8,
                  child: TextButton(
                    onPressed: () => vm.loadEpisodes(vm.selectedSeasonIndex),
                    child: const Text('Tentar novamente'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Empty
    if (vm.episodes.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_library_outlined, size: 48, color: Colors.white24),
              SizedBox(height: 12),
              Text('Nenhum episódio encontrado', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    // Episodes
    final season = vm.selectedSeason;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final episode = vm.episodes[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PauloflixEpisodeCard(
                episode: episode,
                seasonNumber: season?.number ?? 1,
                isTV: isTV,
                onTap: () => _playEpisode(context, episode, index),
              ),
            );
          },
          childCount: vm.episodes.length,
        ),
      ),
    );
  }

  void _playEpisode(BuildContext context, dynamic episode, int index) {
    final vm = context.read<PauloFlixEpisodeListViewModel>();
    final episodes = vm.episodes
        .map(
          (e) => Episode(
            number: e.number.toString(),
            url: e.url,
            title: e.title,
          ),
        )
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModernVideoPlayerScreen(
          episode: episodes[index],
          episodeList: episodes,
          episodeIndex: index,
          animeTitle: vm.content.displayName,
          anime: Anime(
            name: vm.content.displayName,
            url: vm.content.serverUrl,
            source: AnimeSource.pauloFlix,
            fallbackImageUrl: vm.content.imageUrl,
          ),
        ),
      ),
    );
  }
}
