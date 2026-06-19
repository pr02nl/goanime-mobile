import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../domain/models/anime.dart';
import '../domain/models/episode.dart';
import '../domain/models/pauloflix_movie.dart';
import '../domain/models/pauloflix_movie_item.dart';
import '../services/pauloflix_movies_service.dart';
import '../theme/app_colors.dart';
import '../widgets/pauloflix_movies_badge.dart';
import 'video_player_screen.dart';

class PauloFlixMovieDetailScreen extends StatefulWidget {
  final PauloFlixMovie content;

  const PauloFlixMovieDetailScreen({super.key, required this.content});

  @override
  State<PauloFlixMovieDetailScreen> createState() =>
      _PauloFlixMovieDetailScreenState();
}

class _PauloFlixMovieDetailScreenState
    extends State<PauloFlixMovieDetailScreen> {
  bool _isLoadingCollection = true;
  String? _error;
  List<PauloFlixMovieSubfolder> _collectionSubfolders = [];

  // Para filme individual
  String? _movieVideoUrl;
  List<SubtitleTrackInfo> _movieSubtitles = const [];
  bool _isResolvingSingle = false;

  @override
  void initState() {
    super.initState();
    if (widget.content.isCollection) {
      _loadCollectionChildren();
    } else {
      _resolveSingleMovie();
    }
  }

  Future<void> _resolveSingleMovie() async {
    setState(() => _isResolvingSingle = true);
    try {
      final file = await PauloFlixMoviesService.fetchMovieFile(
        widget.content.serverUrl,
      );
      if (!mounted) return;
      setState(() {
        _movieVideoUrl = file?.videoUrl;
        _movieSubtitles = file?.subtitles ?? const [];
        _isResolvingSingle = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao localizar vídeo: $e';
        _isResolvingSingle = false;
      });
    }
  }

  Future<void> _loadCollectionChildren() async {
    try {
      final response = await http
          .get(Uri.parse(widget.content.serverUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _error = 'Falha ao listar coleção (HTTP ${response.statusCode})';
          _isLoadingCollection = false;
        });
        return;
      }

      final links = _parseLinks(response.body);
      final subfolders = links
          .where((l) => l.href.endsWith('/'))
          .map(
            (l) => PauloFlixMovieSubfolder(
              name: l.name,
              url: '${widget.content.serverUrl}${l.href}',
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _collectionSubfolders = subfolders;
        _isLoadingCollection = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar coleção: $e';
        _isLoadingCollection = false;
      });
    }
  }

  static List<_LinkEntry> _parseLinks(String htmlBody) {
    final regExp = RegExp(r'<a href="([^"]+)"[^>]*>([^<]+)</a>');
    final matches = regExp.allMatches(htmlBody);
    final entries = <_LinkEntry>[];
    for (final m in matches) {
      final href = m.group(1) ?? '';
      final text = (m.group(2) ?? '').trim();
      if (href.isEmpty || href == '../' || text.isEmpty || text == '../') {
        continue;
      }
      final rawName = text.endsWith('/')
          ? text.substring(0, text.length - 1)
          : text;
      final name = PauloFlixMoviesService.safeDecodeComponent(rawName);
      entries.add(_LinkEntry(href: href, name: name));
    }
    return entries;
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModernVideoPlayerScreen(
          episode: Episode(
            number: '1',
            url: videoUrl,
            subtitleTracks: episodeTracks,
          ),
          animeTitle: title,
          isMovie: true,
          anime: Anime(
            name: title,
            url: widget.content.serverUrl,
            source: AnimeSource.pauloFlix,
            fallbackImageUrl: widget.content.imageUrl,
          ),
        ),
      ),
    );
  }

  Future<void> _openSubfolder(PauloFlixMovieSubfolder sub) async {
    try {
      final file = await PauloFlixMoviesService.fetchMovieFile(sub.url);
      if (!mounted) return;
      if (file != null) {
        _openPlayer(
          file.videoUrl,
          file.cleanedName.isEmpty ? sub.name : file.cleanedName,
          subtitles: file.subtitles,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum arquivo de vídeo encontrado')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: widget.content.isCollection
          ? _buildCollectionView()
          : _buildSingleMovieView(),
    );
  }

  Widget _buildSingleMovieView() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverToBoxAdapter(child: _buildSingleMovieInfo()),
        SliverToBoxAdapter(child: _buildActionButtons()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildCollectionView() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        if (_isLoadingCollection)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          SliverFillRemaining(child: _buildError())
        else if (_collectionSubfolders.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'Coleção vazia',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, i) {
              final sub = _collectionSubfolders[i];
              return _buildSubfolderTile(sub);
            }, childCount: _collectionSubfolders.length),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildSubfolderTile(PauloFlixMovieSubfolder sub) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.movie_outlined,
          color: Color(0xFF06B6D4),
          size: 28,
        ),
      ),
      title: Text(
        sub.name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(
        Icons.play_circle_outline,
        color: Color(0xFFDC2626),
        size: 32,
      ),
      onTap: () => _openSubfolder(sub),
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

  Widget _buildSingleMovieInfo() {
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
              if (c.isCollection)
                const CollectionBadge(fontSize: 12)
              else
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
    final disabled = _isResolvingSingle || _movieVideoUrl == null;
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
          icon: _isResolvingSingle
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.play_arrow_rounded, size: 28),
          label: Text(
            _isResolvingSingle ? 'Localizando vídeo...' : 'Assistir',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

class _LinkEntry {
  final String href;
  final String name;
  const _LinkEntry({required this.href, required this.name});
}
