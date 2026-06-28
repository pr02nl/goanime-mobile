import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/anime.dart';
import '../../../domain/models/episode.dart';
import '../../../domain/models/paulo_flix_movie_progress_record.dart';
import '../../../domain/models/pauloflix_movie.dart';
import '../../../domain/models/pauloflix_movie_item.dart';
import '../../../domain/repositories/paulo_flix_movie_progress_repository.dart';
import '../../../routing/route_data.dart';
import '../../core/themes/app_colors.dart';
import '../../core/widgets/completed_badge.dart';
import '../../core/widgets/pauloflix_movies_badge.dart';

class PauloFlixMovieDetailScreen extends StatefulWidget {
  final PauloFlixMovie content;

  const PauloFlixMovieDetailScreen({super.key, required this.content});

  @override
  State<PauloFlixMovieDetailScreen> createState() =>
      _PauloFlixMovieDetailScreenState();
}

class _PauloFlixMovieDetailScreenState
    extends State<PauloFlixMovieDetailScreen> {
  String? _error;

  // Para filme individual
  String? _movieVideoUrl;
  List<SubtitleTrackInfo> _movieSubtitles = const [];

  // Progresso do filme
  PauloFlixMovieProgressRecord? _progress;

  @override
  void initState() {
    super.initState();
    _resolveSingleMovie();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final repo = context.read<PauloFlixMovieProgressRepository?>();
      if (repo != null && mounted) {
        final progress = await repo.getProgress(widget.content.folderName);
        if (mounted) setState(() => _progress = progress);
      }
    } catch (e) {
      debugPrint('[MovieDetail] Erro ao carregar progresso: $e');
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

  void _openPlayer(
    String videoUrl,
    String title, {
    List<SubtitleTrackInfo> subtitles = const [],
  }) {
    // Converte SubtitleTrackInfo → EpisodeSubtitleTrack para passar pro player.
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

    context.pushNamed(
      'player',
      extra: PlayerRouteData(
        episode: Episode(
          number: '1',
          url: videoUrl,
          subtitleTracks: episodeTracks,
        ),
        animeTitle: title,
        isMovie: true,
        movieFolderName: widget.content.folderName,
        anime: Anime(
          name: title,
          url: widget.content.serverUrl,
          source: AnimeSource.pauloFlix,
          fallbackImageUrl: widget.content.imageUrl,
        ),
      ),
    );
  }

  // ─── Getters de estado do progresso ────────────────────────────────

  bool get _isCompleted => _progress?.isCompleted ?? false;

  bool get _isInProgress {
    if (_progress == null) return false;
    return _progress!.positionSeconds > 0 && !_progress!.isCompleted;
  }

  double get _progressRatio => _progress?.progressRatio ?? 0.0;

  String get _buttonLabel {
    if (_isCompleted) return 'Reassistir';
    if (_isInProgress) return 'Continuar';
    return 'Assistir';
  }

  IconData get _buttonIcon {
    if (_isCompleted) return Icons.replay_rounded;
    if (_isInProgress) return Icons.play_arrow_rounded;
    return Icons.play_arrow_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildMovieInfo()),
          if (_error != null) SliverToBoxAdapter(child: _buildError()),
          SliverToBoxAdapter(child: _buildActionButtons()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasBanner = (widget.content.bannerUrl ?? '').isNotEmpty;

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (hasBanner)
              CachedNetworkImage(
                imageUrl: widget.content.bannerUrl!,
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
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colorScheme.primary, colorScheme.secondary],
                    ),
                  ),
                ),
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
            // Overlay Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieInfo() {
    final c = widget.content;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              c.displayName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const PauloFlixMoviesBadge(fontSize: 12),
              if (c.score != null) _ratingBadge(c.score!),
              if (c.year != null) _metaChip(c.year!.toString()),
              if (c.runtime != null) _metaChip('${c.runtime} min'),
              // Badge de completado
              if (_isCompleted) _completionBadge(),
            ],
          ),
          // Barra de progresso (se em andamento)
          if (_isInProgress) ...[
            const SizedBox(height: 12),
            _buildProgressBar(),
          ],
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
                          color: AppColors.moviesAccent.withValues(alpha: 0.3),
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
    );
  }

  /// Badge verde "✓ Completo" exibido ao lado dos metadados.
  Widget _completionBadge() {
    return CompletedBadge.detailScreen();
  }

  /// Barra de progresso horizontal (em andamento).
  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.play_circle_outline,
              color: AppColors.moviesAccent,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              '${(_progressRatio * 100).toStringAsFixed(0)}% assistido',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: _progressRatio,
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.moviesAccent),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final disabled = _movieVideoUrl == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: disabled
              ? null
              : () => _openPlayer(
                  _movieVideoUrl!,
                  widget.content.displayName,
                  subtitles: _movieSubtitles,
                ),
          icon: Icon(_buttonIcon, size: 28),
          label: Text(
            _buttonLabel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isCompleted
                ? Colors.green
                : AppColors.moviesAccent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.white12,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

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
