/// Tela principal de filmes PauloFlix — reescrita multi-seção.
///
/// Layout (top → bottom):
/// 1. AppBar pinned com badge "PauloFlix" + título "Filmes" + botão sync
/// 2. Banner de progresso de sync (quando ativo)
/// 3. Hero banner (filme/coleção top-rated)
/// 4. Carrossel "Coleções" (se houver)
/// 5. Carrossel "Mais Bem Avaliados" (top 12 por score)
/// 6. Carrossel "Recentes" (top 12 por ano)
/// 7. Carrosséis por gênero top 4 (≥3 filmes por gênero)
/// 8. Grid paginado "Todos os Filmes" com índice A–Z
///
/// Toda a organização é feita em [initState] a partir de snapshot local
/// — NÃO chama `provider.search()` (anti-pattern #12 do skill
/// `flutter-reactivity-gotchas`).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/anime.dart';
import '../../../domain/models/episode.dart';
import '../../../domain/models/paulo_flix_movie_progress_record.dart';
import '../../../domain/models/pauloflix_movie.dart';
import '../../../domain/repositories/paulo_flix_movie_progress_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/route_data.dart';
import '../../core/themes/app_colors.dart';
import '../../core/utils/pagination.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/tv_detector.dart';
import '../../core/widgets/focusable_widget.dart';
import '../../core/widgets/netflix_card.dart';
import '../../core/widgets/netflix_carousel.dart';
import '../../core/widgets/pauloflix_movies_badge.dart';
import '../models/movie_progress_state.dart';
import '../view_models/paulo_flix_movie_continue_watching_viewmodel.dart';
import '../view_models/pauloflix_movies_provider.dart';
import '_empty_state.dart';
import '_movie_hero_banner.dart';
import '_movie_section.dart';
import '_movies_paginated_grid.dart';

class PauloFlixMoviesHomeScreen extends StatefulWidget {
  const PauloFlixMoviesHomeScreen({super.key});

  @override
  State<PauloFlixMoviesHomeScreen> createState() =>
      _PauloFlixMoviesHomeScreenState();
}

class _PauloFlixMoviesHomeScreenState extends State<PauloFlixMoviesHomeScreen> {
  bool _checkedInitialSync = false;
  bool _isTV = false;

  // ─── Snapshot derivado (memoizado por hash do conteúdo) ─────────────
  List<PauloFlixMovie> _allContents = const [];
  PaginationResult<PauloFlixMovie> _pagination =
      const PaginationResult<PauloFlixMovie>(
        pages: [],
        letterToPageIndex: {},
        availableLetters: [],
      );
  List<PauloFlixMovie> _topRated = const [];
  List<PauloFlixMovie> _recent = const [];
  Map<String, List<PauloFlixMovie>> _byGenre = const {};
  PauloFlixMovie? _featured;
  int _snapshotHash = 0;

  /// Mapa folderName → estado de progresso para overlays nos cards.
  Map<String, MovieProgressState> _progressMap = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<PauloFlixMoviesProvider>();
      await provider.loadContents();
      if (!mounted) return;

      // Primeira abertura: TMDB não configurado OU banco vazio → sincronizar.
      if (!_checkedInitialSync) {
        _checkedInitialSync = true;
        provider.syncContent();
      }

      await _loadAllProgress();

