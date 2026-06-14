import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/anime.dart';
import '../models/pauloflix_models.dart';
import '../services/anime_service.dart';
import '../services/pauloflix_service.dart';
import '../theme/app_colors.dart';
import '../theme/netflix_theme.dart';
import '../widgets/focusable_widget.dart';
import '../widgets/watchlist_button.dart';
import 'modern_episode_list_screen.dart';

class SourceSelectionScreen extends StatefulWidget {
  final String animeTitle;
  final String imageUrl;
  final String myAnimeListUrl;

  const SourceSelectionScreen({
    super.key,
    required this.animeTitle,
    required this.imageUrl,
    required this.myAnimeListUrl,
  });

  @override
  State<SourceSelectionScreen> createState() => _SourceSelectionScreenState();
}

class _SourceSelectionScreenState extends State<SourceSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  bool _isSearchingAnimeFire = false;
  List<Anime> _animeFireResults = [];
  String? _animeFireErrorMessage;

  bool _isFetchingPauloFlix = false;
  List<PauloFlixShow> _pauloFlixShows = [];
  String? _pauloFlixErrorMessage;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
    _searchAnimeFire();
    _fetchPauloFlixShows();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _searchAnimeFire() async {
    setState(() {
      _isSearchingAnimeFire = true;
      _animeFireErrorMessage = null;
    });

    try {
      final results = await AnimeService.searchAnime(widget.animeTitle);
      final animeFireResults = results
          .where((a) => a.source == AnimeSource.animeFire)
          .toList();

      if (animeFireResults.isNotEmpty) {
        setState(() {
          _animeFireResults = animeFireResults;
          _isSearchingAnimeFire = false;
        });
      } else {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        setState(() {
          _isSearchingAnimeFire = false;
          _animeFireErrorMessage = l10n.animeNotFoundOnAnimeFire;
        });
      }
    } catch (e) {
      debugPrint('Error searching AnimeFire: $e');
      setState(() {
        _isSearchingAnimeFire = false;
        _animeFireErrorMessage = 'Error searching on AnimeFire';
      });
    }
  }

  Future<void> _fetchPauloFlixShows() async {
    setState(() {
      _isFetchingPauloFlix = true;
      _pauloFlixErrorMessage = null;
    });

    try {
      final shows = await PauloFlixService.fetchAllShows();
      if (shows.isNotEmpty) {
        setState(() {
          _pauloFlixShows = shows;
          _isFetchingPauloFlix = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isFetchingPauloFlix = false;
          _pauloFlixErrorMessage = 'No shows available on PauloFlix';
        });
      }
    } catch (e) {
      debugPrint('Error fetching PauloFlix shows: $e');
      if (!mounted) return;
      setState(() {
        _isFetchingPauloFlix = false;
        _pauloFlixErrorMessage = 'Error connecting to PauloFlix';
      });
    }
  }

  Future<void> _selectSource(AnimeSource source) async {
    if (source == AnimeSource.animeFire && _animeFireResults.isNotEmpty) {
      // Se houver múltiplos resultados, mostra dialog para escolher
      if (_animeFireResults.length > 1) {
        final selectedAnime = await _showVersionSelectionDialog(
          source: source,
          animeFireAnimes: _animeFireResults,
        );
        if (selectedAnime == null) return; // User cancelled

        // Enrich with AniList data before navigating
        await AnimeService.enrichAnimeWithAniList(selectedAnime);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ModernEpisodeListScreen(anime: selectedAnime),
          ),
        );
      } else {
        // Apenas um resultado, usa diretamente
        final anime = _animeFireResults.first;

        // Enrich with AniList data before navigating
        await AnimeService.enrichAnimeWithAniList(anime);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ModernEpisodeListScreen(anime: anime),
          ),
        );
      }
    } else {
      // Fallback (não deveria acontecer)
      final anime = Anime(
        name: widget.animeTitle,
        url: widget.myAnimeListUrl,
        fallbackImageUrl: widget.imageUrl,
        source: source,
      );

      // Enrich with AniList data before navigating
      await AnimeService.enrichAnimeWithAniList(anime);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ModernEpisodeListScreen(anime: anime),
        ),
      );
    }
  }

  Future<void> _selectPauloFlixSource() async {
    if (_pauloFlixShows.isEmpty) return;

    final selectedShow = await _showPauloFlixShowsDialog();
    if (selectedShow == null) return; // User cancelled

    // PauloFlix shows don't need AniList enrichment - direct file server content
    final anime = Anime(
      name: selectedShow.name,
      url: selectedShow.url,
      source: AnimeSource.pauloFlix,
      fallbackImageUrl: null,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ModernEpisodeListScreen(anime: anime),
      ),
    );
  }

  Future<PauloFlixShow?> _showPauloFlixShowsDialog() async {
    final l10n = AppLocalizations.of(context);

    return showDialog<PauloFlixShow>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          title: Text(
            l10n.locale.languageCode == 'pt'
                ? 'Selecione o Show'
                : 'Select Show',
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.locale.languageCode == 'pt'
                      ? 'PauloFlix tem ${_pauloFlixShows.length} shows disponíveis'
                      : 'PauloFlix has ${_pauloFlixShows.length} shows available',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _pauloFlixShows.length,
                    itemBuilder: (context, index) {
                      final show = _pauloFlixShows[index];
                      return ListTile(
                        title: Text(
                          show.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          color: AppColors.primary,
                        ),
                        onTap: () => Navigator.pop(context, show),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.locale.languageCode == 'pt' ? 'Cancelar' : 'Cancel',
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<dynamic> _showVersionSelectionDialog({
    required AnimeSource source,
    List<Anime>? animeFireAnimes,
  }) async {
    final l10n = AppLocalizations.of(context);

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          title: Text(
            l10n.locale.languageCode == 'pt'
                ? 'Selecione a versão'
                : 'Select Version',
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: animeFireAnimes?.length ?? 0,
              itemBuilder: (context, index) {
                if (source == AnimeSource.animeFire &&
                    animeFireAnimes != null) {
                  final anime = animeFireAnimes[index];
                  return ListTile(
                    title: Text(
                      anime.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.primary,
                    ),
                    onTap: () => Navigator.pop(context, anime),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.locale.languageCode == 'pt' ? 'Cancelar' : 'Cancel',
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // AppBar com imagem do anime
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                l10n.selectVersion,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 8,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: AppColors.surface),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.surface,
                      child: const Icon(
                        Icons.error,
                        color: NetflixTheme.textTertiary,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.background.withValues(alpha: 0.8),
                          AppColors.background,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Conteúdo
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Título do anime com botão de watchlist
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          widget.animeTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 8),
                      WatchlistButton(
                        animeId: widget.myAnimeListUrl,
                        title: widget.animeTitle,
                        coverImage: widget.imageUrl,
                        myAnimeListUrl: widget.myAnimeListUrl,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.selectVersion,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Opção AnimeFire
                  _buildSourceCard(
                    title: 'AnimeFire',
                    subtitle: _isSearchingAnimeFire
                        ? l10n.searching
                        : _animeFireResults.isNotEmpty
                        ? _animeFireResults.length > 1
                              ? 'Available • ${_animeFireResults.length} versions found'
                              : 'Available • Dubbed/Subtitled'
                        : _animeFireErrorMessage ?? 'Unavailable',
                    icon: Icons.local_fire_department,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                    ),
                    available: _animeFireResults.isNotEmpty,
                    isLoading: _isSearchingAnimeFire,
                    onTap: _animeFireResults.isNotEmpty
                        ? () => _selectSource(AnimeSource.animeFire)
                        : null,
                  ),

                  const SizedBox(height: 16),

                  // Opção PauloFlix
                  _buildSourceCard(
                    title: 'PauloFlix',
                    subtitle: _isFetchingPauloFlix
                        ? l10n.searching
                        : _pauloFlixShows.isNotEmpty
                        ? 'Available • ${_pauloFlixShows.length} shows'
                        : _pauloFlixErrorMessage ?? 'Unavailable',
                    icon: Icons.dns,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    available: _pauloFlixShows.isNotEmpty,
                    isLoading: _isFetchingPauloFlix,
                    onTap: _pauloFlixShows.isNotEmpty
                        ? () => _selectPauloFlixSource()
                        : null,
                  ),

                  const SizedBox(height: 32),

                  // Info adicional
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.locale.languageCode == 'pt'
                                ? 'Cada fonte pode ter episódios diferentes disponíveis'
                                : 'Each source may have different episodes available',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required bool available,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    return FocusableWidget(
      onSelect: available && !isLoading ? onTap : null,
      borderRadius: 20,
      focusPadding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          gradient: available && !isLoading
              ? gradient
              : LinearGradient(
                  colors: [Colors.grey.shade800, Colors.grey.shade700],
                ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: available && !isLoading
              ? [
                  BoxShadow(
                    color: gradient.colors.first.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Ícone
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),

              // Textos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Indicador
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              else if (available)
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 20,
                )
              else
                Icon(
                  Icons.block,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
