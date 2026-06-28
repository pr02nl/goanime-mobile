import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/anime.dart';
import '../../../domain/models/episode.dart';
import '../../../domain/models/pauloflix_movie.dart';
import '../../../domain/models/pauloflix_movie_item.dart';
import '../../../routing/route_data.dart';
import '../../core/themes/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _resolveSingleMovie();
  }

  void _resolveSingleMovie() {
    if (widget.content.videoUrl != null) {
      _movieVideoUrl = widget.content.videoUrl;
      _movieSubtitles = _resolveSubtitlesFromJson(
        widget.content.subtitles,
        widget.content.serverUrl,
      );
    } else {
      _error = 'Este filme não possui URL de vídeo no índice. '
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
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.background,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.content.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if ((widget.content.bannerUrl ?? '').isNotEmpty)
              Image.network(
                widget.content.bannerUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, e, s) => Container(color: AppColors.surface),
              )
            else
              Container(color: AppColors.surface),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 120,
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
    );
  }

  Widget _buildMovieInfo() {
    final c = widget.content;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const PauloFlixMoviesBadge(fontSize: 12),
              if (c.score != null) _ratingBadge(c.score!),
              if (c.year != null) _metaChip(c.year!.toString()),
              if (c.runtime != null) _metaChip('${c.runtime} min'),
            ],
          ),
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
                        color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.3),
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
          icon: const Icon(Icons.play_arrow_rounded, size: 28),
          label: const Text(
            'Assistir',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
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
