import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/anime.dart';
import '../models/episode.dart';
import '../screens/video_player_screen.dart';
import '../services/anime_service.dart';
import '../widgets/focusable_widget.dart';
import '../widgets/logo_widget.dart';

class EpisodeListScreen extends StatefulWidget {
  final Anime anime;

  const EpisodeListScreen({super.key, required this.anime});

  @override
  State<EpisodeListScreen> createState() => _EpisodeListScreenState();
}

class _EpisodeListScreenState extends State<EpisodeListScreen> {
  List<Episode> _episodes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[EpisodeListScreen] initState - Anime: ${widget.anime.name}, '
      'Has aniListData: ${widget.anime.aniListData != null}, '
      'AniList ID: ${widget.anime.anilistId}, '
      'MAL ID: ${widget.anime.malId}',
    );
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final episodes = await AnimeService.getAnimeEpisodes(widget.anime);
      setState(() {
        _episodes = episodes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasEpisodes =
        !_isLoading && _errorMessage == null && _episodes.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            title: Text(
              widget.anime.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              titlePadding: EdgeInsets.zero,
              background: _buildFlexibleHeader(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _buildStatusContent(context),
              ),
            ),
          ),
          if (hasEpisodes)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final episode = _episodes[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _episodes.length - 1 ? 0 : 10,
                    ),
                    child: _EpisodeCard(
                      episode: episode,
                      index: index,
                      onTap: () => _openEpisode(episode),
                    ),
                  );
                }, childCount: _episodes.length),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFlexibleHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final hasBanner = widget.anime.bannerUrl.isNotEmpty;
    final hasImage = widget.anime.imageUrl.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background - Banner or Gradient
        if (hasBanner)
          CachedNetworkImage(
            imageUrl: widget.anime.bannerUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colorScheme.primary, colorScheme.secondary],
                ),
              ),
            ),
            errorWidget: (context, url, error) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colorScheme.primary, colorScheme.secondary],
                  ),
                ),
              );
            },
          )
        else
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colorScheme.primary, colorScheme.secondary],
              ),
            ),
          ),
        // Overlay gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.65),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Cover image
                      if (hasImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: widget.anime.imageUrl,
                            width: 60,
                            height: 85,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 60,
                              height: 85,
                              color: Colors.white.withValues(alpha: 0.1),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              return Container(
                                width: 60,
                                height: 85,
                                color: Colors.white.withValues(alpha: 0.1),
                                child: const Icon(
                                  Icons.movie_rounded,
                                  size: 28,
                                  color: Colors.white54,
                                ),
                              );
                            },
                          ),
                        )
                      else
                        const LogoWidget(size: 32, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.anime.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            if (widget.anime.averageScore != null ||
                                widget.anime.episodeCount != null)
                              Row(
                                children: [
                                  if (widget.anime.averageScore != null) ...[
                                    Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: Colors.amber.shade400,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      (widget.anime.averageScore! / 10)
                                          .toStringAsFixed(1),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                    ),
                                  ],
                                  if (widget.anime.episodeCount != null) ...[
                                    if (widget.anime.averageScore != null)
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        width: 3,
                                        height: 3,
                                        decoration: const BoxDecoration(
                                          color: Colors.white54,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    const Icon(
                                      Icons.movie_filter_rounded,
                                      size: 14,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${widget.anime.episodeCount} eps',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                    ),
                                  ],
                                ],
                              )
                            else
                              Text(
                                l10n.availableEpisodes,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontSize: 12,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusContent(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState(context);
    }

    if (_errorMessage != null) {
      return _buildErrorState(context);
    }

    if (_episodes.isEmpty) {
      return _buildEmptyState(context);
    }

    return _buildEpisodesHeader(context);
  }

  Widget _buildLoadingState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('episode-loading'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surface.withValues(alpha: 0.8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text(
            'Carregando episódios...',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('episode-error'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.errorContainer,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 40,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(height: 16),
          Text(
            'Erro ao carregar episódios',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onErrorContainer,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Tente novamente em alguns instantes.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onErrorContainer.withValues(alpha: 0.8),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: _loadEpisodes,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              'Tentar novamente',
              style: TextStyle(fontSize: 13),
            ),
            style: FilledButton.styleFrom(
              foregroundColor: colorScheme.onErrorContainer,
              backgroundColor: colorScheme.onErrorContainer.withValues(
                alpha: 0.12,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const ValueKey('episode-empty'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tv_off_rounded, size: 48, color: colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            'Nenhum episódio disponível',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Volte mais tarde para novas atualizações.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const ValueKey('episode-header'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surface.withValues(alpha: 0.85),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.playlist_play_rounded,
            color: colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_episodes.length} episódio${_episodes.length == 1 ? '' : 's'}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openEpisode(Episode episode) {
    HapticFeedback.lightImpact();
    final index = _episodes.indexOf(episode);
    debugPrint(
      '[EpisodeListScreen] Opening video - Anime: ${widget.anime.name}, '
      'Has aniListData: ${widget.anime.aniListData != null}, '
      'AniList ID: ${widget.anime.anilistId}, '
      'MAL ID: ${widget.anime.malId}',
    );
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ModernVideoPlayerScreen(
              episode: episode,
              animeTitle: widget.anime.name,
              anime: widget.anime,
              episodeList: _episodes,
              episodeIndex: index >= 0 ? index : null,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  final Episode episode;
  final int index;
  final VoidCallback onTap;

  const _EpisodeCard({
    required this.episode,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayTitle = episode.number.toLowerCase().contains('epis')
        ? episode.number
        : 'Episódio ${episode.number}';

    return FocusableWidget(
      onSelect: onTap,
      borderRadius: 24,
      focusPadding: EdgeInsets.zero,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.18),
              colorScheme.surface,
            ],
          ),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.09),
              blurRadius: 22,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colorScheme.primary, colorScheme.secondary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '#${index + 1}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Assista com qualidade estabilizada e sem travamentos.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