      final screenWidth =
          WidgetsBinding
              .instance
              .platformDispatcher
              .views
              .first
              .physicalSize
              .width /
          WidgetsBinding
              .instance
              .platformDispatcher
              .views
              .first
              .devicePixelRatio;
      final isTvBuild = await TVDetector.isTV;
      if (mounted) {
        setState(() {
          _isTV = isTvBuild || screenWidth >= Responsive.tabletMaxWidth;
        });
      }
    });
  }

  /// Carrega TODO progresso salvo (em andamento + completo) e constrói
  /// o mapa folderName → MovieProgressState para overlays nos cards.
  Future<void> _loadAllProgress() async {
    try {
      final repo = context.read<PauloFlixMovieProgressRepository?>();
      if (repo == null) return;
      final all = await repo.getAllProgress();
      if (!mounted) return;
      final map = <String, MovieProgressState>{};
      for (final p in all) {
        map[p.folderName] = MovieProgressState(
          ratio: p.progressRatio,
          isCompleted: p.isCompleted,
        );
      }
      setState(() => _progressMap = map);
    } catch (e) {
      debugPrint('[MoviesHome] Erro ao carregar progresso: $e');
    }
  }

  /// Memoiza o snapshot derivado. Recomputa apenas se o conteúdo mudou
  /// (medido por `length + identidade do primeiro item`).
  void _ensureSnapshotBuilt(List<PauloFlixMovie> contents) {
    final newHash =
        contents.length ^
        (contents.isNotEmpty ? contents.first.hashCode : 0) ^
        (contents.isNotEmpty ? contents.last.hashCode : 0);
    if (newHash == _snapshotHash) return;
    _snapshotHash = newHash;

    // Cópia defensiva (anti-pattern #12).
    _allContents = List<PauloFlixMovie>.from(contents);

    // 1. Hero — top-rated global.
    _featured = PauloFlixMoviesProvider.pickFeaturedMovie(_allContents);

    // 2. Top rated (top 12 por score).
    _topRated = [..._allContents]
      ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
    if (_topRated.length > 12) _topRated = _topRated.sublist(0, 12);

    // 4. Recentes (top 12 por year desc).
    _recent = [..._allContents]
      ..sort((a, b) {
        final yearCmp = (b.year ?? 0).compareTo(a.year ?? 0);
        if (yearCmp != 0) return yearCmp;
        return (b.score ?? 0).compareTo(a.score ?? 0);
      });
    _recent = _recent.where((m) => m.year != null).toList();
    if (_recent.length > 12) _recent = _recent.sublist(0, 12);

    // 5. Por gênero (top 4 com ≥3 filmes).
    _byGenre = PauloFlixMoviesProvider.groupByTopGenres(
      _allContents,
      maxGenres: 4,
      perGenre: 12,
      minPerGenre: 3,
    );

    // 6. Paginação (24/página).
    _pagination = PauloFlixMoviesProvider.paginateByLetter(
      _allContents,
      perPage: 24,
    );
  }

  void _syncContent() {
    context.read<PauloFlixMoviesProvider>().syncContent();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<PauloFlixMoviesProvider>();
    final contents = provider.contents;
    final isSyncing = provider.isSyncing;

    // Memoiza as seções se o conteúdo mudou.
    _ensureSnapshotBuilt(contents);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(l10n, isSyncing),
          if (isSyncing && provider.syncProgress.isNotEmpty)
            _buildSyncBanner(provider),
          if (contents.isEmpty && isSyncing)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFDC2626)),
              ),
            )
          else if (contents.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: MoviesEmptyState(isSyncing: false, onSync: _syncContent),
            )
          else
            ..._buildContentSliversWithContinueWatching(context, l10n),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  List<Widget> _buildContentSlivers(AppLocalizations l10n) {
    final slivers = <Widget>[];

    // 1. Hero banner.
    if (_featured != null) {
      final featuredProgress = _progressMap[_featured!.folderName];
      slivers.add(
        SliverToBoxAdapter(
          child: MovieHeroBanner(
            movie: _featured!,
            isTV: _isTV,
            progress: featuredProgress,
          ),
        ),
      );
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
    }
    slivers.add(
      SliverToBoxAdapter(child: _buildContinueWatchingSection(context)),
    );

    // 2. Mais bem avaliados.
    if (_topRated.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: MovieSection(
            title: l10n.sectionTopRated,
            icon: Icons.star,
            movies: _topRated,
            isTV: _isTV,
            progressMap: _progressMap,
          ),
        ),
      );
    }

    // 4. Recentes.
    if (_recent.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: MovieSection(
            title: l10n.sectionRecent,
            icon: Icons.new_releases,
            movies: _recent,
            isTV: _isTV,
            progressMap: _progressMap,
          ),
        ),
      );
    }

    // 5. Por gênero (apenas os 4 top com ≥3 filmes).
    for (final entry in _byGenre.entries) {
      if (entry.value.length < 3) continue;
      slivers.add(
        SliverToBoxAdapter(
          child: MovieSection(
            title: entry.key,
            icon: _iconForGenre(entry.key),
            movies: entry.value,
            isTV: _isTV,
            progressMap: _progressMap,
          ),
        ),
      );
    }

    // 6. Grid paginado "Todos os Filmes" com índice A–Z.
    slivers.add(SliverToBoxAdapter(child: _buildAllMoviesSection(l10n)));

    return slivers;
  }

  Widget _buildAllMoviesSection(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.movie_filter,
                  size: 22,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(width: 8),
                Text(
                  '${l10n.sectionAllMovies} (${_allContents.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MoviesPaginatedGrid(
            pagination: _pagination,
            isTV: _isTV,
            progressMap: _progressMap,
          ),
        ],
      ),
    );
  }

  IconData _iconForGenre(String genre) {
    final name = PauloFlixMoviesProvider.genreIcon(genre);
    return _genreIconMap[name] ??
        const IconData(0xe02c, fontFamily: 'MaterialIcons');
  }

  // Mapeamento de nome → codePoint. Constante para satisfazer
  // `const IconData(codePoint, fontFamily)`. Fallback = movie_outlined.
  static const Map<String, IconData> _genreIconMap = {
    'flash_on': IconData(0xe3e7, fontFamily: 'MaterialIcons'),
    'explore': IconData(0xe87a, fontFamily: 'MaterialIcons'),
    'animation': IconData(0xe65a, fontFamily: 'MaterialIcons'),
    'sentiment_very_satisfied': IconData(0xea20, fontFamily: 'MaterialIcons'),
    'gavel': IconData(0xe90e, fontFamily: 'MaterialIcons'),
    'article': IconData(0xe238, fontFamily: 'MaterialIcons'),
    'theater_comedy': IconData(0xea66, fontFamily: 'MaterialIcons'),
    'family_restroom': IconData(0xe6f2, fontFamily: 'MaterialIcons'),
    'auto_awesome': IconData(0xe65f, fontFamily: 'MaterialIcons'),
    'history_edu': IconData(0xea3e, fontFamily: 'MaterialIcons'),
    'dark_mode': IconData(0xe51c, fontFamily: 'MaterialIcons'),
    'music_note': IconData(0xe405, fontFamily: 'MaterialIcons'),
    'search': IconData(0xe8b6, fontFamily: 'MaterialIcons'),
    'favorite': IconData(0xe87d, fontFamily: 'MaterialIcons'),
    'rocket_launch': IconData(0xeb5b, fontFamily: 'MaterialIcons'),
    'tv': IconData(0xe333, fontFamily: 'MaterialIcons'),
    'psychology': IconData(0xea4a, fontFamily: 'MaterialIcons'),
    'military_tech': IconData(0xea3f, fontFamily: 'MaterialIcons'),
    'landscape': IconData(0xe564, fontFamily: 'MaterialIcons'),
    'movie_outlined': IconData(0xe02c, fontFamily: 'MaterialIcons'),
  };

  // ─── AppBar + Sync banner ──────────────────────────────────────────

  Widget _buildAppBar(AppLocalizations l10n, bool isSyncing) {
    return SliverAppBar(
      expandedHeight: 110,
      pinned: true,
      backgroundColor: AppColors.background,
      actions: [
        if (isSyncing)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFDC2626),
              ),
            ),
          )
        else
          FocusableWidget(
            onSelect: _syncContent,
            borderRadius: 24,
            focusPadding: EdgeInsets.zero,
            child: IconButton(
              icon: const Icon(Icons.sync),
              tooltip: l10n.sync,
              onPressed: _syncContent,
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 14),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PauloFlixMoviesBadge(
              fontSize: 13,
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.movies,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói a seção "Continue assistindo" para filmes.
  ///
  /// Usa um `ChangeNotifierProvider` local com o
  /// `PauloFlixMovieContinueWatchingViewModel` e renderiza cards
  /// dos filmes com progresso parcial.
  Widget _buildContinueWatchingSection(BuildContext context) {
    return ChangeNotifierProvider<PauloFlixMovieContinueWatchingViewModel>(
      create: (ctx) => PauloFlixMovieContinueWatchingViewModel(
        repository: ctx.read<PauloFlixMovieProgressRepository>(),
      ),
      child: Consumer<PauloFlixMovieContinueWatchingViewModel>(
        builder: (_, vm, _) {
          if (vm.loading) return const SizedBox.shrink();
          return _MovieContinueWatchingCarousel(
            contents: vm.contents,
            isTV: _isTV,
          );
        },
      ),
    );
  }

  /// Retorna os slivers de conteúdo com a seção "Continue assistindo"
  /// inserida no topo (antes dos carrosséis).
  List<Widget> _buildContentSliversWithContinueWatching(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return _buildContentSlivers(l10n);
  }

  Widget _buildSyncBanner(PauloFlixMoviesProvider provider) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFDC2626).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                provider.syncProgress,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carrossel "Continue assistindo" para filmes PauloFlix.
///
/// Exibe cards horizontais dos filmes com progresso parcial.
/// Some completamente quando a lista está vazia.
class _MovieContinueWatchingCarousel extends StatelessWidget {
  final List<PauloFlixMovieProgressRecord> contents;
  final bool isTV;

  const _MovieContinueWatchingCarousel({
    required this.contents,
    this.isTV = false,
  });

  @override
  Widget build(BuildContext context) {
    if (contents.isEmpty) return const SizedBox.shrink();

    return NetflixCarousel(
      title: 'Continue assistindo',
      isTV: isTV,
      items: contents.map((r) => _buildCard(context, r)).toList(),
    );
  }

  Widget _buildCard(BuildContext context, PauloFlixMovieProgressRecord record) {
    // Overlay: barra de progresso.
    // O stream watchInProgressMovies já garante positionSeconds > 0,
    // então o overlay está sempre presente aqui.
    final overlay = _ProgressOverlay(ratio: record.progressRatio);

    return FocusableWidget(
      onSelect: () => _onTap(context, record),
      borderRadius: 6,
      focusPadding: EdgeInsets.zero,
      child: NetflixCard(
        imageUrl: record.imageUrl ?? '',
        title: record.displayName,
        showTitle: true,
        showRating: false,
        isTV: isTV,
        overlayWidget: overlay,
        onTap: () => _onTap(context, record),
      ),
    );
  }

  void _onTap(BuildContext context, PauloFlixMovieProgressRecord record) {
    context.pushNamed(
      'player',
      extra: PlayerRouteData(
        episode: Episode(number: '1', url: record.videoUrl ?? ''),
        animeTitle: record.displayName,
        isMovie: true,
        movieFolderName: record.folderName,
        anime: Anime(
          name: record.displayName,
          url: record.serverUrl,
          source: AnimeSource.pauloFlix,
          fallbackImageUrl: record.imageUrl,
        ),
      ),
    );
  }
}

/// Barra de progresso horizontal exibida na base do card de filme
/// no carrossel "Continue assistindo" (quando em andamento).
class _ProgressOverlay extends StatelessWidget {
  final double ratio;
  const _ProgressOverlay({required this.ratio});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: ratio,
          minHeight: 4,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
        ),
      ),
    );
  }
}
