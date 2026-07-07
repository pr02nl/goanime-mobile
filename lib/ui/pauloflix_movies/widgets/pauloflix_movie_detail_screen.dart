import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/logger/app_logger.dart';
import '../../../domain/models/anime.dart';
import '../../../domain/models/episode.dart';
import '../../../domain/models/paulo_flix_movie_progress_record.dart';
import '../../../domain/models/pauloflix_movie.dart';
import '../../../domain/models/pauloflix_movie_item.dart';
import '../../../domain/repositories/paulo_flix_movie_progress_repository.dart';
import '../../../routing/route_data.dart';
import '../../core/mixins/go_router_route_refresh_mixin.dart';
import '../../core/themes/app_colors.dart';
import '../../core/widgets/focusable_widget.dart';
import '../../core/widgets/progress_bar.dart';
import '../../core/widgets/progress_overlay.dart';

class PauloFlixMovieDetailScreen extends StatefulWidget {
  final PauloFlixMovie content;

  const PauloFlixMovieDetailScreen({super.key, required this.content});

  @override
  State<PauloFlixMovieDetailScreen> createState() =>
      _PauloFlixMovieDetailScreenState();
}

class _PauloFlixMovieDetailScreenState extends State<PauloFlixMovieDetailScreen>
    with GoRouterRouteRefreshMixin<PauloFlixMovieDetailScreen> {
  final ScrollController _scrollController = ScrollController();

  String? _error;

  // Para filme individual
  String? _movieVideoUrl;
  List<SubtitleTrackInfo> _movieSubtitles = const [];

  // Progresso do filme
  PauloFlixMovieProgressRecord? _progress;

  @override
  String get routePath => '/pauloflix-movie-detail';

  @override
  void onRouteRefresh() => _loadProgress();

  @override
  void initState() {
    super.initState();
    _resolveSingleMovie();
    _loadProgress();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    try {
      final repo = context.read<PauloFlixMovieProgressRepository?>();
      if (repo != null && mounted) {
        final progress = await repo.getProgress(widget.content.folderName);
        if (mounted) setState(() => _progress = progress);
      }
    } catch (e, st) {
      const AppLogger(
        'MovieDetailScreen',
      ).error('Erro ao carregar progresso', e, st);
    }
  }

  void _resolveSingleMovie() {
    if (widget.content.videoUrl != null) {
      _movieVideoUrl = widget.content.videoUrl;
      _movieSubtitles = _resolveSubtitlesFromJson(
        widget.content.subtitles,
        widget.content.serverUrl,
      );
    } else {
      _error =
          'Este filme não possui URL de vídeo no índice. '
          'Execute uma sincronização para atualizar o catálogo.';
    }
  }

  Future<void> _openPlayer(
    String videoUrl,
    String title, {
    List<SubtitleTrackInfo> subtitles = const [],
  }) async {
    final episodeTracks = subtitles
        .map(
          (s) => EpisodeSubtitleTrack(
            url: s.url,
            language: s.language,
            displayName: s.displayName,
            forced: s.forced,
          ),
        )
        .toList();

    await context.pushNamed(
      'player',
      extra: PlayerRouteData(
        episode: Episode(
          number: '1',
          url: videoUrl,
          subtitleTracks: episodeTracks,
        ),
        animeTitle: title,
        isMovie: true,
        tmdbId: widget.content.tmdbId,
        movieFolderName: widget.content.folderName,
        anime: Anime(
          name: title,
          url: widget.content.serverUrl,
          source: AnimeSource.pauloFlix,
          fallbackImageUrl: widget.content.imageUrl,
        ),
      ),
    );
    if (mounted) {
      await _loadProgress();
    }
  }

  Future<void> refreshProgress() async {
    await _loadProgress();
  }

  // ─── Getters de estado do progresso ────────────────────────────────

  bool get _isCompleted => _progress?.isCompleted ?? false;

  bool get _isInProgress {
    if (_progress == null) return false;
    return _progress!.positionSeconds > 0 && !_progress!.isCompleted;
  }

  double get _progressRatio => _progress?.progressRatio ?? 0.0;

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasBanner = (widget.content.bannerUrl ?? '').isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom + 24;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Banner em tela cheia
          Positioned.fill(
            child: hasBanner
                ? CachedNetworkImage(
                    imageUrl: widget.content.bannerUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        _buildPlaceholder(colorScheme),
                    errorWidget: (context, url, error) =>
                        _buildPlaceholder(colorScheme),
                  )
                : _buildPlaceholder(colorScheme),
          ),
          // Gradiente escuro: começa cedo (20%) e vai até preto total
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black26,
                      Colors.black87,
                      Colors.black,
                    ],
                    stops: [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Botão voltar no canto superior direito
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: FocusableWidget(
              onSelect: () => _back(),
              borderRadius: 20,
              child: Material(
                color: Colors.black26,
                shape: const CircleBorder(),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _back,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ),
          // Conteúdo ancorado no fim da tela com fundo semi-transparente
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.3, 0.7],
                ),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.50,
                ),
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildPlayButton(),
                          const SizedBox(height: 20),
                          _buildMovieInfo(),
                          if (_error != null) _buildError(),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _back() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.secondary],
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    final disabled = _movieVideoUrl == null;
    final icon = _isCompleted ? Icons.replay_rounded : Icons.play_arrow_rounded;
    final label = _isCompleted
        ? 'Reassistir'
        : _isInProgress
        ? 'Continuar'
        : 'Assistir';

    final playWidget = Row(
      children: [
        if (disabled)
          const _PlayCircle(icon: Icons.play_circle_outline, enabled: false)
        else
          _PlayCircle(
            icon: icon,
            enabled: true,
            accentColor: _isCompleted ? Colors.green : AppColors.moviesAccent,
            onTap: () => _openPlayer(
              _movieVideoUrl!,
              widget.content.displayName,
              subtitles: _movieSubtitles,
            ),
          ),
        const SizedBox(width: 12),
        if (_isInProgress) ...[
          Text(
            '${(_progressRatio * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ProgressBar(
              ratio: _progressRatio,
              accentColor: AppColors.moviesAccent,
              timeLabel: ProgressOverlay.buildTimeLabel(
                positionSeconds: _progress?.positionSeconds,
                durationSeconds: _progress?.durationSeconds,
              ),
            ),
          ),
        ] else
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );

    if (disabled) return playWidget;

    return FocusableWidget(
      onSelect: () => _openPlayer(
        _movieVideoUrl!,
        widget.content.displayName,
        subtitles: _movieSubtitles,
      ),
      borderRadius: 8,
      child: playWidget,
    );
  }

  Widget _buildMovieInfo() {
    final c = widget.content;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          c.displayName,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (c.score != null) _ratingBadge(c.score!),
            if (c.year != null) _metaChip(c.year!.toString()),
            if (c.runtime != null) _metaChip('${c.runtime} min'),
            if (_isCompleted) const _CompletoBadge(),
            if (c.genres.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: c.genres
                    .map(
                      (g) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.moviesAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.moviesAccent.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Text(
                          g,
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
        // if (_isInProgress) ...[const SizedBox(height: 10), _buildProgressBar()],
        const SizedBox(height: 16),
        if ((c.description ?? '').isNotEmpty)
          Text(
            c.description!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
      ],
    );
  }

  // Widget _buildProgressBar() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Row(
  //         children: [
  //           const Icon(
  //             Icons.play_circle_outline,
  //             color: AppColors.moviesAccent,
  //             size: 14,
  //           ),
  //           const SizedBox(width: 4),
  //           Text(
  //             '${(_progressRatio * 100).toStringAsFixed(0)}% assistido',
  //             style: const TextStyle(color: Colors.white70, fontSize: 12),
  //           ),
  //         ],
  //       ),
  //       const SizedBox(height: 6),
  //       ProgressBar(
  //         ratio: _progressRatio,
  //         accentColor: AppColors.moviesAccent,
  //         timeLabel: ProgressOverlay.buildTimeLabel(
  //           positionSeconds: _progress?.positionSeconds,
  //           durationSeconds: _progress?.durationSeconds,
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _ratingBadge(double score) {
    return Container(
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
            score.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Mapa de código de idioma do JSON → código ISO para o player.
  static const Map<String, String> _subtitleLangMap = {
    'pob': 'pt-BR',
    'por': 'pt-BR',
    'pt': 'pt',
    'eng': 'en',
    'en': 'en',
    'spa': 'es',
    'es': 'es',
    'fra': 'fr',
    'fr': 'fr',
    'deu': 'de',
    'ger': 'de',
    'de': 'de',
    'ita': 'it',
    'jpn': 'ja',
  };

  static const Map<String, String> _subtitleDisplayNames = {
    'pt-BR': 'Português (Brasil)',
    'pt': 'Português',
    'en': 'Inglês',
    'es': 'Espanhol',
    'fr': 'Francês',
    'de': 'Alemão',
    'it': 'Italiano',
    'ja': 'Japonês',
  };

  /// Converte [ExternalSubtitleEntry] do JSON index para
  /// [SubtitleTrackInfo] usado pelo player.
  static List<SubtitleTrackInfo> _resolveSubtitlesFromJson(
    List<ExternalSubtitleEntry>? entries,
    String serverUrl,
  ) {
    if (entries == null || entries.isEmpty) return const [];
    return entries.map((entry) {
      final langCode = _subtitleLangMap[entry.lang] ?? entry.lang;
      final displayName = _subtitleDisplayNames[langCode] ?? entry.lang;
      return SubtitleTrackInfo(
        url: entry.file, // já é URL absoluta (resolvida em fromMovieIndex)
        language: langCode,
        displayName: displayName,
      );
    }).toList();
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Botão de play circular discreto usado no topo do conteúdo.
class _PlayCircle extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color accentColor;
  final VoidCallback? onTap;

  const _PlayCircle({
    required this.icon,
    required this.enabled,
    this.accentColor = AppColors.moviesAccent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled ? accentColor : Colors.white12,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

/// Badge "✓ Completo" no metadata row.
class _CompletoBadge extends StatelessWidget {
  const _CompletoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 12),
          SizedBox(width: 4),
          Text(
            'Completo',
            style: TextStyle(
              color: Colors.green,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
