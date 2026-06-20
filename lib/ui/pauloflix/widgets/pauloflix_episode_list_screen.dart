/// Tela de lista de episódios do PauloFlix no estilo Netflix.
///
/// Exibe hero banner, seletor de temporadas horizontal e cards de episódio
/// com thumbnail.
library;

import 'package:flutter/material.dart';

import '../../../data/services/pauloflix_service.dart';
import '../../../domain/models/anime.dart';
import '../../../domain/models/episode.dart';
import '../../../domain/models/pauloflix_content.dart';
import '../../../domain/models/pauloflix_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/widgets/focusable_widget.dart';
import '../../core/widgets/pauloflix_badge.dart';
import '../../player/widgets/video_player_screen.dart';
import 'pauloflix_episode_card.dart';
import 'pauloflix_season_selector.dart';

class PauloFlixEpisodeListScreen extends StatefulWidget {
  final PauloFlixContent content;

  const PauloFlixEpisodeListScreen({super.key, required this.content});

  @override
  State<PauloFlixEpisodeListScreen> createState() =>
      _PauloFlixEpisodeListScreenState();
}

class _PauloFlixEpisodeListScreenState
    extends State<PauloFlixEpisodeListScreen> {
  List<PauloFlixSeason> _seasons = [];
  bool _isLoading = true;
  String? _error;
  int _selectedSeasonIndex = 0;

  // Cache de episódios por temporada
  final Map<int, List<PauloFlixEpisode>> _episodesCache = {};
  final Map<int, bool> _loadingEpisodes = {};
  final Map<int, String?> _episodeErrors = {};

  bool get _isTV => MediaQuery.of(context).size.width > 1200;

  @override
  void initState() {
    super.initState();
    _loadSeasons();
  }

  Future<void> _loadSeasons() async {
    try {
      final seasons = await PauloFlixService.fetchShowSeasons(
        widget.content.serverUrl,
      );
      setState(() {
        _seasons = seasons;
        _isLoading = false;
      });
      // Carrega episódios da primeira temporada
      if (seasons.isNotEmpty) {
        _loadEpisodes(0);
      }
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar temporadas: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEpisodes(int seasonIndex) async {
    if (_episodesCache.containsKey(seasonIndex)) return;
    if (_loadingEpisodes[seasonIndex] == true) return;

    setState(() {
      _loadingEpisodes[seasonIndex] = true;
      _episodeErrors[seasonIndex] = null;
    });

    try {
      final episodes = await PauloFlixService.fetchSeasonEpisodes(
        _seasons[seasonIndex].url,
      );
      if (mounted) {
        setState(() {
          _episodesCache[seasonIndex] = episodes;
          _loadingEpisodes[seasonIndex] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _episodeErrors[seasonIndex] = 'Erro ao carregar episódios: $e';
          _loadingEpisodes[seasonIndex] = false;
        });
      }
    }
  }

  void _onSeasonSelected(int index) {
    setState(() => _selectedSeasonIndex = index);
    _loadEpisodes(index);
  }

  void _playEpisode(PauloFlixEpisode episode, int index) {
    final episodes = _episodesCache[_selectedSeasonIndex] ?? [];
    final episodeList = episodes
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
          episode: episodeList[index],
          episodeList: episodeList,
          episodeIndex: index,
          animeTitle: widget.content.displayName,
          anime: Anime(
            name: widget.content.displayName,
            url: widget.content.serverUrl,
            source: AnimeSource.pauloFlix,
            fallbackImageUrl: widget.content.imageUrl,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Hero Banner
          _buildHeroBanner(),

          // Info Panel
          SliverToBoxAdapter(child: _buildInfoPanel()),

          // Season Selector
          if (!_isLoading && _seasons.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: PauloflixSeasonSelector(
                  seasons: _seasons,
                  selectedIndex: _selectedSeasonIndex,
                  onSeasonSelected: _onSeasonSelected,
                ),
              ),
            ),

          // Loading State
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          // Error State
          else if (_error != null)
            SliverFillRemaining(child: _buildErrorState())
          // Episodes
          else
            _buildEpisodesList(),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return SliverAppBar(
      expandedHeight: _isTV ? 350 : 280,
      pinned: true,
      backgroundColor: AppColors.background,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.content.displayName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Banner Image
            if (widget.content.bannerUrl != null)
              Image.network(
                widget.content.bannerUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildBannerFallback(),
              )
            else
              _buildBannerFallback(),

            // Gradient Overlay (topo)
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

            // Gradient Overlay (base)
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

            // Play Button (centro)
            if (_seasons.isNotEmpty)
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: FocusableWidget(
                    onSelect: () {
                      final episodes =
                          _episodesCache[_selectedSeasonIndex] ?? [];
                      if (episodes.isNotEmpty) {
                        _playEpisode(episodes.first, 0);
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

  Widget _buildBannerFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.movie_outlined,
          color: Colors.white12,
          size: 80,
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row de badges
          Row(
            children: [
              const PauloFlixBadge(),
              if (widget.content.score != null) ...[
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
                        widget.content.score!.toStringAsFixed(1),
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
              if (_seasons.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_seasons.length} ${_seasons.length == 1 ? 'temporada' : 'temporadas'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Descrição
          if (widget.content.description != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.content.description!,
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
          if (widget.content.genres.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.content.genres
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

  Widget _buildErrorState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FocusableWidget(
              onSelect: _loadSeasons,
              borderRadius: 8,
              child: ElevatedButton.icon(
                onPressed: _loadSeasons,
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

  Widget _buildEpisodesList() {
    final currentSeason = _seasons[_selectedSeasonIndex];
    final isLoadingEpisodes = _loadingEpisodes[_selectedSeasonIndex] == true;
    final episodeError = _episodeErrors[_selectedSeasonIndex];
    final episodes = _episodesCache[_selectedSeasonIndex];

    if (isLoadingEpisodes) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (episodeError != null) {
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
                  episodeError,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FocusableWidget(
                  onSelect: () => _loadEpisodes(_selectedSeasonIndex),
                  borderRadius: 8,
                  child: TextButton(
                    onPressed: () => _loadEpisodes(_selectedSeasonIndex),
                    child: const Text('Tentar novamente'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (episodes == null || episodes.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_library_outlined, size: 48, color: Colors.white24),
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

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final episode = episodes[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PauloflixEpisodeCard(
                episode: episode,
                seasonNumber: currentSeason.number,
                isTV: _isTV,
                onTap: () => _playEpisode(episode, index),
              ),
            );
          },
          childCount: episodes.length,
        ),
      ),
    );
  }
}
