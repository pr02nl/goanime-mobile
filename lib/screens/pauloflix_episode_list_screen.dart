import 'package:flutter/material.dart';

import '../domain/models/anime.dart';
import '../domain/models/episode.dart';
import '../domain/models/pauloflix_content.dart';
import '../l10n/app_localizations.dart';
import '../models/pauloflix_models.dart';
import '../services/pauloflix_service.dart';
import '../theme/app_colors.dart';
import '../widgets/pauloflix_badge.dart';
import 'video_player_screen.dart';

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
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar temporadas: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.content.displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.content.bannerUrl != null)
                    Image.network(
                      widget.content.bannerUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: AppColors.surface),
                    )
                  else
                    Container(color: AppColors.surface),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, AppColors.background],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const PauloFlixBadge(),
                      if (widget.content.score != null) ...[
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
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.content.score!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (widget.content.description != null)
                    Text(
                      widget.content.description!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),

                  const SizedBox(height: 16),

                  if (widget.content.genres.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.content.genres
                          .map(
                            (genre) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                genre,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
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
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadSeasons,
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final season = _seasons[index];
                return _buildSeasonCard(season);
              }, childCount: _seasons.length),
            ),
        ],
      ),
    );
  }

  Widget _buildSeasonCard(PauloFlixSeason season) {
    return ExpansionTile(
      title: Text(
        season.name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconColor: AppColors.primary,
      collapsedIconColor: Colors.white54,
      children: [
        FutureBuilder<List<PauloFlixEpisode>>(
          future: PauloFlixService.fetchSeasonEpisodes(season.url),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Erro ao carregar episódios',
                  style: TextStyle(color: Colors.red),
                ),
              );
            }

            final episodes = snapshot.data ?? [];
            final episodeList = episodes
                .map(
                  (e) => Episode(
                    number: e.number.toString(),
                    url: e.url,
                    title: e.title,
                  ),
                )
                .toList();
            return Column(
              children: episodes.asMap().entries.map((entry) {
                final index = entry.key;
                final episode = entry.value;
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'E${episode.number}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    episode.title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    episode.fileSize?.toString() ?? '',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.play_circle_outline,
                    color: AppColors.primary,
                  ),
                  onTap: () {
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
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
